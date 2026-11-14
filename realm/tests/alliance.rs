//! Alliances and chat over a store kept in memory: founding, joining and
//! leaving, ranks, who may do what, and what is said in the realm and
//! within an alliance.

use realm::catalog::{self, Building as Kind, Troops};
use realm::hex::Hex;
use realm::rows::{Alliance, AllianceChat, Applicant, Building, City, March, Member, RealmChat, Troop};
use realm::rules::{self, Asked, Refusal};
use realm::store::{Mem, Seconds, Table};

const START: Seconds = 3_000_000;

/// A realm with players of these names, each with a city.
fn realm_of(names: &[&str]) -> (Mem, Vec<u64>) {
    let mut db = Mem::new(START, 5);
    rules::open(&mut db, 7, 1, 48);
    let players = names.iter().map(|name| db.call(|db| rules::join(db, name)).unwrap().id).collect();
    (db, players)
}

/// Gives a player's city an Embassy.
fn embassy(db: &mut Mem, player: u64) {
    let city = rules::city_of(db, player).unwrap();
    db.insert(Building { id: 0, city: city.id, kind: Kind::Embassy as u8, level: 1 });
}

fn alliance(db: &Mem, id: u64) -> Alliance {
    Table::<Alliance>::get(db, id).expect("the alliance stands")
}

/// Moves the clock on, so that asking is not too fast.
fn later(db: &mut Mem, seconds: Seconds) {
    let to = db.clock + seconds;
    db.advance(to, |db, timer| rules::fire(db, timer));
}

#[test]
fn an_alliance_is_founded_under_a_name_and_a_tag_of_its_own() {
    let (mut db, players) = realm_of(&["Ada", "Bryn"]);
    let (ada, bryn) = (players[0], players[1]);

    // An Embassy is needed to found one.
    assert_eq!(db.call(|db| rules::found_alliance(db, ada, "Keepers of the Mere", "mere")), Err(Refusal::NeedsOther(Kind::Embassy, 1)));
    assert_eq!(Refusal::NeedsOther(Kind::Embassy, 1).to_string(), "Raise your Embassy to level 1 first.");
    embassy(&mut db, ada);
    embassy(&mut db, bryn);

    // Names and tags that won't do.
    for name in ["Me", "A name much too long to be an alliance's", "Keepers!", " -Keepers"] {
        assert_eq!(db.call(|db| rules::found_alliance(db, ada, name, "MERE")), Err(Refusal::AllianceNameNotAllowed), "{name}");
    }
    for tag in ["ME", "MERES", "M E", "M-R"] {
        assert_eq!(db.call(|db| rules::found_alliance(db, ada, "Keepers", tag)), Err(Refusal::TagNotAllowed), "{tag}");
    }
    assert_eq!(Refusal::TagNotAllowed.to_string(), "A tag is 3 or 4 letters or digits.");
    assert!(Table::<Alliance>::all(&db).is_empty());

    // Founded: its name tidied, its tag in capitals, its founder its leader, open to all.
    let founded = db.call(|db| rules::found_alliance(db, ada, "  Keepers   of the Mere ", " mere ")).unwrap();
    assert_eq!((founded.name.as_str(), founded.tag.as_str(), founded.leader, founded.members, founded.open), ("Keepers of the Mere", "MERE", ada, 1, true));
    assert_eq!(founded.founded, db.clock);
    assert_eq!(rules::member_of(&db, ada), Some(Member { player: ada, alliance: founded.id, rank: Member::LEADER, joined: db.clock }));
    assert!(rules::member_of(&db, bryn).is_none());

    // No one is in two; no two alliances share a name or a tag, however written.
    assert_eq!(db.call(|db| rules::found_alliance(db, ada, "Another", "ANO")), Err(Refusal::AlreadyAllied));
    assert_eq!(Refusal::AlreadyAllied.to_string(), "You are in an alliance already. Leave it first.");
    assert_eq!(db.call(|db| rules::found_alliance(db, bryn, "KEEPERS OF THE MERE", "KOM")), Err(Refusal::AllianceNameTaken));
    assert_eq!(db.call(|db| rules::found_alliance(db, bryn, "Wardens", "Mere")), Err(Refusal::TagTaken));
    assert_eq!(Refusal::TagTaken.to_string(), "Another alliance has that tag.");
    let other = db.call(|db| rules::found_alliance(db, bryn, "Wardens", "WRD")).unwrap();
    assert_ne!(other.id, founded.id);

    // A name is shown with its alliance's tag before it.
    let player = Table::<realm::rows::Player>::get(&db, ada).unwrap();
    assert_eq!(rules::shown_name(&db, &player), "[MERE] Ada");
    assert!(rules::allied(&db, ada, ada));
    assert!(!rules::allied(&db, ada, bryn));
    // Someone who has not joined the realm founds nothing.
    assert_eq!(db.call(|db| rules::found_alliance(db, 99, "Ghosts", "GST")), Err(Refusal::NotAPlayer));
}

