//! A city under attack: another player's army at its walls, the fight,
//! what is carried off, and the peace that follows.

use super::{building_of, fallen, fight_sheltered, goods, keep_troop, realm, reckon, report, room_for_wounded, set_goods, settle, squads, Refusal, MOST_ROUNDS};
use crate::catalog::{self, Building as Kind, Goods, Troops, Unit};
use crate::hex::Hex;
use crate::rows::{City, Db, Haul, March, Place, Player, Report, Squad, Troop};
use crate::store::Table;

/// The city at a hex, if one stands there.
pub fn city_at(db: &impl Db, hex: Hex) -> Option<City> {
    match Table::<Place>::get(db, hex.packed()) {
        Some(place) if place.kind == Place::CITY => Table::<City>::get(db, place.id),
        _ => None,
    }
}

/// A player's name, for a report.
fn name_of(db: &impl Db, player: u64) -> String {
    Table::<Player>::get(db, player).map(|row| row.name).unwrap_or_else(|| "Someone".into())
}

/// Whether a player may send an army against the city at a hex: one
/// stands there, it is not their own, and it is not at peace.
pub(super) fn may_attack(db: &impl Db, player: u64, to: Hex) -> Result<City, Refusal> {
    let city = city_at(db, to).ok_or(Refusal::NoCityThere)?;
    if city.owner == player {
        return Err(Refusal::OwnCity);
    }
    let left = city.shield - db.now();
    if left > 0 {
        return Err(Refusal::AtPeace(left));
    }
    Ok(city)
}

/// A player who sends an army against a city gives up their own city's
/// peace: it may be attacked from now on.
pub(super) fn break_peace(db: &mut impl Db, mut city: City) {
    let now = db.now();
    if city.shield > now {
        city.shield = now;
        db.update(city);
    }
}

/// An army has reached the city it set out against: if it still stands
/// there and is not at peace, the assault begins, and lasts a while.
/// False if there is nothing to attack.
pub(super) fn besiege(db: &mut impl Db, march: &mut March) -> bool {
    let now = db.now();
    let stands = Table::<City>::get(db, march.target).is_some_and(|city| city.hex == march.to && city.shield <= now);
    if !stands {
        return false;
    }
    let pace = realm(db).map(|realm| realm.pace).unwrap_or(1);
    march.state = March::FIGHTING;
    march.departed = now;
    march.arrives = now + catalog::paced(catalog::ASSAULT_SECONDS, pace).max(1);
    true
}

