//! Armies on the map: sent out along a way over open ground, arriving in
//! real time, gathering what lies at a site, and carrying it home.

use super::{
    asking, besiege, break_peace, city_of, engage, fought, goods, keep_troop, may_attack, may_hunt, realm, set_goods, settle, spend_energy, stormed, troop, Refusal,
};
use crate::catalog::{self, Goods, Troops, TOP_TIER};
use crate::hex::{self, Hex};
use crate::land::{self, Ground};
use crate::rows::{City, Db, Haul, March, Place, Site, Squad};
use crate::store::{Seconds, Table};

/// A timer that brings a march to the end of what it is doing: its
/// subject is the march.
pub const TIMER_MARCH: u8 = 2;

/// How much one soldier gathers in an hour, as written.
pub const GATHERED_AN_HOUR: u64 = 36;

/// How many hexes of land there are to each site.
pub const HEXES_A_SITE: u32 = 40;

/// Soldiers of a kind and tier asked for a march.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Asked {
    pub kind: u8,
    pub tier: u32,
    pub count: u64,
}

/// The good a kind of site holds, as goods.
fn of_kind(kind: u8, amount: u64) -> Goods {
    match kind {
        Site::GRAIN => Goods::of(amount, 0, 0, 0),
        Site::TIMBER => Goods::of(0, amount, 0, 0),
        Site::STONE => Goods::of(0, 0, amount, 0),
        _ => Goods::of(0, 0, 0, amount),
    }
}

/// Sets one new site somewhere on the land: grain on the plain, timber in
/// the wood, stone on the heath, moonsalt on the salt, richer the nearer
/// the lake, on a hex with nothing on it or beside it. False if chance
/// found no such hex.
pub fn spawn_site(db: &mut impl Db) -> bool {
    let Ok(realm) = realm(db) else { return false };
    let span = 2 * realm.radius as u64 + 1;
    for _ in 0..60 {
        let (a, b) = (db.chance(), db.chance());
        let hex = Hex::new((a % span) as i32 - realm.radius as i32, (b % span) as i32 - realm.radius as i32);
        if hex.length() > realm.radius {
            continue;
        }
        let kind = match land::ground(realm.seed, realm.radius, hex) {
            Ground::Plain => Site::GRAIN,
            Ground::Wood => Site::TIMBER,
            Ground::Heath => Site::STONE,
            Ground::Salt => Site::MOONSALT,
            _ => continue,
        };
        if hex.within(1).iter().any(|near| Table::<Place>::get(db, near.packed()).is_some()) {
            continue;
        }
        // Six levels from the mountains in to the lake's shore.
        let level = 1 + (realm.radius - hex.length()) * 6 / realm.radius.max(1);
        let level = level.clamp(1, 6);
        let left = if kind == Site::MOONSALT { 4_000 } else { 20_000 } * level as u64;
        let site = db.insert(Site { id: 0, hex: hex.packed(), kind, level, left, gatherer: 0 });
        db.insert(Place { hex: hex.packed(), kind: Place::SITE, id: site.id });
        return true;
    }
    false
}

/// Scatters the realm's sites over its land as it opens.
pub fn scatter_sites(db: &mut impl Db) {
    let Ok(realm) = realm(db) else { return };
    let hexes = 1 + 3 * realm.radius * (realm.radius + 1);
    for _ in 0..hexes / HEXES_A_SITE {
        spawn_site(db);
    }
}

/// The soldiers of a march.
pub fn squads(db: &impl Db, march: u64) -> Vec<Squad> {
    Table::<Squad>::by(db, 0, march)
}

/// The power of all a city's soldiers out on marches.
pub fn marching_power(db: &impl Db, city: u64) -> u64 {
    Table::<March>::by(db, 1, city)
        .iter()
        .flat_map(|march| squads(db, march.id))
        .map(|squad| Troops::of(squad.kind).map(|kind| kind.soldier(squad.tier).power).unwrap_or(0) * squad.count)
        .sum()
}

/// How long a march of these soldiers takes over a number of steps: at
/// the pace of its slowest, in this realm.
fn travel(db: &impl Db, squads: &[Squad], steps: usize) -> Seconds {
    let slowest = squads.iter().filter_map(|squad| Troops::of(squad.kind).map(|kind| kind.soldier(squad.tier).pace)).max().unwrap_or(60);
    let pace = realm(db).map(|realm| realm.pace).unwrap_or(1);
    catalog::paced((steps as u64 * slowest).div_ceil(10) as Seconds, pace)
}

