//! Commanders over a store kept in memory: who a player has, taking on
//! more, an army led, and what its leader adds and learns.

use realm::catalog::{self, Building as Kind, Goods, Leading, Troops, Way};
use realm::hex::Hex;
use realm::land;
use realm::rows::{Barrow, Building, City, Commander, Haul, March, Report, Site, Stock, Troop};
use realm::rules::{self, Asked, Refusal};
use realm::store::{Mem, Seconds, Table};

const START: Seconds = 3_000_000;
const SEED: u64 = 7;
const RADIUS: u32 = 48;

/// A realm with one player, their Keep high enough for three armies,
/// with spearmen ready, and their one commander.
fn led(spearmen: u64) -> (Mem, u64, City, Commander) {
    let mut db = Mem::new(START, 5);
    rules::open(&mut db, SEED, 1, RADIUS);
    let player = db.call(|db| rules::join(db, "Ada")).unwrap().id;
    let mut city = rules::city_of(&db, player).unwrap();
    city.keep = 12;
    db.update(city.clone());
    rules::keep_troop(&mut db, Troop { id: Troop::key(city.id, 1, 1), city: city.id, kind: 1, tier: 1, ready: spearmen, wounded: 0 });
    let commander = rules::commanders_of(&db, player).remove(0);
    (db, player, city, commander)
}

/// Gives a commander a way and a level.
fn make(db: &mut Mem, commander: &Commander, way: Way, level: u32) -> Commander {
    let mut row = Table::<Commander>::get(db, commander.id).unwrap();
    (row.way, row.level, row.seen) = (way as u8, level, 0);
    db.update(row.clone());
    row
}

fn until(db: &mut Mem, moment: Seconds) {
    db.advance(moment, |db, timer| rules::fire(db, timer));
}

fn spears(count: u64) -> Vec<Asked> {
    vec![Asked { kind: Troops::Spearmen as u8, tier: 1, count }]
}

/// The nearest site or barrow of the first level that a way leads to.
fn nearest_site(db: &Mem, city: &City) -> Site {
    let from = Hex::unpacked(city.hex);
    let mut sites = Table::<Site>::all(db);
    sites.sort_by_key(|site| (Hex::unpacked(site.hex).distance(from), site.id));
    sites.into_iter().find(|site| land::way(SEED, RADIUS, from, Hex::unpacked(site.hex)).is_some()).unwrap()
}

fn nearest_barrow(db: &mut Mem, city: &City) -> Barrow {
    let from = Hex::unpacked(city.hex);
    let mut barrows = Table::<Barrow>::all(db);
    barrows.sort_by_key(|barrow| (Hex::unpacked(barrow.hex).distance(from), barrow.id));
    let mut barrow = barrows.into_iter().find(|barrow| land::way(SEED, RADIUS, from, Hex::unpacked(barrow.hex)).is_some()).unwrap();
    barrow.level = 1;
    db.update(barrow.clone());
    barrow
}

#[test]
fn each_way_of_war_adds_what_it_is_best_at() {
    assert_eq!(Way::ALL.len(), 6);
    for way in Way::ALL {
        assert_eq!(Way::of(way as u8), Some(way));
        assert!(!way.name().is_empty() && way.words().ends_with('.'));
        let (first, last) = (way.leading(1), way.leading(catalog::TOP_COMMAND));
        assert_ne!(first, Leading::default(), "{} adds something from the first", way.name());
        assert_ne!(first, last, "and more at the last");
        assert_eq!(way.leading(99), last);
        assert_eq!(way.leading(0), first);
    }
    assert_eq!(Way::of(0), None);
    assert_eq!(Way::of(7), None);
    assert_eq!(Way::Vanguard.leading(1), Leading { strikes: [6, 0, 0, 0], ..Leading::default() });
    assert_eq!(Way::Fletcher.leading(10).strikes, [0, 15, 0, 0]);
    assert_eq!(Way::Outrider.leading(10), Leading { strikes: [0, 0, 15, 0], haste: 8, ..Leading::default() });
    assert_eq!(Way::Wallbreaker.leading(30), Leading { strikes: [0, 0, 0, 35], breaches: 40, ..Leading::default() });
    assert_eq!(Way::Warden.leading(30).shields, 35);
    assert_eq!(Way::Gleaner.leading(5), Leading { gathers: 20, carries: 10, ..Leading::default() });
    assert_eq!([1, 2, 10].map(catalog::command_needs), [100, 400, 10_000]);
    assert_eq!([0, 1, 4, 5, 10, 19, 20, 25].map(catalog::commanders), [1, 2, 2, 3, 4, 5, 6, 6]);
    assert_eq!(catalog::hire_cost(1), Goods::of(2_000, 2_000, 1_000, 0));
    assert_eq!(catalog::hire_cost(3), Goods::of(18_000, 18_000, 9_000, 150));
}

