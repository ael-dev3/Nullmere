//! Alliances and what players say to one another: founding an alliance,
//! joining and leaving it, its ranks, and the realm's chat and each
//! alliance's own.

use super::{asking, building_of, city_of, name_key, tidy, Refusal};
use crate::catalog::{self, Building as Kind};
use crate::rows::{Alliance, AllianceChat, Applicant, Db, Member, Pace, Player, RealmChat};
use crate::store::Table;

/// The shortest and longest an alliance's name may be, in letters.
pub const ALLIANCE_NAME_SHORTEST: usize = 3;
pub const ALLIANCE_NAME_LONGEST: usize = 20;

/// A player's place in an alliance, if they are in one.
pub fn member_of(db: &impl Db, player: u64) -> Option<Member> {
    Table::<Member>::get(db, player)
}

/// Whether two players are of one alliance.
pub fn allied(db: &impl Db, one: u64, other: u64) -> bool {
    match (member_of(db, one), member_of(db, other)) {
        (Some(a), Some(b)) => a.alliance == b.alliance,
        _ => false,
    }
}

/// A player's name as others read it: their alliance's tag before it,
/// where they are in one.
pub fn shown_name(db: &impl Db, player: &Player) -> String {
    match member_of(db, player.id).and_then(|member| Table::<Alliance>::get(db, member.alliance)) {
        Some(alliance) => format!("[{}] {}", alliance.tag, player.name),
        None => player.name.clone(),
    }
}

/// A player founds an alliance and leads it. They need an Embassy, and
/// must be in no alliance; its name and its tag must be no one else's.
pub fn found_alliance(db: &mut impl Db, player: u64, name: &str, tag: &str) -> Result<Alliance, Refusal> {
    asking(db, player)?;
    let city = city_of(db, player)?;
    if member_of(db, player).is_some() {
        return Err(Refusal::AlreadyAllied);
    }
    if building_of(db, city.id, Kind::Embassy).is_none_or(|embassy| embassy.level == 0) {
        return Err(Refusal::NeedsOther(Kind::Embassy, 1));
    }
    let name = tidy(name);
    let letters = name.chars().count();
    let allowed = |c: char| c.is_alphanumeric() || c == ' ' || c == '-' || c == '\'';
    let ends = |c: Option<char>| c.is_some_and(char::is_alphanumeric);
    if !(ALLIANCE_NAME_SHORTEST..=ALLIANCE_NAME_LONGEST).contains(&letters) || !name.chars().all(allowed) || !ends(name.chars().next()) || !ends(name.chars().last()) {
        return Err(Refusal::AllianceNameNotAllowed);
    }
    let tag = tag.trim().to_uppercase();
    if !(3..=4).contains(&tag.chars().count()) || !tag.chars().all(char::is_alphanumeric) {
        return Err(Refusal::TagNotAllowed);
    }
    if Table::<Alliance>::by(db, 0, name_key(&name)).iter().any(|other| other.name.to_lowercase() == name.to_lowercase()) {
        return Err(Refusal::AllianceNameTaken);
    }
    if Table::<Alliance>::by(db, 1, name_key(&tag)).iter().any(|other| other.tag == tag) {
        return Err(Refusal::TagTaken);
    }
    let now = db.now();
    let alliance = db.insert(Alliance {
        id: 0,
        name_key: name_key(&name),
        tag_key: name_key(&tag),
        name,
        tag,
        leader: player,
        founded: now,
        members: 1,
        open: true,
        words: String::new(),
    });
    Table::<Applicant>::delete(db, player);
    db.insert(Member { player, alliance: alliance.id, rank: Member::LEADER, joined: now });
    Ok(alliance)
}

/// Adds a player to an alliance that has room.
fn take_in(db: &mut impl Db, mut alliance: Alliance, player: u64) -> Result<Member, Refusal> {
    if alliance.members >= catalog::ALLIANCE_MOST {
        return Err(Refusal::AllianceFull);
    }
    alliance.members += 1;
    db.update(alliance.clone());
    Table::<Applicant>::delete(db, player);
    Ok(db.insert(Member { player, alliance: alliance.id, rank: Member::MEMBER, joined: db.now() }))
}

