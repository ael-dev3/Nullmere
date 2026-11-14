//! Armies over a store kept in memory: sent to a site along a way over
//! open ground, arriving in real time, gathering, and carrying it home.

use realm::catalog::{self, Building as Kind, Goods, Troops};
use realm::hex::{self, Hex};
use realm::land;
use realm::rows::{Building, City, Haul, March, Place, Site, Squad, Stock, Troop};
use realm::rules::{self, Asked, Refusal};
use realm::store::{Mem, Seconds, Table};

const START: Seconds = 3_000_000;
const SEED: u64 = 7;
const RADIUS: u32 = 48;

/// A realm with one player whose Keep stands at a level, with troops ready.
fn armed(keep: u32, troops: &[(Troops, u32, u64)]) -> (Mem, u64, City) {
    let mut db = Mem::new(START, 5);
    rules::open(&mut db, SEED, 1, RADIUS);
    let player = db.call(|db| rules::join(db, "Ada")).unwrap().id;
    let mut city = rules::city_of(&db, player).unwrap();
    city.keep = keep;
    db.update(city.clone());
    let mut keep_row = rules::building_of(&db, city.id, Kind::Keep).unwrap();
    keep_row.level = keep;
    db.update(keep_row);
    for (kind, tier, count) in troops {
        rules::keep_troop(&mut db, Troop { id: Troop::key(city.id, *kind as u8, *tier), city: city.id, kind: *kind as u8, tier: *tier, ready: *count, wounded: 0 });
    }
    (db, player, city)
}

fn wait(db: &mut Mem, seconds: Seconds) {
    let to = db.clock + seconds;
    db.advance(to, |db, timer| rules::fire(db, timer));
}

/// The site nearest a city that holds a good and that a way leads to.
fn nearest_site(db: &Mem, city: &City, kind: u8) -> Site {
    let from = Hex::unpacked(city.hex);
    let mut sites: Vec<Site> = Table::<Site>::all(db).into_iter().filter(|site| site.kind == kind).collect();
    sites.sort_by_key(|site| (Hex::unpacked(site.hex).distance(from), site.id));
    sites.into_iter().find(|site| land::way(SEED, RADIUS, from, Hex::unpacked(site.hex)).is_some()).expect("a site within reach")
}

fn spears(count: u64) -> Vec<Asked> {
    vec![Asked { kind: Troops::Spearmen as u8, tier: 1, count }]
}

fn stock(db: &Mem, city: u64) -> Goods {
    rules::goods(&rules::grown(&Table::<Stock>::get(db, city).unwrap(), db.clock))
}

#[test]
fn sites_are_scattered_over_the_land_as_the_realm_opens() {
    let (db, _, _) = armed(1, &[]);
    let sites = Table::<Site>::all(&db);
    let hexes = 1 + 3 * RADIUS * (RADIUS + 1);
    assert!(sites.len() as u32 > hexes / rules::HEXES_A_SITE * 8 / 10, "about one to every forty hexes: {}", sites.len());
    for site in &sites {
        let hex = Hex::unpacked(site.hex);
        let ground = land::ground(SEED, RADIUS, hex);
        let fits = match site.kind {
            Site::GRAIN => ground == land::Ground::Plain,
            Site::TIMBER => ground == land::Ground::Wood,
            Site::STONE => ground == land::Ground::Heath,
            Site::MOONSALT => ground == land::Ground::Salt,
            _ => false,
        };
        assert!(fits, "{site:?} on {ground:?}");
        assert!((1..=6).contains(&site.level));
        assert_eq!(site.left, if site.kind == Site::MOONSALT { 4_000 } else { 20_000 } * site.level as u64);
        assert_eq!(site.gatherer, 0);
        assert_eq!(Table::<Place>::get(&db, site.hex), Some(Place { hex: site.hex, kind: Place::SITE, id: site.id }));
        for near in hex.neighbours() {
            assert!(Table::<Place>::get(&db, near.packed()).is_none_or(|place| place.kind == Place::CITY), "no two sites side by side");
        }
    }
    for kind in [Site::GRAIN, Site::TIMBER, Site::STONE, Site::MOONSALT] {
        assert!(sites.iter().any(|site| site.kind == kind), "every good lies somewhere");
    }
    let near_lake = sites.iter().filter(|s| Hex::unpacked(s.hex).length() < RADIUS / 2).map(|s| s.level).max().unwrap();
    let near_rim = sites.iter().filter(|s| Hex::unpacked(s.hex).length() > RADIUS * 8 / 10).map(|s| s.level).max().unwrap();
    assert!(near_lake > near_rim, "richer nearer the lake");
}

