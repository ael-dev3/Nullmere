//! Battle: two forces of counted troops meet in rounds until one is gone;
//! the barrows of the Unquiet that players clear, and the energy that
//! takes; the wounded and their healing; and the reports of what happened.

use super::{asking, city_of, goods, keep_troop, realm, set_goods, settle, squads, troop, Refusal, TIMER_JOB};
use crate::catalog::{self, Building as Kind, Goods, Troops, Unit, TOP_TIER};
use crate::hex::Hex;
use crate::land::{self, Ground};
use crate::rows::{Barrow, Building, Db, Hunt, Job, March, Place, Report, Squad, Troop};
use crate::store::{Seconds, Table};

/// The most rounds a fight goes: whoever defends holds the field after.
pub const MOST_ROUNDS: u32 = 20;

/// How many hexes of land there are to each barrow.
pub const HEXES_A_BARROW: u32 = 60;

/// How many reports a player is kept: the oldest go as new ones come.
pub const REPORTS_KEPT: usize = 40;

/// How a fight went.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Outcome {
    pub rounds: u32,
    /// How many of each side's units fell, unit for unit as they were given.
    pub attackers_lost: Vec<u64>,
    pub defenders_lost: Vec<u64>,
    /// Whether the attackers hold the field: every defender down, and some
    /// of their own still standing.
    pub won: bool,
}

/// How hard one kind strikes another, in hundredths: spears stop riders,
/// riders run down bows, bows pick off spears. Mangonels are made for
/// walls, and are poor in the field.
pub fn edge(striker: Troops, struck: Troops) -> u64 {
    use Troops::*;
    match (striker, struck) {
        (Spearmen, Riders) | (Riders, Archers) | (Archers, Spearmen) => 125,
        (Riders, Spearmen) | (Archers, Riders) | (Spearmen, Archers) => 85,
        (Mangonels, _) => 70,
        _ => 100,
    }
}

/// Two forces fight. Each round both strike at once, from how they stood
/// as the round began: a force's blow is a quarter of its soldiers'
/// attack, each unit's by its edge over those it faces, a tenth more or
/// less by chance; it falls on the other side's units by their share of
/// the heads, and takes a soldier for every measure of health and defence
/// it has worn through. It ends when a side has no one left, or after
/// twenty rounds.
pub fn fight(attackers: &[Unit], defenders: &[Unit], chance: impl FnMut() -> u64) -> Outcome {
    fight_sheltered(attackers, defenders, 0, chance)
}

/// The same fight with the defenders behind a wall: each of them takes
/// `shelter` hundredths more to bring down.
pub fn fight_sheltered(attackers: &[Unit], defenders: &[Unit], shelter: u64, mut chance: impl FnMut() -> u64) -> Outcome {
    let sides = [attackers, defenders];
    let mut left: [Vec<u64>; 2] = [attackers.iter().map(|unit| unit.count).collect(), defenders.iter().map(|unit| unit.count).collect()];
    // What each unit has taken toward its next soldier down.
    let mut worn: [Vec<u64>; 2] = [vec![0; attackers.len()], vec![0; defenders.len()]];
    let mut rounds = 0;
    while rounds < MOST_ROUNDS && left.iter().all(|side| side.iter().sum::<u64>() > 0) {
        rounds += 1;
        let stood = left.clone();
        for striking in 0..2 {
            let struck = 1 - striking;
            let heads: u128 = stood[struck].iter().map(|count| *count as u128).sum();
            let luck = 90 + (chance() % 21) as u128;
            let mut blow: u128 = 0;
            for (unit, count) in sides[striking].iter().zip(&stood[striking]) {
                let over: u128 = sides[struck].iter().zip(&stood[struck]).map(|(other, there)| *there as u128 * edge(unit.kind, other.kind) as u128).sum();
                blow += *count as u128 * unit.kind.soldier(unit.tier).attack as u128 * over / heads / 100;
            }
            let blow = blow * luck / 100 / 4;
            for (index, unit) in sides[struck].iter().enumerate() {
                let soldier = unit.kind.soldier(unit.tier);
                let behind = if struck == 1 { 100 + shelter } else { 100 };
                let tough = (soldier.health * soldier.defence * behind / 10_000).max(1);
                worn[struck][index] += (blow * stood[struck][index] as u128 / heads) as u64;
                let down = (worn[struck][index] / tough).min(left[struck][index]);
                worn[struck][index] -= down * tough;
                left[struck][index] -= down;
            }
        }
    }
    let lost = |side: usize| sides[side].iter().zip(&left[side]).map(|(unit, left)| unit.count - left).collect::<Vec<u64>>();
    Outcome {
        rounds,
        attackers_lost: lost(0),
        defenders_lost: lost(1),
        won: left[1].iter().sum::<u64>() == 0 && left[0].iter().sum::<u64>() > 0,
    }
}

