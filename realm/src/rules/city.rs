//! Cities: founding one, raising its buildings on timers, and its goods.

use super::{asking, realm, Refusal};
use crate::catalog::{self, Building as Kind, Goods, TOP_LEVEL};
use crate::hex::Hex;
use crate::land;
use crate::rows::{Building, City, Db, Job, Place, Player, Stock};
use crate::store::{Seconds, Table};

/// A timer that ends a job: its subject is the job.
pub const TIMER_JOB: u8 = 1;

/// How many hexes lie clear between one city and the next.
pub const CITY_SPACING: u32 = 2;

/// Whether a hex and the ground about it stand clear for a city.
fn is_clear(db: &impl Db, hex: Hex) -> bool {
    hex.within(CITY_SPACING).iter().all(|near| Table::<Place>::get(db, near.packed()).is_none())
}

/// A place for a new city: buildable ground between the lake's shores and
/// the mountains, clear of every other city. Tried by chance, so new
/// cities are scattered, then hex by hex, so a place is found if one is
/// left.
fn settle_site(db: &mut impl Db, seed: u64, radius: u32) -> Option<Hex> {
    let (near, far) = (radius * 30 / 100, radius * 86 / 100);
    let fits = |db: &dyn Fn(Hex) -> bool, hex: Hex| {
        let length = hex.length();
        length >= near && length <= far && land::ground(seed, radius, hex).is_buildable() && db(hex)
    };
    let span = 2 * radius as u64 + 1;
    for _ in 0..200 {
        let (a, b) = (db.chance(), db.chance());
        let hex = Hex::new((a % span) as i32 - radius as i32, (b % span) as i32 - radius as i32);
        if fits(&|hex| is_clear(db, hex), hex) {
            return Some(hex);
        }
    }
    (near..=far).flat_map(|ring| Hex::new(0, 0).ring(ring)).find(|hex| fits(&|hex| is_clear(db, hex), *hex))
}

/// A player's city.
pub fn city_of(db: &impl Db, player: u64) -> Result<City, Refusal> {
    Table::<City>::by(db, 0, player).into_iter().next().ok_or(Refusal::NoCity)
}

/// A city's building of a kind, if it has one.
pub fn building_of(db: &impl Db, city: u64, kind: Kind) -> Option<Building> {
    Table::<Building>::by(db, 0, city).into_iter().find(|building| building.kind == kind as u8)
}

/// Founds a new player's city: a Keep, a Farm and a Sawmill on clear
/// ground, and goods to begin with.
pub fn found(db: &mut impl Db, player: &Player) -> Result<City, Refusal> {
    let realm = realm(db)?;
    let hex = settle_site(db, realm.seed, realm.radius).ok_or(Refusal::NoRoom)?;
    let now = db.now();
    let city = db.insert(City { id: 0, owner: player.id, hex: hex.packed(), name: player.name.clone(), keep: 1, power: 0, founded: now, builders: 1 });
    db.insert(Place { hex: hex.packed(), kind: Place::CITY, id: city.id });
    for kind in [Kind::Keep, Kind::Farm, Kind::Sawmill] {
        db.insert(Building { id: 0, city: city.id, kind: kind as u8, level: 1 });
    }
    let start = catalog::STARTING_GOODS;
    db.insert(Stock {
        city: city.id,
        grain: start.grain,
        timber: start.timber,
        stone: start.stone,
        moonsalt: start.moonsalt,
        as_of: now,
        grain_hourly: 0,
        timber_hourly: 0,
        stone_hourly: 0,
        moonsalt_hourly: 0,
        grain_part: 0,
        timber_part: 0,
        stone_part: 0,
        moonsalt_part: 0,
        holds: 0,
    });
    Ok(reckon(db, city.id))
}

/// A stock's goods, and the same back into it.
pub fn goods(stock: &Stock) -> Goods {
    Goods::of(stock.grain, stock.timber, stock.stone, stock.moonsalt)
}

fn set_goods(stock: &mut Stock, goods: Goods) {
    (stock.grain, stock.timber, stock.stone, stock.moonsalt) = (goods.grain, goods.timber, goods.stone, goods.moonsalt);
}

/// A stock as it stands at a moment: each good grown by its hourly rate
/// since the stock was last settled, never past what the city holds. What
/// a good had earned toward its next unit is carried, so nothing is lost
/// however often it is settled.
pub fn grown(stock: &Stock, now: Seconds) -> Stock {
    let elapsed = (now - stock.as_of).max(0) as u64;
    let grow = |amount: u64, hourly: u64, part: u32| -> (u64, u32) {
        if amount >= stock.holds {
            return (amount, 0);
        }
        let earned = hourly * elapsed + part as u64;
        let total = amount + earned / 3_600;
        if total >= stock.holds {
            (stock.holds, 0)
        } else {
            (total, (earned % 3_600) as u32)
        }
    };
    let mut next = stock.clone();
    (next.grain, next.grain_part) = grow(stock.grain, stock.grain_hourly, stock.grain_part);
    (next.timber, next.timber_part) = grow(stock.timber, stock.timber_hourly, stock.timber_part);
    (next.stone, next.stone_part) = grow(stock.stone, stock.stone_hourly, stock.stone_part);
    (next.moonsalt, next.moonsalt_part) = grow(stock.moonsalt, stock.moonsalt_hourly, stock.moonsalt_part);
    next.as_of = now.max(stock.as_of);
    next
}

/// Brings a city's stock up to now, keeps it, and gives it back.
pub fn settle(db: &mut impl Db, city: u64) -> Result<Stock, Refusal> {
    let stock = Table::<Stock>::get(db, city).ok_or(Refusal::NoCity)?;
    let settled = grown(&stock, db.now());
    db.update(settled.clone());
    Ok(settled)
}

