//! Battle over a store kept in memory: how a fight is decided, the
//! Unquiet's barrows, the energy an attack takes, the wounded and their
//! healing, and the reports.

use realm::catalog::{self, Building as Kind, Goods, Troops, Unit};
use realm::hex::Hex;
use realm::land;
use realm::rows::{Barrow, Building, City, Haul, Hunt, Job, March, Place, Report, Stock, Troop};
use realm::rules::{self, Asked, Refusal};
use realm::store::{Mem, Seconds, Table};

const START: Seconds = 3_000_000;
const SEED: u64 = 7;
const RADIUS: u32 = 48;

fn unit(kind: Troops, tier: u32, count: u64) -> Unit {
    Unit { kind, tier, count }
}

/// A fight where chance gives neither side anything.
fn even(attackers: &[Unit], defenders: &[Unit]) -> rules::Outcome {
    rules::fight(attackers, defenders, || 10)
}

/// A realm with one player whose Keep stands at a level, with troops ready.
fn armed(keep: u32, troops: &[(Troops, u32, u64)]) -> (Mem, u64, City) {
    let mut db = Mem::new(START, 5);
    rules::open(&mut db, SEED, 1, RADIUS);
    let player = db.call(|db| rules::join(db, "Ada")).unwrap().id;
    let mut city = rules::city_of(&db, player).unwrap();
    city.keep = keep;
    db.update(city.clone());
    for (kind, tier, count) in troops {
        rules::keep_troop(&mut db, Troop { id: Troop::key(city.id, *kind as u8, *tier), city: city.id, kind: *kind as u8, tier: *tier, ready: *count, wounded: 0 });
    }
    (db, player, city)
}

fn wait(db: &mut Mem, seconds: Seconds) {
    let to = db.clock + seconds;
    db.advance(to, |db, timer| rules::fire(db, timer));
}

/// Moves the clock on to a moment.
fn until(db: &mut Mem, moment: Seconds) {
    db.advance(moment, |db, timer| rules::fire(db, timer));
}

/// The barrow nearest a city that a way leads to, set to a level.
fn nearest_barrow(db: &mut Mem, city: &City, level: u32) -> Barrow {
    let from = Hex::unpacked(city.hex);
    let mut barrows = Table::<Barrow>::all(db);
    barrows.sort_by_key(|barrow| (Hex::unpacked(barrow.hex).distance(from), barrow.id));
    let mut barrow = barrows.into_iter().find(|barrow| land::way(SEED, RADIUS, from, Hex::unpacked(barrow.hex)).is_some()).expect("a barrow within reach");
    barrow.level = level;
    db.update(barrow.clone());
    barrow
}

fn spears(count: u64) -> Vec<Asked> {
    vec![Asked { kind: Troops::Spearmen as u8, tier: 1, count }]
}

fn stock(db: &Mem, city: u64) -> Goods {
    rules::goods(&rules::grown(&Table::<Stock>::get(db, city).unwrap(), db.clock))
}

fn reports(db: &Mem, player: u64) -> Vec<Report> {
    let mut all = Table::<Report>::by(db, 0, player);
    all.sort_by_key(|report| report.id);
    all
}

