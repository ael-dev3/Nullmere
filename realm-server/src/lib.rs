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
//! carries them out, answers each by its nonce, and publishes the realm.

use spacetimedb::{reducer, table, ReducerContext, Table};

/// Longest request payload: an order, or a name.
const MAX_PAYLOAD: usize = 4096;
/// Longest nonce a client may choose.
const MAX_NONCE: usize = 64;
/// Most requests one keeper may have waiting.
const MAX_WAITING: usize = 32;

/// The one identity that may write the world: the steward's.
#[table(accessor = steward)]
pub struct Steward {
    #[primary_key]
    pub id: u8,
    pub identity: String,
}

/// A keeper's request, waiting for the steward.
#[table(accessor = request, public)]
pub struct Request {
    #[primary_key]
    #[auto_inc]
    pub id: u64,
    /// The keeper's identity, in hex.
    pub keeper: String,
    /// arrive, order, ready, here or leave.
    pub kind: String,
    pub nonce: String,
    pub payload: String,
}

/// The steward's answer to a request, found by its nonce.
#[table(accessor = reply, public)]
pub struct Reply {
    #[primary_key]
    pub nonce: String,
    pub keeper: String,
    pub payload: String,
}

/// The realm as it stands: its whole state, its status, and the events of
/// the last change, each as the rules core's JSON.
#[table(accessor = world, public)]
pub struct World {
    #[primary_key]
    pub id: u8,
    pub version: u64,
    pub state: String,
    pub status: String,
    pub events: String,
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
    let waiting = ctx.db.request().iter().filter(|r| r.keeper == keeper).count();
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

/// The steward answers a request.
#[reducer]
pub fn settle(ctx: &ReducerContext, request: u64, reply: String) -> Result<(), String> {
    if !is_steward(ctx) {
        return Err("Only the steward settles requests.".into());
    }
    let Some(asked) = ctx.db.request().id().find(request) else {
        return Ok(());
    };
    ctx.db.request().id().delete(request);
    ctx.db.reply().nonce().delete(asked.nonce.clone());
    ctx.db.reply().insert(Reply { nonce: asked.nonce, keeper: asked.keeper, payload: reply });
    Ok(())
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

/// The steward publishes the realm as it now stands.
#[reducer]
pub fn publish(ctx: &ReducerContext, version: u64, state: String, status: String, events: String) -> Result<(), String> {
    if !is_steward(ctx) {
        return Err("Only the steward writes the world.".into());
    }
    if let Some(current) = ctx.db.world().id().find(0) {
        if version <= current.version {
            return Err(format!("Version {version} is not after {}.", current.version));
        }
        ctx.db.world().id().delete(0);
    }
    ctx.db.world().insert(World { id: 0, version, state, status, events });
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
