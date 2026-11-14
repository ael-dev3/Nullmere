//! What a city learns over a store kept in memory: its Academy's studies
//! on their timers, and what each topic adds.

use realm::catalog::{self, Building as Kind, Goods, Topic, Troops, Unit};
use realm::hex::Hex;
use realm::rows::{Building, City, Job, Lore, March, Site, Stock, Study, Troop};
use realm::rules::{self, Asked, Mastery, Refusal};
use realm::store::{Mem, Seconds, Table};

const START: Seconds = 3_000_000;

fn joined() -> (Mem, u64, City) {
    let mut db = Mem::new(START, 5);
    rules::open(&mut db, 7, 1, 48);
    let player = db.call(|db| rules::join(db, "Ada")).unwrap().id;
    let city = rules::city_of(&db, player).unwrap();
    (db, player, city)
}

fn stock(db: &Mem, city: u64) -> Goods {
    rules::goods(&rules::grown(&Table::<Stock>::get(db, city).unwrap(), db.clock))
}

fn wait(db: &mut Mem, seconds: Seconds) {
    let to = db.clock + seconds;
    db.advance(to, |db, timer| rules::fire(db, timer));
}

/// Sets what a city has learnt of a topic, and reckons the city afresh
/// by raising and settling nothing: the next thing asked reads it.
fn learn(db: &mut Mem, city: u64, topic: Topic, level: u32) {
    let lore = Lore { id: Lore::key(city, topic as u8), city, topic: topic as u8, level };
    if Table::<Lore>::get(db, lore.id).is_some() {
        db.update(lore);
    } else {
        db.insert(lore);
    }
}

fn academy(db: &mut Mem, city: u64, level: u32) -> Building {
    match rules::building_of(db, city, Kind::Academy) {
        Some(mut building) => {
            building.level = level;
            db.update(building.clone());
            building
        }
        None => db.insert(Building { id: 0, city, kind: Kind::Academy as u8, level }),
    }
}

#[test]
fn the_studies_are_written_out_for_clients() {
    let (db, _, _) = joined();
    let written = Table::<Study>::all(&db);
    assert_eq!(written.len(), 15 * 10);
    let first = Table::<Study>::get(&db, Study::key(Topic::Tillage as u8, 1)).unwrap();
    assert_eq!((first.name.as_str(), first.words.as_str(), first.each), ("Tillage", "Your Farm brings in 5% more grain.", 5));
    assert_eq!(Goods::of(first.grain, first.timber, first.stone, first.moonsalt), Goods::of(500, 333, 0, 0));
    assert_eq!((first.seconds, first.needs_level), (120, 1));
    let last = Table::<Study>::get(&db, Study::key(Topic::Drill as u8, 10)).unwrap();
    assert_eq!((last.name.as_str(), last.words.as_str()), ("Drill", "Soldiers are trained 3% sooner."));
    assert_eq!(Goods::of(last.grain, last.timber, last.stone, last.moonsalt), Goods::of(0, 32_000, 21_333, 300), "arms are paid for in timber and stone");
    assert_eq!((last.seconds, last.needs_level), (12_000, 19));
    for topic in Topic::ALL {
        assert_eq!(Topic::of(topic as u8), Some(topic));
        assert!(topic.words().contains(&format!("{}%", topic.each())), "{}", topic.words());
        for level in 1..catalog::TOP_STUDY {
            let (lower, higher) = (catalog::study_cost(topic, level).parts(), catalog::study_cost(topic, level + 1).parts());
            assert!((0..4).all(|good| higher[good] >= lower[good]) && higher != lower);
            assert!(catalog::study_seconds(level + 1) > catalog::study_seconds(level));
            assert!(catalog::study_needs(level + 1) > catalog::study_needs(level));
        }
    }
    assert_eq!(Topic::of(0), None);
    assert_eq!(Topic::of(16), None);
    assert_eq!(Topic::sharpens(Troops::Riders), Topic::Horsemanship);
    assert!(!Topic::Gathering.is_of_war() && Topic::Spearcraft.is_of_war());
    // A faster realm studies as much faster.
    let mut fast = Mem::new(START, 5);
    rules::open(&mut fast, 7, 60, 48);
    assert_eq!(Table::<Study>::get(&fast, Study::key(1, 1)).unwrap().seconds, 2);
}

