//! The realm as a SpacetimeDB module.
//!
//! Nothing of the game is decided here. Each reducer finds who is asking,
//! hands the request to the rules over the database (`Stdb`), and gives the
//! player the rules' refusal, in its own words, if there is one. The one
//! timer table schedules whatever the rules ask to happen later.

use spacetimedb::{reducer, table, view, Identity, ReducerContext, ScheduleAt, SpacetimeType, Table as _, Timestamp, ViewContext};

use crate::hex::Hex;
use crate::rows::{
    blueprint as _, building as _, building__view as _, city as _, city__view as _, haul as _, haul__view as _, job as _, job__view as _,
    land as _, march as _, march__view as _, pace as _, place as _, player as _, player__view as _, realm as _, site as _, soldier as _,
    squad as _, squad__view as _, stock as _, stock__view as _, troop as _, troop__view as _, Blueprint, Building, City, Haul, Job, Land,
    March, Pace, Place, Player, Realm, Site, Soldier, Squad, Stock, Troop,
};
use crate::rules::{self, Refusal};
use crate::store::{Seconds, Table, World};

/// Whose player a connection's identity is. The rules know players by
/// number alone; only the module knows identities.
#[table(accessor = account)]
pub struct Account {
    #[primary_key]
    pub identity: Identity,
    #[unique]
    pub player: u64,
}

/// How many connections an identity has open. A player's client keeps a
/// subscription open while it runs, and each thing it asks over HTTP is a
/// connection of its own that opens and closes: a player is here while
/// any of theirs is open.
#[table(accessor = presence)]
pub struct Presence {
    #[primary_key]
    pub identity: Identity,
    pub connections: u32,
}

/// Who published the module: the realm's owner, who alone sets its pace.
#[table(accessor = owner)]
pub struct Owner {
    #[primary_key]
    pub id: u8,
    pub identity: Identity,
}

/// What the rules have asked to happen later: the scheduler calls `fire`
/// with the row when its moment comes.
#[table(accessor = timer, scheduled(fire))]
pub struct Timer {
    #[primary_key]
    #[auto_inc]
    pub scheduled_id: u64,
    pub scheduled_at: ScheduleAt,
    pub kind: u8,
    pub subject: u64,
}

/// The database, as the rules see it.
struct Stdb<'a>(&'a ReducerContext);

impl World for Stdb<'_> {
    fn now(&self) -> Seconds {
        self.0.timestamp.to_micros_since_unix_epoch().div_euclid(1_000_000)
    }

    fn chance(&mut self) -> u64 {
        self.0.random()
    }

    fn after(&mut self, at: Seconds, kind: u8, subject: u64) -> u64 {
        let moment = Timestamp::from_micros_since_unix_epoch(at.saturating_mul(1_000_000));
        self.0.db.timer().insert(Timer { scheduled_id: 0, scheduled_at: moment.into(), kind, subject }).scheduled_id
    }

    fn cancel(&mut self, timer: u64) {
        self.0.db.timer().scheduled_id().delete(timer);
    }
}

/// A table of the database as the rules' table of its rows: its accessor,
/// its key, and its indexes in the order `rows!` lists them.
macro_rules! stored {
    ($row:ident in $accessor:ident by $key:ident $(, $index:ident)*) => {
        impl Table<$row> for Stdb<'_> {
            fn get(&self, key: u64) -> Option<$row> {
                self.0.db.$accessor().$key().find(key)
            }

            #[allow(unused_variables, unused_mut, unused_assignments)]
            fn by(&self, index: usize, value: u64) -> Vec<$row> {
                let mut at = 0;
                $(
                    if index == at {
                        return self.0.db.$accessor().$index().filter(value).collect();
                    }
                    at += 1;
                )*
                Vec::new()
            }

            fn all(&self) -> Vec<$row> {
                self.0.db.$accessor().iter().collect()
            }

            fn insert(&mut self, row: $row) -> $row {
                self.0.db.$accessor().insert(row)
            }

            fn update(&mut self, row: $row) {
                self.0.db.$accessor().$key().update(row);
            }

            fn delete(&mut self, key: u64) {
                self.0.db.$accessor().$key().delete(key);
            }
        }
    };
}