/// A player joins an alliance: at once if it is open, and otherwise they
/// ask to be let in, for its officers to answer. True if they are in.
pub fn join_alliance(db: &mut impl Db, player: u64, alliance: u64) -> Result<bool, Refusal> {
    let asker = asking(db, player)?;
    city_of(db, player)?;
    if member_of(db, player).is_some() {
        return Err(Refusal::AlreadyAllied);
    }
    let alliance = Table::<Alliance>::get(db, alliance).ok_or(Refusal::NoSuchAlliance)?;
    if alliance.members >= catalog::ALLIANCE_MOST {
        return Err(Refusal::AllianceFull);
    }
    if alliance.open {
        take_in(db, alliance, player)?;
        return Ok(true);
    }
    let asked = Applicant { player, alliance: alliance.id, name: asker.name, at: db.now() };
    if Table::<Applicant>::get(db, player).is_some() {
        db.update(asked);
    } else {
        db.insert(asked);
    }
    Ok(false)
}

/// The member a player is, if they are of a rank to decide who is let
/// into their alliance and who is put out of it.
fn officer(db: &impl Db, player: u64) -> Result<Member, Refusal> {
    let member = member_of(db, player).ok_or(Refusal::NotAllied)?;
    if member.rank < Member::OFFICER {
        return Err(Refusal::NotAnOfficer);
    }
    Ok(member)
}

/// An officer lets in, or turns away, a player who asked to join.
pub fn answer_applicant(db: &mut impl Db, player: u64, applicant: u64, admit: bool) -> Result<(), Refusal> {
    asking(db, player)?;
    let officer = officer(db, player)?;
    let asked = Table::<Applicant>::get(db, applicant).filter(|asked| asked.alliance == officer.alliance).ok_or(Refusal::NoSuchApplicant)?;
    if admit {
        let alliance = Table::<Alliance>::get(db, officer.alliance).ok_or(Refusal::NoSuchAlliance)?;
        take_in(db, alliance, asked.player)?;
    } else {
        Table::<Applicant>::delete(db, asked.player);
    }
    Ok(())
}

/// Takes a member out of their alliance; with its last member gone, the
/// alliance is no more.
fn put_out(db: &mut impl Db, member: &Member) {
    Table::<Member>::delete(db, member.player);
    let Some(mut alliance) = Table::<Alliance>::get(db, member.alliance) else { return };
    alliance.members = alliance.members.saturating_sub(1);
    if alliance.members == 0 {
        for said in Table::<AllianceChat>::by(db, 0, alliance.id) {
            Table::<AllianceChat>::delete(db, said.id);
        }
        for asked in Table::<Applicant>::by(db, 0, alliance.id) {
            Table::<Applicant>::delete(db, asked.player);
        }
        Table::<Alliance>::delete(db, alliance.id);
    } else {
        db.update(alliance);
    }
}

/// A player leaves their alliance. Its leader may only leave it to
/// someone else, unless they are its last member.
pub fn leave_alliance(db: &mut impl Db, player: u64) -> Result<(), Refusal> {
    asking(db, player)?;
    let member = member_of(db, player).ok_or(Refusal::NotAllied)?;
    let alone = Table::<Alliance>::get(db, member.alliance).is_none_or(|alliance| alliance.members <= 1);
    if member.rank == Member::LEADER && !alone {
        return Err(Refusal::LeaderMustHandOver);
    }
    put_out(db, &member);
    Ok(())
}

/// An officer puts a member of lower rank out of the alliance.
pub fn expel(db: &mut impl Db, player: u64, other: u64) -> Result<(), Refusal> {
    asking(db, player)?;
    let officer = officer(db, player)?;
    let member = member_of(db, other).filter(|member| member.alliance == officer.alliance).ok_or(Refusal::NotAMember)?;
    if member.rank >= officer.rank {
        return Err(Refusal::OutranksYou);
    }
    put_out(db, &member);
    Ok(())
}

