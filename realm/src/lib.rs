//! Nullmere Online's realm.
//!
//! One persistent world on server time. Every rule of the game is written
//! here, once, over the tables in `rows`, and runs inside the SpacetimeDB
//! module (`module`): reducers check and apply what players ask, timers
//! finish what takes time, and clients read the tables themselves. There
//! is no other server process.
//!
//! The rules never touch the database directly. They are written over
//! `store::Db`, which the module gives them as SpacetimeDB and the unit
//! tests as `store::Mem`, a store kept in memory with a clock the test
//! moves: `cargo test` runs every rule natively, in milliseconds.

pub mod rows;
pub mod rules;
pub mod store;

mod module;