stored!(Realm in realm by id);
stored!(Player in player by id, name_key);
stored!(Pace in pace by player);
stored!(Land in land by chunk);
stored!(Place in place by hex);
stored!(Blueprint in blueprint by id);
stored!(City in city by id, owner);
stored!(Building in building by id, city);
stored!(Job in job by id, city);
stored!(Stock in stock by city);
stored!(Troop in troop by id, city);
stored!(Soldier in soldier by id);
stored!(Site in site by id);
stored!(March in march by id, owner, city);
stored!(Squad in squad by id, march);
stored!(Haul in haul by march, owner);

/// The player a caller is, by their identity.
fn caller(ctx: &ReducerContext) -> Result<u64, Refusal> {
    ctx.db.account().identity().find(ctx.sender()).map(|account| account.player).ok_or(Refusal::NotAPlayer)
}

/// A rule's answer as the caller hears it.
fn said<T>(result: Result<T, Refusal>) -> Result<(), String> {
    result.map(|_| ()).map_err(|refusal| refusal.to_string())
}

/// How many times faster than written the realm runs: 1, the realm
/// proper's pace.
const PACE: u32 = 1;
/// How many hexes the world reaches from the lake's heart: room for some
/// two thousand cities.
const RADIUS: u32 = 128;

/// The module is published: the realm opens, its land grown from a seed
/// drawn then.
#[reducer(init)]
pub fn init(ctx: &ReducerContext) {
    let seed: u64 = ctx.random();
    ctx.db.owner().insert(Owner { id: 0, identity: ctx.sender() });
    rules::open(&mut Stdb(ctx), seed, PACE, RADIUS);
    log::info!("The realm is open: seed {seed}, {RADIUS} hexes from heart to rim.");
}

/// Sets how many times faster than written the realm runs: its owner's
/// alone to ask, for a trial realm or a check.
#[reducer]
pub fn set_pace(ctx: &ReducerContext, pace: u32) -> Result<(), String> {
    if ctx.db.owner().id().find(0).is_none_or(|owner| owner.identity != ctx.sender()) {
        return said::<()>(Err(Refusal::NotTheOwner));
    }
    said(rules::repace(&mut Stdb(ctx), pace))
}

/// Counts one connection more or fewer for the caller, and gives how many
/// they now have open.
fn connections(ctx: &ReducerContext, opened: bool) -> u32 {
    let identity = ctx.sender();
    let had = ctx.db.presence().identity().find(identity).map(|presence| presence.connections).unwrap_or(0);
    let have = if opened { had + 1 } else { had.saturating_sub(1) };
    match (had, have) {
        (0, 0) => {}
        (0, _) => {
            ctx.db.presence().insert(Presence { identity, connections: have });
        }
        (_, 0) => {
            ctx.db.presence().identity().delete(identity);
        }
        _ => {
            ctx.db.presence().identity().update(Presence { identity, connections: have });
        }
    }
    have
}

/// A connection opens. A player's first means they are here.
#[reducer(client_connected)]
pub fn connected(ctx: &ReducerContext) {
    if connections(ctx, true) == 1 {
        if let Ok(player) = caller(ctx) {
            rules::seen(&mut Stdb(ctx), player, true);
        }
    }
}

/// A connection closes. A player's last means they are gone, until they
/// come back: their city, their armies and everything under way go on
/// without them.
#[reducer(client_disconnected)]
pub fn disconnected(ctx: &ReducerContext) {
    if connections(ctx, false) == 0 {
        if let Ok(player) = caller(ctx) {
            rules::seen(&mut Stdb(ctx), player, false);
        }
    }
}

/// Join the realm under a name.
#[reducer]
pub fn join(ctx: &ReducerContext, name: String) -> Result<(), String> {
    if caller(ctx).is_ok() {
        return said::<()>(Err(Refusal::AlreadyAPlayer));
    }
    let joined = rules::join(&mut Stdb(ctx), &name).map(|player| {
        ctx.db.account().insert(Account { identity: ctx.sender(), player: player.id });
    });
    said(joined)
}

/// Build a building the caller's city has not got, by its kind's number.
#[reducer]
pub fn build(ctx: &ReducerContext, kind: u8) -> Result<(), String> {
    said(caller(ctx).and_then(|player| rules::build(&mut Stdb(ctx), player, kind)))
}

/// Raise one of the caller's buildings a level.
#[reducer]
pub fn upgrade(ctx: &ReducerContext, building: u64) -> Result<(), String> {
    said(caller(ctx).and_then(|player| rules::upgrade(&mut Stdb(ctx), player, building)))
}

