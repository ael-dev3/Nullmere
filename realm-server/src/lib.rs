//! The Nullmere Online realm, as a SpacetimeDB module.
//!
//! SpacetimeDB is the realm's authority of record: it knows every keeper by
//! their identity, keeps the world, and lets no one but the steward write
//! it. The rules themselves run in the steward, a trusted Swift process
//! (`NullmereSteward`) holding the same rules core the clients carry, so
//! there is one set of rules, not two.
//!
//! A keeper's client adds requests (arrive, order, ready, here, leave), each
//! carrying a nonce the client chose. The steward takes them in order,
//! carries them out, answers each by its nonce, and publishes the realm:
//! its status for everyone, and for each keeper their own view of the
//! world, never the whole of it.
//!
//! The world, the requests, the answers and the keepers' views are private
//! tables. Everyone may read the realm's status; a keeper reads their own
//! view and their own answers through the `my_view` and `my_replies` views,
//! which show each caller their rows alone.

use spacetimedb::{reducer, table, view, ReducerContext, Table, ViewContext};

/// Longest request payload: an order, or a name.
const MAX_PAYLOAD: usize = 4096;
/// Longest nonce a client may choose.
const MAX_NONCE: usize = 64;
/// Most requests one keeper may have waiting.
const MAX_WAITING: usize = 32;

/// How long a steward's hold on the realm lasts without a publication.
const LEASE_MICROS: i64 = 60_000_000;

/// The one steward running the realm now. Stewards share the publisher's
/// identity, so a second one started by mistake would carry out the same
/// requests twice and pull the world two ways; the lease lets one run.
#[table(accessor = lease)]
pub struct Lease {
    #[primary_key]
    pub id: u8,
    /// The running steward's own name for itself, chosen when it starts.
    pub holder: String,
    pub until_micros: i64,
}

/// The one identity that may write the world: the steward's.
#[table(accessor = steward)]
pub struct Steward {
    #[primary_key]
    pub id: u8,
    pub identity: String,
}

/// A keeper's request, waiting for the steward.
#[table(accessor = request)]
pub struct Request {
    #[primary_key]
    #[auto_inc]
    pub id: u64,
    /// The keeper's identity, in hex.
    #[index(btree)]
    pub keeper: String,
    /// arrive, order, ready, here or leave.
    pub kind: String,
    #[index(btree)]
    pub nonce: String,
    pub payload: String,
}

/// The steward's answer to a request, found by its nonce.
#[table(accessor = reply)]
pub struct Reply {
    #[primary_key]
    pub nonce: String,
    #[index(btree)]
    pub keeper: String,
    pub payload: String,
}

/// The realm as it stands, as the rules core's JSON, in parts (the map, a
/// page of each long list, the rest), so the steward rewrites only the
/// parts that changed: the steward's alone to read.
#[table(accessor = world_part)]
pub struct WorldPart {
    #[primary_key]
    pub name: String,
    pub version: u64,
    pub text: String,
}

/// What anyone may know of the realm: its age, watch, keepers and seats.
#[table(accessor = status, public)]
pub struct Status {
    #[primary_key]
    pub id: u8,
    pub version: u64,
    pub status: String,
}

/// When the server took the status's publication, by its own clock: a
/// keeper arriving mid-watch takes off the time since, read by the same
/// clock, so its countdown is right whatever the keeper's own clock says.
#[table(accessor = stamp, public)]
pub struct Stamp {
    #[primary_key]
    pub id: u8,
    pub version: u64,
    pub at_micros: i64,
}

/// One keeper's view of the realm, and what they heard lately: the events
/// of the last few publications, each with its version, so a client that
/// missed one still hears it, and only once.
#[table(accessor = keeper_view)]
pub struct KeeperView {
    #[primary_key]
    pub keeper: String,
    pub version: u64,
    pub view: String,
    pub events: String,
}

/// The caller's own view of the realm.
#[view(accessor = my_view, public)]
fn my_view(ctx: &ViewContext) -> Option<KeeperView> {
    ctx.db.keeper_view().keeper().find(ctx.sender().to_hex().to_string())
}

/// The steward's answers to the caller's own requests.
#[view(accessor = my_replies, public)]
fn my_replies(ctx: &ViewContext) -> Vec<Reply> {
    let me = ctx.sender().to_hex().to_string();
    ctx.db.reply().keeper().filter(&me).collect()
}

/// The publisher of the module is the first steward.
#[reducer(init)]
pub fn init(ctx: &ReducerContext) {
    ctx.db.steward().insert(Steward { id: 0, identity: ctx.sender().to_hex().to_string() });
}

fn is_steward(ctx: &ReducerContext) -> bool {
    let me = ctx.sender().to_hex().to_string();
    ctx.db.steward().id().find(0).map(|s| s.identity == me).unwrap_or(false)
}

fn ask(ctx: &ReducerContext, kind: &str, nonce: String, payload: String) -> Result<(), String> {
    if nonce.is_empty() || nonce.len() > MAX_NONCE {
        return Err("A request needs a nonce of 1 to 64 characters.".into());
    }
    if payload.len() > MAX_PAYLOAD {
        return Err("The request is too long.".into());
    }
    let keeper = ctx.sender().to_hex().to_string();
    // A request sent again, after an answer that never came back, is the
    // same request: it waits, or has been answered, once.
    if ctx.db.request().nonce().filter(&nonce).any(|r| r.keeper == keeper)
        || ctx.db.reply().nonce().find(nonce.clone()).is_some_and(|r| r.keeper == keeper)
    {
        return Ok(());
    }
    let waiting = ctx.db.request().keeper().filter(&keeper).count();
    if waiting >= MAX_WAITING {
        return Err("Too many requests are waiting; give the steward a moment.".into());
    }
    ctx.db.request().insert(Request { id: 0, keeper, kind: kind.into(), nonce, payload });
    Ok(())
}