#[test]
fn players_join_an_open_alliance_and_ask_to_join_a_closed_one() {
    let (mut db, players) = realm_of(&["Ada", "Bryn", "Cato", "Dara"]);
    let (ada, bryn, cato, dara) = (players[0], players[1], players[2], players[3]);
    embassy(&mut db, ada);
    let mere = db.call(|db| rules::found_alliance(db, ada, "Keepers", "MERE")).unwrap().id;

    // Open: in at once.
    assert_eq!(db.call(|db| rules::join_alliance(db, bryn, mere)), Ok(true));
    assert_eq!(rules::member_of(&db, bryn).map(|member| (member.alliance, member.rank)), Some((mere, Member::MEMBER)));
    assert_eq!(alliance(&db, mere).members, 2);
    assert!(rules::allied(&db, ada, bryn));
    assert_eq!(db.call(|db| rules::join_alliance(db, bryn, mere)), Err(Refusal::AlreadyAllied));
    assert_eq!(db.call(|db| rules::join_alliance(db, cato, 999)), Err(Refusal::NoSuchAlliance));

    // Closed by its leader, with a word of its own; only the leader may.
    assert_eq!(db.call(|db| rules::set_alliance(db, bryn, false, "")), Err(Refusal::NotTheLeader));
    let closed = db.call(|db| rules::set_alliance(db, ada, false, "  We keep   the east shore. ")).unwrap();
    assert_eq!((closed.open, closed.words.as_str()), (false, "We keep the east shore."));
    assert_eq!(db.call(|db| rules::set_alliance(db, ada, false, &"x".repeat(201))), Err(Refusal::SaidTooLong));

    // Cato asks; he is not in until an officer lets him in. Bryn is no officer.
    assert_eq!(db.call(|db| rules::join_alliance(db, cato, mere)), Ok(false));
    assert!(rules::member_of(&db, cato).is_none());
    assert_eq!(Table::<Applicant>::get(&db, cato).map(|asked| (asked.alliance, asked.name)), Some((mere, "Cato".to_string())));
    assert_eq!(db.call(|db| rules::answer_applicant(db, bryn, cato, true)), Err(Refusal::NotAnOfficer));
    assert_eq!(Refusal::NotAnOfficer.to_string(), "Only your alliance's officers may do that.");
    assert_eq!(db.call(|db| rules::answer_applicant(db, dara, cato, true)), Err(Refusal::NotAllied));
    assert_eq!(db.call(|db| rules::answer_applicant(db, ada, dara, true)), Err(Refusal::NoSuchApplicant));
    assert_eq!(db.call(|db| rules::answer_applicant(db, ada, cato, true)), Ok(()));
    assert_eq!(rules::member_of(&db, cato).map(|member| member.alliance), Some(mere));
    assert!(Table::<Applicant>::get(&db, cato).is_none());
    assert_eq!(alliance(&db, mere).members, 3);

    // Dara asks and is turned away; asks again, and founds her own instead: her asking is gone.
    later(&mut db, 20);
    assert_eq!(db.call(|db| rules::join_alliance(db, dara, mere)), Ok(false));
    assert_eq!(db.call(|db| rules::answer_applicant(db, ada, dara, false)), Ok(()));
    assert!(Table::<Applicant>::get(&db, dara).is_none());
    assert!(rules::member_of(&db, dara).is_none());
    assert_eq!(db.call(|db| rules::join_alliance(db, dara, mere)), Ok(false));
    embassy(&mut db, dara);
    db.call(|db| rules::found_alliance(db, dara, "Wardens", "WRD")).unwrap();
    assert!(Table::<Applicant>::get(&db, dara).is_none());

    // An alliance takes a hundred members and no more.
    let mut full = alliance(&db, mere);
    full.members = catalog::ALLIANCE_MOST;
    full.open = true;
    db.update(full);
    let (mut crowd, more) = realm_of(&["Edda"]);
    assert_eq!(crowd.call(|db| rules::join_alliance(db, more[0], 1)), Err(Refusal::NoSuchAlliance));
    db.call(|db| rules::leave_alliance(db, dara)).unwrap();
    later(&mut db, 20);
    assert_eq!(db.call(|db| rules::join_alliance(db, dara, mere)), Err(Refusal::AllianceFull));
    assert_eq!(Refusal::AllianceFull.to_string(), "That alliance is full.");
}

