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
    pub const SITE: u8 = 2;
    pub const BARROW: u8 = 3;
}

/// Somewhere on the land where goods lie to be gathered, until they run
/// out. Everyone sees it, and whose army is working it.
#[spacetimedb::table(accessor = site, public)]
#[derive(Clone, Debug, PartialEq)]
pub struct Site {
    #[primary_key]
    #[auto_inc]
    pub id: u64,
    pub hex: u64,
    /// Which good lies there (`Site::GRAIN` and the rest), how rich it was
    /// found, and how much is left.
    pub kind: u8,
    pub level: u32,
    pub left: u64,
    /// The march gathering there now; 0 for none.
    pub gatherer: u64,
}
row!(Site in site, auto, by id);

impl Site {
    pub const GRAIN: u8 = 1;
    pub const TIMBER: u8 = 2;
    pub const STONE: u8 = 3;
    pub const MOONSALT: u8 = 4;
}

/// An army out of its city: where it set out from, where it is bound, the
/// way it takes and when it gets there. Everyone sees it on the map; what
/// it is made of and what it carries are its owner's alone to read.
///
/// On the way out or home it moves along `route` from `departed` to
/// `arrives`, at an even pace. Working, it stands at `to` until `arrives`.
#[spacetimedb::table(accessor = march, public)]
#[derive(Clone, Debug, PartialEq)]
pub struct March {
    #[primary_key]
    #[auto_inc]
    pub id: u64,
    #[index(btree)]
    pub owner: u64,
    #[index(btree)]
    pub city: u64,
    /// What it set out to do (`March::GATHER`), and what it is doing now
    /// (`March::GOING`, `WORKING`, `RETURNING`).
    pub kind: u8,
    pub state: u8,
    pub from: u64,
    pub to: u64,
    /// What it set out for: a site's number, a barrow's, or a city's.
    pub target: u64,
    pub departed: Seconds,
    pub arrives: Seconds,
    /// How many soldiers march.
    pub soldiers: u64,
    /// The way it is on now, hex by hex (`hex::decode`).
    pub route: Vec<u8>,
    pub timer: u64,
}
row!(March in march, auto, by id, owner, city);

impl March {
    /// To gather at a site.
    pub const GATHER: u8 = 1;
    /// To clear a barrow of the Unquiet.
    pub const HUNT: u8 = 2;
    /// To take another player's city by storm and plunder it.
    pub const ATTACK: u8 = 3;

    pub const GOING: u8 = 1;
    pub const WORKING: u8 = 2;
    pub const RETURNING: u8 = 3;
    /// Fighting where it stands, at `to`, until `arrives`.
    pub const FIGHTING: u8 = 4;
}

/// The soldiers of one kind and tier in a march: its owner's alone to
/// read. Keyed by march, kind and tier.
#[spacetimedb::table(accessor = squad)]
#[derive(Clone, Debug, PartialEq)]
pub struct Squad {
    #[primary_key]
    pub id: u64,
    #[index(btree)]
    pub march: u64,
    pub kind: u8,
    pub tier: u32,
    /// How many march fit to fight, and how many it carries wounded.
    pub count: u64,
    pub wounded: u64,
}
row!(Squad in squad, by id, march);

impl Squad {
    pub fn key(march: u64, kind: u8, tier: u32) -> u64 {
        (march << 16) | ((kind as u64) << 8) | tier as u64
    }
}

/// What a march carries home: its owner's alone to read. Keyed by the
/// march.
#[spacetimedb::table(accessor = haul)]
#[derive(Clone, Debug, PartialEq)]
pub struct Haul {
    #[primary_key]
    pub march: u64,
    #[index(btree)]
    pub owner: u64,
    pub grain: u64,
    pub timber: u64,
    pub stone: u64,
    pub moonsalt: u64,
}
row!(Haul in haul, by march, owner);

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
    /// When they last said something for others to read.
    pub said: Seconds,
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
    /// Until when it is at peace: no army may attack it before then.
    pub shield: Seconds,
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
    /// What kind of work (`Job::RAISE` and the rest), on what, and to what:
    /// a building and its new level, or a training building, the tier it
    /// trains and how many.
    pub kind: u8,
    pub subject: u64,
    pub level: u32,
    pub amount: u64,
    pub started: Seconds,
    pub ends: Seconds,
    /// The timer that ends it.
    pub timer: u64,
}
row!(Job in job, auto, by id, city);

