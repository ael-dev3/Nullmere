//! The rules of the game.
//!
//! Each public function here is one thing a player may ask of the realm, or
//! one thing the realm does of itself when a timer fires. It checks, then
//! changes rows, or refuses with the reason in plain words and changes
//! nothing.

mod city;
mod entry;

pub use city::*;
pub use entry::*;

use crate::catalog::{Building, Goods};
use crate::rows::Db;
use crate::store::Timer;
use std::fmt;

/// A timer the rules set has come due: what it was set for is done.
pub fn fire(db: &mut impl Db, timer: &Timer) {
    if timer.kind == TIMER_JOB {
        finish(db, timer.subject);
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
            _ => "",
        })
    }
}
