//! Cities under attack over a store kept in memory: the peace a new city
//! has, an assault on a city's walls, what is carried off, and what each
//! side is told.

use realm::catalog::{self, Building as Kind, Goods, Troops};
use realm::hex::Hex;
use realm::rows::{Building, City, Haul, March, Report, Stock, Troop};
use realm::rules::{self, Asked, Refusal};
use realm::store::{Mem, Seconds, Table};

const START: Seconds = 3_000_000;

/// A realm with two neighbours, Ada and Bryn, each with a Keep high
/// enough to send an army, and troops ready.
fn neighbours(ada: &[(Troops, u32, u64)], bryn: &[(Troops, u32, u64)]) -> (Mem, (u64, City), (u64, City)) {
    let mut db = Mem::new(START, 5);
    rules::open(&mut db, 7, 1, 48);
    let mut both = Vec::new();
    for (name, troops) in [("Ada", ada), ("Bryn", bryn)] {
        let player = db.call(|db| rules::join(db, name)).unwrap().id;
        let city = rules::city_of(&db, player).unwrap();
        for (kind, tier, count) in troops {
            rules::keep_troop(&mut db, Troop { id: Troop::key(city.id, *kind as u8, *tier), city: city.id, kind: *kind as u8, tier: *tier, ready: *count, wounded: 0 });
        }
        both.push((player, city));
    }
    (db, both[0].clone(), both[1].clone())
}

fn until(db: &mut Mem, moment: Seconds) {
    db.advance(moment, |db, timer| rules::fire(db, timer));
}

fn spears(count: u64) -> Vec<Asked> {
    vec![Asked { kind: Troops::Spearmen as u8, tier: 1, count }]
}

fn stock(db: &Mem, city: u64) -> Goods {
    rules::goods(&rules::grown(&Table::<Stock>::get(db, city).unwrap(), db.clock))
}

/// A city's goods as they will stand at a moment to come.
fn stock_at(db: &Mem, city: u64, moment: Seconds) -> Goods {
    rules::goods(&rules::grown(&Table::<Stock>::get(db, city).unwrap(), moment))
}

fn reports(db: &Mem, player: u64) -> Vec<Report> {
    let mut all = Table::<Report>::by(db, 0, player);
    all.sort_by_key(|report| report.id);
    all
}

/// Ends a city's peace now, as if its days had passed.
fn end_peace(db: &mut Mem, city: u64) {
    let mut row = Table::<City>::get(db, city).unwrap();
    row.shield = db.clock;
    db.update(row);
}

#[test]
fn a_new_city_is_at_peace_until_it_attacks_or_its_days_pass() {
    let (mut db, (ada, hers), (bryn, his)) = neighbours(&[(Troops::Spearmen, 1, 100)], &[(Troops::Spearmen, 1, 100)]);
    let (to_his, to_hers) = (Hex::unpacked(his.hex), Hex::unpacked(hers.hex));
    assert_eq!(hers.shield, START + catalog::NEW_CITY_PEACE, "three days from its founding");
    assert_eq!(rules::city_at(&db, to_his).map(|city| city.id), Some(his.id));
    assert_eq!(rules::city_at(&db, Hex::new(0, 0)), None);

    // No army may be sent against a city at peace, against one's own, or
    // where no city stands.
    assert_eq!(db.call(|db| rules::send(db, ada, to_his, March::ATTACK, &spears(100))), Err(Refusal::AtPeace(catalog::NEW_CITY_PEACE)));
    assert_eq!(Refusal::AtPeace(catalog::NEW_CITY_PEACE).to_string(), "That city is at peace for another 3 days.");
    assert_eq!(Refusal::AtPeace(4_000).to_string(), "That city is at peace for another 1 hour 6 minutes.");
    assert_eq!(db.call(|db| rules::send(db, ada, to_hers, March::ATTACK, &spears(100))), Err(Refusal::OwnCity));
    assert_eq!(Refusal::OwnCity.to_string(), "That is your own city.");
    assert_eq!(db.call(|db| rules::send(db, ada, Hex::new(0, 0), March::ATTACK, &spears(100))), Err(Refusal::NoCityThere));
    assert_eq!(Refusal::NoCityThere.to_string(), "There is no city to attack there.");
    assert_eq!(Table::<City>::get(&db, hers.id).unwrap().shield, hers.shield, "a refusal costs her nothing");

    // A day on, Bryn's peace has two days left; once it has passed, Ada may attack.
    until(&mut db, START + 86_400);
    assert_eq!(db.call(|db| rules::send(db, ada, to_his, March::ATTACK, &spears(100))), Err(Refusal::AtPeace(2 * 86_400)));
    until(&mut db, START + catalog::NEW_CITY_PEACE);
    // Her own peace is given up as her army sets out: his may answer at once.
    let mut early = Table::<City>::get(&db, hers.id).unwrap();
    early.shield = db.clock + 500;
    db.update(early);
    let march = db.call(|db| rules::send(db, ada, to_his, March::ATTACK, &spears(100))).unwrap();
    assert_eq!((march.kind, march.state, march.target), (March::ATTACK, March::GOING, his.id));
    assert_eq!(Table::<City>::get(&db, hers.id).unwrap().shield, db.clock, "whoever attacks is at peace no longer");
    assert!(db.call(|db| rules::send(db, bryn, to_hers, March::ATTACK, &spears(50))).is_ok());

    // A faster realm's peace is as much shorter.
    let mut fast = Mem::new(START, 5);
    rules::open(&mut fast, 7, 60, 48);
    let quick = fast.call(|db| rules::join(db, "Ada")).unwrap().id;
    assert_eq!(rules::city_of(&fast, quick).unwrap().shield, START + catalog::NEW_CITY_PEACE / 60);
}