#[test]
fn members_leave_are_put_out_and_change_rank() {
    let (mut db, players) = realm_of(&["Ada", "Bryn", "Cato"]);
    let (ada, bryn, cato) = (players[0], players[1], players[2]);
    embassy(&mut db, ada);
    let mere = db.call(|db| rules::found_alliance(db, ada, "Keepers", "MERE")).unwrap().id;
    db.call(|db| rules::join_alliance(db, bryn, mere)).unwrap();
    db.call(|db| rules::join_alliance(db, cato, mere)).unwrap();

    // Ranks: the leader alone gives them; an officer may put out a member, never an equal.
    assert_eq!(db.call(|db| rules::set_rank(db, bryn, cato, Member::OFFICER)), Err(Refusal::NotTheLeader));
    assert_eq!(db.call(|db| rules::set_rank(db, ada, bryn, Member::OFFICER)), Ok(()));
    assert_eq!(rules::member_of(&db, bryn).unwrap().rank, Member::OFFICER);
    assert_eq!(db.call(|db| rules::set_rank(db, ada, bryn, 3)), Err(Refusal::NoSuchRank));
    assert_eq!(db.call(|db| rules::set_rank(db, ada, ada, Member::MEMBER)), Err(Refusal::NotAMember), "not her own");
    assert_eq!(db.call(|db| rules::set_rank(db, ada, 99, Member::OFFICER)), Err(Refusal::NotAMember));
    assert_eq!(db.call(|db| rules::expel(db, cato, bryn)), Err(Refusal::NotAnOfficer));
    assert_eq!(db.call(|db| rules::expel(db, bryn, ada)), Err(Refusal::OutranksYou));
    assert_eq!(Refusal::OutranksYou.to_string(), "They are of your rank or above it.");
    assert_eq!(db.call(|db| rules::expel(db, bryn, bryn)), Err(Refusal::OutranksYou));
    assert_eq!(db.call(|db| rules::expel(db, bryn, cato)), Ok(()));
    assert!(rules::member_of(&db, cato).is_none());
    assert_eq!(alliance(&db, mere).members, 2);
    assert_eq!(db.call(|db| rules::expel(db, bryn, cato)), Err(Refusal::NotAMember));

    // The leader can't walk out on an alliance with members; handing it
    // over makes her an officer of it, and then she may go.
    later(&mut db, 20);
    assert_eq!(db.call(|db| rules::leave_alliance(db, ada)), Err(Refusal::LeaderMustHandOver));
    assert_eq!(Refusal::LeaderMustHandOver.to_string(), "Hand the alliance over to another member before you leave it.");
    assert_eq!(db.call(|db| rules::set_rank(db, ada, bryn, Member::LEADER)), Ok(()));
    assert_eq!(alliance(&db, mere).leader, bryn);
    assert_eq!((rules::member_of(&db, bryn).unwrap().rank, rules::member_of(&db, ada).unwrap().rank), (Member::LEADER, Member::OFFICER));
    assert_eq!(db.call(|db| rules::leave_alliance(db, ada)), Ok(()));
    assert_eq!(db.call(|db| rules::leave_alliance(db, ada)), Err(Refusal::NotAllied));
    assert_eq!(alliance(&db, mere).members, 1);

    // The last member leaves, and the alliance is no more: its words and
    // those who had asked to join go with it.
    db.call(|db| rules::set_alliance(db, bryn, false, "")).unwrap();
    db.call(|db| rules::join_alliance(db, cato, mere)).unwrap();
    db.call(|db| rules::say(db, bryn, true, "Anyone there?")).unwrap();
    later(&mut db, 20);
    assert_eq!(db.call(|db| rules::leave_alliance(db, bryn)), Ok(()));
    assert!(Table::<Alliance>::get(&db, mere).is_none());
    assert!(Table::<AllianceChat>::all(&db).is_empty());
    assert!(Table::<Applicant>::all(&db).is_empty());
    assert!(Table::<Member>::all(&db).is_empty());
    // Its name is free again.
    embassy(&mut db, cato);
    assert!(db.call(|db| rules::found_alliance(db, cato, "Keepers", "MERE")).is_ok());
}

#[test]
fn allies_do_not_attack_one_another() {
    let (mut db, players) = realm_of(&["Ada", "Bryn"]);
    let (ada, bryn) = (players[0], players[1]);
    let hers = rules::city_of(&db, ada).unwrap();
    let his = rules::city_of(&db, bryn).unwrap();
    rules::keep_troop(&mut db, Troop { id: Troop::key(hers.id, 1, 1), city: hers.id, kind: 1, tier: 1, ready: 100, wounded: 0 });
    let mut open = Table::<City>::get(&db, his.id).unwrap();
    open.shield = db.clock;
    db.update(open);
    embassy(&mut db, ada);
    let mere = db.call(|db| rules::found_alliance(db, ada, "Keepers", "MERE")).unwrap().id;
    db.call(|db| rules::join_alliance(db, bryn, mere)).unwrap();
    let army = [Asked { kind: Troops::Spearmen as u8, tier: 1, count: 100 }];
    assert_eq!(db.call(|db| rules::send(db, ada, Hex::unpacked(his.hex), March::ATTACK, &army)), Err(Refusal::AllysCity));
    assert_eq!(Refusal::AllysCity.to_string(), "That city is your ally's.");
    assert_eq!(Table::<City>::get(&db, hers.id).unwrap().shield, hers.shield, "and her own peace is not given up for it");
    // Out of the alliance, he may be attacked.
    later(&mut db, 20);
    db.call(|db| rules::leave_alliance(db, bryn)).unwrap();
    assert!(db.call(|db| rules::send(db, ada, Hex::unpacked(his.hex), March::ATTACK, &army)).is_ok());
}

