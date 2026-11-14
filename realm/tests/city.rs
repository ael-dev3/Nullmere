//! Cities over a store kept in memory: founded as a player joins, their
//! buildings raised on timers, their goods growing with time.

use realm::catalog::{self, Building as Kind, Goods};
use realm::hex::Hex;
use realm::land;
use realm::rows::{Blueprint, Building, City, Job, Land, Place, Stock};
use realm::rules::{self, Refusal};
use realm::store::{Mem, Seconds, Table};

const START: Seconds = 1_000_000;

fn opened(pace: u32) -> Mem {
    let mut db = Mem::new(START, 11);
    rules::open(&mut db, 42, pace, 48);
    db
}

fn joined(db: &mut Mem, name: &str) -> (u64, City) {
    let player = db.call(|db| rules::join(db, name)).unwrap();
    (player.id, rules::city_of(db, player.id).unwrap())
}

fn building(db: &Mem, city: u64, kind: Kind) -> Building {
    rules::building_of(db, city, kind).unwrap_or_else(|| panic!("the city has a {}", kind.name()))
}

fn stock(db: &Mem, city: u64) -> Stock {
    rules::grown(&Table::<Stock>::get(db, city).unwrap(), db.clock)
}

fn wait(db: &mut Mem, seconds: Seconds) {
    let to = db.clock + seconds;
    db.advance(to, |db, timer| rules::fire(db, timer));
}

#[test]
fn the_realm_opens_with_its_land_and_its_catalogue() {
    let db = opened(1);
    let chunks = Table::<Land>::all(&db);
    assert_eq!(chunks.len(), land::chunks(42, 48).len());
    assert!(chunks.iter().all(|chunk| chunk.ground.len() == 256));
    let blueprints = Table::<Blueprint>::all(&db);
    assert_eq!(blueprints.len(), 18 * 25);
    let keep2 = Table::<Blueprint>::get(&db, Blueprint::key(Kind::Keep as u8, 2)).unwrap();
    assert_eq!((keep2.name.as_str(), keep2.timber, keep2.stone, keep2.seconds, keep2.opens_at), ("Keep", 620, 310, 8, 1));
    let keep4 = Table::<Blueprint>::get(&db, Blueprint::key(Kind::Keep as u8, 4)).unwrap();
    assert_eq!((keep4.needs_building, keep4.needs_level), (Kind::Wall as u8, 3));
    let farm3 = Table::<Blueprint>::get(&db, Blueprint::key(Kind::Farm as u8, 3)).unwrap();
    assert_eq!(farm3.grain_hourly, catalog::yields(Kind::Farm, 3).grain);

    // A faster realm's catalogue is written at its pace.
    let fast = opened(10);
    let keep5 = Table::<Blueprint>::get(&fast, Blueprint::key(Kind::Keep as u8, 5)).unwrap();
    assert_eq!(keep5.seconds, 60, "ten minutes as written, one at ten times the pace");
    assert_eq!(Table::<Blueprint>::get(&fast, Blueprint::key(Kind::Farm as u8, 1)).unwrap().grain_hourly, 9_000);
}