#[test]
fn a_player_begins_with_one_commander_and_takes_on_more_from_a_tavern() {
    let (mut db, player, city, first) = led(0);
    assert_eq!(rules::commanders_of(&db, player), vec![first.clone()]);
    assert_eq!((first.owner, first.level, first.seen, first.march), (player, 1, 0, 0));
    assert!(Way::of(first.way).is_some());
    assert!(first.name.len() >= 4 && first.name.chars().next().unwrap().is_uppercase(), "{}", first.name);

    // No Tavern, no more.
    assert_eq!(db.call(|db| rules::hire(db, player)), Err(Refusal::NeedsOther(Kind::Tavern, 1)));
    let tavern = db.insert(Building { id: 0, city: city.id, kind: Kind::Tavern as u8, level: 1 });
    let before = rules::goods(&rules::grown(&Table::<Stock>::get(&db, city.id).unwrap(), db.clock));
    let second = db.call(|db| rules::hire(db, player)).unwrap();
    let after = rules::goods(&rules::grown(&Table::<Stock>::get(&db, city.id).unwrap(), db.clock));
    assert_eq!(before.minus(after), catalog::hire_cost(1));
    assert_ne!(second.way, first.way, "of a way she has not yet");
    assert_ne!(second.name, first.name);
    assert_eq!(rules::commanders_of(&db, player).len(), 2);
    // The third waits on the Tavern's fifth level.
    assert_eq!(db.call(|db| rules::hire(db, player)), Err(Refusal::NeedsOther(Kind::Tavern, 5)));

    // With a Tavern of the twentieth and goods enough, six in all: one of each way.
    let mut grown = tavern;
    grown.level = 20;
    db.update(grown);
    let mut rich = Table::<Stock>::get(&db, city.id).unwrap();
    (rich.grain, rich.timber, rich.stone, rich.moonsalt) = (9_000_000, 9_000_000, 9_000_000, 9_000);
    db.update(rich);
    for _ in 0..4 {
        db.call(|db| rules::hire(db, player)).unwrap();
    }
    let all = rules::commanders_of(&db, player);
    assert_eq!(all.len(), 6);
    let mut ways: Vec<u8> = all.iter().map(|commander| commander.way).collect();
    ways.sort();
    assert_eq!(ways, vec![1, 2, 3, 4, 5, 6]);
    let mut names: Vec<&str> = all.iter().map(|commander| commander.name.as_str()).collect();
    names.sort();
    names.dedup();
    assert_eq!(names.len(), 6, "no two of a name");
    assert_eq!(db.call(|db| rules::hire(db, player)), Err(Refusal::NoMoreCommanders));
    assert_eq!(Refusal::NoMoreCommanders.to_string(), "Your city keeps as many commanders as it can.");
    // Too dear is refused with what is missing.
    let (mut db, player, city, _) = led(0);
    db.insert(Building { id: 0, city: city.id, kind: Kind::Tavern as u8, level: 1 });
    let mut poor = Table::<Stock>::get(&db, city.id).unwrap();
    (poor.grain, poor.grain_hourly) = (500, 0);
    db.update(poor);
    assert_eq!(db.call(|db| rules::hire(db, player)), Err(Refusal::CannotAfford(Goods::of(1_500, 0, 0, 0))));
}