/// A player sends soldiers from their city: to gather at a site, to
/// clear a barrow of the Unquiet, or against another player's city.
pub fn send(db: &mut impl Db, player: u64, to: Hex, kind: u8, asked: &[Asked]) -> Result<March, Refusal> {
    asking(db, player)?;
    let city = city_of(db, player)?;
    let realm = realm(db)?;
    let target = match kind {
        March::GATHER => {
            let site = match Table::<Place>::get(db, to.packed()) {
                Some(place) if place.kind == Place::SITE => Table::<Site>::get(db, place.id).ok_or(Refusal::NothingThere)?,
                _ => return Err(Refusal::NothingThere),
            };
            if site.gatherer != 0 {
                return Err(Refusal::SiteTaken);
            }
            site.id
        }
        March::HUNT => may_hunt(db, player, to)?.id,
        March::ATTACK => may_attack(db, player, to)?.id,
        _ => return Err(Refusal::NoSuchOrder),
    };
    // What was asked, each kind and tier once.
    let mut wanted: Vec<Asked> = Vec::new();
    for ask in asked.iter().filter(|ask| ask.count > 0) {
        let troops = Troops::of(ask.kind).ok_or(Refusal::NoSuchTroops)?;
        if !(1..=TOP_TIER).contains(&ask.tier) {
            return Err(Refusal::NoSuchTroops);
        }
        match wanted.iter_mut().find(|other| other.kind == troops as u8 && other.tier == ask.tier) {
            Some(other) => other.count += ask.count,
            None => wanted.push(*ask),
        }
    }
    if wanted.is_empty() {
        return Err(Refusal::NothingAsked);
    }
    for ask in &wanted {
        let troops = Troops::of(ask.kind).ok_or(Refusal::NoSuchTroops)?;
        let ready = troop(db, city.id, troops, ask.tier).ready;
        if ready < ask.count {
            return Err(Refusal::NotEnoughTroops(troops, ask.tier, ready));
        }
    }
    let most = catalog::marches(city.keep);
    if Table::<March>::by(db, 1, city.id).len() as u32 >= most {
        return Err(Refusal::NoFreeMarch(most));
    }
    let from = Hex::unpacked(city.hex);
    let way = land::way(realm.seed, realm.radius, from, to).ok_or(Refusal::NoWay)?;

    if kind == March::HUNT {
        spend_energy(db, player, false);
    }
    if kind == March::ATTACK {
        break_peace(db, city.clone());
    }
    for ask in &wanted {
        let troops = Troops::of(ask.kind).ok_or(Refusal::NoSuchTroops)?;
        let mut row = troop(db, city.id, troops, ask.tier);
        row.ready -= ask.count;
        keep_troop(db, row);
    }
    let now = db.now();
    let mut march = db.insert(March {
        id: 0,
        owner: player,
        city: city.id,
        kind,
        state: March::GOING,
        from: city.hex,
        to: to.packed(),
        target,
        departed: now,
        arrives: now,
        soldiers: wanted.iter().map(|ask| ask.count).sum(),
        route: hex::encode(&way),
        timer: 0,
    });
    for ask in &wanted {
        db.insert(Squad { id: Squad::key(march.id, ask.kind, ask.tier), march: march.id, kind: ask.kind, tier: ask.tier, count: ask.count, wounded: 0 });
    }
    march.arrives = now + travel(db, &squads(db, march.id), way.len() - 1);
    march.timer = db.after(march.arrives, TIMER_MARCH, march.id);
    db.update(march.clone());
    Ok(march)
}

/// Turns a march for home along a way, from now.
fn turn_home(db: &mut impl Db, mut march: March, way: Vec<Hex>) {
    let now = db.now();
    march.state = March::RETURNING;
    march.departed = now;
    march.arrives = now + travel(db, &squads(db, march.id), way.len().saturating_sub(1));
    march.route = hex::encode(&way);
    march.timer = db.after(march.arrives, TIMER_MARCH, march.id);
    db.update(march);
}

/// The way a march came, turned round.
fn way_back(march: &March) -> Vec<Hex> {
    let mut way = hex::decode(&march.route);
    way.reverse();
    way
}

/// How much a march can carry.
fn load(db: &impl Db, march: u64) -> u64 {
    squads(db, march).iter().map(|squad| Troops::of(squad.kind).map(|kind| kind.soldier(squad.tier).load).unwrap_or(0) * squad.count).sum()
}

/// A march takes what it has gathered from its site: the amount comes off
/// the site, which is gone when nothing is left (and another is set
/// somewhere), and goes into the march's haul.
fn take(db: &mut impl Db, march: &March, amount: u64) {
    let Some(mut site) = Table::<Site>::get(db, march.target) else { return };
    let amount = amount.min(site.left);
    site.left -= amount;
    site.gatherer = 0;
    let gathered = of_kind(site.kind, amount);
    if site.left == 0 {
        Table::<Place>::delete(db, site.hex);
        Table::<Site>::delete(db, site.id);
        spawn_site(db);
    } else {
        db.update(site);
    }
    if amount > 0 {
        db.insert(Haul { march: march.id, owner: march.owner, grain: gathered.grain, timber: gathered.timber, stone: gathered.stone, moonsalt: gathered.moonsalt });
    }
}

