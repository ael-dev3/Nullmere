//! Opening the realm, joining it, and being seen in it.

use super::Refusal;
use crate::rows::{Db, Pace, Player, Realm};
use crate::store::{Seconds, Table};

/// The fewest and the most letters in a player's name.
pub const NAME_SHORTEST: usize = 3;
pub const NAME_LONGEST: usize = 16;
/// The most players who may join in one minute. A stopgap against one
/// script taking the realm: identities are free until sign-in is real.
pub const JOINING_A_MINUTE: u32 = 120;
/// The most things one player may ask of the realm in ten seconds.
pub const ASKING_IN_TEN_SECONDS: u32 = 40;

/// Opens the realm: once, as the module is published.
pub fn open(db: &mut impl Db, seed: u64, pace: u32) {
    if Table::<Realm>::get(db, 0).is_some() {
        return;
    }
    let now = db.now();
    db.insert(Realm { id: 0, seed, opened: now, pace: pace.max(1), joining_minute: now, joined_in_minute: 0 });
}

/// The realm's one row.
pub fn realm(db: &impl Db) -> Result<Realm, Refusal> {
    Table::<Realm>::get(db, 0).ok_or(Refusal::NotOpen)
}

/// A name as it is kept: trimmed, its inner spaces single.
pub fn tidy(name: &str) -> String {
    name.split_whitespace().collect::<Vec<_>>().join(" ")
}

/// The number two names share exactly when they are the same name but for
/// capitals.
pub fn name_key(name: &str) -> u64 {
    // FNV-1a over the folded name: the index finds candidates, and the
    // names themselves are compared to be sure.
    let mut hash: u64 = 0xcbf2_9ce4_8422_2325;
    for byte in name.to_lowercase().bytes() {
        hash ^= byte as u64;
        hash = hash.wrapping_mul(0x0000_0100_0000_01b3);
    }
    hash
}

/// Why a name can't be a player's, if it can't.
pub fn name_refusal(name: &str) -> Option<Refusal> {
    let letters = name.chars().count();
    if letters < NAME_SHORTEST {
        return Some(Refusal::NameTooShort);
    }
    if letters > NAME_LONGEST {
        return Some(Refusal::NameTooLong);
    }
    let allowed = |c: char| c.is_alphanumeric() || c == ' ' || c == '-' || c == '\'';
    let ends = |c: Option<char>| c.is_some_and(char::is_alphanumeric);
    if !name.chars().all(allowed) || !ends(name.chars().next()) || !ends(name.chars().last()) {
        return Some(Refusal::NameNotAllowed);
    }
    None
}

/// Whether a player already has this name, however it is capitalised.
pub fn name_taken(db: &impl Db, name: &str) -> bool {
    let folded = name.to_lowercase();
    Table::<Player>::by(db, 0, name_key(name)).iter().any(|player| player.name.to_lowercase() == folded)
}

/// A new player joins the realm under a name, and is given their number.
pub fn join(db: &mut impl Db, name: &str) -> Result<Player, Refusal> {
    let mut realm = realm(db)?;
    let name = tidy(name);
    if let Some(refusal) = name_refusal(&name) {
        return Err(refusal);
    }
    if name_taken(db, &name) {
        return Err(Refusal::NameTaken);
    }
    let now = db.now();
    let minute = now - now.rem_euclid(60);
    if realm.joining_minute != minute {
        realm.joining_minute = minute;
        realm.joined_in_minute = 0;
    }
    if realm.joined_in_minute >= JOINING_A_MINUTE {
        return Err(Refusal::Crowded);
    }
    realm.joined_in_minute += 1;
    db.update(realm);
    Ok(db.insert(Player { id: 0, name_key: name_key(&name), name, joined: now, online: true, seen: now }))
}

/// A player connects or disconnects: seen now, here or gone.
pub fn seen(db: &mut impl Db, player: u64, online: bool) {
    if let Some(mut row) = Table::<Player>::get(db, player) {
        row.online = online;
        row.seen = db.now();
        db.update(row);
    }
}

/// Counts one more thing a player asks of the realm, and refuses it if
/// they have asked too much in the last ten seconds. Every reducer a
/// player may call begins here.
pub fn asking(db: &mut impl Db, player: u64) -> Result<Player, Refusal> {
    let row = Table::<Player>::get(db, player).ok_or(Refusal::NotAPlayer)?;
    let now: Seconds = db.now();
    match Table::<Pace>::get(db, player) {
        Some(mut pace) => {
            if now - pace.window >= 10 {
                pace.window = now;
                pace.asked = 0;
            }
            if pace.asked >= ASKING_IN_TEN_SECONDS {
                return Err(Refusal::TooFast);
            }
            pace.asked += 1;
            db.update(pace);
        }
        None => {
            db.insert(Pace { player, window: now, asked: 1 });
        }
    }
    Ok(row)
}