#[test]
fn an_army_takes_a_city_by_storm_and_carries_off_what_it_can() {
    // Three hundred against a hundred, with no Wall: the city falls.
    let (mut db, (ada, hers), (bryn, his)) = neighbours(&[(Troops::Spearmen, 1, 300)], &[(Troops::Spearmen, 1, 100)]);
    end_peace(&mut db, his.id);
    let march = db.call(|db| rules::send(db, ada, Hex::unpacked(his.hex), March::ATTACK, &spears(300))).unwrap();
    // What his city will hold as the assault ends.
    let before = stock_at(&db, his.id, march.arrives + catalog::ASSAULT_SECONDS);

    // The assault lasts a while and can't be left.
    until(&mut db, march.arrives);
    let fighting = Table::<March>::get(&db, march.id).unwrap();
    assert_eq!((fighting.state, fighting.arrives - fighting.departed), (March::FIGHTING, catalog::ASSAULT_SECONDS));
    assert_eq!(db.call(|db| rules::recall(db, ada, march.id)), Err(Refusal::Fighting));
    assert!(reports(&db, ada).is_empty() && reports(&db, bryn).is_empty());
    until(&mut db, fighting.arrives);

    // Ada is told: her losses, half of the fallen carried home wounded
    // (her city tends fifty), and what her army carries off.
    let told = reports(&db, ada).pop().unwrap();
    assert_eq!((told.kind, told.won, told.foe, told.hex), (Report::ATTACK, true, bryn, his.hex));
    assert_eq!((told.fought, told.stood, told.fell), (300, 100, 100));
    let lost = told.wounded + told.dead;
    assert!((20..=60).contains(&lost), "three hundred lose {lost} taking a hundred");
    assert_eq!(told.wounded, lost / 2, "half of the fallen are carried home");
    let returning = Table::<March>::get(&db, march.id).unwrap();
    assert_eq!((returning.state, returning.soldiers), (March::RETURNING, 300 - lost));
    // What is open to plunder: all but the 2,000 of each good a city with
    // no Storehouse keeps safe; as much of it as the army can carry.
    let open = Goods::of(before.grain - 2_000, before.timber - 2_000, before.stone - 2_000, 0);
    let load = (300 - lost) * 12;
    let all: u64 = open.parts().iter().sum();
    assert!(all > load, "more lies open than they can carry");
    let carried = Goods::from_parts(open.parts().map(|part| part * load / all));
    assert_eq!(Table::<Haul>::get(&db, march.id).map(|haul| Goods::of(haul.grain, haul.timber, haul.stone, haul.moonsalt)), Some(carried));
    assert_eq!(Goods::of(told.grain, told.timber, told.stone, told.moonsalt), carried);
    assert_eq!(
        told.words,
        format!("Your army took Bryn's city by storm. Of your 300 soldiers, {} were wounded and {} died. It is bringing home {carried}.", told.wounded, told.dead)
    );

    // Bryn is told: every defender fell, fifty of them tended (his city's
    // room) and fifty dead; what was carried off; and his city's peace.
    let heard = reports(&db, bryn).pop().unwrap();
    assert_eq!((heard.kind, heard.won, heard.foe, heard.hex), (Report::DEFENCE, false, ada, his.hex));
    assert_eq!((heard.fought, heard.wounded, heard.dead, heard.stood, heard.fell), (100, 50, 50, 300, lost));
    assert_eq!(
        heard.words,
        format!("Ada's army took your city by storm and carried off {carried}. Of your 100 defenders, 50 were wounded and 50 died. Your city is at peace for 4 hours.")
    );
    let garrison = rules::troop(&db, his.id, Troops::Spearmen, 1);
    assert_eq!((garrison.ready, garrison.wounded), (0, 50));
    let after = stock(&db, his.id);
    assert_eq!(before.minus(after), carried, "what she carries is what he lost");
    let beaten = Table::<City>::get(&db, his.id).unwrap();
    assert_eq!(beaten.shield, db.clock + catalog::BEATEN_PEACE);
    assert_eq!(beaten.power, 140 + 50 * Troops::Spearmen.soldier(1).power, "his power is reckoned afresh: the dead no longer count toward it");
    assert_eq!(db.call(|db| rules::send(db, ada, Hex::unpacked(his.hex), March::ATTACK, &spears(1))), Err(Refusal::AtPeace(catalog::BEATEN_PEACE)));

    // Her army comes home: the plunder in her stock, her wounded in her city.
    let mine = stock(&db, hers.id);
    until(&mut db, returning.arrives);
    assert!(Table::<March>::get(&db, march.id).is_none());
    let home = rules::troop(&db, hers.id, Troops::Spearmen, 1);
    assert_eq!((home.ready, home.wounded), (300 - lost, told.wounded));
    let richer = stock(&db, hers.id);
    assert!(richer.grain >= mine.grain + carried.grain && richer.stone >= mine.stone + carried.stone);
}

