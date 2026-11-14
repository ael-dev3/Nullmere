//! The rules of the game.
//!
//! Each public function here is one thing a player may ask of the realm, or
//! one thing the realm does of itself when a timer fires. It checks, then
//! changes rows, or refuses with the reason in plain words and changes
//! nothing.

mod entry;

pub use entry::*;

use std::fmt;

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
}

impl fmt::Display for Refusal {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
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
        })
    }
}