/// Reckons a city afresh from what stands in it: its power, its Keep's
/// level, what its works bring in each hour and how much it holds. Its
/// stock is settled first, at the rates it had.
fn reckon(db: &mut impl Db, city: u64) -> City {
    let pace = realm(db).map(|realm| realm.pace).unwrap_or(1) as u64;
    let mut row = Table::<City>::get(db, city).expect("a city reckoned is a city kept");
    let buildings = Table::<Building>::by(db, 0, city);
    let level_of = |kind: Kind| buildings.iter().find(|b| b.kind == kind as u8).map(|b| b.level).unwrap_or(0);
    let mut hourly = Goods::NONE;
    let mut power = 0;
    for building in &buildings {
        if let Some(kind) = Kind::of(building.kind) {
            hourly = hourly.plus(catalog::yields(kind, building.level));
            power += catalog::power(kind, building.level);
        }
    }
    if let Ok(mut stock) = settle(db, city) {
        let hourly = hourly.times(pace);
        (stock.grain_hourly, stock.timber_hourly, stock.stone_hourly, stock.moonsalt_hourly) = (hourly.grain, hourly.timber, hourly.stone, hourly.moonsalt);
        stock.holds = catalog::holds(level_of(Kind::Storehouse));
        db.update(stock);
    }
    row.keep = level_of(Kind::Keep).max(1);
    row.power = power;
    db.update(row.clone());
    row
}

/// Begins raising a building to a level: a builder free, the cost paid
/// from the city's stock, and a timer set for when it is done.
fn raise(db: &mut impl Db, city: &City, building: &Building, kind: Kind, level: u32) -> Result<Job, Refusal> {
    let jobs = Table::<Job>::by(db, 0, city.id);
    if jobs.iter().any(|job| job.kind == Job::RAISE && job.subject == building.id) {
        return Err(Refusal::AlreadyRising(kind));
    }
    if jobs.iter().filter(|job| job.kind == Job::RAISE).count() as u32 >= city.builders {
        return Err(Refusal::BuildersBusy);
    }
    let mut stock = settle(db, city.id)?;
    let cost = catalog::cost(kind, level);
    let short = goods(&stock).short_of(cost);
    if !short.is_none() {
        return Err(Refusal::CannotAfford(short));
    }
    let left = goods(&stock).minus(cost);
    set_goods(&mut stock, left);
    db.update(stock);
    let now = db.now();
    let ends = now + catalog::paced(catalog::seconds(kind, level), realm(db)?.pace);
    let mut job = db.insert(Job { id: 0, city: city.id, kind: Job::RAISE, subject: building.id, level, started: now, ends, timer: 0 });
    job.timer = db.after(ends, TIMER_JOB, job.id);
    db.update(job.clone());
    Ok(job)
}

/// A player builds a building their city has not got.
pub fn build(db: &mut impl Db, player: u64, kind: u8) -> Result<Job, Refusal> {
    asking(db, player)?;
    let city = city_of(db, player)?;
    let kind = Kind::of(kind).ok_or(Refusal::NoSuchBuilding)?;
    if building_of(db, city.id, kind).is_some() {
        return Err(Refusal::AlreadyBuilt(kind));
    }
    if city.keep < kind.opens_at() {
        return Err(Refusal::NeedsKeep(kind.opens_at()));
    }
    // Checked before the building is added, so a refusal leaves no trace
    // even where nothing undoes a failed reducer.
    if Table::<Job>::by(db, 0, city.id).iter().filter(|job| job.kind == Job::RAISE).count() as u32 >= city.builders {
        return Err(Refusal::BuildersBusy);
    }
    let short = goods(&settle(db, city.id)?).short_of(catalog::cost(kind, 1));
    if !short.is_none() {
        return Err(Refusal::CannotAfford(short));
    }
    let building = db.insert(Building { id: 0, city: city.id, kind: kind as u8, level: 0 });
    raise(db, &city, &building, kind, 1)
}

/// A player raises one of their buildings a level.
pub fn upgrade(db: &mut impl Db, player: u64, building: u64) -> Result<Job, Refusal> {
    asking(db, player)?;
    let building = Table::<Building>::get(db, building).ok_or(Refusal::NoSuchBuilding)?;
    let city = Table::<City>::get(db, building.city).ok_or(Refusal::NoSuchBuilding)?;
    if city.owner != player {
        return Err(Refusal::NotYours);
    }
    let kind = Kind::of(building.kind).ok_or(Refusal::NoSuchBuilding)?;
    let level = building.level + 1;
    if building.level == 0 {
        return Err(Refusal::AlreadyRising(kind));
    }
    if level > TOP_LEVEL {
        return Err(Refusal::AtTopLevel(kind));
    }
    if kind != Kind::Keep && level > city.keep {
        return Err(Refusal::NeedsKeep(level));
    }
    if let Some((other, needed)) = catalog::needs(kind, level) {
        if building_of(db, city.id, other).map(|b| b.level).unwrap_or(0) < needed {
            return Err(Refusal::NeedsOther(other, needed));
        }
    }
    raise(db, &city, &building, kind, level)
}

/// A job's timer has come due: the work is done.
pub fn finish(db: &mut impl Db, job: u64) {
    let Some(job) = Table::<Job>::get(db, job) else { return };
    Table::<Job>::delete(db, job.id);
    if job.kind == Job::RAISE {
        if let Some(mut building) = Table::<Building>::get(db, job.subject) {
            building.level = job.level;
            db.update(building);
            reckon(db, job.city);
        }
    }
}