#[test]
fn a_fight_is_decided_by_numbers_kind_and_tier() {
    use Troops::*;
    // Like against like, the more win, and lose far fewer than they kill.
    let outcome = even(&[unit(Spearmen, 1, 100)], &[unit(Spearmen, 1, 50)]);
    assert!(outcome.won);
    assert_eq!(outcome.defenders_lost, vec![50]);
    assert!((8..=25).contains(&outcome.attackers_lost[0]), "a hundred lose {} beating fifty", outcome.attackers_lost[0]);
    // The same the other way about: the fewer attack and are beaten.
    let outcome = even(&[unit(Spearmen, 1, 50)], &[unit(Spearmen, 1, 100)]);
    assert!(!outcome.won);
    assert_eq!(outcome.attackers_lost, vec![50]);

    // Equal forces wear each other down alike, and the defenders hold.
    let outcome = even(&[unit(Spearmen, 1, 10_000)], &[unit(Spearmen, 1, 10_000)]);
    assert_eq!(outcome.rounds, rules::MOST_ROUNDS);
    assert_eq!(outcome.attackers_lost, outcome.defenders_lost);
    assert!(outcome.attackers_lost[0] > 9_000 && outcome.attackers_lost[0] < 10_000);
    assert!(!outcome.won, "whoever defends holds the field after twenty rounds");

    // Spears stop riders, riders run down bows, bows pick off spears:
    // each wins whichever side it is on.
    for (strong, weak) in [(Spearmen, Riders), (Riders, Archers), (Archers, Spearmen)] {
        assert_eq!((rules::edge(strong, weak), rules::edge(weak, strong)), (125, 85));
        let attacking = even(&[unit(strong, 1, 100)], &[unit(weak, 1, 100)]);
        assert!(attacking.won, "{} beat {}", strong.name(), weak.name());
        assert!(attacking.attackers_lost[0] < 80);
        assert!(!even(&[unit(weak, 1, 100)], &[unit(strong, 1, 100)]).won);
    }
    // A tier above beats the tier below, man for man.
    let outcome = even(&[unit(Spearmen, 2, 100)], &[unit(Spearmen, 1, 100)]);
    assert!(outcome.won);
    assert!(outcome.attackers_lost[0] < 70, "tier 2 lose {}", outcome.attackers_lost[0]);
    assert!(even(&[unit(Spearmen, 1, 100)], &[unit(Spearmen, 5, 40)]).attackers_lost[0] == 100, "forty of the fifth tier see off a hundred of the first");
    // Mangonels are poor in the field.
    assert!(!even(&[unit(Mangonels, 1, 100)], &[unit(Spearmen, 1, 60)]).won);
    assert_eq!(rules::edge(Mangonels, Archers), 70);
    assert_eq!(rules::edge(Spearmen, Spearmen), 100);

    // A mixed force: the blow falls on each unit by its share of the heads.
    let outcome = even(&[unit(Spearmen, 1, 300), unit(Archers, 1, 100)], &[unit(Riders, 1, 150)]);
    assert!(outcome.won);
    let (spears, bows) = (outcome.attackers_lost[0], outcome.attackers_lost[1]);
    assert!(spears > bows, "three times the spears take the more of it: {spears} and {bows}");
    assert!(bows > 0);

    // Chance moves it a tenth either way, never the result of a fight this uneven.
    let lucky = rules::fight(&[unit(Spearmen, 1, 100)], &[unit(Spearmen, 1, 50)], || 20);
    let unlucky = rules::fight(&[unit(Spearmen, 1, 100)], &[unit(Spearmen, 1, 50)], || 0);
    assert!(lucky.won && unlucky.won);
    // The same chance gives the same fight.
    let mut seed = 99u64;
    let mut dice = move || {
        seed = seed.wrapping_mul(6_364_136_223_846_793_005).wrapping_add(1_442_695_040_888_963_407);
        seed >> 33
    };
    let once = rules::fight(&[unit(Archers, 2, 500), unit(Riders, 1, 200)], &catalog::barrow(9), &mut dice);
    let mut seed = 99u64;
    let mut dice = move || {
        seed = seed.wrapping_mul(6_364_136_223_846_793_005).wrapping_add(1_442_695_040_888_963_407);
        seed >> 33
    };
    assert_eq!(once, rules::fight(&[unit(Archers, 2, 500), unit(Riders, 1, 200)], &catalog::barrow(9), &mut dice));

    // No one against someone, and someone against no one.
    assert_eq!(even(&[], &[unit(Spearmen, 1, 5)]), rules::Outcome { rounds: 0, attackers_lost: vec![], defenders_lost: vec![0], won: false });
    assert!(even(&[unit(Spearmen, 1, 5)], &[]).won);
    // Numbers as large as any realm will see do not overflow.
    let outcome = even(&[unit(Riders, 5, 50_000_000)], &[unit(Archers, 5, 40_000_000)]);
    assert!(outcome.won);
}