#[test]
fn an_academy_studies_one_topic_at_a_time_on_a_timer() {
    let (mut db, player, city) = joined();
    // No Academy, no studies.
    assert_eq!(db.call(|db| rules::study(db, player, Topic::Tillage as u8)), Err(Refusal::NeedsOther(Kind::Academy, 1)));
    let school = academy(&mut db, city.id, 1);
    assert_eq!(db.call(|db| rules::study(db, player, 99)), Err(Refusal::NoSuchTopic));
    assert_eq!(Refusal::NoSuchTopic.to_string(), "There is no such study.");

    // Begun: paid for at once, learnt when its two minutes are up.
    let before = stock(&db, city.id);
    let hourly = Table::<Stock>::get(&db, city.id).unwrap().grain_hourly;
    let job = db.call(|db| rules::study(db, player, Topic::Tillage as u8)).unwrap();
    assert_eq!((job.kind, job.subject, job.level, job.ends - job.started), (Job::STUDY, Topic::Tillage as u64, 1, 120));
    assert_eq!(before.minus(stock(&db, city.id)), Goods::of(500, 333, 0, 0));
    assert_eq!(rules::learnt(&db, city.id, Topic::Tillage), 0);
    // One at a time, and the Academy can't be raised meanwhile.
    assert_eq!(db.call(|db| rules::study(db, player, Topic::Forestry as u8)), Err(Refusal::AlreadyStudying));
    assert_eq!(Refusal::AlreadyStudying.to_string(), "Your Academy is already at its studies. Wait for them to finish.");
    let mut keep = Table::<City>::get(&db, city.id).unwrap();
    keep.keep = 9;
    db.update(keep);
    assert_eq!(db.call(|db| rules::upgrade(db, player, school.id)), Err(Refusal::BusyStudying));
    assert_eq!(Refusal::BusyStudying.to_string(), "Your Academy is at its studies. Wait for them to finish.");

    wait(&mut db, 119);
    assert_eq!(rules::learnt(&db, city.id, Topic::Tillage), 0);
    wait(&mut db, 1);
    assert_eq!(rules::learnt(&db, city.id, Topic::Tillage), 1);
    assert_eq!(rules::boost(&db, city.id, Topic::Tillage), 5);
    assert!(Table::<Job>::by(&db, 0, city.id).is_empty());
    // The Farm brings in a twentieth more from that moment.
    assert_eq!(Table::<Stock>::get(&db, city.id).unwrap().grain_hourly, hourly * 105 / 100);
    assert_eq!(Table::<Stock>::get(&db, city.id).unwrap().timber_hourly, hourly, "and the Sawmill what it did");

    // The second level asks an Academy of the third.
    assert_eq!(db.call(|db| rules::study(db, player, Topic::Tillage as u8)), Err(Refusal::NeedsOther(Kind::Academy, 3)));
    academy(&mut db, city.id, 3);
    let job = db.call(|db| rules::study(db, player, Topic::Tillage as u8)).unwrap();
    assert_eq!((job.level, job.ends - job.started), (2, 480));
    wait(&mut db, 480);
    assert_eq!(rules::learnt(&db, city.id, Topic::Tillage), 2);
    // An Academy still being raised studies nothing.
    academy(&mut db, city.id, 0);
    assert_eq!(db.call(|db| rules::study(db, player, Topic::Forestry as u8)), Err(Refusal::AlreadyRising(Kind::Academy)));
    // Too dear is refused with what is missing; all there is to learn, with that.
    academy(&mut db, city.id, 25);
    let mut poor = Table::<Stock>::get(&db, city.id).unwrap();
    (poor.grain, poor.timber, poor.grain_hourly, poor.timber_hourly) = (100, 5_000, 0, 0);
    db.update(poor);
    assert_eq!(db.call(|db| rules::study(db, player, Topic::Storage as u8)), Err(Refusal::CannotAfford(Goods::of(400, 0, 0, 0))));
    learn(&mut db, city.id, Topic::Marching, 10);
    assert_eq!(db.call(|db| rules::study(db, player, Topic::Marching as u8)), Err(Refusal::NothingMoreToLearn(Topic::Marching)));
    assert_eq!(Refusal::NothingMoreToLearn(Topic::Marching).to_string(), "You have learnt all there is of Marching.");
    assert_eq!(db.call(|db| rules::study(db, 99, 1)), Err(Refusal::NotAPlayer));
}