#[test]
fn an_army_is_led_by_one_commander_who_comes_home_with_it() {
    let (mut db, player, city, commander) = led(100);
    let site = nearest_site(&db, &city);
    let to = Hex::unpacked(site.hex);

    // Someone else's, or no one's, leads nothing.
    let other = db.call(|db| rules::join(db, "Bryn")).unwrap().id;
    let theirs = rules::commanders_of(&db, other).remove(0);
    assert_eq!(db.call(|db| rules::send_led(db, player, to, March::GATHER, &spears(20), theirs.id)), Err(Refusal::NoSuchCommander));
    assert_eq!(db.call(|db| rules::send_led(db, player, to, March::GATHER, &spears(20), 999)), Err(Refusal::NoSuchCommander));
    assert_eq!(Refusal::NoSuchCommander.to_string(), "You have no such commander.");
    assert_eq!(rules::troop(&db, city.id, Troops::Spearmen, 1).ready, 100, "and no one has set out");

    // Led: the march names its leader, and the leader is out with it.
    let march = db.call(|db| rules::send_led(db, player, to, March::GATHER, &spears(20), commander.id)).unwrap();
    assert_eq!(march.leader, commander.id);
    assert_eq!(Table::<Commander>::get(&db, commander.id).unwrap().march, march.id);
    // They can't lead a second meanwhile; an army with no one to lead it still goes.
    let elsewhere = Table::<Site>::all(&db).into_iter().find(|other| other.id != site.id && land::way(SEED, RADIUS, Hex::unpacked(city.hex), Hex::unpacked(other.hex)).is_some()).unwrap();
    let again = db.call(|db| rules::send_led(db, player, Hex::unpacked(elsewhere.hex), March::GATHER, &spears(20), commander.id));
    assert_eq!(again, Err(Refusal::CommanderAway(commander.name.clone())));
    assert_eq!(Refusal::CommanderAway("Corwen".into()).to_string(), "Corwen is out with another army.");
    let unled = db.call(|db| rules::send(db, player, Hex::unpacked(elsewhere.hex), March::GATHER, &spears(20))).unwrap();
    assert_eq!(unled.leader, 0);
    assert_eq!(rules::leading_of(&db, &unled), Leading::default());

    // Home: the commander is in the city again, and has seen a little of the work.
    until(&mut db, START + 200_000);
    assert!(Table::<March>::get(&db, march.id).is_none());
    let back = Table::<Commander>::get(&db, commander.id).unwrap();
    assert_eq!(back.march, 0);
    assert!(back.seen > 0 || back.level > 1, "a load of 240 is twelve seen");
    assert!(db.call(|db| rules::send_led(db, player, to, March::GATHER, &spears(20), commander.id)).is_ok());
}

#[test]
fn what_a_commander_adds_tells_on_the_road_at_work_and_in_a_fight() {
    // The same road and the same work, led by no one, by an outrider and by a gleaner.
    let timed = |way: Option<(Way, u32)>| {
        let (mut db, player, city, commander) = led(100);
        let site = nearest_site(&db, &city);
        let leader = way.map(|(way, level)| make(&mut db, &commander, way, level).id).unwrap_or(0);
        let march = db.call(|db| rules::send_led(db, player, Hex::unpacked(site.hex), March::GATHER, &spears(50), leader)).unwrap();
        let road = march.arrives - march.departed;
        until(&mut db, march.arrives);
        let working = Table::<March>::get(&db, march.id).unwrap();
        let work = working.arrives - working.departed;
        until(&mut db, working.arrives);
        let haul = Table::<Haul>::get(&db, march.id).unwrap();
        (road, work, haul.grain + haul.timber + haul.stone + haul.moonsalt)
    };
    let (road, work, load) = timed(None);
    assert_eq!(load, 50 * 12);
    let (faster, _, same) = timed(Some((Way::Outrider, 30)));
    assert!(faster < road, "an outrider's army takes {faster} seconds of a road of {road}");
    assert_eq!(same, load);
    let (_, quicker, more) = timed(Some((Way::Gleaner, 30)));
    assert_eq!(more, load * 135 / 100, "a gleaner's army carries a third more");
    // A third more to gather at 1.7 times the speed: sooner all the same.
    assert!(quicker < work, "{quicker} seconds of work against {work}");

    // The same fight at a barrow, led by no one, by a vanguard and by a warden.
    let fallen = |way: Option<(Way, u32)>| {
        let (mut db, player, city, commander) = led(60);
        let barrow = nearest_barrow(&mut db, &city);
        let leader = way.map(|(way, level)| make(&mut db, &commander, way, level).id).unwrap_or(0);
        let march = db.call(|db| rules::send_led(db, player, Hex::unpacked(barrow.hex), March::HUNT, &spears(60), leader)).unwrap();
        until(&mut db, march.arrives + catalog::FIGHT_SECONDS);
        let report = Table::<Report>::by(&db, 0, player).pop().unwrap();
        assert!(report.won);
        let seen = Table::<Commander>::get(&db, commander.id).unwrap();
        (report.wounded + report.dead, seen.level, seen.seen)
    };
    let (unled, level, seen) = fallen(None);
    assert_eq!((level, seen), (1, 0), "a commander who stayed at home saw nothing");
    let (sharper, _, _) = fallen(Some((Way::Vanguard, 30)));
    let (guarded, _, _) = fallen(Some((Way::Warden, 30)));
    assert!(sharper < unled, "{sharper} fell under a vanguard, {unled} with no one");
    assert!(guarded < unled, "{guarded} fell under a warden, {unled} with no one");
    // A fletcher is nothing to spearmen; but whoever leads has seen twenty-five fall.
    let (plain, level, seen) = fallen(Some((Way::Fletcher, 1)));
    assert_eq!(plain, unled);
    assert_eq!((level, seen), (1, 25));
}