#[test]
fn the_unquiet_grow_stronger_level_by_level() {
    assert_eq!(catalog::barrow(1), vec![unit(Troops::Spearmen, 1, 25)]);
    assert_eq!(catalog::barrow(4), vec![unit(Troops::Spearmen, 1, 112), unit(Troops::Archers, 1, 48)]);
    assert_eq!(catalog::barrow(8), vec![unit(Troops::Spearmen, 2, 240), unit(Troops::Archers, 2, 144), unit(Troops::Riders, 2, 96)]);
    assert_eq!(catalog::barrow(25).iter().map(|unit| (unit.tier, unit.count)).collect::<Vec<_>>(), vec![(5, 1_813), (5, 1_087), (5, 725)]);
    assert_eq!(catalog::barrow(99), catalog::barrow(25));
    let strength = |level: u32| catalog::barrow(level).iter().map(|unit| unit.count * unit.kind.soldier(unit.tier).power).sum::<u64>();
    for level in 1..catalog::TOP_BARROW {
        assert!(strength(level + 1) > strength(level), "level {level}");
        let (lower, higher) = (catalog::spoils(level).parts(), catalog::spoils(level + 1).parts());
        assert!((0..4).all(|good| higher[good] >= lower[good]) && higher != lower);
    }
    assert_eq!(catalog::spoils(1), Goods::of(800, 800, 0, 0));
    assert_eq!(catalog::spoils(6), Goods::of(4_800, 4_800, 1_800, 180));

    // What a new player can train in their first minutes clears the first
    // barrow with few hurt; the tenth sees the same army off.
    let first = even(&[unit(Troops::Spearmen, 1, 100)], &catalog::barrow(1));
    assert!(first.won && first.attackers_lost[0] <= 10, "a hundred lose {} at the first barrow", first.attackers_lost[0]);
    assert!(!even(&[unit(Troops::Spearmen, 1, 100)], &catalog::barrow(10)).won);
    assert_eq!((catalog::tends(0), catalog::tends(1), catalog::tends(25)), (50, 210, 10_050));
}

#[test]
fn barrows_are_scattered_over_the_land_as_the_realm_opens() {
    let (db, _, _) = armed(1, &[]);
    let barrows = Table::<Barrow>::all(&db);
    let hexes = 1 + 3 * RADIUS * (RADIUS + 1);
    assert!(barrows.len() as u32 > hexes / rules::HEXES_A_BARROW * 8 / 10, "about one to every sixty hexes: {}", barrows.len());
    for barrow in &barrows {
        let hex = Hex::unpacked(barrow.hex);
        assert!(matches!(land::ground(SEED, RADIUS, hex), land::Ground::Plain | land::Ground::Wood | land::Ground::Heath | land::Ground::Salt));
        assert!((1..=catalog::TOP_BARROW).contains(&barrow.level));
        assert_eq!(barrow.fighter, 0);
        assert_eq!(Table::<Place>::get(&db, barrow.hex), Some(Place { hex: barrow.hex, kind: Place::BARROW, id: barrow.id }));
        for near in hex.neighbours() {
            assert!(Table::<Place>::get(&db, near.packed()).is_none_or(|place| place.kind == Place::CITY), "nothing stands beside a barrow but a city founded since");
        }
    }
    // The weak are the commonest, so a new player has some within reach;
    // the strong stand nearer the lake.
    let weak = barrows.iter().filter(|barrow| barrow.level <= 3).count();
    assert!(weak * 4 > barrows.len(), "{weak} of {} are of the first three levels", barrows.len());
    let mean = |inner: bool| {
        let chosen: Vec<u32> = barrows.iter().filter(|barrow| (Hex::unpacked(barrow.hex).length() < RADIUS / 2) == inner).map(|barrow| barrow.level).collect();
        chosen.iter().sum::<u32>() as f64 / chosen.len().max(1) as f64
    };
    assert!(mean(true) > mean(false) + 1.0, "nearer the lake {:.1}, further out {:.1}", mean(true), mean(false));
}