#[test]
fn what_is_learnt_adds_to_the_citys_works_and_its_pace() {
    let (mut db, player, city) = joined();
    let mut keep = rules::building_of(&db, city.id, Kind::Keep).unwrap();
    keep.level = 9;
    db.update(keep);
    let mut row = Table::<City>::get(&db, city.id).unwrap();
    row.keep = 9;
    db.update(row);
    let plain = Table::<Stock>::get(&db, city.id).unwrap();

    // Storage: a tenth more held for each level. Read as the city is next reckoned.
    learn(&mut db, city.id, Topic::Storage, 3);
    learn(&mut db, city.id, Topic::Forestry, 4);
    let farm = rules::building_of(&db, city.id, Kind::Farm).unwrap();
    db.call(|db| rules::upgrade(db, player, farm.id)).unwrap();
    wait(&mut db, 1_000);
    let learned = Table::<Stock>::get(&db, city.id).unwrap();
    assert_eq!(learned.holds, plain.holds * 130 / 100);
    assert_eq!(learned.timber_hourly, plain.timber_hourly * 120 / 100);

    // Building: three hundredths sooner for each level.
    let sawmill = rules::building_of(&db, city.id, Kind::Sawmill).unwrap();
    let written = catalog::seconds(Kind::Sawmill, 2);
    learn(&mut db, city.id, Topic::Building, 10);
    let job = db.call(|db| rules::upgrade(db, player, sawmill.id)).unwrap();
    assert_eq!(job.ends - job.started, written * 70 / 100);
    assert_eq!(rules::sooner(&db, city.id, Topic::Building, 1), 1, "never to nothing");
    wait(&mut db, 10_000);

    // Drill: soldiers trained sooner.
    let barracks = db.insert(Building { id: 0, city: city.id, kind: Kind::Barracks as u8, level: 1 });
    learn(&mut db, city.id, Topic::Drill, 5);
    let batch = db.call(|db| rules::train(db, player, barracks.id, 1, 20)).unwrap();
    assert_eq!(batch.ends - batch.started, 20 * 8 * 85 / 100);
    wait(&mut db, 1_000);

    // Marching: the same road in less time; gathering: the same load sooner.
    let from = Hex::unpacked(city.hex);
    let mut sites: Vec<Site> = Table::<Site>::all(&db);
    sites.sort_by_key(|site| (Hex::unpacked(site.hex).distance(from), site.id));
    let site = sites.into_iter().find(|site| realm::land::way(7, 48, from, Hex::unpacked(site.hex)).is_some()).unwrap();
    let army = [Asked { kind: 1, tier: 1, count: 20 }];
    let slow = db.call(|db| rules::send(db, player, Hex::unpacked(site.hex), March::GATHER, &army)).unwrap();
    let road = slow.arrives - slow.departed;
    wait(&mut db, road);
    let working = Table::<March>::get(&db, slow.id).unwrap();
    let work = working.arrives - working.departed;
    db.call(|db| rules::recall(db, player, slow.id)).unwrap();
    wait(&mut db, 100_000);
    learn(&mut db, city.id, Topic::Marching, 10);
    learn(&mut db, city.id, Topic::Gathering, 10);
    let fast = db.call(|db| rules::send(db, player, Hex::unpacked(site.hex), March::GATHER, &army)).unwrap();
    let quicker = fast.arrives - fast.departed;
    assert!(quicker < road && quicker >= road * 100 / 150 - 1, "{road} seconds of road, {quicker} with marching learnt to the full");
    wait(&mut db, quicker);
    let working = Table::<March>::get(&db, fast.id).unwrap();
    assert_eq!(working.arrives - working.departed, (work as u64).div_ceil(2) as i64, "twice as fast at the tenth level");

    // Field medicine: room to tend more.
    assert_eq!(rules::room_for_wounded(&db, city.id), 50);
    learn(&mut db, city.id, Topic::Medicine, 4);
    assert_eq!(rules::room_for_wounded(&db, city.id), 70);
}