/// A march's timer has come due: it has arrived, finished its work, or
/// come home.
pub fn arrive(db: &mut impl Db, march: u64) {
    let Some(mut march) = Table::<March>::get(db, march) else { return };
    match march.state {
        March::GOING if march.kind == March::HUNT => {
            if engage(db, &mut march) {
                march.timer = db.after(march.arrives, TIMER_MARCH, march.id);
                db.update(march);
            } else {
                // Cleared already, or another army is at it: home again.
                let way = way_back(&march);
                turn_home(db, march, way);
            }
        }
        March::GOING if march.kind == March::ATTACK => {
            if besiege(db, &mut march) {
                march.timer = db.after(march.arrives, TIMER_MARCH, march.id);
                db.update(march);
            } else {
                // Gone, or at peace since the army set out: home again.
                let way = way_back(&march);
                turn_home(db, march, way);
            }
        }
        March::FIGHTING => {
            if march.kind == March::ATTACK {
                stormed(db, &mut march);
            } else {
                fought(db, &mut march);
            }
            if squads(db, march.id).is_empty() {
                // No one is left to come home.
                Table::<Haul>::delete(db, march.id);
                Table::<March>::delete(db, march.id);
            } else {
                let way = way_back(&march);
                turn_home(db, march, way);
            }
        }
        March::GOING => {
            let free = Table::<Site>::get(db, march.target).filter(|site| site.gatherer == 0 && site.left > 0);
            let Some(mut site) = free else {
                // Gone, or another army got there first: home again, empty.
                let way = way_back(&march);
                return turn_home(db, march, way);
            };
            site.gatherer = march.id;
            let amount = load(db, march.id).min(site.left);
            db.update(site);
            let pace = realm(db).map(|realm| realm.pace).unwrap_or(1);
            let hourly = (march.soldiers * GATHERED_AN_HOUR).max(1);
            let now = db.now();
            march.state = March::WORKING;
            march.departed = now;
            march.arrives = now + catalog::paced((amount * 3_600).div_ceil(hourly) as Seconds, pace);
            march.timer = db.after(march.arrives, TIMER_MARCH, march.id);
            db.update(march);
        }
        March::WORKING => {
            let amount = load(db, march.id);
            take(db, &march, amount);
            let way = way_back(&march);
            turn_home(db, march, way);
        }
        _ => home(db, &march),
    }
}

/// A march is home: its soldiers stand ready again, its wounded are laid
/// in the Hospital, and what it carried goes into the city's stock,
/// though it overfill it.
fn home(db: &mut impl Db, march: &March) {
    for squad in squads(db, march.id) {
        if let Some(kind) = Troops::of(squad.kind) {
            let mut row = troop(db, march.city, kind, squad.tier);
            row.ready += squad.count;
            row.wounded += squad.wounded;
            keep_troop(db, row);
        }
        Table::<Squad>::delete(db, squad.id);
    }
    if let Some(haul) = Table::<Haul>::get(db, march.id) {
        if let Ok(mut stock) = settle(db, march.city) {
            let more = goods(&stock).plus(Goods::of(haul.grain, haul.timber, haul.stone, haul.moonsalt));
            set_goods(&mut stock, more);
            db.update(stock);
        }
        Table::<Haul>::delete(db, march.id);
    }
    Table::<March>::delete(db, march.id);
}

/// A player calls one of their marches home: from the road it turns where
/// it stands; from its work it takes what it has gathered so far.
pub fn recall(db: &mut impl Db, player: u64, march: u64) -> Result<March, Refusal> {
    asking(db, player)?;
    let march = Table::<March>::get(db, march).ok_or(Refusal::NoSuchMarch)?;
    if march.owner != player {
        return Err(Refusal::NotYours);
    }
    let now = db.now();
    let (gone, whole) = ((now - march.departed).max(0) as u64, (march.arrives - march.departed).max(1) as u64);
    match march.state {
        March::GOING => {
            // Where it stands on its way: as many steps along as its time gone.
            let way = hex::decode(&march.route);
            let steps = ((way.len() as u64 - 1) * gone.min(whole) / whole) as usize;
            let mut back: Vec<Hex> = way[..=steps].to_vec();
            back.reverse();
            db.cancel(march.timer);
            if march.kind == March::HUNT {
                // It never fought: the energy the attack took comes back.
                spend_energy(db, player, true);
            }
            turn_home(db, march.clone(), back);
        }
        March::WORKING => {
            let amount = load(db, march.id) * gone.min(whole) / whole;
            db.cancel(march.timer);
            take(db, &march, amount);
            let way = way_back(&march);
            turn_home(db, march.clone(), way);
        }
        March::FIGHTING => return Err(Refusal::Fighting),
        _ => return Err(Refusal::AlreadyReturning),
    }
    Table::<March>::get(db, march.id).ok_or(Refusal::NoSuchMarch)
}

/// Whether a hex is clear for a new city: nothing on it, and no other
/// city within the spacing cities keep.
pub(super) fn clear_for_city(db: &impl Db, hex: Hex, spacing: u32) -> bool {
    Table::<Place>::get(db, hex.packed()).is_none()
        && hex.within(spacing).iter().all(|near| Table::<Place>::get(db, near.packed()).is_none_or(|place| place.kind != Place::CITY))
}

/// A city's soldiers, wherever they are: for its owner's count.
pub fn city_marches(db: &impl Db, city: &City) -> Vec<March> {
    Table::<March>::by(db, 1, city.id)
}