#[test]
fn an_army_clears_a_barrow_and_brings_home_its_spoils() {
    let (mut db, player, city) = armed(3, &[(Troops::Spearmen, 1, 200)]);
    let barrow = nearest_barrow(&mut db, &city, 1);
    let to = Hex::unpacked(barrow.hex);
    let barrows = Table::<Barrow>::all(&db).len();
    let before = stock(&db, city.id);

    // A new player has all their energy; the attack takes fifty of it.
    let hunt = Table::<Hunt>::get(&db, player).unwrap();
    assert_eq!((hunt.energy, hunt.most, hunt.point_millis, hunt.cleared), (1_000, 1_000, 8_000, 0));
    let march = db.call(|db| rules::send(db, player, to, March::HUNT, &spears(200))).unwrap();
    assert_eq!((march.kind, march.state, march.target, march.soldiers), (March::HUNT, March::GOING, barrow.id, 200));
    assert_eq!(Table::<Hunt>::get(&db, player).unwrap().energy, 950);

    // It arrives and the fight begins: it lasts a while, and neither it
    // nor the barrow can be had by anyone else meanwhile.
    until(&mut db, march.arrives);
    let fighting = Table::<March>::get(&db, march.id).unwrap();
    assert_eq!(fighting.state, March::FIGHTING);
    assert_eq!(fighting.arrives - fighting.departed, catalog::FIGHT_SECONDS);
    assert_eq!(Table::<Barrow>::get(&db, barrow.id).unwrap().fighter, march.id);
    assert_eq!(db.call(|db| rules::recall(db, player, march.id)), Err(Refusal::Fighting));
    assert_eq!(Refusal::Fighting.to_string(), "That army is fighting. Wait for the fight to end.");
    let other = db.call(|db| rules::join(db, "Bryn")).unwrap().id;
    let theirs = rules::city_of(&db, other).unwrap();
    rules::keep_troop(&mut db, Troop { id: Troop::key(theirs.id, 1, 1), city: theirs.id, kind: 1, tier: 1, ready: 50, wounded: 0 });
    assert_eq!(db.call(|db| rules::send(db, other, to, March::HUNT, &spears(50))), Err(Refusal::BarrowTaken));
    assert_eq!(Refusal::BarrowTaken.to_string(), "Another army is fighting there.");
    assert!(reports(&db, player).is_empty(), "nothing is told until it is over");

    // Over: the barrow is cleared and gone, and another stands somewhere.
    wait(&mut db, catalog::FIGHT_SECONDS);
    assert!(Table::<Barrow>::get(&db, barrow.id).is_none());
    assert!(Table::<Place>::get(&db, barrow.hex).is_none());
    assert_eq!(Table::<Barrow>::all(&db).len(), barrows);
    assert_eq!(Table::<Hunt>::get(&db, player).unwrap().cleared, 1);

    // The report: two hundred against twenty-five, a few wounded, none dead.
    let told = reports(&db, player);
    assert_eq!(told.len(), 1);
    let report = &told[0];
    assert_eq!((report.kind, report.hex, report.won, report.foe, report.read), (Report::HUNT, barrow.hex, true, 1, false));
    assert_eq!((report.fought, report.stood, report.fell, report.dead), (200, 25, 25, 0));
    assert!((1..=8).contains(&report.wounded), "{} wounded", report.wounded);
    assert!((1..=4).contains(&report.rounds), "{} rounds", report.rounds);
    assert_eq!((report.grain, report.timber, report.stone, report.moonsalt), (800, 800, 0, 0));
    assert_eq!(
        report.words,
        format!(
            "Your army cleared a level 1 barrow of the Unquiet. Of your 200 soldiers, {} wounded. It is bringing home 800 grain and 800 timber.",
            if report.wounded == 1 { "1 was".to_string() } else { format!("{} were", report.wounded) }
        )
    );

    // It turns for home with its wounded and its spoils.
    let returning = Table::<March>::get(&db, march.id).unwrap();
    assert_eq!(returning.state, March::RETURNING);
    assert_eq!(returning.soldiers, 200 - report.wounded);
    let squad = &rules::squads(&db, march.id)[0];
    assert_eq!((squad.count, squad.wounded), (200 - report.wounded, report.wounded));
    assert_eq!(Table::<Haul>::get(&db, march.id).map(|haul| (haul.grain, haul.timber)), Some((800, 800)));
    assert_eq!(rules::room_for_wounded(&db, city.id), 50 - report.wounded, "those it carries are counted against the room at home");

    // Home: the fit stand ready, the wounded lie in the city, the spoils are in the stock.
    until(&mut db, returning.arrives);
    assert!(Table::<March>::get(&db, march.id).is_none());
    let row = rules::troop(&db, city.id, Troops::Spearmen, 1);
    assert_eq!((row.ready, row.wounded), (200 - report.wounded, report.wounded));
    let after = stock(&db, city.id);
    assert!(after.grain >= before.grain + 800 && after.timber >= before.timber + 800);

    // Reports are read and thrown away by their own player alone.
    assert_eq!(db.call(|db| rules::read_report(db, other, report.id)), Err(Refusal::NoSuchReport));
    assert_eq!(db.call(|db| rules::read_report(db, player, report.id)), Ok(()));
    assert!(Table::<Report>::get(&db, report.id).unwrap().read);
    assert_eq!(db.call(|db| rules::forget_report(db, other, report.id)), Err(Refusal::NoSuchReport));
    assert_eq!(db.call(|db| rules::forget_report(db, player, report.id)), Ok(()));
    assert!(reports(&db, player).is_empty());
    assert_eq!(Refusal::NoSuchReport.to_string(), "There is no such report.");
}