#[test]
fn an_army_marches_to_a_site_gathers_and_carries_it_home() {
    let (mut db, ada, city) = armed(1, &[(Troops::Spearmen, 1, 100)]);
    let site = nearest_site(&db, &city, Site::GRAIN);
    let to = Hex::unpacked(site.hex);
    let power = rules::city_of(&db, ada).unwrap().power;
    let before = stock(&db, city.id);

    let march = db.call(|db| rules::send(db, ada, to, March::GATHER, &spears(60))).unwrap();
    let way = hex::decode(&march.route);
    let steps = way.len() as Seconds - 1;
    assert_eq!((way[0], *way.last().unwrap()), (Hex::unpacked(city.hex), to));
    assert!(way.windows(2).all(|pair| pair[0].distance(pair[1]) == 1));
    assert_eq!((march.kind, march.state, march.owner, march.city, march.target, march.soldiers), (March::GATHER, March::GOING, ada, city.id, site.id, 60));
    assert_eq!(march.arrives - march.departed, steps * 6, "six seconds a hex at a spearman's pace");
    assert_eq!(rules::troop(&db, city.id, Troops::Spearmen, 1).ready, 40, "those sent are out of the city");
    assert_eq!(rules::squads(&db, march.id), vec![Squad { id: Squad::key(march.id, 1, 1), march: march.id, kind: 1, tier: 1, count: 60, wounded: 0 }]);

    // On the road nothing has changed at the site.
    wait(&mut db, steps * 6 - 1);
    assert_eq!(Table::<March>::get(&db, march.id).unwrap().state, March::GOING);
    assert_eq!(Table::<Site>::get(&db, site.id).unwrap().gatherer, 0);

    // Arrived: it works the site, long enough to fill what sixty spearmen carry.
    wait(&mut db, 1);
    let working = Table::<March>::get(&db, march.id).unwrap();
    assert_eq!(working.state, March::WORKING);
    assert_eq!(Table::<Site>::get(&db, site.id).unwrap().gatherer, march.id);
    let carried = 60 * 12;
    assert_eq!(working.arrives - working.departed, carried * 3_600 / (60 * 36), "twenty minutes to fill a spearman's load");
    assert!(Table::<Haul>::all(&db).is_empty(), "nothing is its until the work is done");

    // Done: the load comes off the site and it turns for home.
    wait(&mut db, working.arrives - working.departed);
    let returning = Table::<March>::get(&db, march.id).unwrap();
    assert_eq!(returning.state, March::RETURNING);
    assert_eq!(hex::decode(&returning.route), way.iter().rev().copied().collect::<Vec<_>>(), "home the way it came");
    assert_eq!(returning.arrives - returning.departed, steps * 6);
    let after = Table::<Site>::get(&db, site.id).unwrap();
    assert_eq!((after.left, after.gatherer), (site.left - carried as u64, 0));
    assert_eq!(Table::<Haul>::get(&db, march.id).unwrap().grain, carried as u64);

    // Home: the soldiers stand ready, the grain is in the stock, nothing is left of the march.
    let grown = stock(&db, city.id);
    wait(&mut db, steps * 6);
    assert!(Table::<March>::all(&db).is_empty());
    assert!(Table::<Squad>::all(&db).is_empty());
    assert!(Table::<Haul>::all(&db).is_empty());
    assert!(db.timers.is_empty());
    assert_eq!(rules::troop(&db, city.id, Troops::Spearmen, 1).ready, 100);
    let now = stock(&db, city.id);
    assert!(now.grain >= grown.grain + carried as u64 && now.grain <= grown.grain + carried as u64 + 1_300, "{} then {}", grown.grain, now.grain);
    assert!(now.grain > before.grain + carried as u64);
    assert_eq!(rules::troop_power(&db, city.id), 100, "all hundred home and counted");
    assert_eq!(rules::marching_power(&db, city.id), 0);
    assert_eq!(rules::city_of(&db, ada).unwrap().power, power, "a march changes nothing of what stands in the city");
}

