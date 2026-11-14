//! Where the realm is kept, as the rules see it.
//!
//! The rules are written once, over `Db`: a set of tables of plain rows, a
//! clock, a source of chance and timers that fire later. In the module that
//! is SpacetimeDB itself (`crate::module`); in the unit tests it is `Mem`, a
//! store kept in memory with a clock the test moves. So every rule is
//! tested natively, in milliseconds, and runs unchanged inside the database.

use std::any::{Any, TypeId};
use std::collections::BTreeMap;

/// A moment or a span on the realm's clock, in whole seconds. Moments are
/// counted from the Unix epoch.
pub type Seconds = i64;

/// A row of one of the realm's tables.
///
/// Every table is keyed by one `u64`. Where a row is naturally found by two
/// or three small numbers (a hex, a troop kind in a city) its key packs
/// them. A table whose rows are numbered as they are added (`AUTO`) takes
/// the next number when a row is inserted with key 0.
pub trait Row: Clone + std::fmt::Debug + 'static {
    /// The table's name, as the database has it.
    const NAME: &'static str;
    /// Whether rows are numbered as they are added.
    const AUTO: bool;
    fn key(&self) -> u64;
    fn set_key(&mut self, key: u64);
    /// The row's value in one of the table's other indexes, numbered from
    /// zero as `rows!` lists them.
    fn index(&self, _index: usize) -> u64 {
        0
    }
}

/// One table of the realm.
pub trait Table<R: Row> {
    fn get(&self, key: u64) -> Option<R>;
    /// Every row with `value` in the table's index numbered `index`.
    fn by(&self, index: usize, value: u64) -> Vec<R>;
    /// Every row. For small tables and for tests: a rule never walks a
    /// table that grows with the realm.
    fn all(&self) -> Vec<R>;
    /// Adds a row and gives it back as kept, numbered if its table numbers
    /// its rows. A row whose key is taken is an error in the rules.
    fn insert(&mut self, row: R) -> R;
    /// Replaces the row with this row's key.
    fn update(&mut self, row: R);
    fn delete(&mut self, key: u64);
}

/// Something that happens later: what, to which row, and when.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Timer {
    pub at: Seconds,
    pub kind: u8,
    pub subject: u64,
}

/// The realm's clock, its chance, and its timers.
pub trait World {
    /// The moment the reducer running now began.
    fn now(&self) -> Seconds;
    /// A number by chance, different each time it is asked.
    fn chance(&mut self) -> u64;
    /// Has `kind` happen to `subject` at `at`, and gives the timer's number.
    fn after(&mut self, at: Seconds, kind: u8, subject: u64) -> u64;
    /// Calls off a timer by its number, if it has not fired.
    fn cancel(&mut self, timer: u64);
}

/// A store kept in memory: every table a map by key, the clock a number the
/// test sets, the timers a list the test fires as it moves the clock.
#[derive(Default)]
pub struct Mem {
    tables: BTreeMap<TypeId, Box<dyn AnyTable>>,
    pub clock: Seconds,
    seed: u64,
    next_timer: u64,
    pub timers: BTreeMap<u64, Timer>,
}

trait AnyTable: Any {
    fn boxed(&self) -> Box<dyn AnyTable>;
    fn as_any(&self) -> &dyn Any;
    fn as_any_mut(&mut self) -> &mut dyn Any;
}

struct MemTable<R: Row> {
    rows: BTreeMap<u64, R>,
    next: u64,
}

impl<R: Row> AnyTable for MemTable<R> {
    fn boxed(&self) -> Box<dyn AnyTable> {
        Box::new(MemTable { rows: self.rows.clone(), next: self.next })
    }
    fn as_any(&self) -> &dyn Any {
        self
    }
    fn as_any_mut(&mut self) -> &mut dyn Any {
        self
    }
}

impl Clone for Mem {
    fn clone(&self) -> Self {
        Mem {
            tables: self.tables.iter().map(|(id, table)| (*id, table.boxed())).collect(),
            clock: self.clock,
            seed: self.seed,
            next_timer: self.next_timer,
            timers: self.timers.clone(),
        }
    }
}

impl Mem {
    /// An empty realm at a moment, its chance from a seed: the same seed
    /// gives the same chances.
    pub fn new(clock: Seconds, seed: u64) -> Mem {
        Mem { clock, seed, ..Mem::default() }
    }

    fn table<R: Row>(&self) -> Option<&MemTable<R>> {
        self.tables.get(&TypeId::of::<R>()).and_then(|table| table.as_any().downcast_ref())
    }

    fn table_mut<R: Row>(&mut self) -> &mut MemTable<R> {
        self.tables
            .entry(TypeId::of::<R>())
            .or_insert_with(|| Box::new(MemTable::<R> { rows: BTreeMap::new(), next: 1 }))
            .as_any_mut()
            .downcast_mut()
            .expect("a table holds its own rows")
    }

