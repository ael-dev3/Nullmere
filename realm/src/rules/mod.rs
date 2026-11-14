//! The rules of the game.
//!
//! Each public function here is one thing a player may ask of the realm, or
//! one thing the realm does of itself when a timer fires. It checks, then
//! changes rows, or refuses with the reason in plain words and changes
//! nothing.

mod army;
mod city;
mod entry;
mod march;

pub use army::*;
pub use city::*;
pub use entry::*;
pub use march::*;

use crate::catalog::{Building, Goods, Troops};
use crate::rows::Db;
use crate::store::Timer;
use std::fmt;

/// A timer the rules set has come due: what it was set for is done.
pub fn fire(db: &mut impl Db, timer: &Timer) {
    match timer.kind {
        TIMER_JOB => finish(db, timer.subject),
        TIMER_MARCH => arrive(db, timer.subject),
        _ => {}
    }
}

/// Why the realm will not do what was asked: said to the player as it is.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Refusal {
    /// The realm has not been opened.
    NotOpen,
    /// Someone unknown to the realm asked for something only a player may.
    NotAPlayer,
    AlreadyAPlayer,
    NameTooShort,
    NameTooLong,
    NameNotAllowed,
    NameTaken,
    /// Too many players joined in the last minute.
    Crowded,
    /// One player asking too much too quickly.
    TooFast,
    /// No clear ground is left for a new city.
    NoRoom,
    NoCity,
    NoSuchBuilding,
    /// Something of another player's.
    NotYours,
    AlreadyBuilt(Building),
    /// It is being raised already.
    AlreadyRising(Building),
    AtTopLevel(Building),
    /// The Keep must reach this level first.
    NeedsKeep(u32),
    /// Another building must reach a level first.
    NeedsOther(Building, u32),
    BuildersBusy,
    /// What the city's stock is short by.
    CannotAfford(Goods),
    /// The building trains no troops.
    TrainsNothing(Building),
    NoSuchTroops,
    NothingAsked,
    /// The most that may be asked for at once.
    TooMany(u64),
    AlreadyTraining(Building),
    /// It can't be raised while troops train in it.
    BusyTraining(Building),
    /// An order the realm does not know.
    NoSuchOrder,
    /// Nothing to gather at the hex named.
    NothingThere,
    /// Another army is gathering there.
    SiteTaken,
    /// The city has fewer ready than were asked for: which, and how many.
    NotEnoughTroops(Troops, u32, u64),
    /// Every army the city may send is out: how many that is.
    NoFreeMarch(u32),
    /// No way over open ground.
    NoWay,
    NoSuchMarch,
    AlreadyReturning,
    /// Something only the realm's owner may do.
    NotTheOwner,
}

impl fmt::Display for Refusal {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Refusal::AlreadyBuilt(building) => return write!(f, "Your city already has a {}.", building.name()),
            Refusal::AlreadyRising(building) => return write!(f, "Your {} is already being built.", building.name()),
            Refusal::AtTopLevel(building) => return write!(f, "Your {} is at its highest level.", building.name()),
            Refusal::NeedsKeep(level) => return write!(f, "Raise your Keep to level {level} first."),
            Refusal::NeedsOther(building, level) => return write!(f, "Raise your {} to level {level} first.", building.name()),
            Refusal::CannotAfford(short) => return write!(f, "You need {short} more."),
            Refusal::TrainsNothing(building) => return write!(f, "No troops are trained in a {}.", building.name()),
            Refusal::TooMany(most) => return write!(f, "At most {} at once.", crate::catalog::grouped(*most)),
            Refusal::AlreadyTraining(building) => return write!(f, "Your {} is already training troops.", building.name()),
            Refusal::BusyTraining(building) => return write!(f, "Your {} is training troops. Wait for them to finish.", building.name()),
            Refusal::NotEnoughTroops(troops, tier, ready) => {
                return write!(f, "You have only {} tier {tier} {} ready.", crate::catalog::grouped(*ready), troops.name());
            }
            Refusal::NoFreeMarch(1) => return write!(f, "Your one army is out. Raise your Keep to send more."),
            Refusal::NoFreeMarch(most) => return write!(f, "All {most} of your armies are out."),
            _ => {}
        }
        f.write_str(match self {
            Refusal::NotOpen => "The realm is not open yet.",
            Refusal::NotAPlayer => "Join the realm first.",
            Refusal::AlreadyAPlayer => "You have already joined the realm.",
            Refusal::NameTooShort => "A name needs at least 3 letters.",
            Refusal::NameTooLong => "A name can have at most 16 letters.",
            Refusal::NameNotAllowed => "A name can use letters, digits, spaces, hyphens and apostrophes, and must start and end with a letter or digit.",
            Refusal::NameTaken => "Another player has that name.",
            Refusal::Crowded => "Many players are joining right now. Try again in a minute.",
            Refusal::TooFast => "You are doing that too quickly. Wait a few seconds.",
            Refusal::NoRoom => "The realm has no clear ground left for a new city.",
            Refusal::NoCity => "You have no city.",
            Refusal::NoSuchBuilding => "There is no such building.",
            Refusal::NotYours => "That is not yours.",
            Refusal::BuildersBusy => "Your builders are busy. Wait for them to finish.",
            Refusal::NoSuchTroops => "There are no such troops.",
            Refusal::NothingAsked => "Ask for at least one.",
            Refusal::NoSuchOrder => "The realm knows no such order.",
            Refusal::NothingThere => "There is nothing to gather there.",
            Refusal::SiteTaken => "Another army is gathering there.",
            Refusal::NoWay => "There is no way there over open ground.",
            Refusal::NoSuchMarch => "There is no such army.",
            Refusal::AlreadyReturning => "That army is already on its way home.",
            Refusal::NotTheOwner => "Only the realm's owner may do that.",
            _ => "",
        })
    }
}
