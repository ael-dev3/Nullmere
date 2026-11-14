//! What a city has learnt: its Academy studies one topic at a time, a
//! level at a time, and each level adds to what the city's works bring
//! in, how fast it builds, trains and marches, or how its soldiers fight.

use super::{asking, building_of, city_of, goods, realm, set_goods, settle, Refusal, TIMER_JOB};
use crate::catalog::{self, Building as Kind, Topic, Troops, TOP_STUDY};
use crate::rows::{Db, Job, Lore, Study};
use crate::store::Table;

/// What a city's studies add to its soldiers in a fight, in hundredths:
/// how much harder each kind strikes, by the kind's number less one, and
/// how much harder all of them are to bring down.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Mastery {
    pub strikes: [u64; 4],
    pub shields: u64,
}

/// The level a city has learnt a topic to.
pub fn learnt(db: &impl Db, city: u64, topic: Topic) -> u32 {
    Table::<Lore>::get(db, Lore::key(city, topic as u8)).map(|lore| lore.level).unwrap_or(0)
}

/// What a topic gives a city, in hundredths: each level's share, times
/// the levels learnt.
pub fn boost(db: &impl Db, city: u64, topic: Topic) -> u64 {
    topic.each() * learnt(db, city, topic) as u64
}

/// A length of time shortened by a topic's hundredths, never to nothing.
pub fn sooner(db: &impl Db, city: u64, topic: Topic, seconds: i64) -> i64 {
    (seconds * (100 - boost(db, city, topic).min(90) as i64) / 100).max(1)
}

/// What a city's studies add to its soldiers in a fight.
pub fn mastery(db: &impl Db, city: u64) -> Mastery {
    let mut mastery = Mastery { strikes: [0; 4], shields: boost(db, city, Topic::Shields) };
    for kind in Troops::ALL {
        mastery.strikes[kind as usize - 1] = boost(db, city, Topic::sharpens(kind));
    }
    mastery
}

/// Writes what each topic's levels cost and give out as rows, at a pace,
/// for clients to show.
pub fn write_studies(db: &mut impl Db, pace: u32) {
    for row in Table::<Study>::all(db) {
        Table::<Study>::delete(db, row.id);
    }
    for topic in Topic::ALL {
        for level in 1..=TOP_STUDY {
            let cost = catalog::study_cost(topic, level);
            db.insert(Study {
                id: Study::key(topic as u8, level),
                topic: topic as u8,
                level,
                name: topic.name().to_string(),
                words: topic.words(),
                each: topic.each(),
                grain: cost.grain,
                timber: cost.timber,
                stone: cost.stone,
                moonsalt: cost.moonsalt,
                seconds: catalog::paced(catalog::study_seconds(level), pace),
                needs_level: catalog::study_needs(level),
            });
        }
    }
}

/// A player has their Academy study the next level of a topic: paid for
/// at once, learnt when the timer ends. One study at a time.
pub fn study(db: &mut impl Db, player: u64, topic: u8) -> Result<Job, Refusal> {
    asking(db, player)?;
    let city = city_of(db, player)?;
    let topic = Topic::of(topic).ok_or(Refusal::NoSuchTopic)?;
    let academy = building_of(db, city.id, Kind::Academy).ok_or(Refusal::NeedsOther(Kind::Academy, 1))?;
    let jobs = Table::<Job>::by(db, 0, city.id);
    if academy.level == 0 || jobs.iter().any(|job| job.kind == Job::RAISE && job.subject == academy.id) {
        return Err(Refusal::AlreadyRising(Kind::Academy));
    }
    if jobs.iter().any(|job| job.kind == Job::STUDY) {
        return Err(Refusal::AlreadyStudying);
    }
    let level = learnt(db, city.id, topic) + 1;
    if level > TOP_STUDY {
        return Err(Refusal::NothingMoreToLearn(topic));
    }
    if academy.level < catalog::study_needs(level) {
        return Err(Refusal::NeedsOther(Kind::Academy, catalog::study_needs(level)));
    }
    let mut stock = settle(db, city.id)?;
    let cost = catalog::study_cost(topic, level);
    let short = goods(&stock).short_of(cost);
    if !short.is_none() {
        return Err(Refusal::CannotAfford(short));
    }
    let left = goods(&stock).minus(cost);
    set_goods(&mut stock, left);
    db.update(stock);
    let now = db.now();
    let ends = now + catalog::paced(catalog::study_seconds(level), realm(db)?.pace);
    let mut job = db.insert(Job { id: 0, city: city.id, kind: Job::STUDY, subject: topic as u64, level, amount: 0, started: now, ends, timer: 0 });
    job.timer = db.after(ends, TIMER_JOB, job.id);
    db.update(job.clone());
    Ok(job)
}

/// A study is done: the city has learnt the topic's next level.
pub(super) fn studied(db: &mut impl Db, job: &Job) {
    let id = Lore::key(job.city, job.subject as u8);
    let lore = Lore { id, city: job.city, topic: job.subject as u8, level: job.level };
    if Table::<Lore>::get(db, id).is_some() {
        db.update(lore);
    } else {
        db.insert(lore);
    }
}