/// Train a batch of troops of a tier in one of the caller's training
/// buildings.
#[reducer]
pub fn train(ctx: &ReducerContext, building: u64, tier: u32, count: u64) -> Result<(), String> {
    said(caller(ctx).and_then(|player| rules::train(&mut Stdb(ctx), player, building, tier, count)))
}

/// Soldiers of a kind and tier, as a client asks for them in a march.
#[derive(SpacetimeType)]
pub struct Soldiers {
    pub kind: u8,
    pub tier: u32,
    pub count: u64,
}

/// Send soldiers from the caller's city to a hex, to do an order there
/// (1, to gather).
#[reducer]
pub fn send(ctx: &ReducerContext, q: i32, r: i32, order: u8, soldiers: Vec<Soldiers>) -> Result<(), String> {
    let asked: Vec<rules::Asked> = soldiers.iter().map(|s| rules::Asked { kind: s.kind, tier: s.tier, count: s.count }).collect();
    said(caller(ctx).and_then(|player| rules::send(&mut Stdb(ctx), player, Hex::new(q, r), order, &asked)))
}

/// Call one of the caller's armies home.
#[reducer]
pub fn recall(ctx: &ReducerContext, march: u64) -> Result<(), String> {
    said(caller(ctx).and_then(|player| rules::recall(&mut Stdb(ctx), player, march)))
}

/// A timer the rules set has come due. Only the scheduler may call this.
#[reducer]
pub fn fire(ctx: &ReducerContext, timer: Timer) -> Result<(), String> {
    if ctx.sender() != ctx.database_identity() {
        return Err("Only the realm itself keeps its timers.".into());
    }
    let at = match timer.scheduled_at {
        ScheduleAt::Time(moment) => moment.to_micros_since_unix_epoch().div_euclid(1_000_000),
        ScheduleAt::Interval(_) => Stdb(ctx).now(),
    };
    rules::fire(&mut Stdb(ctx), &crate::store::Timer { at, kind: timer.kind, subject: timer.subject });
    Ok(())
}

/// The player a view's caller is, if they have joined.
fn viewer(ctx: &ViewContext) -> Option<u64> {
    ctx.db.account().identity().find(ctx.sender()).map(|account| account.player)
}

/// The caller's own player, if they have joined.
#[view(accessor = me, public)]
fn me(ctx: &ViewContext) -> Option<Player> {
    ctx.db.player().id().find(viewer(ctx)?)
}

/// The caller's own city.
#[view(accessor = my_city, public)]
fn my_city(ctx: &ViewContext) -> Option<City> {
    ctx.db.city().owner().filter(viewer(ctx)?).next()
}

/// What stands in the caller's city.
#[view(accessor = my_buildings, public)]
fn my_buildings(ctx: &ViewContext) -> Vec<Building> {
    my_city(ctx).map(|city| ctx.db.building().city().filter(city.id).collect()).unwrap_or_default()
}

/// What the caller's city has under way.
#[view(accessor = my_jobs, public)]
fn my_jobs(ctx: &ViewContext) -> Vec<Job> {
    my_city(ctx).map(|city| ctx.db.job().city().filter(city.id).collect()).unwrap_or_default()
}

/// The troops in the caller's city, ready and wounded.
#[view(accessor = my_troops, public)]
fn my_troops(ctx: &ViewContext) -> Vec<Troop> {
    my_city(ctx).map(|city| ctx.db.troop().city().filter(city.id).collect()).unwrap_or_default()
}

/// The soldiers in the caller's armies out of the city.
#[view(accessor = my_squads, public)]
fn my_squads(ctx: &ViewContext) -> Vec<Squad> {
    let Some(player) = viewer(ctx) else { return Vec::new() };
    ctx.db.march().owner().filter(player).flat_map(|march| ctx.db.squad().march().filter(march.id)).collect()
}

/// What the caller's armies carry home.
#[view(accessor = my_hauls, public)]
fn my_hauls(ctx: &ViewContext) -> Vec<Haul> {
    viewer(ctx).map(|player| ctx.db.haul().owner().filter(player).collect()).unwrap_or_default()
}

/// The caller's city's goods, as they stood when the realm last touched
/// them: the client reckons their growth since from the hourly rates.
#[view(accessor = my_stock, public)]
fn my_stock(ctx: &ViewContext) -> Option<Stock> {
    ctx.db.stock().city().find(my_city(ctx)?.id)
}