#[test]
fn joining_founds_a_city_on_clear_ground() {
    let mut db = opened(1);
    let (ada, city) = joined(&mut db, "Ada");
    assert_eq!((city.owner, city.name.as_str(), city.keep, city.builders, city.founded), (ada, "Ada", 1, 1, START));
    let hex = Hex::unpacked(city.hex);
    assert!(land::ground(42, 48, hex).is_buildable());
    assert!((48 * 30 / 100..=48 * 86 / 100).contains(&hex.length()), "between the shores and the mountains: {hex:?}");
    assert_eq!(Table::<Place>::get(&db, city.hex), Some(Place { hex: city.hex, kind: Place::CITY, id: city.id }));
    let mut kinds: Vec<(u8, u32)> = Table::<Building>::by(&db, 0, city.id).iter().map(|b| (b.kind, b.level)).collect();
    kinds.sort();
    assert_eq!(kinds, vec![(Kind::Keep as u8, 1), (Kind::Farm as u8, 1), (Kind::Sawmill as u8, 1)]);
    assert_eq!(city.power, 100 + 20 + 20);
    let stock = stock(&db, city.id);
    assert_eq!(rules::goods(&stock), catalog::STARTING_GOODS);
    assert_eq!((stock.grain_hourly, stock.timber_hourly, stock.stone_hourly, stock.moonsalt_hourly), (1_300, 1_300, 300, 0));
    assert_eq!(stock.holds, 30_000);

    // Thirty more: every city on ground of its own, none crowding another.
    let mut cities = vec![city];
    for index in 0..30 {
        cities.push(joined(&mut db, &format!("Player {index}")).1);
    }
    for (index, a) in cities.iter().enumerate() {
        assert!(land::ground(42, 48, Hex::unpacked(a.hex)).is_buildable());
        for b in &cities[index + 1..] {
            assert!(Hex::unpacked(a.hex).distance(Hex::unpacked(b.hex)) > rules::CITY_SPACING, "{} and {} crowd each other", a.name, b.name);
        }
    }
    assert_eq!(Table::<Place>::all(&db).iter().filter(|place| place.kind == Place::CITY).count(), 31);
}

#[test]
fn those_who_join_about_the_same_time_are_neighbours() {
    // A world as wide as the realm's own, where chance alone would set
    // sixty cities a hundred hexes apart.
    let mut db = Mem::new(START, 5);
    rules::open(&mut db, 7, 1, 128);
    let cities: Vec<Hex> = (0..60).map(|index| Hex::unpacked(joined(&mut db, &format!("Player {index}")).1.hex)).collect();
    let nearest = |index: usize| cities.iter().enumerate().filter(|(other, _)| *other != index).map(|(_, hex)| hex.distance(cities[index])).min().unwrap();

    // The second player is settled beside the first.
    assert!(cities[0].distance(cities[1]) <= rules::NEIGHBOUR_REACH, "{} hexes apart", cities[0].distance(cities[1]));
    // Every city has a neighbour in reach, none crowding it,
    for index in 0..cities.len() {
        assert!(nearest(index) > rules::CITY_SPACING, "city {index} is crowded");
        assert!(nearest(index) <= rules::NEIGHBOUR_REACH, "city {index} stands {} hexes from anyone", nearest(index));
    }
    // and each was settled by one of the twelve who joined before it.
    for index in 1..cities.len() {
        let before = &cities[index.saturating_sub(12)..index];
        assert!(before.iter().any(|hex| hex.distance(cities[index]) <= rules::NEIGHBOUR_REACH), "city {index} was settled away from those before it");
    }
    // Sixty cities make one country, not a scattering over the world.
    let widest = cities.iter().flat_map(|a| cities.iter().map(|b| a.distance(*b))).max().unwrap();
    assert!(widest < 70, "the sixty lie {widest} hexes across");

    // Where the country about the latest has no room left, the next is
    // begun elsewhere: a small world fills to its last places all the same.
    let mut small = Mem::new(START, 3);
    rules::open(&mut small, 42, 1, 16);
    let mut count = 0;
    while small.call(|db| rules::join(db, &format!("Player {count}"))).is_ok() {
        count += 1;
        assert!(count < 400);
    }
    let all = Table::<City>::all(&small);
    assert_eq!(all.len(), count);
    assert!(count >= 12, "a world sixteen hexes out has room for a dozen cities: {count}");
    for hex in Hex::new(0, 0).within(16) {
        let length = hex.length();
        let bare = Table::<Place>::get(&small, hex.packed()).is_none();
        if bare && length >= 16 * 30 / 100 && length <= 16 * 86 / 100 && land::ground(42, 16, hex).is_buildable() {
            assert!(all.iter().any(|city| Hex::unpacked(city.hex).distance(hex) <= rules::CITY_SPACING), "room was left at {}, {}", hex.q, hex.r);
        }
    }
}