/// Sets one new barrow of the Unquiet somewhere on the land, on open
/// ground with nothing on it or beside it. Most are weak; the strong
/// stand nearer the lake. False if chance found no such hex.
pub fn spawn_barrow(db: &mut impl Db) -> bool {
    let Ok(realm) = realm(db) else { return false };
    let span = 2 * realm.radius as u64 + 1;
    for _ in 0..60 {
        let (a, b, c, d) = (db.chance(), db.chance(), db.chance(), db.chance());
        let hex = Hex::new((a % span) as i32 - realm.radius as i32, (b % span) as i32 - realm.radius as i32);
        if hex.length() > realm.radius || !matches!(land::ground(realm.seed, realm.radius, hex), Ground::Plain | Ground::Wood | Ground::Heath | Ground::Salt) {
            continue;
        }
        if hex.within(1).iter().any(|near| Table::<Place>::get(db, near.packed()).is_some()) {
            continue;
        }
        // One to ten by chance, the low levels the commonest; and up to
        // fifteen more the nearer the lake it stands.
        let roll = c % 100;
        let nearer = (realm.radius - hex.length()) as u64 * 15 / realm.radius.max(1) as u64;
        let level = (1 + roll * roll / 1_000 + d % (nearer + 1)).min(catalog::TOP_BARROW as u64) as u32;
        let barrow = db.insert(Barrow { id: 0, hex: hex.packed(), level, fighter: 0 });
        db.insert(Place { hex: hex.packed(), kind: Place::BARROW, id: barrow.id });
        return true;
    }
    false
}

/// Scatters the Unquiet's barrows over the realm's land as it opens.
pub fn scatter_barrows(db: &mut impl Db) {
    let Ok(realm) = realm(db) else { return };
    let hexes = 1 + 3 * realm.radius * (realm.radius + 1);
    for _ in 0..hexes / HEXES_A_BARROW {
        spawn_barrow(db);
    }
}

/// The barrow at a hex, if one stands there.
pub fn barrow_at(db: &impl Db, hex: Hex) -> Option<Barrow> {
    match Table::<Place>::get(db, hex.packed()) {
        Some(place) if place.kind == Place::BARROW => Table::<Barrow>::get(db, place.id),
        _ => None,
    }
}

/// What a player has for hunting, as it stands now: their energy grown
/// since it was last settled. Not yet kept: `keep_hunt` does that.
pub fn hunt_of(db: &impl Db, player: u64) -> Hunt {
    let pace = realm(db).map(|realm| realm.pace).unwrap_or(1).max(1) as u64;
    let now = db.now();
    let mut hunt = Table::<Hunt>::get(db, player).unwrap_or(Hunt { player, energy: catalog::ENERGY_MOST, as_of: now, most: 0, point_millis: 0, cleared: 0 });
    hunt.most = catalog::ENERGY_MOST;
    hunt.point_millis = (catalog::ENERGY_SECONDS * 1_000 / pace).max(1);
    let gone = (now - hunt.as_of).max(0) as u64 * 1_000;
    let grown = hunt.energy as u64 + gone / hunt.point_millis;
    if grown >= hunt.most as u64 {
        hunt.energy = hunt.energy.max(hunt.most);
        hunt.as_of = now;
    } else {
        // What has not yet made a whole point is kept toward the next.
        hunt.energy = grown as u32;
        hunt.as_of = now - ((gone % hunt.point_millis) / 1_000) as Seconds;
    }
    hunt
}

