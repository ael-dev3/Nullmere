//! Commanders: the people who lead a player's armies. Each has a name, a
//! way of war, and a level that rises with what they have seen; an army
//! they lead is the better for it.

use super::{asking, building_of, city_of, goods, set_goods, settle, Refusal};
use crate::catalog::{self, Building as Kind, Leading, Way, TOP_COMMAND};
use crate::rows::{Commander, Db, March};
use crate::store::Table;

const FIRST: [&str; 24] = [
    "Ael", "Bran", "Cor", "Dun", "Eir", "Fen", "Gar", "Hal", "Ior", "Kes", "Lun", "Mor", "Nev", "Orl", "Pen", "Ren", "Sel", "Tor", "Ul", "Ves", "Wyn", "Yor",
    "Isk", "Tam",
];
const LAST: [&str; 12] = ["a", "en", "ic", "is", "or", "wen", "eth", "ald", "ine", "ar", "us", "ry"];

/// A player's commanders, in the order they came.
pub fn commanders_of(db: &impl Db, player: u64) -> Vec<Commander> {
    let mut all = Table::<Commander>::by(db, 0, player);
    all.sort_by_key(|commander| commander.id);
    all
}

/// A new commander comes to a player: of a way none of theirs has yet,
/// where there is one, and under a name none of theirs has.
pub fn enlist(db: &mut impl Db, player: u64) -> Commander {
    let have = commanders_of(db, player);
    let free: Vec<Way> = Way::ALL.into_iter().filter(|way| !have.iter().any(|commander| commander.way == *way as u8)).collect();
    let pool = if free.is_empty() { Way::ALL.to_vec() } else { free };
    let way = pool[(db.chance() % pool.len() as u64) as usize];
    let mut name = String::new();
    for _ in 0..40 {
        let (a, b) = (db.chance(), db.chance());
        name = format!("{}{}", FIRST[(a % FIRST.len() as u64) as usize], LAST[(b % LAST.len() as u64) as usize]);
        if !have.iter().any(|commander| commander.name == name) {
            break;
        }
    }
    db.insert(Commander { id: 0, owner: player, name, way: way as u8, level: 1, seen: 0, march: 0 })
}

/// A player takes on another commander: as many as their Tavern's level
/// allows, each dearer than the last.
pub fn hire(db: &mut impl Db, player: u64) -> Result<Commander, Refusal> {
    asking(db, player)?;
    let city = city_of(db, player)?;
    let have = commanders_of(db, player).len() as u32;
    let tavern = building_of(db, city.id, Kind::Tavern).map(|tavern| tavern.level).unwrap_or(0);
    if tavern == 0 {
        return Err(Refusal::NeedsOther(Kind::Tavern, 1));
    }
    if have >= catalog::commanders(tavern) {
        return Err(if have >= 6 { Refusal::NoMoreCommanders } else { Refusal::NeedsOther(Kind::Tavern, (have - 1) * 5) });
    }
    let mut stock = settle(db, city.id)?;
    let cost = catalog::hire_cost(have);
    let short = goods(&stock).short_of(cost);
    if !short.is_none() {
        return Err(Refusal::CannotAfford(short));
    }
    let left = goods(&stock).minus(cost);
    set_goods(&mut stock, left);
    db.update(stock);
    Ok(enlist(db, player))
}

/// The commander a player names to lead an army: theirs, and in the city.
pub(super) fn leader_for(db: &impl Db, player: u64, commander: u64) -> Result<Commander, Refusal> {
    let commander = Table::<Commander>::get(db, commander).filter(|commander| commander.owner == player).ok_or(Refusal::NoSuchCommander)?;
    if commander.march != 0 {
        return Err(Refusal::CommanderAway(commander.name));
    }
    Ok(commander)
}

/// What the commander who leads a march adds to it; nothing where no one
/// leads it.
pub fn leading_of(db: &impl Db, march: &March) -> Leading {
    Table::<Commander>::get(db, march.leader).and_then(|commander| Way::of(commander.way).map(|way| way.leading(commander.level))).unwrap_or_default()
}

/// A march's commander has seen something of war or of work: so much is
/// added to what they have seen, and they rise a level for each measure
/// of it, to the thirtieth.
pub(super) fn seen_by_leader(db: &mut impl Db, march: &March, amount: u64) {
    let Some(mut commander) = Table::<Commander>::get(db, march.leader) else { return };
    commander.seen += amount;
    while commander.level < TOP_COMMAND && commander.seen >= catalog::command_needs(commander.level) {
        commander.seen -= catalog::command_needs(commander.level);
        commander.level += 1;
    }
    db.update(commander);
}

/// A march is over: its commander is back in the city.
pub(super) fn release(db: &mut impl Db, march: &March) {
    if let Some(mut commander) = Table::<Commander>::get(db, march.leader) {
        commander.march = 0;
        db.update(commander);
    }
}