impl Job {
    /// A building being raised a level: its subject is the building.
    pub const RAISE: u8 = 1;
    /// Troops in training: its subject is the building that trains them.
    pub const TRAIN: u8 = 2;
    /// Wounded being healed: its subject is their troop row, its level
    /// their tier, its amount how many.
    pub const HEAL: u8 = 3;
    /// A topic being studied in the Academy: its subject is the topic,
    /// its level the one being learnt.
    pub const STUDY: u8 = 4;
}

/// A city's troops of one kind and tier: its owner's alone to read. Keyed
/// by city, kind and tier.
#[spacetimedb::table(accessor = troop)]
#[derive(Clone, Debug, PartialEq)]
pub struct Troop {
    #[primary_key]
    pub id: u64,
    #[index(btree)]
    pub city: u64,
    pub kind: u8,
    pub tier: u32,
    /// How many stand ready in the city, and how many lie wounded in its
    /// Hospital.
    pub ready: u64,
    pub wounded: u64,
}
row!(Troop in troop, by id, city);

impl Troop {
    pub fn key(city: u64, kind: u8, tier: u32) -> u64 {
        (city << 16) | ((kind as u64) << 8) | tier as u64
    }
}

/// What one soldier of a kind and tier is and costs in this realm, as the
/// catalogue has it, for clients to show. Keyed by kind and tier.
#[spacetimedb::table(accessor = soldier, public)]
#[derive(Clone, Debug, PartialEq)]
pub struct Soldier {
    #[primary_key]
    pub id: u64,
    pub kind: u8,
    pub tier: u32,
    pub name: String,
    pub attack: u64,
    pub defence: u64,
    pub health: u64,
    /// Tenths of a second to cross a hex, in this realm.
    pub pace: u64,
    pub load: u64,
    pub power: u64,
    pub grain: u64,
    pub timber: u64,
    pub stone: u64,
    pub moonsalt: u64,
    /// Thousandths of a second to train one, in this realm.
    pub millis: u64,
    /// The building that trains them, and the level it must have reached.
    pub building: u8,
    pub needs_level: u32,
}
row!(Soldier in soldier, by id);