#[test]
fn a_world_with_no_ground_left_takes_no_more_players() {
    // A world so small that its band of settled ground is a few hexes wide.
    let mut db = Mem::new(START, 3);
    rules::open(&mut db, 42, 1, 12);
    let mut joined = 0;
    let refusal = loop {
        match db.call(|db| rules::join(db, &format!("Player {joined}"))) {
            Ok(_) => joined += 1,
            Err(refusal) => break refusal,
        }
        assert!(joined < 200, "a world of 469 hexes has no room for 200 cities");
    };
    assert_eq!(refusal, Refusal::NoRoom);
    assert!(joined >= 3, "but it had room for a few: {joined}");
    assert_eq!(Table::<City>::all(&db).len(), joined, "the one refused left no player and no city");
    assert_eq!(Table::<realm::rows::Player>::all(&db).len(), joined);
}

#[test]
fn the_keep_is_raised_on_a_timer_and_paid_for_at_once() {
    let mut db = opened(1);
    let (ada, city) = joined(&mut db, "Ada");
    let keep = building(&db, city.id, Kind::Keep);
    let job = db.call(|db| rules::upgrade(db, ada, keep.id)).unwrap();
    assert_eq!((job.kind, job.subject, job.level, job.started, job.ends), (Job::RAISE, keep.id, 2, START, START + 8));
    assert_eq!(rules::goods(&stock(&db, city.id)), catalog::STARTING_GOODS.minus(Goods::of(0, 620, 310, 0)), "paid as it begins");
    assert_eq!(db.timers.len(), 1);
    assert_eq!(db.timers[&job.timer].at, START + 8);

    // While it rises: still level 1, its builder busy, and it can't be raised twice.
    wait(&mut db, 7);
    assert_eq!(building(&db, city.id, Kind::Keep).level, 1);
    assert_eq!(db.call(|db| rules::upgrade(db, ada, keep.id)), Err(Refusal::AlreadyRising(Kind::Keep)));
    let farm = building(&db, city.id, Kind::Farm);
    assert_eq!(db.call(|db| rules::upgrade(db, ada, farm.id)), Err(Refusal::NeedsKeep(2)), "nothing rises above the Keep");
    assert_eq!(db.call(|db| rules::build(db, ada, Kind::Storehouse as u8)), Err(Refusal::NeedsKeep(2)));

    // Done: level 2, the city stronger, the job and its timer gone.
    wait(&mut db, 1);
    assert_eq!(building(&db, city.id, Kind::Keep).level, 2);
    let city = rules::city_of(&db, ada).unwrap();
    assert_eq!((city.keep, city.power), (2, 400 + 20 + 20));
    assert!(Table::<Job>::all(&db).is_empty());
    assert!(db.timers.is_empty());

    // Now the Farm may follow it, and one builder raises one thing at a time.
    let job = db.call(|db| rules::upgrade(db, ada, farm.id)).unwrap();
    assert_eq!(job.ends - job.started, 3);
    let sawmill = building(&db, city.id, Kind::Sawmill);
    assert_eq!(db.call(|db| rules::upgrade(db, ada, sawmill.id)), Err(Refusal::BuildersBusy));
    assert_eq!(db.call(|db| rules::build(db, ada, Kind::Quarry as u8)), Err(Refusal::BuildersBusy));
    assert_eq!(Table::<Building>::by(&db, 0, city.id).len(), 3, "a refusal adds no building");
    wait(&mut db, 3);
    assert_eq!(building(&db, city.id, Kind::Farm).level, 2);
    assert_eq!(stock(&db, city.id).grain_hourly, 400 + catalog::yields(Kind::Farm, 2).grain);
}