#[test]
fn a_barrow_asks_energy_and_the_one_below_it_cleared() {
    let (mut db, player, city) = armed(3, &[(Troops::Spearmen, 1, 100)]);
    let barrow = nearest_barrow(&mut db, &city, 3);
    let to = Hex::unpacked(barrow.hex);

    // Nothing to fight where no barrow stands; a barrow two levels above
    // the strongest cleared is refused.
    assert_eq!(db.call(|db| rules::send(db, player, Hex::unpacked(city.hex), March::HUNT, &spears(10))), Err(Refusal::NothingToFight));
    assert_eq!(Refusal::NothingToFight.to_string(), "There is nothing to fight there.");
    assert_eq!(db.call(|db| rules::send(db, player, to, March::HUNT, &spears(100))), Err(Refusal::TooStrong(2)));
    assert_eq!(Refusal::TooStrong(2).to_string(), "Clear a level 2 barrow first.");
    assert_eq!(Table::<Hunt>::get(&db, player).unwrap().energy, 1_000, "a refusal takes nothing");
    assert_eq!(db.call(|db| rules::send(db, player, to, March::GATHER, &spears(100))), Err(Refusal::NothingThere));

    // With the second cleared, the third may be tried.
    let mut hunt = Table::<Hunt>::get(&db, player).unwrap();
    hunt.cleared = 2;
    hunt.energy = 40;
    db.update(hunt);
    assert_eq!(db.call(|db| rules::send(db, player, to, March::HUNT, &spears(100))), Err(Refusal::NoEnergy(40)));
    assert_eq!(Refusal::NoEnergy(40).to_string(), "An attack takes 50 energy. You have 40.");

    // Energy comes back a point every eight seconds, and what has not yet
    // made a point is kept toward the next however often it is asked.
    wait(&mut db, 79);
    assert_eq!(rules::hunt_of(&db, player).energy, 49);
    let kept = rules::hunt_of(&db, player);
    rules::keep_hunt(&mut db, kept);
    wait(&mut db, 1);
    assert_eq!(rules::hunt_of(&db, player).energy, 50);
    let march = db.call(|db| rules::send(db, player, to, March::HUNT, &spears(100))).unwrap();
    assert_eq!(Table::<Hunt>::get(&db, player).unwrap().energy, 0);

    // Called back from the road it never fought: the energy comes back.
    wait(&mut db, 1);
    db.call(|db| rules::recall(db, player, march.id)).unwrap();
    assert_eq!(rules::hunt_of(&db, player).energy, 50);
    wait(&mut db, 600);
    assert!(Table::<March>::get(&db, march.id).is_none());
    assert_eq!(rules::troop(&db, city.id, Troops::Spearmen, 1).ready, 100);
    assert!(reports(&db, player).is_empty());

    // It never grows past the most a player keeps.
    wait(&mut db, 100_000);
    assert_eq!(rules::hunt_of(&db, player).energy, 1_000);

    // A barrow cleared by someone else before the army gets there: home
    // again, and the energy back.
    let march = db.call(|db| rules::send(db, player, to, March::HUNT, &spears(100))).unwrap();
    assert_eq!(rules::hunt_of(&db, player).energy, 950);
    Table::<Place>::delete(&mut db, barrow.hex);
    Table::<Barrow>::delete(&mut db, barrow.id);
    until(&mut db, march.arrives);
    assert_eq!(Table::<March>::get(&db, march.id).unwrap().state, March::RETURNING);
    assert_eq!(rules::hunt_of(&db, player).energy, 1_000);

    // A faster realm gives energy back as much faster.
    let mut fast = Mem::new(START, 5);
    rules::open(&mut fast, SEED, 60, RADIUS);
    let quick = fast.call(|db| rules::join(db, "Ada")).unwrap().id;
    let mut hunt = Table::<Hunt>::get(&fast, quick).unwrap();
    assert_eq!(hunt.point_millis, 133);
    hunt.energy = 0;
    fast.update(hunt);
    wait(&mut fast, 8);
    assert_eq!(rules::hunt_of(&fast, quick).energy, 60);
    // And a realm's pace changed keeps what had grown, and grows on at the new.
    fast.call(|db| rules::repace(db, 1)).unwrap();
    let slowed = Table::<Hunt>::get(&fast, quick).unwrap();
    assert_eq!((slowed.energy, slowed.point_millis), (60, 8_000));
    wait(&mut fast, 16);
    assert_eq!(rules::hunt_of(&fast, quick).energy, 62);
}