impl Soldier {
    pub fn key(kind: u8, tier: u32) -> u64 {
        ((kind as u64) << 8) | tier as u64
    }
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

/// A barrow of the Unquiet on the land, for players to clear. Everyone
/// sees it, and whether an army is fighting there.
#[spacetimedb::table(accessor = barrow, public)]
#[derive(Clone, Debug, PartialEq)]
pub struct Barrow {
    #[primary_key]
    #[auto_inc]
    pub id: u64,
    pub hex: u64,
    /// How strong it is, 1 to 25 (`catalog::barrow`).
    pub level: u32,
    /// The march fighting there now; 0 for none.
    pub fighter: u64,
}
row!(Barrow in barrow, auto, by id);

/// What a player has for hunting the Unquiet: theirs alone to read. Keyed
/// by their player number.
///
/// `energy` is as it stood at `as_of`. Since then it has grown by a point
/// every `point_millis`, up to `most`: the rules settle that whenever
/// they touch the row, and a client reckons it for itself between times.
#[spacetimedb::table(accessor = hunt)]
#[derive(Clone, Debug, PartialEq)]
pub struct Hunt {
    #[primary_key]
    pub player: u64,
    pub energy: u32,
    pub as_of: Seconds,
    pub most: u32,
    pub point_millis: u64,
    /// The strongest barrow they have cleared: they may attack one level
    /// above it.
    pub cleared: u32,
}
row!(Hunt in hunt, by player);

/// What happened to a player's army, told to them: theirs alone to read.
#[spacetimedb::table(accessor = report)]
#[derive(Clone, Debug, PartialEq)]
pub struct Report {
    #[primary_key]
    #[auto_inc]
    pub id: u64,
    #[index(btree)]
    pub player: u64,
    pub at: Seconds,
    /// What it tells of (`Report::HUNT`), where, and whether it went the
    /// player's way.
    pub kind: u8,
    pub hex: u64,
    pub won: bool,
    /// The other side: a barrow's level, or a player's number.
    pub foe: u64,
    pub rounds: u32,
    /// The player's soldiers: how many fought, and of them how many came
    /// away wounded and how many died.
    pub fought: u64,
    pub wounded: u64,
    pub dead: u64,
    /// The other side's: how many stood, and how many fell.
    pub stood: u64,
    pub fell: u64,
    /// What was won.
    pub grain: u64,
    pub timber: u64,
    pub stone: u64,
    pub moonsalt: u64,
    /// The whole of it in plain words.
    pub words: String,
    pub read: bool,
}
row!(Report in report, auto, by id, player);

impl Report {
    /// A fight at a barrow: `foe` is the barrow's level.
    pub const HUNT: u8 = 1;
    /// The player's army at another's city, and another's army at the
    /// player's own: `foe` is the other player's number.
    pub const ATTACK: u8 = 2;
    pub const DEFENCE: u8 = 3;
}

/// An alliance of players. Everyone may read it.
#[spacetimedb::table(accessor = alliance, public)]
#[derive(Clone, Debug, PartialEq)]
pub struct Alliance {
    #[primary_key]
    #[auto_inc]
    pub id: u64,
    /// Its name and its tag, each folded to one case and hashed: no two
    /// alliances share either.
    #[index(btree)]
    pub name_key: u64,
    #[index(btree)]
    pub tag_key: u64,
    pub name: String,
    /// Its short name, three or four letters, shown before its members'.
    pub tag: String,
    pub leader: u64,
    pub founded: Seconds,
    pub members: u32,
    /// Whether anyone may join without being let in.
    pub open: bool,
    /// What it says of itself.
    pub words: String,
}
row!(Alliance in alliance, auto, by id, name_key, tag_key);

/// A player's place in an alliance. Everyone may read it. Keyed by the
/// player: no one is in two.
#[spacetimedb::table(accessor = member, public)]
#[derive(Clone, Debug, PartialEq)]
pub struct Member {
    #[primary_key]
    pub player: u64,
    #[index(btree)]
    pub alliance: u64,
    /// `Member::MEMBER`, `OFFICER` or `LEADER`.
    pub rank: u8,
    pub joined: Seconds,
}
row!(Member in member, by player, alliance);

impl Member {
    pub const MEMBER: u8 = 1;
    pub const OFFICER: u8 = 4;
    pub const LEADER: u8 = 5;
}

/// A player asking to be let into an alliance that is not open: for the
/// player and that alliance's officers to read. Keyed by the player: one
/// asking at a time.
#[spacetimedb::table(accessor = applicant)]
#[derive(Clone, Debug, PartialEq)]
pub struct Applicant {
    #[primary_key]
    pub player: u64,
    #[index(btree)]
    pub alliance: u64,
    pub name: String,
    pub at: Seconds,
}
row!(Applicant in applicant, by player, alliance);

/// Something said in the realm, for everyone to read.
#[spacetimedb::table(accessor = realm_chat, public)]
#[derive(Clone, Debug, PartialEq)]
pub struct RealmChat {
    #[primary_key]
    #[auto_inc]
    pub id: u64,
    pub player: u64,
    /// Their name as it was, with their alliance's tag if they had one.
    pub name: String,
    pub at: Seconds,
    pub words: String,
}
row!(RealmChat in realm_chat, auto, by id);

/// Something said within an alliance, for its members alone to read.
#[spacetimedb::table(accessor = alliance_chat)]
#[derive(Clone, Debug, PartialEq)]
pub struct AllianceChat {
    #[primary_key]
    #[auto_inc]
    pub id: u64,
    #[index(btree)]
    pub alliance: u64,
    pub player: u64,
    pub name: String,
    pub at: Seconds,
    pub words: String,
}
row!(AllianceChat in alliance_chat, auto, by id, alliance);

/// One of a player's first tasks, as the catalogue has it, for clients to
/// show: what it asks, in words and in numbers a client can check
/// against its own rows (`catalog::Goal::numbers`), and what it gives.
/// Keyed by its place in the order, from 1.
#[spacetimedb::table(accessor = task, public)]
#[derive(Clone, Debug, PartialEq)]
pub struct Task {
    #[primary_key]
    pub step: u64,
    pub goal: u8,
    pub amount: u64,
    pub level: u64,
    pub words: String,
    pub grain: u64,
    pub timber: u64,
    pub stone: u64,
    pub moonsalt: u64,
}
row!(Task in task, by step);

/// How far through their tasks a player is: theirs alone to read. Keyed
/// by their player number. `step` is the task they are on; one past the
/// last when they have done them all.
#[spacetimedb::table(accessor = progress)]
#[derive(Clone, Debug, PartialEq)]
pub struct Progress {
    #[primary_key]
    pub player: u64,
    pub step: u64,
}
row!(Progress in progress, by player);

/// What a city has learnt of a topic: its owner's alone to read. Keyed
/// by city and topic.
#[spacetimedb::table(accessor = lore)]
#[derive(Clone, Debug, PartialEq)]
pub struct Lore {
    #[primary_key]
    pub id: u64,
    #[index(btree)]
    pub city: u64,
    pub topic: u8,
    pub level: u32,
}
row!(Lore in lore, by id, city);

impl Lore {
    pub fn key(city: u64, topic: u8) -> u64 {
        (city << 8) | topic as u64
    }
}

/// What learning a level of a topic costs and gives in this realm, as
/// the catalogue has it, for clients to show. Keyed by topic and level.
#[spacetimedb::table(accessor = study, public)]
#[derive(Clone, Debug, PartialEq)]
pub struct Study {
    #[primary_key]
    pub id: u64,
    pub topic: u8,
    pub level: u32,
    pub name: String,
    /// What the topic does, in a player's words, and how many hundredths
    /// each level adds.
    pub words: String,
    pub each: u64,
    pub grain: u64,
    pub timber: u64,
    pub stone: u64,
    pub moonsalt: u64,
    pub seconds: Seconds,
    /// The level the Academy must have reached.
    pub needs_level: u32,
}
row!(Study in study, by id);

impl Study {
    pub fn key(topic: u8, level: u32) -> u64 {
        ((topic as u64) << 32) | level as u64
    }
}

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
    + Table<Troop>
    + Table<Soldier>
    + Table<Site>
    + Table<March>
    + Table<Squad>
    + Table<Haul>
    + Table<Barrow>
    + Table<Hunt>
    + Table<Report>
    + Table<Alliance>
    + Table<Member>
    + Table<Applicant>
    + Table<RealmChat>
    + Table<AllianceChat>
    + Table<Task>
    + Table<Progress>
    + Table<Lore>
    + Table<Study>
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
            + Table<Stock>
            + Table<Troop>
            + Table<Soldier>
            + Table<Site>
            + Table<March>
            + Table<Squad>
            + Table<Haul>
            + Table<Barrow>
            + Table<Hunt>
            + Table<Report>
            + Table<Alliance>
            + Table<Member>
            + Table<Applicant>
            + Table<RealmChat>
            + Table<AllianceChat>
            + Table<Task>
            + Table<Progress>
            + Table<Lore>
            + Table<Study>,
    > Db for T
{
}