#[test]
fn an_armys_soldiers_count_for_their_city_while_they_are_out() {
    let (mut db, ada, city) = armed(2, &[(Troops::Spearmen, 1, 100)]);
    let site = nearest_site(&db, &city, Site::TIMBER);
    db.call(|db| rules::send(db, ada, Hex::unpacked(site.hex), March::GATHER, &spears(100))).unwrap();
    assert!(Table::<Troop>::by(&db, 0, city.id).is_empty(), "all are out");
    assert_eq!(rules::troop_power(&db, city.id), 0);
    assert_eq!(rules::marching_power(&db, city.id), 100);
    // Raising something reckons the city afresh: its army still counts.
    let farm = rules::building_of(&db, city.id, Kind::Farm).unwrap();
    db.call(|db| rules::upgrade(db, ada, farm.id)).unwrap();
    wait(&mut db, 3);
    assert_eq!(rules::city_of(&db, ada).unwrap().power, catalog::power(Kind::Keep, 2) + catalog::power(Kind::Farm, 2) + 20 + 100);
}

#[test]
fn a_site_worked_out_is_gone_and_another_is_set() {
    let (mut db, ada, city) = armed(1, &[(Troops::Mangonels, 1, 500)]);
    let site = nearest_site(&db, &city, Site::STONE);
    let mut thin = site.clone();
    thin.left = 900;
    db.update(thin);
    let sites = Table::<Site>::all(&db).len();
    let asked = vec![Asked { kind: Troops::Mangonels as u8, tier: 1, count: 500 }];
    let march = db.call(|db| rules::send(db, ada, Hex::unpacked(site.hex), March::GATHER, &asked)).unwrap();
    assert_eq!(march.arrives - march.departed, (hex::decode(&march.route).len() as Seconds - 1) * 9, "at an engine's pace");
    wait(&mut db, march.arrives - march.departed);
    let working = Table::<March>::get(&db, march.id).unwrap();
    assert_eq!(working.arrives - working.departed, 900 * 3_600 / (500 * 36), "only as long as what is left takes");
    wait(&mut db, working.arrives - working.departed);
    assert_eq!(Table::<Haul>::get(&db, march.id).unwrap().stone, 900);
    assert_eq!(Table::<Site>::get(&db, site.id), None, "worked out");
    assert!(Table::<Place>::get(&db, site.hex).is_none());
    assert_eq!(Table::<Site>::all(&db).len(), sites, "and another set somewhere");
}

#[test]
fn an_army_that_finds_its_site_taken_comes_home_empty() {
    let (mut db, ada, city) = armed(5, &[(Troops::Spearmen, 1, 100), (Troops::Riders, 1, 50)]);
    let site = nearest_site(&db, &city, Site::GRAIN);
    let to = Hex::unpacked(site.hex);
    // Horse sets out second and gets there first.
    let foot = db.call(|db| rules::send(db, ada, to, March::GATHER, &spears(50))).unwrap();
    let riders = vec![Asked { kind: Troops::Riders as u8, tier: 1, count: 50 }];
    let horse = db.call(|db| rules::send(db, ada, to, March::GATHER, &riders)).unwrap();
    assert!(horse.arrives < foot.arrives);
    wait(&mut db, foot.arrives - foot.departed);
    assert_eq!(Table::<March>::get(&db, horse.id).unwrap().state, March::WORKING);
    let turned = Table::<March>::get(&db, foot.id).unwrap();
    assert_eq!(turned.state, March::RETURNING, "the site is taken: home again");
    assert_eq!(db.call(|db| rules::send(db, ada, to, March::GATHER, &spears(10))), Err(Refusal::SiteTaken));
    wait(&mut db, turned.arrives - turned.departed);
    assert_eq!(Table::<March>::get(&db, foot.id), None);
    assert!(Table::<Haul>::get(&db, foot.id).is_none());
    assert_eq!(rules::troop(&db, city.id, Troops::Spearmen, 1).ready, 100);
}

