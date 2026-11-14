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
}
row!(Realm in realm, by id);

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

/// Everything the rules keep: every table, the clock, chance and timers.
pub trait Db: World + Table<Realm> + Table<Player> + Table<Pace> {}

impl<T: World + Table<Realm> + Table<Player> + Table<Pace>> Db for T {}