#[test]
fn a_commander_rises_with_what_they_have_seen() {
    let (mut db, player, city, commander) = led(4_000);
    let mut row = Table::<Commander>::get(&db, commander.id).unwrap();
    row.seen = 90;
    db.update(row);
    let barrow = nearest_barrow(&mut db, &city);
    let march = db.call(|db| rules::send_led(db, player, Hex::unpacked(barrow.hex), March::HUNT, &spears(400), commander.id)).unwrap();
    until(&mut db, march.arrives + catalog::FIGHT_SECONDS);
    // Ninety and twenty-five more: past the hundred the second level asks.
    let risen = Table::<Commander>::get(&db, commander.id).unwrap();
    assert_eq!((risen.level, risen.seen), (2, 15));
    assert_eq!(rules::leading_of(&db, &Table::<March>::get(&db, march.id).unwrap()), Way::of(risen.way).unwrap().leading(2));
    // Enough seen at once lifts them several levels, and never past the thirtieth.
    let mut much = risen.clone();
    (much.level, much.seen) = (29, 0);
    db.update(much);
    until(&mut db, START + 100_000);
    let barrow = nearest_barrow(&mut db, &city);
    let mut strong = barrow.clone();
    strong.level = 1;
    db.update(strong);
    let mut top = Table::<Commander>::get(&db, commander.id).unwrap();
    top.seen = catalog::command_needs(29) - 1;
    db.update(top);
    let march = db.call(|db| rules::send_led(db, player, Hex::unpacked(barrow.hex), March::HUNT, &spears(400), commander.id)).unwrap();
    until(&mut db, march.arrives + catalog::FIGHT_SECONDS);
    let last = Table::<Commander>::get(&db, commander.id).unwrap();
    assert_eq!(last.level, catalog::TOP_COMMAND);
    assert_eq!(last.seen, 24, "what is seen at the last level is only kept");
    // An army lost with no room for its wounded leaves no march, and its
    // commander comes back to the city all the same.
    let (mut db, player, city, commander) = led(10);
    let mut full = rules::troop(&db, city.id, Troops::Archers, 1);
    full.wounded = 50;
    rules::keep_troop(&mut db, full);
    let barrow = nearest_barrow(&mut db, &city);
    let march = db.call(|db| rules::send_led(db, player, Hex::unpacked(barrow.hex), March::HUNT, &spears(10), commander.id)).unwrap();
    until(&mut db, march.arrives + catalog::FIGHT_SECONDS);
    assert!(Table::<March>::get(&db, march.id).is_none());
    assert_eq!(Table::<Commander>::get(&db, commander.id).unwrap().march, 0);
}