#[test]
fn a_new_building_is_raised_from_nothing() {
    let mut db = opened(1);
    let (ada, city) = joined(&mut db, "Ada");
    let keep = building(&db, city.id, Kind::Keep);
    db.call(|db| rules::upgrade(db, ada, keep.id)).unwrap();
    wait(&mut db, 8);
    assert_eq!(db.call(|db| rules::build(db, ada, Kind::Farm as u8)), Err(Refusal::AlreadyBuilt(Kind::Farm)));
    assert_eq!(db.call(|db| rules::build(db, ada, 99)), Err(Refusal::NoSuchBuilding));
    assert_eq!(db.call(|db| rules::build(db, ada, Kind::Workshop as u8)), Err(Refusal::NeedsKeep(10)));
    let before = stock(&db, city.id);
    let job = db.call(|db| rules::build(db, ada, Kind::Quarry as u8)).unwrap();
    let quarry = building(&db, city.id, Kind::Quarry);
    assert_eq!((quarry.level, job.subject, job.level), (0, quarry.id, 1), "standing at no level while it is first raised");
    assert_eq!(rules::goods(&stock(&db, city.id)), rules::goods(&before).minus(catalog::cost(Kind::Quarry, 1)));
    assert_eq!(db.call(|db| rules::upgrade(db, ada, quarry.id)), Err(Refusal::AlreadyRising(Kind::Quarry)));
    wait(&mut db, 3);
    assert_eq!(building(&db, city.id, Kind::Quarry).level, 1);
    assert_eq!(stock(&db, city.id).stone_hourly, 300 + 600);
    assert_eq!(rules::city_of(&db, ada).unwrap().power, 400 + 20 + 20 + 20);
}

#[test]
fn what_is_not_a_players_is_not_theirs_to_raise() {
    let mut db = opened(1);
    let (ada, city) = joined(&mut db, "Ada");
    let (bryn, _) = joined(&mut db, "Bryn");
    let keep = building(&db, city.id, Kind::Keep);
    assert_eq!(db.call(|db| rules::upgrade(db, bryn, keep.id)), Err(Refusal::NotYours));
    assert_eq!(db.call(|db| rules::upgrade(db, ada, 9_999)), Err(Refusal::NoSuchBuilding));
    assert_eq!(db.call(|db| rules::upgrade(db, 77, keep.id)), Err(Refusal::NotAPlayer));
    assert_eq!(db.call(|db| rules::build(db, 77, Kind::Quarry as u8)), Err(Refusal::NotAPlayer));
    assert_eq!(building(&db, city.id, Kind::Keep).level, 1);
    assert!(Table::<Job>::all(&db).is_empty());
}

#[test]
fn a_city_short_of_goods_is_told_what_it_lacks() {
    let mut db = opened(1);
    let (ada, city) = joined(&mut db, "Ada");
    let mut poor = Table::<Stock>::get(&db, city.id).unwrap();
    (poor.grain, poor.timber, poor.stone) = (0, 300, 300);
    db.update(poor);
    let keep = building(&db, city.id, Kind::Keep);
    let refusal = db.call(|db| rules::upgrade(db, ada, keep.id)).unwrap_err();
    assert_eq!(refusal, Refusal::CannotAfford(Goods::of(0, 320, 10, 0)));
    assert_eq!(refusal.to_string(), "You need 320 timber and 10 stone more.");
    assert_eq!(rules::goods(&stock(&db, city.id)), Goods::of(0, 300, 300, 0), "nothing taken");
    // The timber comes in at 1,300 an hour: fifteen minutes on there is enough.
    wait(&mut db, 15 * 60);
    assert_eq!(stock(&db, city.id).timber, 300 + 325);
    assert!(db.call(|db| rules::upgrade(db, ada, keep.id)).is_ok());
}