#[test]
fn an_army_too_weak_is_beaten_and_its_fallen_are_tended_or_lost() {
    // Ten against twenty-five: all ten fall. The city has room to tend
    // fifty, so all ten are carried home wounded.
    let (mut db, player, city) = armed(3, &[(Troops::Spearmen, 1, 100)]);
    let barrow = nearest_barrow(&mut db, &city, 1);
    let to = Hex::unpacked(barrow.hex);
    let march = db.call(|db| rules::send(db, player, to, March::HUNT, &spears(10))).unwrap();
    until(&mut db, march.arrives + catalog::FIGHT_SECONDS);
    let report = reports(&db, player).pop().unwrap();
    assert!(!report.won);
    assert_eq!((report.fought, report.wounded, report.dead), (10, 10, 0));
    assert!(report.fell < 25 && report.fell > 0, "{} of the Unquiet fell", report.fell);
    assert_eq!((report.grain, report.timber), (0, 0));
    assert_eq!(
        report.words,
        format!("Your army was beaten at a level 1 barrow of the Unquiet. {} of the Unquiet still stood. Of your 10 soldiers, 10 were wounded.", 25 - report.fell)
    );
    // The barrow stands as it stood, free for the next; nothing is cleared.
    assert_eq!(Table::<Barrow>::get(&db, barrow.id), Some(Barrow { fighter: 0, ..barrow.clone() }));
    assert_eq!(Table::<Hunt>::get(&db, player).unwrap().cleared, 0);
    assert_eq!(Table::<Hunt>::get(&db, player).unwrap().energy, 950, "a lost fight costs its energy all the same");
    let returning = Table::<March>::get(&db, march.id).unwrap();
    assert_eq!((returning.state, returning.soldiers), (March::RETURNING, 0));
    assert!(Table::<Haul>::get(&db, march.id).is_none());
    until(&mut db, returning.arrives);
    let row = rules::troop(&db, city.id, Troops::Spearmen, 1);
    assert_eq!((row.ready, row.wounded), (90, 10));

    // With forty-five already lying wounded there is room for five more:
    // of the next ten to fall, five are tended and five die.
    let mut row = rules::troop(&db, city.id, Troops::Spearmen, 1);
    row.wounded = 45;
    rules::keep_troop(&mut db, row);
    assert_eq!(rules::room_for_wounded(&db, city.id), 5);
    let march = db.call(|db| rules::send(db, player, to, March::HUNT, &spears(10))).unwrap();
    until(&mut db, march.arrives + catalog::FIGHT_SECONDS);
    let report = reports(&db, player).pop().unwrap();
    assert_eq!((report.fought, report.wounded, report.dead), (10, 5, 5));
    assert!(report.words.ends_with("Of your 10 soldiers, 5 were wounded and 5 died. Your city had no room to tend more wounded."), "{}", report.words);
    let returning = Table::<March>::get(&db, march.id).unwrap();
    until(&mut db, returning.arrives);
    let row = rules::troop(&db, city.id, Troops::Spearmen, 1);
    assert_eq!((row.ready, row.wounded), (80, 50));

    // With no room at all, the fallen die where they fall and no one is
    // left to come home.
    assert_eq!(rules::room_for_wounded(&db, city.id), 0);
    let march = db.call(|db| rules::send(db, player, to, March::HUNT, &spears(10))).unwrap();
    until(&mut db, march.arrives + catalog::FIGHT_SECONDS);
    assert!(Table::<March>::get(&db, march.id).is_none());
    assert!(rules::squads(&db, march.id).is_empty());
    let report = reports(&db, player).pop().unwrap();
    assert_eq!((report.wounded, report.dead), (0, 10));
    assert!(report.words.ends_with("Of your 10 soldiers, 10 died. Your city had no room to tend more wounded."), "{}", report.words);
    let row = rules::troop(&db, city.id, Troops::Spearmen, 1);
    assert_eq!((row.ready, row.wounded), (70, 50));

    // A Hospital makes room: at its first level the city tends 210.
    db.insert(Building { id: 0, city: city.id, kind: Kind::Hospital as u8, level: 1 });
    assert_eq!(rules::room_for_wounded(&db, city.id), 160);

    // Of a mixed army's fallen, the best are tended first.
    let mut db = armed(3, &[(Troops::Spearmen, 1, 30), (Troops::Spearmen, 2, 5)]).0;
    let city = rules::city_of(&db, 1).unwrap();
    let barrow = nearest_barrow(&mut db, &city, 2);
    let mut hunt = Table::<Hunt>::get(&db, 1).unwrap();
    hunt.cleared = 1;
    db.update(hunt);
    let mut filler = rules::troop(&db, city.id, Troops::Archers, 1);
    filler.wounded = 46;
    rules::keep_troop(&mut db, filler);
    let asked = vec![Asked { kind: 1, tier: 1, count: 30 }, Asked { kind: 1, tier: 2, count: 5 }];
    let march = db.call(|db| rules::send(db, 1, Hex::unpacked(barrow.hex), March::HUNT, &asked)).unwrap();
    until(&mut db, march.arrives + catalog::FIGHT_SECONDS);
    let report = reports(&db, 1).pop().unwrap();
    assert!(!report.won, "thirty-five against sixty");
    assert_eq!((report.fought, report.wounded, report.dead), (35, 4, 31));
    let carried: Vec<(u32, u64)> = rules::squads(&db, march.id).iter().map(|squad| (squad.tier, squad.wounded)).collect();
    assert_eq!(carried, vec![(2, 4)], "the four there was room for are of the second tier");
}