/// The leader makes a member an officer, or an officer a member again;
/// or, with the leader's rank, hands the alliance over and becomes an
/// officer of it.
pub fn set_rank(db: &mut impl Db, player: u64, other: u64, rank: u8) -> Result<(), Refusal> {
    asking(db, player)?;
    let mut leader = member_of(db, player).ok_or(Refusal::NotAllied)?;
    if leader.rank != Member::LEADER {
        return Err(Refusal::NotTheLeader);
    }
    let mut member = member_of(db, other).filter(|member| member.alliance == leader.alliance && member.player != player).ok_or(Refusal::NotAMember)?;
    match rank {
        Member::MEMBER | Member::OFFICER => {
            member.rank = rank;
            db.update(member);
        }
        Member::LEADER => {
            let mut alliance = Table::<Alliance>::get(db, leader.alliance).ok_or(Refusal::NoSuchAlliance)?;
            alliance.leader = other;
            db.update(alliance);
            member.rank = Member::LEADER;
            db.update(member);
            leader.rank = Member::OFFICER;
            db.update(leader);
        }
        _ => return Err(Refusal::NoSuchRank),
    }
    Ok(())
}

/// The leader says whether anyone may join without being let in, and
/// what the alliance says of itself.
pub fn set_alliance(db: &mut impl Db, player: u64, open: bool, words: &str) -> Result<Alliance, Refusal> {
    asking(db, player)?;
    let leader = member_of(db, player).ok_or(Refusal::NotAllied)?;
    if leader.rank != Member::LEADER {
        return Err(Refusal::NotTheLeader);
    }
    let words = spoken_words(words, true)?;
    let mut alliance = Table::<Alliance>::get(db, leader.alliance).ok_or(Refusal::NoSuchAlliance)?;
    alliance.open = open;
    alliance.words = words;
    db.update(alliance.clone());
    Ok(alliance)
}

/// What someone means to say, tidied: its spaces single, nothing in it
/// but what can be read, and no longer than a saying may be.
fn spoken_words(words: &str, may_be_empty: bool) -> Result<String, Refusal> {
    let words = tidy(words);
    if words.is_empty() && !may_be_empty {
        return Err(Refusal::NothingSaid);
    }
    if words.chars().count() > catalog::SAID_LONGEST || words.chars().any(char::is_control) {
        return Err(Refusal::SaidTooLong);
    }
    Ok(words)
}

/// A player says something: to the whole realm, or within their
/// alliance. One thing every two seconds.
pub fn say(db: &mut impl Db, player: u64, within_alliance: bool, words: &str) -> Result<(), Refusal> {
    let speaker = asking(db, player)?;
    let words = spoken_words(words, false)?;
    let now = db.now();
    let mut pace = Table::<Pace>::get(db, player).ok_or(Refusal::NotAPlayer)?;
    if now - pace.said < catalog::SAID_EVERY {
        return Err(Refusal::SayingTooFast);
    }
    pace.said = now;
    db.update(pace);
    if within_alliance {
        let member = member_of(db, player).ok_or(Refusal::NotAllied)?;
        db.insert(AllianceChat { id: 0, alliance: member.alliance, player, name: speaker.name, at: now, words });
        let mut all = Table::<AllianceChat>::by(db, 0, member.alliance);
        all.sort_by_key(|said| said.id);
        for old in all.iter().take(all.len().saturating_sub(catalog::ALLIANCE_CHAT_KEPT)) {
            Table::<AllianceChat>::delete(db, old.id);
        }
    } else {
        let name = shown_name(db, &speaker);
        let said = db.insert(RealmChat { id: 0, player, name, at: now, words });
        // The realm's sayings are numbered as they come: the one that
        // many back is let go.
        if said.id > catalog::REALM_CHAT_KEPT {
            Table::<RealmChat>::delete(db, said.id - catalog::REALM_CHAT_KEPT);
        }
    }
    Ok(())
}