#[test]
fn an_army_is_called_home_from_the_road_and_from_its_work() {
    let (mut db, ada, city) = armed(5, &[(Troops::Spearmen, 1, 100)]);
    let site = nearest_site(&db, &city, Site::GRAIN);
    let to = Hex::unpacked(site.hex);

    // From the road: it turns where it stands and is home in as long as it was out.
    let march = db.call(|db| rules::send(db, ada, to, March::GATHER, &spears(50))).unwrap();
    let way = hex::decode(&march.route);
    let out = (march.arrives - march.departed) / 2;
    wait(&mut db, out);
    let turned = db.call(|db| rules::recall(db, ada, march.id)).unwrap();
    let back = hex::decode(&turned.route);
    assert_eq!(turned.state, March::RETURNING);
    assert_eq!(back[0], way[(way.len() - 1) / 2], "from where it stood, half way along");
    assert_eq!(*back.last().unwrap(), Hex::unpacked(city.hex));
    assert_eq!(turned.arrives - turned.departed, (back.len() as Seconds - 1) * 6);
    assert_eq!(db.timers.len(), 1, "its old timer called off");
    assert_eq!(db.call(|db| rules::recall(db, ada, march.id)), Err(Refusal::AlreadyReturning));
    wait(&mut db, turned.arrives - turned.departed);
    assert_eq!(rules::troop(&db, city.id, Troops::Spearmen, 1).ready, 100);
    assert_eq!(Table::<Site>::get(&db, site.id).unwrap().left, site.left, "it never reached the site");

    // From its work: it takes what it has gathered so far.
    let march = db.call(|db| rules::send(db, ada, to, March::GATHER, &spears(50))).unwrap();
    wait(&mut db, march.arrives - march.departed);
    let working = Table::<March>::get(&db, march.id).unwrap();
    wait(&mut db, (working.arrives - working.departed) / 4);
    db.call(|db| rules::recall(db, ada, march.id)).unwrap();
    assert_eq!(Table::<Haul>::get(&db, march.id).unwrap().grain, 50 * 12 / 4, "a quarter of its load in a quarter of the time");
    let after = Table::<Site>::get(&db, site.id).unwrap();
    assert_eq!((after.left, after.gatherer), (site.left - 150, 0), "and the site is free again");

    let bryn = db.call(|db| rules::join(db, "Bryn")).unwrap().id;
    assert_eq!(db.call(|db| rules::recall(db, bryn, march.id)), Err(Refusal::NotYours));
    assert_eq!(db.call(|db| rules::recall(db, ada, 9_999)), Err(Refusal::NoSuchMarch));
}

