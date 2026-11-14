//! Opening the realm and joining it, over a store kept in memory.

use realm::rows::{Pace, Player, Realm};
use realm::rules::{self, Refusal};
use realm::store::{Mem, Table};

fn opened() -> Mem {
    let mut db = Mem::new(1_000_000, 7);
    rules::open(&mut db, 42, 1);
    db
}

#[test]
fn the_realm_opens_once() {
    let mut db = Mem::new(500, 7);
    assert_eq!(rules::realm(&db), Err(Refusal::NotOpen));
    assert_eq!(rules::join(&mut db, "Ada"), Err(Refusal::NotOpen));
    rules::open(&mut db, 42, 0);
    let realm = rules::realm(&db).unwrap();
    assert_eq!((realm.seed, realm.opened, realm.pace), (42, 500, 1), "a pace of nothing is the pace as written");
    db.clock = 900;
    rules::open(&mut db, 99, 5);
    assert_eq!(rules::realm(&db).unwrap(), realm, "opened once, it stays as it opened");
    assert_eq!(Table::<Realm>::all(&db).len(), 1);
}

#[test]
fn a_player_joins_under_a_name_of_their_own() {
    let mut db = opened();
    let ada = db.call(|db| rules::join(db, "  Ada   of  the Lake ")).unwrap();
    assert_eq!(ada.id, 1);
    assert_eq!(ada.name, "Ada of the Lake", "trimmed, its spaces single");
    assert_eq!((ada.joined, ada.seen, ada.online), (1_000_000, 1_000_000, true));
    let bryn = db.call(|db| rules::join(db, "Bryn")).unwrap();
    assert_eq!(bryn.id, 2);
    assert_eq!(Table::<Player>::get(&db, 2), Some(bryn));

    for (name, why) in [
        ("ada OF the lake", Refusal::NameTaken),
        ("Al", Refusal::NameTooShort),
        ("A name much too long", Refusal::NameTooLong),
        ("-Ada", Refusal::NameNotAllowed),
        ("Ada!", Refusal::NameNotAllowed),
        ("Ada <b>", Refusal::NameNotAllowed),
        ("   ", Refusal::NameTooShort),
    ] {
        assert_eq!(db.call(|db| rules::join(db, name)), Err(why), "{name:?}");
    }
    assert_eq!(Table::<Player>::all(&db).len(), 2, "a refusal changes nothing");
    assert!(db.call(|db| rules::join(db, "Órlaith O'Dea-2")).is_ok(), "letters of any alphabet, digits, hyphens, apostrophes");
    assert_eq!(rules::name_key("ADA"), rules::name_key("ada"));
    assert_ne!(rules::name_key("Ada"), rules::name_key("Adb"));
}

#[test]
fn only_so_many_join_in_a_minute() {
    let mut db = opened();
    for index in 0..rules::JOINING_A_MINUTE {
        db.call(|db| rules::join(db, &format!("Player {index}"))).unwrap();
    }
    assert_eq!(db.call(|db| rules::join(db, "One more")), Err(Refusal::Crowded));
    assert_eq!(Table::<Player>::all(&db).len() as u32, rules::JOINING_A_MINUTE);
    assert_eq!(rules::realm(&db).unwrap().joined_in_minute, rules::JOINING_A_MINUTE, "the refusal was not counted");
    db.clock += 60;
    assert!(db.call(|db| rules::join(db, "One more")).is_ok(), "the next minute, room again");
    assert_eq!(rules::realm(&db).unwrap().joined_in_minute, 1);
}

#[test]
fn a_player_is_seen_coming_and_going() {
    let mut db = opened();
    let ada = db.call(|db| rules::join(db, "Ada")).unwrap();
    db.clock += 300;
    rules::seen(&mut db, ada.id, false);
    let gone = Table::<Player>::get(&db, ada.id).unwrap();
    assert_eq!((gone.online, gone.seen), (false, 1_000_300));
    db.clock += 50;
    rules::seen(&mut db, ada.id, true);
    assert!(Table::<Player>::get(&db, ada.id).unwrap().online);
    rules::seen(&mut db, 99, true);
    assert_eq!(Table::<Player>::all(&db).len(), 1, "no one unknown is seen");
}

#[test]
fn a_player_asking_too_fast_is_refused_for_a_while() {
    let mut db = opened();
    let ada = db.call(|db| rules::join(db, "Ada")).unwrap();
    assert_eq!(db.call(|db| rules::asking(db, 77)), Err(Refusal::NotAPlayer));
    for _ in 0..rules::ASKING_IN_TEN_SECONDS {
        assert_eq!(db.call(|db| rules::asking(db, ada.id)).unwrap().id, ada.id);
    }
    assert_eq!(db.call(|db| rules::asking(db, ada.id)), Err(Refusal::TooFast));
    db.clock += 9;
    assert_eq!(db.call(|db| rules::asking(db, ada.id)), Err(Refusal::TooFast));
    db.clock += 1;
    assert!(db.call(|db| rules::asking(db, ada.id)).is_ok(), "ten seconds on, they may ask again");
    assert_eq!(Table::<Pace>::get(&db, ada.id).unwrap().asked, 1);
    let bryn = db.call(|db| rules::join(db, "Bryn")).unwrap();
    assert!(db.call(|db| rules::asking(db, bryn.id)).is_ok(), "each player is counted alone");
}

#[test]
fn a_reducer_that_fails_changes_nothing_and_timers_fire_in_order() {
    use realm::store::World;
    let mut db = opened();
    let failed: Result<(), Refusal> = db.call(|db| {
        rules::join(db, "Ada")?;
        Err(Refusal::TooFast)
    });
    assert_eq!(failed, Err(Refusal::TooFast));
    assert!(Table::<Player>::all(&db).is_empty(), "undone with the failure");

    let late = db.after(1_000_050, 2, 9);
    db.after(1_000_020, 1, 8);
    db.after(1_000_020, 3, 7);
    assert_eq!(db.next_due(), Some(1_000_020));
    assert!(db.due().is_empty(), "none is due yet");
    db.clock = 1_000_030;
    let due = db.due();
    assert_eq!(due.iter().map(|t| (t.kind, t.subject)).collect::<Vec<_>>(), vec![(1, 8), (3, 7)], "earliest first, then as set");
    db.cancel(late);
    db.clock = 2_000_000;
    assert!(db.due().is_empty(), "a timer called off never fires");
    let (a, b) = (db.chance(), db.chance());
    assert_ne!(a, b);
    let mut again = Mem::new(0, 7);
    let mut first = Mem::new(0, 7);
    assert_eq!(again.chance(), first.chance(), "the same seed, the same chances");
}