/// Keeps a player's hunting row as it now stands.
pub fn keep_hunt(db: &mut impl Db, hunt: Hunt) {
    if Table::<Hunt>::get(db, hunt.player).is_some() {
        db.update(hunt);
    } else {
        db.insert(hunt);
    }
}

/// Whether a player may send an army against the barrow at a hex: one
/// stands there, no one is fighting it, it is no more than a level above
/// the strongest they have cleared, and they have the energy.
pub(super) fn may_hunt(db: &impl Db, player: u64, to: Hex) -> Result<Barrow, Refusal> {
    let barrow = barrow_at(db, to).ok_or(Refusal::NothingToFight)?;
    if barrow.fighter != 0 {
        return Err(Refusal::BarrowTaken);
    }
    let hunt = hunt_of(db, player);
    if barrow.level > hunt.cleared + 1 {
        return Err(Refusal::TooStrong(barrow.level - 1));
    }
    if hunt.energy < catalog::ENERGY_A_HUNT {
        return Err(Refusal::NoEnergy(hunt.energy));
    }
    Ok(barrow)
}

/// Takes the energy an attack costs, or gives it back: never past the
/// most a player keeps, though some has grown back meanwhile.
pub(super) fn spend_energy(db: &mut impl Db, player: u64, back: bool) {
    let mut hunt = hunt_of(db, player);
    hunt.energy = if back { (hunt.energy + catalog::ENERGY_A_HUNT).min(hunt.most.max(hunt.energy)) } else { hunt.energy.saturating_sub(catalog::ENERGY_A_HUNT) };
    keep_hunt(db, hunt);
}

/// How many more wounded a city can take in: what it tends, less those
/// lying there and those its armies are carrying home.
pub fn room_for_wounded(db: &impl Db, city: u64) -> u64 {
    let hospital = Table::<Building>::by(db, 0, city).iter().find(|building| building.kind == Kind::Hospital as u8).map(|building| building.level).unwrap_or(0);
    let lying: u64 = Table::<Troop>::by(db, 0, city).iter().map(|row| row.wounded).sum();
    let carried: u64 = Table::<March>::by(db, 1, city).iter().flat_map(|march| squads(db, march.id)).map(|squad| squad.wounded).sum();
    catalog::tends(hospital).saturating_sub(lying + carried)
}

/// An army has reached its barrow: if it still stands and no one else is
/// at it, the fight begins, and lasts a while. False if there is nothing
/// to fight, and the energy the attack took is given back.
pub(super) fn engage(db: &mut impl Db, march: &mut March) -> bool {
    let Some(mut barrow) = Table::<Barrow>::get(db, march.target).filter(|barrow| barrow.fighter == 0) else {
        spend_energy(db, march.owner, true);
        return false;
    };
    barrow.fighter = march.id;
    db.update(barrow);
    let pace = realm(db).map(|realm| realm.pace).unwrap_or(1);
    let now = db.now();
    march.state = March::FIGHTING;
    march.departed = now;
    march.arrives = now + catalog::paced(catalog::FIGHT_SECONDS, pace).max(1);
    true
}