    /// Runs a reducer as the database does: what it changed is kept if it
    /// succeeds and undone if it fails.
    pub fn call<T, E>(&mut self, reducer: impl FnOnce(&mut Mem) -> Result<T, E>) -> Result<T, E> {
        let before = self.clone();
        let result = reducer(self);
        if result.is_err() {
            *self = before;
        }
        result
    }

    /// The timers due by now, earliest first, taken off the list: the test
    /// hands each to the rules, as the database's scheduler would.
    pub fn due(&mut self) -> Vec<Timer> {
        let mut due: Vec<(u64, Timer)> = self.timers.iter().filter(|(_, t)| t.at <= self.clock).map(|(id, t)| (*id, t.clone())).collect();
        due.sort_by_key(|(id, timer)| (timer.at, *id));
        for (id, _) in &due {
            self.timers.remove(id);
        }
        due.into_iter().map(|(_, timer)| timer).collect()
    }

    /// The moment of the next timer to fire, if any waits.
    pub fn next_due(&self) -> Option<Seconds> {
        self.timers.values().map(|timer| timer.at).min()
    }

    /// Moves the clock on to a moment, firing every timer that comes due
    /// on the way, each at its own moment and in its own transaction, as
    /// the database's scheduler does; `fire` is the rules' own.
    pub fn advance(&mut self, to: Seconds, mut fire: impl FnMut(&mut Mem, &Timer)) {
        while let Some(at) = self.next_due().filter(|at| *at <= to) {
            self.clock = self.clock.max(at);
            for timer in self.due() {
                let _: Result<(), ()> = self.call(|db| {
                    fire(db, &timer);
                    Ok(())
                });
            }
        }
        self.clock = self.clock.max(to);
    }
}

impl<R: Row> Table<R> for Mem {
    fn get(&self, key: u64) -> Option<R> {
        self.table::<R>().and_then(|table| table.rows.get(&key).cloned())
    }

    fn by(&self, index: usize, value: u64) -> Vec<R> {
        self.table::<R>().map(|table| table.rows.values().filter(|row| row.index(index) == value).cloned().collect()).unwrap_or_default()
    }

    fn all(&self) -> Vec<R> {
        self.table::<R>().map(|table| table.rows.values().cloned().collect()).unwrap_or_default()
    }

    fn insert(&mut self, mut row: R) -> R {
        let table = self.table_mut::<R>();
        if R::AUTO && row.key() == 0 {
            row.set_key(table.next);
        }
        table.next = table.next.max(row.key() + 1);
        assert!(!table.rows.contains_key(&row.key()), "{} already holds a row keyed {}", R::NAME, row.key());
        table.rows.insert(row.key(), row.clone());
        row
    }

    fn update(&mut self, row: R) {
        let table = self.table_mut::<R>();
        assert!(table.rows.contains_key(&row.key()), "{} holds no row keyed {} to update", R::NAME, row.key());
        table.rows.insert(row.key(), row);
    }

    fn delete(&mut self, key: u64) {
        self.table_mut::<R>().rows.remove(&key);
    }
}

impl World for Mem {
    fn now(&self) -> Seconds {
        self.clock
    }

    fn chance(&mut self) -> u64 {
        // SplitMix64: small, fast, and even enough for a game's dice.
        self.seed = self.seed.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.seed;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }

    fn after(&mut self, at: Seconds, kind: u8, subject: u64) -> u64 {
        self.next_timer += 1;
        self.timers.insert(self.next_timer, Timer { at, kind, subject });
        self.next_timer
    }

    fn cancel(&mut self, timer: u64) {
        self.timers.remove(&timer);
    }
}

/// Makes a struct a row of the realm: its table's name, whether its rows
/// are numbered as they are added, its key, and its other indexes in the
/// order `Table::by` numbers them. Keys and indexes are all `u64`.
///
/// ```ignore
/// #[spacetimedb::table(accessor = city, public)]
/// #[derive(Clone, Debug, PartialEq)]
/// pub struct City {
///     #[primary_key]
///     #[auto_inc]
///     pub id: u64,
///     #[index(btree)]
///     pub owner: u64,
///     pub name: String,
/// }
/// row!(City in city, auto, by id, owner);
/// ```
#[macro_export]
macro_rules! row {
    ($name:ident in $table:ident, auto, by $key:ident $(, $index:ident)*) => {
        $crate::row!(@impl $name $table true $key $($index)*);
    };
    ($name:ident in $table:ident, by $key:ident $(, $index:ident)*) => {
        $crate::row!(@impl $name $table false $key $($index)*);
    };
    (@impl $name:ident $table:ident $auto:literal $key:ident $($index:ident)*) => {
        impl $crate::store::Row for $name {
            const NAME: &'static str = stringify!($table);
            const AUTO: bool = $auto;
            fn key(&self) -> u64 {
                self.$key
            }
            fn set_key(&mut self, key: u64) {
                self.$key = key;
            }
            #[allow(unused_variables, unused_mut, unused_assignments)]
            fn index(&self, index: usize) -> u64 {
                let mut at = 0;
                $(
                    if index == at {
                        return self.$index;
                    }
                    at += 1;
                )*
                0
            }
        }
    };
}