#[test]
fn the_wounded_are_healed_for_goods_and_time() {
    let (mut db, player, city) = armed(3, &[(Troops::Spearmen, 1, 20)]);
    let mut row = rules::troop(&db, city.id, Troops::Spearmen, 1);
    row.wounded = 40;
    rules::keep_troop(&mut db, row);
    let before = stock(&db, city.id);

    assert_eq!(db.call(|db| rules::heal(db, player, 1, 1, 41)), Err(Refusal::NotEnoughWounded(Troops::Spearmen, 1, 40)));
    assert_eq!(Refusal::NotEnoughWounded(Troops::Spearmen, 1, 40).to_string(), "You have only 40 wounded tier 1 Spearmen.");
    assert_eq!(db.call(|db| rules::heal(db, player, 1, 1, 0)), Err(Refusal::NothingAsked));
    assert_eq!(db.call(|db| rules::heal(db, player, 9, 1, 1)), Err(Refusal::NoSuchTroops));
    assert_eq!(db.call(|db| rules::heal(db, player, 1, 6, 1)), Err(Refusal::NoSuchTroops));
    assert_eq!(db.call(|db| rules::heal(db, player, 2, 1, 1)), Err(Refusal::NotEnoughWounded(Troops::Archers, 1, 0)));

    // A third of what training them cost, in a quarter of the time.
    assert_eq!(catalog::healing(Troops::Spearmen.soldier(1)), (Goods::of(16, 16, 0, 0), 2));
    let job = db.call(|db| rules::heal(db, player, 1, 1, 10)).unwrap();
    assert_eq!((job.kind, job.level, job.amount, job.ends - job.started), (Job::HEAL, 1, 10, 20));
    let paid = stock(&db, city.id);
    assert_eq!((before.grain - paid.grain, before.timber - paid.timber), (160, 160));
    assert_eq!(db.call(|db| rules::heal(db, player, 1, 1, 5)), Err(Refusal::AlreadyHealing));
    assert_eq!(Refusal::AlreadyHealing.to_string(), "Your wounded are already being healed. Wait for them to finish.");

    wait(&mut db, 19);
    assert_eq!(rules::troop(&db, city.id, Troops::Spearmen, 1).wounded, 40);
    wait(&mut db, 1);
    let row = rules::troop(&db, city.id, Troops::Spearmen, 1);
    assert_eq!((row.ready, row.wounded), (30, 30));
    assert!(Table::<Job>::by(&db, 0, city.id).is_empty());
    assert_eq!(rules::city_of(&db, player).unwrap().power, 140 + 60 * Troops::Spearmen.soldier(1).power, "ready or wounded, a soldier counts toward power alike");

    // Too dear is refused with what is missing.
    let mut poor = Table::<Stock>::get(&db, city.id).unwrap();
    (poor.grain, poor.timber, poor.grain_hourly, poor.timber_hourly) = (100, 500, 0, 0);
    db.update(poor);
    assert_eq!(db.call(|db| rules::heal(db, player, 1, 1, 30)), Err(Refusal::CannotAfford(Goods::of(380, 0, 0, 0))));
    // Someone who has not joined heals no one.
    assert_eq!(db.call(|db| rules::heal(db, 99, 1, 1, 1)), Err(Refusal::NotAPlayer));
}

#[test]
fn a_player_is_kept_their_latest_reports() {
    let (mut db, player, _) = armed(1, &[]);
    for index in 0..rules::REPORTS_KEPT as u64 + 5 {
        let blank = Report {
            id: 0,
            player,
            at: db.clock,
            kind: Report::HUNT,
            hex: 0,
            won: true,
            foe: index,
            rounds: 1,
            fought: 1,
            wounded: 0,
            dead: 0,
            stood: 1,
            fell: 1,
            grain: 0,
            timber: 0,
            stone: 0,
            moonsalt: 0,
            words: String::new(),
            read: false,
        };
        rules::report(&mut db, blank);
    }
    let kept = reports(&db, player);
    assert_eq!(kept.len(), rules::REPORTS_KEPT);
    assert_eq!((kept[0].foe, kept.last().unwrap().foe), (5, rules::REPORTS_KEPT as u64 + 4), "the oldest five are gone");
}
