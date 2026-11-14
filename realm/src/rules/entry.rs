//! Opening the realm, joining it, and being seen in it.

use super::{found, hunt_of, keep_hunt, reckon, scatter_barrows, scatter_sites, write_tasks, Refusal};
use crate::catalog::{self, Building, Troops};
use crate::land;
use crate::rows::{Blueprint, City, Db, Hunt, Land, Pace, Player, Progress, Realm, Soldier};
use crate::store::{Seconds, Table};

/// The fewest and the most letters in a player's name.
pub const NAME_SHORTEST: usize = 3;
pub const NAME_LONGEST: usize = 16;
/// The most players who may join in one minute. A stopgap against one
/// script taking the realm: identities are free until sign-in is real.
pub const JOINING_A_MINUTE: u32 = 120;
/// The most things one player may ask of the realm in ten seconds.
pub const ASKING_IN_TEN_SECONDS: u32 = 40;

/// Opens the realm: once, as the module is published. Its land is grown
/// from the seed and kept, and the catalogue is written out for clients.
pub fn open(db: &mut impl Db, seed: u64, pace: u32, radius: u32) {
    if Table::<Realm>::get(db, 0).is_some() {
        return;
    }
    let now = db.now();
    let pace = pace.max(1);
    db.insert(Realm { id: 0, seed, opened: now, pace, joining_minute: now, joined_in_minute: 0, radius });
    for (chunk, ground) in land::chunks(seed, radius) {
        db.insert(Land { chunk, ground });
    }
    write_catalogue(db, pace);
    write_tasks(db);
    scatter_sites(db);
    scatter_barrows(db);
}

/// Sets the realm's pace: how many times faster than written everything
/// that takes time runs. The catalogue is written out afresh at the new
/// pace and every city's hourly rates reckoned again; what is already
/// under way keeps the end it was given. For a trial realm, or a check.
pub fn repace(db: &mut impl Db, pace: u32) -> Result<(), Refusal> {
    let mut realm = realm(db)?;
    // Every player's energy as it has grown at the old pace; from here
    // on it grows at the new.
    let hunts: Vec<Hunt> = Table::<Hunt>::all(db).iter().map(|hunt| hunt_of(db, hunt.player)).collect();
    realm.pace = pace.max(1);
    db.update(realm.clone());
    for hunt in hunts {
        db.update(hunt.clone());
        let paced = hunt_of(db, hunt.player);
        db.update(paced);
    }
    for row in Table::<Blueprint>::all(db) {
        Table::<Blueprint>::delete(db, row.id);
    }
    for row in Table::<Soldier>::all(db) {
        Table::<Soldier>::delete(db, row.id);
    }
    write_catalogue(db, realm.pace);
    for city in Table::<City>::all(db) {
        reckon(db, city.id);
    }
    Ok(())
}

/// Writes the catalogue out as rows, at a pace, for clients to show.
fn write_catalogue(db: &mut impl Db, pace: u32) {
    for building in Building::ALL {
        for level in 1..=catalog::TOP_LEVEL {
            let cost = catalog::cost(building, level);
            let hourly = catalog::yields(building, level).times(pace as u64);
            let needs = catalog::needs(building, level);
            db.insert(Blueprint {
                id: Blueprint::key(building as u8, level),
                building: building as u8,
                level,
                name: building.name().to_string(),
                grain: cost.grain,
                timber: cost.timber,
                stone: cost.stone,
                moonsalt: cost.moonsalt,
                seconds: catalog::paced(catalog::seconds(building, level), pace),
                grain_hourly: hourly.grain,
                timber_hourly: hourly.timber,
                stone_hourly: hourly.stone,
                moonsalt_hourly: hourly.moonsalt,
                opens_at: building.opens_at(),
                needs_building: needs.map(|(other, _)| other as u8).unwrap_or(0),
                needs_level: needs.map(|(_, level)| level).unwrap_or(0),
                power: catalog::power(building, level),
            });
        }
    }
    for troops in Troops::ALL {
        for tier in 1..=catalog::TOP_TIER {
            let soldier = troops.soldier(tier);
            db.insert(Soldier {
                id: Soldier::key(troops as u8, tier),
                kind: troops as u8,
                tier,
                name: troops.name().to_string(),
                attack: soldier.attack,
                defence: soldier.defence,
                health: soldier.health,
                pace: (soldier.pace / pace as u64).max(1),
                load: soldier.load,
                power: soldier.power,
                grain: soldier.cost.grain,
                timber: soldier.cost.timber,
                stone: soldier.cost.stone,
                moonsalt: soldier.cost.moonsalt,
                millis: (soldier.seconds as u64 * 1_000 / pace as u64).max(1),
                building: troops.trained_in() as u8,
                needs_level: soldier.needs_level,
            });
        }
    }
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

/// A new player joins the realm under a name, is given their number, and
/// their city is founded.
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
    let player = db.insert(Player { id: 0, name_key: name_key(&name), name, joined: now, online: true, seen: now });
    found(db, &player)?;
    let hunt = hunt_of(db, player.id);
    keep_hunt(db, hunt);
    db.insert(Progress { player: player.id, step: 1 });
    Ok(player)
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
            db.insert(Pace { player, window: now, asked: 1, said: 0 });
        }
    }
    Ok(row)
}