#[test]
fn what_cant_be_sent_is_refused_in_plain_words() {
    let (mut db, ada, city) = armed(1, &[(Troops::Spearmen, 1, 100), (Troops::Archers, 2, 5)]);
    let site = nearest_site(&db, &city, Site::GRAIN);
    let to = Hex::unpacked(site.hex);
    let nothing = Hex::unpacked(city.hex).neighbours().into_iter().find(|hex| Table::<Place>::get(&db, hex.packed()).is_none()).unwrap();
    let ask = |kind: u8, tier: u32, count: u64| vec![Asked { kind, tier, count }];
    let cases: Vec<(Hex, u8, Vec<Asked>, Refusal, &str)> = vec![
        (nothing, March::GATHER, spears(10), Refusal::NothingThere, "There is nothing to gather there."),
        (Hex::unpacked(city.hex), March::GATHER, spears(10), Refusal::NothingThere, "There is nothing to gather there."),
        (to, 9, spears(10), Refusal::NoSuchOrder, "The realm knows no such order."),
        (to, March::GATHER, vec![], Refusal::NothingAsked, "Ask for at least one."),
        (to, March::GATHER, spears(0), Refusal::NothingAsked, "Ask for at least one."),
        (to, March::GATHER, ask(9, 1, 10), Refusal::NoSuchTroops, "There are no such troops."),
        (to, March::GATHER, ask(1, 7, 10), Refusal::NoSuchTroops, "There are no such troops."),
        (to, March::GATHER, spears(101), Refusal::NotEnoughTroops(Troops::Spearmen, 1, 100), "You have only 100 tier 1 Spearmen ready."),
        (to, March::GATHER, ask(2, 2, 6), Refusal::NotEnoughTroops(Troops::Archers, 2, 5), "You have only 5 tier 2 Archers ready."),
        (to, March::GATHER, ask(3, 1, 1), Refusal::NotEnoughTroops(Troops::Riders, 1, 0), "You have only 0 tier 1 Riders ready."),
    ];
    for (hex, order, asked, refusal, words) in cases {
        let got = db.call(|db| rules::send(db, ada, hex, order, &asked)).unwrap_err();
        assert_eq!(got, refusal);
        assert_eq!(got.to_string(), words);
    }
    assert_eq!(db.call(|db| rules::send(db, 77, to, March::GATHER, &spears(10))), Err(Refusal::NotAPlayer));
    // Asked for twice over, a kind is counted once: sixty and forty-one are too many.
    let twice = vec![Asked { kind: 1, tier: 1, count: 60 }, Asked { kind: 1, tier: 1, count: 41 }];
    assert_eq!(db.call(|db| rules::send(db, ada, to, March::GATHER, &twice)), Err(Refusal::NotEnoughTroops(Troops::Spearmen, 1, 100)));
    assert!(Table::<March>::all(&db).is_empty());
    assert_eq!(rules::troop(&db, city.id, Troops::Spearmen, 1).ready, 100, "nothing sent, nothing taken");

    // A city sends as many armies as its Keep allows: one, at first.
    db.call(|db| rules::send(db, ada, to, March::GATHER, &spears(10))).unwrap();
    let other = Table::<Site>::all(&db).into_iter().find(|s| s.id != site.id && land::way(SEED, RADIUS, Hex::unpacked(city.hex), Hex::unpacked(s.hex)).is_some()).unwrap();
    let refusal = db.call(|db| rules::send(db, ada, Hex::unpacked(other.hex), March::GATHER, &spears(10))).unwrap_err();
    assert_eq!(refusal, Refusal::NoFreeMarch(1));
    assert_eq!(refusal.to_string(), "Your one army is out. Raise your Keep to send more.");
    assert_eq!(Refusal::NoFreeMarch(3).to_string(), "All 3 of your armies are out.");
}

#[test]
fn a_city_keeps_room_for_itself_among_the_sites() {
    // Sites don't keep cities off the land: a city needs only its own hex
    // free and no other city crowding it.
    let mut db = Mem::new(START, 9);
    rules::open(&mut db, SEED, 1, RADIUS);
    let mut cities = Vec::new();
    for index in 0..60 {
        let player = db.call(|db| rules::join(db, &format!("Player {index}"))).unwrap();
        cities.push(rules::city_of(&db, player.id).unwrap());
    }
    for (index, a) in cities.iter().enumerate() {
        assert_eq!(Table::<Place>::get(&db, a.hex).map(|place| (place.kind, place.id)), Some((Place::CITY, a.id)));
        for b in &cities[index + 1..] {
            assert!(Hex::unpacked(a.hex).distance(Hex::unpacked(b.hex)) > rules::CITY_SPACING);
        }
    }
    let _: Vec<Building> = Table::<Building>::by(&db, 0, cities[0].id);
}