#[test]
fn what_is_said_is_read_by_the_realm_or_by_an_alliance_alone() {
    let (mut db, players) = realm_of(&["Ada", "Bryn", "Cato"]);
    let (ada, bryn, cato) = (players[0], players[1], players[2]);
    embassy(&mut db, ada);

    // To the realm: tidied, under the speaker's name.
    assert_eq!(db.call(|db| rules::say(db, ada, false, "  Good   morning,\tall. ")), Ok(()));
    let said = Table::<RealmChat>::all(&db);
    assert_eq!(said.len(), 1);
    assert_eq!((said[0].player, said[0].name.as_str(), said[0].words.as_str(), said[0].at), (ada, "Ada", "Good morning, all.", db.clock));

    // Nothing, too much, and too soon are refused.
    assert_eq!(db.call(|db| rules::say(db, bryn, false, "   ")), Err(Refusal::NothingSaid));
    assert_eq!(db.call(|db| rules::say(db, bryn, false, &"a".repeat(201))), Err(Refusal::SaidTooLong));
    assert_eq!(Refusal::SaidTooLong.to_string(), "That is too long to say at once: 200 letters at most.");
    assert_eq!(db.call(|db| rules::say(db, bryn, false, &"a".repeat(200))), Ok(()));
    assert_eq!(db.call(|db| rules::say(db, ada, false, "And again")), Err(Refusal::SayingTooFast));
    assert_eq!(Refusal::SayingTooFast.to_string(), "Wait a moment before you say more.");
    later(&mut db, catalog::SAID_EVERY);
    assert_eq!(db.call(|db| rules::say(db, ada, false, "And again")), Ok(()));
    assert_eq!(Table::<RealmChat>::all(&db).len(), 3);
    assert_eq!(db.call(|db| rules::say(db, 99, false, "Hello")), Err(Refusal::NotAPlayer));

    // Within an alliance: its members' alone, and no one's who is in none.
    assert_eq!(db.call(|db| rules::say(db, cato, true, "Hello?")), Err(Refusal::NotAllied));
    later(&mut db, 20);
    let mere = db.call(|db| rules::found_alliance(db, ada, "Keepers", "MERE")).unwrap().id;
    db.call(|db| rules::join_alliance(db, bryn, mere)).unwrap();
    db.call(|db| rules::say(db, bryn, true, "East shore is quiet")).unwrap();
    let within = Table::<AllianceChat>::by(&db, 0, mere);
    assert_eq!(within.len(), 1);
    assert_eq!((within[0].player, within[0].name.as_str(), within[0].words.as_str()), (bryn, "Bryn", "East shore is quiet"));
    assert_eq!(Table::<RealmChat>::all(&db).len(), 3, "nothing of it reaches the realm");
    // In the realm, an ally speaks under their tag.
    later(&mut db, 20);
    db.call(|db| rules::say(db, bryn, false, "Greetings")).unwrap();
    assert_eq!(Table::<RealmChat>::all(&db).last().map(|said| said.name.clone()), Some("[MERE] Bryn".to_string()));

    // Only the latest are kept: three hundred of the realm's, two hundred of an alliance's.
    for index in 0..catalog::REALM_CHAT_KEPT + 10 {
        later(&mut db, catalog::SAID_EVERY);
        db.call(|db| rules::say(db, ada, false, &format!("Saying {index}"))).unwrap();
    }
    let kept = Table::<RealmChat>::all(&db);
    assert_eq!(kept.len() as u64, catalog::REALM_CHAT_KEPT);
    assert!(kept.iter().all(|said| said.words.starts_with("Saying ")), "the oldest are gone");
    for index in 0..catalog::ALLIANCE_CHAT_KEPT + 5 {
        later(&mut db, catalog::SAID_EVERY);
        db.call(|db| rules::say(db, ada, true, &format!("Within {index}"))).unwrap();
    }
    let within = Table::<AllianceChat>::by(&db, 0, mere);
    assert_eq!(within.len(), catalog::ALLIANCE_CHAT_KEPT);
    assert!(within.iter().all(|said| said.words != "East shore is quiet"));
}