/// An army's assault on a city is over.
///
/// Everyone standing ready in the city defends it, each harder to bring
/// down for every level of its Wall. Of the army's fallen, half are
/// carried home wounded while its own city has room to tend them, and
/// the rest die. The city's fallen lie wounded within it while it has
/// room, and the rest die. If the army holds the field it carries off as
/// much of the city's goods as those still standing can bear, less what
/// the Storehouse keeps safe, and the city is at peace for a while. Both
/// players are told.
pub(super) fn stormed(db: &mut impl Db, march: &mut March) {
    let Some(mut city) = Table::<City>::get(db, march.target) else { return };
    let (attacker, defender) = (name_of(db, march.owner), name_of(db, city.owner));

    let mut own = squads(db, march.id);
    own.sort_by_key(|squad| (std::cmp::Reverse(squad.tier), squad.kind));
    let army: Vec<Unit> = own.iter().filter_map(|squad| Troops::of(squad.kind).map(|kind| Unit { kind, tier: squad.tier, count: squad.count })).collect();
    let mut garrison: Vec<Troop> = Table::<Troop>::by(db, 0, city.id).into_iter().filter(|row| row.ready > 0 && Troops::of(row.kind).is_some()).collect();
    garrison.sort_by_key(|row| (std::cmp::Reverse(row.tier), row.kind));
    let defenders: Vec<Unit> = garrison.iter().filter_map(|row| Troops::of(row.kind).map(|kind| Unit { kind, tier: row.tier, count: row.ready })).collect();
    let wall = building_of(db, city.id, Kind::Wall).map(|building| building.level).unwrap_or(0);
    let mut rolls: Vec<u64> = (0..2 * MOST_ROUNDS).map(|_| db.chance()).collect();
    let outcome = fight_sheltered(&army, &defenders, catalog::shelter(wall), || rolls.pop().unwrap_or(0));

    // The army's fallen: half carried home wounded, while there is room.
    let mut room = room_for_wounded(db, march.city);
    let (mut wounded, mut dead) = (0, 0);
    for (squad, lost) in own.iter_mut().zip(&outcome.attackers_lost) {
        let saved = (lost / 2).min(room);
        room -= saved;
        wounded += saved;
        dead += lost - saved;
        squad.count -= lost;
        squad.wounded += saved;
        if squad.count + squad.wounded == 0 {
            Table::<Squad>::delete(db, squad.id);
        } else {
            db.update(squad.clone());
        }
    }
    let fought: u64 = army.iter().map(|unit| unit.count).sum();
    march.soldiers = fought - outcome.attackers_lost.iter().sum::<u64>();

    // The city's fallen: wounded within it, while there is room.
    let mut room = room_for_wounded(db, city.id);
    let (mut hurt, mut slain) = (0, 0);
    for (row, lost) in garrison.iter_mut().zip(&outcome.defenders_lost) {
        let saved = (*lost).min(room);
        room -= saved;
        hurt += saved;
        slain += lost - saved;
        row.ready -= lost;
        row.wounded += saved;
        keep_troop(db, row.clone());
    }
    let stood: u64 = defenders.iter().map(|unit| unit.count).sum();
    let fell: u64 = outcome.defenders_lost.iter().sum();

    let mut taken = Goods::NONE;
    let now = db.now();
    let pace = realm(db).map(|realm| realm.pace).unwrap_or(1);
    if outcome.won {
        if let Ok(mut stock) = settle(db, city.id) {
            let storehouse = building_of(db, city.id, Kind::Storehouse).map(|building| building.level).unwrap_or(0);
            let safe = catalog::kept_safe(storehouse);
            let open = goods(&stock).parts().map(|part| part.saturating_sub(safe));
            let all: u64 = open.iter().sum();
            let load: u64 = own.iter().map(|squad| Troops::of(squad.kind).map(|kind| kind.soldier(squad.tier).load).unwrap_or(0) * squad.count).sum();
            taken = Goods::from_parts(open.map(|part| if all > load { (part as u128 * load as u128 / all as u128) as u64 } else { part }));
            let left = goods(&stock).minus(taken);
            set_goods(&mut stock, left);
            db.update(stock);
        }
        if !taken.is_none() {
            db.insert(Haul { march: march.id, owner: march.owner, grain: taken.grain, timber: taken.timber, stone: taken.stone, moonsalt: taken.moonsalt });
        }
        city.shield = now + catalog::paced(catalog::BEATEN_PEACE, pace);
        db.update(city.clone());
    }

    // Each side is told, in its own words.
    let mut to_attacker = if outcome.won {
        format!("Your army took {defender}'s city by storm.")
    } else {
        format!("Your army was beaten at {defender}'s city. {} of its defenders still stood.", catalog::grouped(stood - fell))
    };
    to_attacker += " ";
    to_attacker += &fallen(fought, wounded, dead, "soldier", "soldiers");
    if outcome.won {
        to_attacker += &if taken.is_none() { " There was nothing to carry off.".to_string() } else { format!(" It is bringing home {taken}.") };
    }
    let mut to_defender = if outcome.won {
        if taken.is_none() {
            format!("{attacker}'s army took your city by storm, and found nothing to carry off.")
        } else {
            format!("{attacker}'s army took your city by storm and carried off {taken}.")
        }
    } else {
        format!("{attacker}'s army attacked your city and was beaten. {} of its {} fell.", catalog::grouped(fought - march.soldiers), catalog::grouped(fought))
    };
    to_defender += " ";
    to_defender += &if stood == 0 { "Your city had no defenders.".to_string() } else { fallen(stood, hurt, slain, "defender", "defenders") };
    if outcome.won {
        to_defender += &format!(" Your city is at peace for {}.", catalog::spoken(catalog::paced(catalog::BEATEN_PEACE, pace)));
    }
    let told = |player: u64, kind: u8, won: bool, foe: u64, mine: (u64, u64, u64), theirs: (u64, u64), words: String| Report {
        id: 0,
        player,
        at: now,
        kind,
        hex: city.hex,
        won,
        foe,
        rounds: outcome.rounds,
        fought: mine.0,
        wounded: mine.1,
        dead: mine.2,
        stood: theirs.0,
        fell: theirs.1,
        grain: taken.grain,
        timber: taken.timber,
        stone: taken.stone,
        moonsalt: taken.moonsalt,
        words,
        read: false,
    };
    report(db, told(march.owner, Report::ATTACK, outcome.won, city.owner, (fought, wounded, dead), (stood, fell), to_attacker));
    report(db, told(city.owner, Report::DEFENCE, !outcome.won, march.owner, (stood, hurt, slain), (fought, fought - march.soldiers), to_defender));
    reckon(db, city.id);
}