/// An army's fight at its barrow is over: who fell on each side, who of
/// the army's fallen are carried home wounded (as many as its city has
/// room to tend, the best soldiers first; the rest are dead), the barrow
/// cleared and its spoils taken if the army won, and the report written.
pub(super) fn fought(db: &mut impl Db, march: &mut March) {
    let Some(mut barrow) = Table::<Barrow>::get(db, march.target) else { return };
    let mut own = squads(db, march.id);
    own.sort_by_key(|squad| (std::cmp::Reverse(squad.tier), squad.kind));
    let army: Vec<Unit> = own.iter().filter_map(|squad| Troops::of(squad.kind).map(|kind| Unit { kind, tier: squad.tier, count: squad.count })).collect();
    let unquiet = catalog::barrow(barrow.level);
    let mut rolls: Vec<u64> = (0..2 * MOST_ROUNDS).map(|_| db.chance()).collect();
    let outcome = fight(&army, &unquiet, || rolls.pop().unwrap_or(0));

    let mut room = room_for_wounded(db, march.city);
    let (mut wounded, mut dead) = (0, 0);
    for (squad, lost) in own.iter_mut().zip(&outcome.attackers_lost) {
        let saved = (*lost).min(room);
        room -= saved;
        wounded += saved;
        dead += lost - saved;
        squad.count -= lost;
        squad.wounded += saved;
        if squad.count + squad.wounded == 0 {
            Table::<Squad>::delete(db, squad.id);
        } else {
            db.update(squad.clone());
        }
    }
    let fought: u64 = army.iter().map(|unit| unit.count).sum();
    march.soldiers = fought - outcome.attackers_lost.iter().sum::<u64>();

    let mut won = Goods::of(0, 0, 0, 0);
    if outcome.won {
        // As much of the spoils as those still standing can carry, each
        // good by its share.
        let load: u64 = own.iter().map(|squad| Troops::of(squad.kind).map(|kind| kind.soldier(squad.tier).load).unwrap_or(0) * squad.count).sum();
        let spoils = catalog::spoils(barrow.level);
        let all: u64 = spoils.parts().iter().sum();
        won = Goods::from_parts(spoils.parts().map(|part| if all > load { (part as u128 * load as u128 / all as u128) as u64 } else { part }));
        if !won.is_none() {
            db.insert(crate::rows::Haul { march: march.id, owner: march.owner, grain: won.grain, timber: won.timber, stone: won.stone, moonsalt: won.moonsalt });
        }
        Table::<Place>::delete(db, barrow.hex);
        Table::<Barrow>::delete(db, barrow.id);
        spawn_barrow(db);
        let mut hunt = hunt_of(db, march.owner);
        hunt.cleared = hunt.cleared.max(barrow.level);
        keep_hunt(db, hunt);
    } else {
        // The Unquiet who fell rise again: the barrow stands as it stood.
        barrow.fighter = 0;
        db.update(barrow.clone());
    }

    let stood: u64 = unquiet.iter().map(|unit| unit.count).sum();
    let fell: u64 = outcome.defenders_lost.iter().sum();
    let words = told(barrow.level, outcome.won, fought, wounded, dead, stood - fell, won);
    report(
        db,
        Report {
            id: 0,
            player: march.owner,
            at: db.now(),
            kind: Report::HUNT,
            hex: barrow.hex,
            won: outcome.won,
            foe: barrow.level as u64,
            rounds: outcome.rounds,
            fought,
            wounded,
            dead,
            stood,
            fell,
            grain: won.grain,
            timber: won.timber,
            stone: won.stone,
            moonsalt: won.moonsalt,
            words,
            read: false,
        },
    );
}

/// A fight at a barrow in plain words.
fn told(level: u32, won: bool, fought: u64, wounded: u64, dead: u64, standing: u64, spoils: Goods) -> String {
    let mut words = if won {
        format!("Your army cleared a level {level} barrow of the Unquiet.")
    } else {
        format!("Your army was beaten at a level {level} barrow of the Unquiet. {} of the Unquiet still stood.", catalog::grouped(standing))
    };
    words += " ";
    words += &fallen(fought, wounded, dead, "soldier", "soldiers");
    if dead > 0 {
        words += " Your city had no room to tend more wounded.";
    }
    if !spoils.is_none() {
        words += &format!(" It is bringing home {spoils}.");
    }
    words
}