/// Arrive in the realm: a new keeper names themself; a returning one sends
/// an empty name.
#[reducer]
pub fn arrive(ctx: &ReducerContext, nonce: String, name: String) -> Result<(), String> {
    ask(ctx, "arrive", nonce, name)
}

/// An order for the keeper's House, as the rules core's JSON.
#[reducer]
pub fn order(ctx: &ReducerContext, nonce: String, command: String) -> Result<(), String> {
    ask(ctx, "order", nonce, command)
}

/// Ready for the watch to turn, or not.
#[reducer]
pub fn ready(ctx: &ReducerContext, nonce: String, ready: bool) -> Result<(), String> {
    ask(ctx, "ready", nonce, if ready { "true".into() } else { "false".into() })
}

/// Still here: a keeper's client says so now and then.
#[reducer]
pub fn here(ctx: &ReducerContext, nonce: String) -> Result<(), String> {
    ask(ctx, "here", nonce, String::new())
}

/// Leave the realm; the keeper's House stands as they left it.
#[reducer]
pub fn leave(ctx: &ReducerContext, nonce: String) -> Result<(), String> {
    ask(ctx, "leave", nonce, String::new())
}

/// The steward forgets answers that have been read.
#[reducer]
pub fn forget(ctx: &ReducerContext, nonces: Vec<String>) -> Result<(), String> {
    if !is_steward(ctx) {
        return Err("Only the steward forgets answers.".into());
    }
    for nonce in nonces {
        ctx.db.reply().nonce().delete(nonce);
    }
    Ok(())
}

/// The steward publishes the realm as it now stands, and answers the
/// requests it carried out, in one transaction: the world is never kept
/// without its answers, nor an answer given for a world not kept. It sends
/// the world's parts that changed and the names of those now gone, the
/// status, the views of the keepers whose views changed, each with the
/// events they heard, and its answers.
#[reducer]
#[allow(clippy::too_many_arguments)]
pub fn publish(
    ctx: &ReducerContext,
    version: u64,
    parts: Vec<String>,
    texts: Vec<String>,
    gone: Vec<String>,
    status: String,
    keepers: Vec<String>,
    views: Vec<String>,
    events: Vec<String>,
    requests: Vec<u64>,
    replies: Vec<String>,
    holder: String,
) -> Result<(), String> {
    if !is_steward(ctx) {
        return Err("Only the steward writes the world.".into());
    }
    let now = ctx.timestamp.to_micros_since_unix_epoch();
    if let Some(lease) = ctx.db.lease().id().find(0) {
        if lease.holder != holder && lease.until_micros > now {
            let seconds = (lease.until_micros - now) / 1_000_000 + 1;
            return Err(format!("Another steward holds the realm for {seconds} s more."));
        }
        ctx.db.lease().id().delete(0);
    }
    ctx.db.lease().insert(Lease { id: 0, holder, until_micros: now + LEASE_MICROS });
    if keepers.len() != views.len() || keepers.len() != events.len() {
        return Err("Every view needs its keeper and its events.".into());
    }
    if requests.len() != replies.len() {
        return Err("Every answer needs its request.".into());
    }
    if parts.len() != texts.len() {
        return Err("Every part of the world needs its name.".into());
    }
    let last = ctx.db.status().id().find(0).map(|s| s.version).unwrap_or(0);
    if version <= last {
        return Err(format!("Version {version} is not after {last}."));
    }
    for name in gone {
        ctx.db.world_part().name().delete(name);
    }
    for (name, text) in parts.into_iter().zip(texts) {
        ctx.db.world_part().name().delete(name.clone());
        ctx.db.world_part().insert(WorldPart { name, version, text });
    }
    // An error undoes the whole reducer, these parts with it.
    if ctx.db.world_part().count() == 0 {
        return Err("The first publication holds the world.".into());
    }
    ctx.db.status().id().delete(0);
    ctx.db.status().insert(Status { id: 0, version, status });
    ctx.db.stamp().id().delete(0);
    ctx.db.stamp().insert(Stamp { id: 0, version, at_micros: now });
    for ((keeper, view), events) in keepers.into_iter().zip(views).zip(events) {
        ctx.db.keeper_view().keeper().delete(keeper.clone());
        ctx.db.keeper_view().insert(KeeperView { keeper, version, view, events });
    }
    for (request, reply) in requests.into_iter().zip(replies) {
        let Some(asked) = ctx.db.request().id().find(request) else { continue };
        ctx.db.request().id().delete(request);
        ctx.db.reply().nonce().delete(asked.nonce.clone());
        ctx.db.reply().insert(Reply { nonce: asked.nonce, keeper: asked.keeper, payload: reply });
    }
    Ok(())
}

/// The steward hands the realm to another steward identity.
#[reducer]
pub fn hand_over(ctx: &ReducerContext, identity: String) -> Result<(), String> {
    if !is_steward(ctx) {
        return Err("Only the steward hands over the realm.".into());
    }
    ctx.db.steward().id().delete(0);
    ctx.db.steward().insert(Steward { id: 0, identity });
    Ok(())
}