#[test]
fn a_wall_and_its_defenders_hold_a_city() {
    // A hundred and ten against a hundred: in the open the attackers
    // would win; behind a Wall of the tenth level the city holds.
    let open = rules::fight(&[realm::catalog::Unit { kind: Troops::Spearmen, tier: 1, count: 110 }], &[realm::catalog::Unit { kind: Troops::Spearmen, tier: 1, count: 100 }], || 10);
    assert!(open.won);
    assert_eq!((catalog::shelter(0), catalog::shelter(10), catalog::shelter(99)), (0, 30, 75));
    let walled = rules::fight_sheltered(
        &[realm::catalog::Unit { kind: Troops::Spearmen, tier: 1, count: 110 }],
        &[realm::catalog::Unit { kind: Troops::Spearmen, tier: 1, count: 100 }],
        catalog::shelter(10),
        || 10,
    );
    assert!(!walled.won);

    let (mut db, (ada, hers), (bryn, his)) = neighbours(&[(Troops::Spearmen, 1, 110)], &[(Troops::Spearmen, 1, 100)]);
    db.insert(Building { id: 0, city: his.id, kind: Kind::Wall as u8, level: 10 });
    end_peace(&mut db, his.id);
    let march = db.call(|db| rules::send(db, ada, Hex::unpacked(his.hex), March::ATTACK, &spears(110))).unwrap();
    let before = stock_at(&db, his.id, march.arrives + catalog::ASSAULT_SECONDS);
    until(&mut db, march.arrives + catalog::ASSAULT_SECONDS);

    let told = reports(&db, ada).pop().unwrap();
    assert!(!told.won);
    assert_eq!((told.fought, told.wounded + told.dead), (110, 110), "all of them fell");
    assert_eq!(told.wounded, 50, "as many as her city has room to tend, of the half that might be carried home");
    assert_eq!((told.grain, told.timber), (0, 0));
    assert_eq!(
        told.words,
        format!("Your army was beaten at Bryn's city. {} of its defenders still stood. Of your 110 soldiers, 50 were wounded and 60 died.", 100 - told.fell)
    );
    let heard = reports(&db, bryn).pop().unwrap();
    assert!(heard.won);
    assert_eq!((heard.kind, heard.fought, heard.stood, heard.fell), (Report::DEFENCE, 100, 110, 110));
    assert_eq!(heard.wounded, told.fell.min(50));
    assert!(heard.words.starts_with("Ada's army attacked your city and was beaten. 110 of its 110 fell. Of your 100 defenders, "), "{}", heard.words);
    // Nothing is carried off, and a city that held keeps no new peace.
    assert_eq!(stock(&db, his.id), before);
    assert!(Table::<City>::get(&db, his.id).unwrap().shield <= db.clock);
    // Her wounded are carried home by no one standing: they come all the same.
    let returning = Table::<March>::get(&db, march.id).unwrap();
    assert_eq!((returning.state, returning.soldiers), (March::RETURNING, 0));
    until(&mut db, returning.arrives);
    let home = rules::troop(&db, hers.id, Troops::Spearmen, 1);
    assert_eq!((home.ready, home.wounded), (0, 50));
}