#[test]
fn goods_grow_with_time_whenever_they_are_settled_and_stop_at_what_the_city_holds() {
    let mut db = opened(1);
    let (_, city) = joined(&mut db, "Ada");
    let start = Table::<Stock>::get(&db, city.id).unwrap();

    // An hour on, settled once.
    let hour = rules::grown(&start, START + 3_600);
    assert_eq!((hour.grain, hour.timber, hour.stone), (start.grain + 1_300, start.timber + 1_300, start.stone + 300));

    // The same hour, settled every seven seconds: nothing lost between.
    let mut often = start.clone();
    let mut at = START;
    while at < START + 3_600 {
        at = (at + 7).min(START + 3_600);
        often = rules::grown(&often, at);
    }
    assert_eq!(rules::goods(&often), rules::goods(&hour));
    assert_eq!(often.as_of, START + 3_600);

    // And kept in the realm the same way.
    db.clock = START + 1_800;
    let half = db.call(|db| rules::settle(db, city.id)).unwrap();
    assert_eq!(half.grain, start.grain + 650);
    assert_eq!(Table::<Stock>::get(&db, city.id).unwrap().as_of, START + 1_800);
    assert_eq!(rules::grown(&half, START).as_of, START + 1_800, "time never runs back");

    // Stone comes in slowest: 300 an hour is one every 12 seconds.
    assert_eq!(rules::grown(&start, START + 11).stone, start.stone);
    assert_eq!(rules::grown(&start, START + 12).stone, start.stone + 1);

    // Nothing comes in past what the city holds, and what it has beyond
    // that (won, or given) is kept.
    let full = rules::grown(&start, START + 3_600 * 100);
    assert_eq!((full.grain, full.timber, full.stone), (30_000, 30_000, 30_000));
    let mut rich = start.clone();
    rich.grain = 45_000;
    assert_eq!(rules::grown(&rich, START + 3_600).grain, 45_000);
    assert_eq!(rules::settle(&mut db, 999), Err(Refusal::NoCity));
}

#[test]
fn the_keep_waits_on_the_wall_from_its_fourth_level() {
    let mut db = opened(1);
    let (ada, city) = joined(&mut db, "Ada");
    let mut rich = Table::<Stock>::get(&db, city.id).unwrap();
    (rich.grain, rich.timber, rich.stone, rich.holds) = (1_000_000, 1_000_000, 1_000_000, 2_000_000);
    db.update(rich);
    let keep = building(&db, city.id, Kind::Keep);
    for level in 2..=3 {
        db.call(|db| rules::upgrade(db, ada, keep.id)).unwrap();
        wait(&mut db, catalog::seconds(Kind::Keep, level));
    }
    assert_eq!(rules::city_of(&db, ada).unwrap().keep, 3);
    let refusal = db.call(|db| rules::upgrade(db, ada, keep.id)).unwrap_err();
    assert_eq!(refusal, Refusal::NeedsOther(Kind::Wall, 3));
    assert_eq!(refusal.to_string(), "Raise your Wall to level 3 first.");
    db.call(|db| rules::build(db, ada, Kind::Wall as u8)).unwrap();
    wait(&mut db, 3);
    let wall = building(&db, city.id, Kind::Wall);
    for level in 2..=3 {
        db.call(|db| rules::upgrade(db, ada, wall.id)).unwrap();
        wait(&mut db, catalog::seconds(Kind::Wall, level));
    }
    assert_eq!(db.call(|db| rules::upgrade(db, ada, wall.id)), Err(Refusal::NeedsKeep(4)));
    let job = db.call(|db| rules::upgrade(db, ada, keep.id)).unwrap();
    assert_eq!(job.ends - job.started, 180);
    wait(&mut db, 180);
    assert_eq!(rules::city_of(&db, ada).unwrap().keep, 4);
}

#[test]
fn a_faster_realm_runs_everything_at_its_pace() {
    let mut db = opened(20);
    let (ada, city) = joined(&mut db, "Ada");
    assert_eq!(stock(&db, city.id).grain_hourly, 26_000);
    let keep = building(&db, city.id, Kind::Keep);
    let job = db.call(|db| rules::upgrade(db, ada, keep.id)).unwrap();
    assert_eq!(job.ends - job.started, 1, "eight seconds as written, never less than one");
    wait(&mut db, 1);
    let job = db.call(|db| rules::upgrade(db, ada, keep.id)).unwrap();
    assert_eq!(job.ends - job.started, 2, "forty-five as written");
}