/// What became of a force that fought, in a sentence: "Of your 200
/// soldiers, 6 were wounded and 2 died."
pub(super) fn fallen(fought: u64, wounded: u64, dead: u64, one: &str, many: &str) -> String {
    let count = |number: u64, one: &str, many: &str| format!("{} {}", catalog::grouped(number), if number == 1 { one } else { many });
    match (wounded, dead) {
        (0, 0) => format!("None of your {} fell.", count(fought, one, many)),
        (wounded, 0) => format!("Of your {}, {} wounded.", count(fought, one, many), count(wounded, "was", "were")),
        (0, dead) => format!("Of your {}, {} died.", count(fought, one, many), catalog::grouped(dead)),
        (wounded, dead) => format!("Of your {}, {} wounded and {} died.", count(fought, one, many), count(wounded, "was", "were"), catalog::grouped(dead)),
    }
}

/// Keeps a report for its player, and lets their oldest go past what a
/// player is kept.
pub fn report(db: &mut impl Db, report: Report) -> Report {
    let player = report.player;
    let kept = db.insert(report);
    let mut all = Table::<Report>::by(db, 0, player);
    all.sort_by_key(|report| report.id);
    for old in all.iter().take(all.len().saturating_sub(REPORTS_KEPT)) {
        Table::<Report>::delete(db, old.id);
    }
    kept
}

/// A player has read one of their reports.
pub fn read_report(db: &mut impl Db, player: u64, report: u64) -> Result<(), Refusal> {
    let mut report = Table::<Report>::get(db, report).filter(|report| report.player == player).ok_or(Refusal::NoSuchReport)?;
    if !report.read {
        report.read = true;
        db.update(report);
    }
    Ok(())
}

/// A player throws one of their reports away.
pub fn forget_report(db: &mut impl Db, player: u64, report: u64) -> Result<(), Refusal> {
    let report = Table::<Report>::get(db, report).filter(|report| report.player == player).ok_or(Refusal::NoSuchReport)?;
    Table::<Report>::delete(db, report.id);
    Ok(())
}

/// A player has some of their wounded healed: paid for at once, ready
/// when the timer ends. One lot at a time.
pub fn heal(db: &mut impl Db, player: u64, kind: u8, tier: u32, count: u64) -> Result<Job, Refusal> {
    asking(db, player)?;
    let city = city_of(db, player)?;
    let troops = Troops::of(kind).ok_or(Refusal::NoSuchTroops)?;
    if !(1..=TOP_TIER).contains(&tier) {
        return Err(Refusal::NoSuchTroops);
    }
    if count == 0 {
        return Err(Refusal::NothingAsked);
    }
    if Table::<Job>::by(db, 0, city.id).iter().any(|job| job.kind == Job::HEAL) {
        return Err(Refusal::AlreadyHealing);
    }
    let row = troop(db, city.id, troops, tier);
    if row.wounded < count {
        return Err(Refusal::NotEnoughWounded(troops, tier, row.wounded));
    }
    let (each, seconds) = catalog::healing(troops.soldier(tier));
    let mut stock = settle(db, city.id)?;
    let cost = each.times(count);
    let short = goods(&stock).short_of(cost);
    if !short.is_none() {
        return Err(Refusal::CannotAfford(short));
    }
    let left = goods(&stock).minus(cost);
    set_goods(&mut stock, left);
    db.update(stock);
    let now = db.now();
    let ends = now + catalog::paced(seconds * count as i64, realm(db)?.pace);
    let mut job = db.insert(Job { id: 0, city: city.id, kind: Job::HEAL, subject: row.id, level: tier, amount: count, started: now, ends, timer: 0 });
    job.timer = db.after(ends, TIMER_JOB, job.id);
    db.update(job.clone());
    Ok(job)
}

/// A lot of wounded are healed: they stand ready again.
pub(super) fn healed(db: &mut impl Db, job: &Job) {
    let Some(mut row) = Table::<Troop>::get(db, job.subject) else { return };
    let back = job.amount.min(row.wounded);
    row.wounded -= back;
    row.ready += back;
    keep_troop(db, row);
}