#[test]
fn an_empty_city_falls_at_once_and_a_storehouse_keeps_some_safe() {
    let (mut db, (ada, _), (bryn, his)) = neighbours(&[(Troops::Spearmen, 1, 2_000)], &[]);
    db.insert(Building { id: 0, city: his.id, kind: Kind::Storehouse as u8, level: 3 });
    end_peace(&mut db, his.id);
    assert_eq!((catalog::kept_safe(0), catalog::kept_safe(3), catalog::kept_safe(99)), (2_000, 5_000, 27_000));
    let march = db.call(|db| rules::send(db, ada, Hex::unpacked(his.hex), March::ATTACK, &spears(2_000))).unwrap();
    let before = stock_at(&db, his.id, march.arrives + catalog::ASSAULT_SECONDS);
    until(&mut db, march.arrives + catalog::ASSAULT_SECONDS);

    // No one fell on either side; two thousand soldiers carry all that lies open.
    let told = reports(&db, ada).pop().unwrap();
    assert!(told.won);
    assert_eq!((told.rounds, told.wounded, told.dead, told.stood, told.fell), (0, 0, 0, 0, 0));
    let open = Goods::of(before.grain - 5_000, before.timber - 5_000, before.stone - 5_000, 0);
    assert_eq!(Goods::of(told.grain, told.timber, told.stone, told.moonsalt), open);
    assert_eq!(told.words, format!("Your army took Bryn's city by storm. None of your 2,000 soldiers fell. It is bringing home {open}."));
    let heard = reports(&db, bryn).pop().unwrap();
    assert_eq!(heard.words, format!("Ada's army took your city by storm and carried off {open}. Your city had no defenders. Your city is at peace for 4 hours."));
    let after = stock(&db, his.id);
    assert_eq!((after.grain, after.timber, after.stone), (5_000, 5_000, 5_000), "what the Storehouse keeps safe is left");

    // A city with nothing open to plunder is taken for nothing.
    let later = db.clock + catalog::BEATEN_PEACE + 1_000;
    until(&mut db, later);
    let mut poor = Table::<Stock>::get(&db, his.id).unwrap();
    (poor.grain, poor.timber, poor.stone, poor.grain_hourly, poor.timber_hourly, poor.stone_hourly) = (100, 100, 100, 0, 0, 0);
    db.update(poor);
    let march = db.call(|db| rules::send(db, ada, Hex::unpacked(his.hex), March::ATTACK, &spears(10))).unwrap();
    until(&mut db, march.arrives + catalog::ASSAULT_SECONDS);
    assert_eq!(reports(&db, ada).pop().unwrap().words, "Your army took Bryn's city by storm. None of your 10 soldiers fell. There was nothing to carry off.");
    assert_eq!(
        reports(&db, bryn).pop().unwrap().words,
        "Ada's army took your city by storm, and found nothing to carry off. Your city had no defenders. Your city is at peace for 4 hours."
    );
    assert!(Table::<Haul>::get(&db, march.id).is_none());
}

#[test]
fn an_army_that_finds_its_city_at_peace_comes_home() {
    // Two armies set out against Bryn; the first takes his city, and the
    // second arrives to find it at peace.
    let (mut db, (ada, _), (_, his)) = neighbours(&[(Troops::Spearmen, 1, 400)], &[]);
    let mut keep = rules::city_of(&db, ada).unwrap();
    keep.keep = 5;
    db.update(keep);
    end_peace(&mut db, his.id);
    let first = db.call(|db| rules::send(db, ada, Hex::unpacked(his.hex), March::ATTACK, &spears(200))).unwrap();
    until(&mut db, first.arrives + catalog::ASSAULT_SECONDS - 1);
    let second = db.call(|db| rules::send(db, ada, Hex::unpacked(his.hex), March::ATTACK, &spears(200))).unwrap();
    until(&mut db, second.arrives);
    assert_eq!(Table::<March>::get(&db, second.id).unwrap().state, March::RETURNING);
    assert_eq!(reports(&db, ada).len(), 1, "only the first fought");
    until(&mut db, second.arrives + 10_000);
    assert_eq!(rules::troop(&db, rules::city_of(&db, ada).unwrap().id, Troops::Spearmen, 1).ready, 400);
}