#[test]
fn the_realms_pace_can_be_set_afresh() {
    let mut db = opened(1);
    let (ada, city) = joined(&mut db, "Ada");
    let keep = building(&db, city.id, Kind::Keep);
    let slow = db.call(|db| rules::upgrade(db, ada, keep.id)).unwrap();
    db.call(|db| rules::repace(db, 60)).unwrap();
    assert_eq!(rules::realm(&db).unwrap().pace, 60);
    assert_eq!(Table::<Blueprint>::all(&db).len(), 18 * 25, "written out afresh, none twice");
    assert_eq!(Table::<Blueprint>::get(&db, Blueprint::key(Kind::Keep as u8, 5)).unwrap().seconds, 10);
    assert_eq!(Table::<realm::rows::Soldier>::all(&db).len(), 20);
    assert_eq!(stock(&db, city.id).grain_hourly, 1_300 * 60, "every city's rates reckoned again");
    assert_eq!(Table::<Job>::get(&db, slow.id).unwrap().ends, slow.ends, "what is under way keeps its end");
    wait(&mut db, 8);
    let fast = db.call(|db| rules::upgrade(db, ada, keep.id)).unwrap();
    assert_eq!(fast.ends - fast.started, 1, "forty-five seconds as written");
    db.call(|db| rules::repace(db, 0)).unwrap();
    assert_eq!(rules::realm(&db).unwrap().pace, 1, "never slower than written");
}

/// A player who builds whatever they can afford, in order, for a day:
/// every timer fires, nothing breaks, and the first hours move quickly.
#[test]
fn a_city_grows_through_its_first_day() {
    let mut db = opened(1);
    let (ada, city) = joined(&mut db, "Ada");
    let mut reached: Vec<(u32, Seconds)> = Vec::new();
    let end = START + 24 * 3_600;
    while db.clock < end {
        let now = rules::city_of(&db, ada).unwrap();
        if reached.last().map(|(level, _)| *level) != Some(now.keep) {
            reached.push((now.keep, db.clock - START));
        }
        if Table::<Job>::by(&db, 0, city.id).is_empty() {
            // The Keep first, then whatever is missing, then the lowest.
            let keep = building(&db, city.id, Kind::Keep);
            let mut wanted: Vec<Result<Job, Refusal>> = vec![db.call(|db| rules::upgrade(db, ada, keep.id))];
            if wanted[0].is_err() {
                for kind in Kind::ALL {
                    if rules::building_of(&db, city.id, kind).is_none() && now.keep >= kind.opens_at() {
                        wanted.push(db.call(|db| rules::build(db, ada, kind as u8)));
                        if wanted.last().unwrap().is_ok() {
                            break;
                        }
                    }
                }
            }
            if wanted.iter().all(Result::is_err) {
                let mut standing = Table::<Building>::by(&db, 0, city.id);
                standing.sort_by_key(|b| (b.level, b.kind));
                for b in standing {
                    if db.call(|db| rules::upgrade(db, ada, b.id)).is_ok() {
                        break;
                    }
                }
            }
        }
        // On to whatever happens next, or a minute for goods to come in.
        let next = db.next_due().unwrap_or(db.clock + 60).min(db.clock + 60).max(db.clock + 1);
        db.advance(next, |db, timer| rules::fire(db, timer));
        // A player asks no faster than the realm allows.
    }
    let city = rules::city_of(&db, ada).unwrap();
    let buildings = Table::<Building>::by(&db, 0, city.id);
    let said: Vec<String> = reached.iter().map(|(level, at)| format!("Keep {level} at {}", catalog::spoken(*at))).collect();
    println!("REALM a first day: {}; {} buildings, power {}", said.join(", "), buildings.len(), catalog::grouped(city.power));
    assert!(buildings.iter().all(|b| b.kind == Kind::Keep as u8 || b.level <= city.keep), "nothing stands above the Keep");
    assert!(city.keep >= 6, "a day's play reaches at least Keep 6: reached {reached:?}");
    assert!(city.keep <= 12, "and no further than the timers allow: reached {reached:?}");
    let to = |level: u32| reached.iter().find(|(l, _)| *l == level).map(|(_, at)| *at).unwrap();
    assert!(to(3) < 5 * 60, "the first levels come in minutes: {reached:?}");
    assert!(buildings.len() >= 8, "a town about the Keep by then: {}", buildings.len());
    assert_eq!(city.power, buildings.iter().map(|b| catalog::power(Kind::of(b.kind).unwrap(), b.level)).sum::<u64>());
}