#[test]
fn what_is_learnt_of_arms_tells_in_a_fight() {
    let unit = |count: u64| [Unit { kind: Troops::Spearmen, tier: 1, count }];
    let plain = rules::fight(&unit(100), &unit(100), || 10);
    assert!(!plain.won, "like against like, the defenders hold");
    // Spearcraft to the full: three tenths harder a blow, and the same hundred win.
    let sharp = Mastery { strikes: [30, 0, 0, 0], shields: 0 };
    let sharper = rules::fight_learned(&unit(100), &unit(100), [sharp, Mastery::default()], 0, || 10);
    assert!(sharper.won);
    assert!(sharper.attackers_lost[0] < plain.attackers_lost[0]);
    // The other kinds' craft is nothing to spearmen.
    let wrong = Mastery { strikes: [0, 30, 30, 30], shields: 0 };
    assert_eq!(rules::fight_learned(&unit(100), &unit(100), [wrong, Mastery::default()], 0, || 10), plain);
    // Shields to the full on the defenders' side: they lose fewer, and hold against more.
    let guarded = Mastery { strikes: [0; 4], shields: 30 };
    let held = rules::fight_learned(&unit(110), &unit(100), [Mastery::default(), guarded], 0, || 10);
    assert!(!held.won, "a hundred and ten would have beaten a hundred unshielded");
    assert!(rules::fight(&unit(110), &unit(100), || 10).won);

    // A city's mastery is read from what it has learnt.
    let (mut db, _, city) = joined();
    assert_eq!(rules::mastery(&db, city.id), Mastery::default());
    learn(&mut db, city.id, Topic::Archery, 4);
    learn(&mut db, city.id, Topic::Siegecraft, 1);
    learn(&mut db, city.id, Topic::Shields, 7);
    assert_eq!(rules::mastery(&db, city.id), Mastery { strikes: [0, 12, 0, 3], shields: 21 });

    // And it tells at a barrow: the same army loses fewer with its craft learnt.
    let lost_with = |spearcraft: u32| {
        let (mut db, player, city) = joined();
        rules::keep_troop(&mut db, Troop { id: Troop::key(city.id, 1, 1), city: city.id, kind: 1, tier: 1, ready: 60, wounded: 0 });
        learn(&mut db, city.id, Topic::Spearcraft, spearcraft);
        let from = Hex::unpacked(city.hex);
        let mut barrows = Table::<realm::rows::Barrow>::all(&db);
        barrows.sort_by_key(|barrow| (Hex::unpacked(barrow.hex).distance(from), barrow.id));
        let mut barrow = barrows.into_iter().find(|barrow| realm::land::way(7, 48, from, Hex::unpacked(barrow.hex)).is_some()).unwrap();
        barrow.level = 1;
        db.update(barrow.clone());
        let march = db.call(|db| rules::send(db, player, Hex::unpacked(barrow.hex), March::HUNT, &[Asked { kind: 1, tier: 1, count: 60 }])).unwrap();
        db.advance(march.arrives + catalog::FIGHT_SECONDS, |db, timer| rules::fire(db, timer));
        let report = Table::<realm::rows::Report>::by(&db, 0, player).pop().unwrap();
        assert!(report.won);
        report.wounded + report.dead
    };
    assert!(lost_with(10) < lost_with(0), "{} against {}", lost_with(10), lost_with(0));
}
