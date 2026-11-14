//! The realm's tables, as the rules and the clients both read them.
//!
//! Each row is a plain struct and a SpacetimeDB table at once. A table
//! marked `public` is read by every client; the rest are read through
//! views that show each player their own rows.

use crate::row;
use crate::store::{Seconds, Table, World};

/// The realm itself: one row, keyed 0.
#[spacetimedb::table(accessor = realm, public)]
#[derive(Clone, Debug, PartialEq)]
pub struct Realm {
    #[primary_key]
    pub id: u64,
    /// What the world was grown from.
    pub seed: u64,
    /// The moment the realm opened.
    pub opened: Seconds,
    /// How many times faster than written every build, march and harvest
    /// runs: 1 for the realm proper, more for a trial realm.
    pub pace: u32,
    /// The minute in which players last joined, and how many did.
    pub joining_minute: Seconds,
    pub joined_in_minute: u32,
    /// How many hexes the world reaches from the lake's heart.
    pub radius: u32,
}
row!(Realm in realm, by id);

/// A chunk of the land, sixteen hexes by sixteen: a byte a hex, its ground
/// (`land::Ground`), row by row. Keyed by the chunk's own place.
#[spacetimedb::table(accessor = land, public)]
#[derive(Clone, Debug, PartialEq)]
pub struct Land {
    #[primary_key]
    pub chunk: u64,
    pub ground: Vec<u8>,
}
row!(Land in land, by chunk);

/// What stands on a hex: at most one thing. Keyed by the hex.
#[spacetimedb::table(accessor = place, public)]
#[derive(Clone, Debug, PartialEq)]
pub struct Place {
    #[primary_key]
    pub hex: u64,
    /// What kind of thing (`Place::CITY` and the rest), and its number
    /// among its kind.
    pub kind: u8,
    pub id: u64,
}
row!(Place in place, by hex);

impl Place {
    pub const CITY: u8 = 1;
}

/// What a building costs and gives at a level, as the catalogue has it:
/// the game's numbers, for clients to show. Keyed by kind and level.
#[spacetimedb::table(accessor = blueprint, public)]
#[derive(Clone, Debug, PartialEq)]
pub struct Blueprint {
    #[primary_key]
    pub id: u64,
    pub building: u8,
    pub level: u32,
    pub name: String,
    /// What raising it to this level costs, and how long it takes in this
    /// realm.
    pub grain: u64,
    pub timber: u64,
    pub stone: u64,
    pub moonsalt: u64,
    pub seconds: Seconds,
    /// What it gives each hour at this level in this realm.
    pub grain_hourly: u64,
    pub timber_hourly: u64,
    pub stone_hourly: u64,
    pub moonsalt_hourly: u64,
    /// The Keep level it opens at, and the other building and level that
    /// must stand first (0 for none).
    pub opens_at: u32,
    pub needs_building: u8,
    pub needs_level: u32,
    pub power: u64,
}
row!(Blueprint in blueprint, by id);

impl Blueprint {
    pub fn key(building: u8, level: u32) -> u64 {
        ((building as u64) << 32) | level as u64
    }
}

/// A player, as everyone may know them.
#[spacetimedb::table(accessor = player, public)]
#[derive(Clone, Debug, PartialEq)]
pub struct Player {
    #[primary_key]
    #[auto_inc]
    pub id: u64,
    /// The name folded to one case and hashed: no two players share a
    /// name, however it is capitalised.
    #[index(btree)]
    pub name_key: u64,
    pub name: String,
    pub joined: Seconds,
    /// Whether they are connected now, and when they were last seen.
    pub online: bool,
    pub seen: Seconds,
}
row!(Player in player, auto, by id, name_key);

/// How fast a player has been asking things of the realm: theirs alone,
/// keyed by their player number.
#[spacetimedb::table(accessor = pace)]
#[derive(Clone, Debug, PartialEq)]
pub struct Pace {
    #[primary_key]
    pub player: u64,
    /// The start of the ten seconds being counted, and the count.
    pub window: Seconds,
    pub asked: u32,
}
row!(Pace in pace, by player);

/// A city: where it stands and whose it is, as everyone may know.
#[spacetimedb::table(accessor = city, public)]
#[derive(Clone, Debug, PartialEq)]
pub struct City {
    #[primary_key]
    #[auto_inc]
    pub id: u64,
    #[index(btree)]
    pub owner: u64,
    pub hex: u64,
    pub name: String,
    /// Its Keep's level, and the power of all that stands in it.
    pub keep: u32,
    pub power: u64,
    pub founded: Seconds,
    /// How many buildings it can raise at once.
    pub builders: u32,
}
row!(City in city, auto, by id, owner);

/// A building in a city. Its owner's alone to read, but for the Keep's
/// level, which the city shows.
#[spacetimedb::table(accessor = building)]
#[derive(Clone, Debug, PartialEq)]
pub struct Building {
    #[primary_key]
    #[auto_inc]
    pub id: u64,
    #[index(btree)]
    pub city: u64,
    /// Which building (`catalog::Building`), and its level: 0 while it is
    /// first being raised.
    pub kind: u8,
    pub level: u32,
}
row!(Building in building, auto, by id, city);

/// Something a city has under way that ends at a moment: its owner's
/// alone to read.
#[spacetimedb::table(accessor = job)]
#[derive(Clone, Debug, PartialEq)]
pub struct Job {
    #[primary_key]
    #[auto_inc]
    pub id: u64,
    #[index(btree)]
    pub city: u64,
    /// What kind of work (`Job::RAISE` and the rest), on what, and to what.
    pub kind: u8,
    pub subject: u64,
    pub level: u32,
    pub started: Seconds,
    pub ends: Seconds,
    /// The timer that ends it.
    pub timer: u64,
}
row!(Job in job, auto, by id, city);

impl Job {
    /// A building being raised a level: its subject is the building.
    pub const RAISE: u8 = 1;
}

/// A city's goods: its owner's alone to read. Keyed by the city.
///
/// The amounts are as they stood at `as_of`. Since then each has grown by
/// its hourly rate, up to `holds`: the rules settle that whenever they
/// touch the row, and a client reckons it for itself between times.
#[spacetimedb::table(accessor = stock)]
#[derive(Clone, Debug, PartialEq)]
pub struct Stock {
    #[primary_key]
    pub city: u64,
    pub grain: u64,
    pub timber: u64,
    pub stone: u64,
    pub moonsalt: u64,
    pub as_of: Seconds,
    pub grain_hourly: u64,
    pub timber_hourly: u64,
    pub stone_hourly: u64,
    pub moonsalt_hourly: u64,
    /// What each good had earned toward its next whole unit at `as_of`, in
    /// 3,600ths.
    pub grain_part: u32,
    pub timber_part: u32,
    pub stone_part: u32,
    pub moonsalt_part: u32,
    /// The most of each good the city keeps: nothing more comes in past it.
    pub holds: u64,
}
row!(Stock in stock, by city);

/// Everything the rules keep: every table, the clock, chance and timers.
pub trait Db:
    World
    + Table<Realm>
    + Table<Player>
    + Table<Pace>
    + Table<Land>
    + Table<Place>
    + Table<Blueprint>
    + Table<City>
    + Table<Building>
    + Table<Job>
    + Table<Stock>
{
}

impl<
        T: World
            + Table<Realm>
            + Table<Player>
            + Table<Pace>
            + Table<Land>
            + Table<Place>
            + Table<Blueprint>
            + Table<City>
            + Table<Building>
            + Table<Job>
            + Table<Stock>,
    > Db for T
{
}
