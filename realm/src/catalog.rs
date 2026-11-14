//! What can be built, what it costs, how long it takes and what it gives.
//!
//! These are the game's numbers, written once. The module copies them into
//! the `blueprint` table as the realm opens, so a client shows a cost or a
//! time by reading a row, never by carrying a second copy of the rules.

use std::fmt;

/// The four goods a city keeps.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Goods {
    pub grain: u64,
    pub timber: u64,
    pub stone: u64,
    pub moonsalt: u64,
}

impl Goods {
    pub const NONE: Goods = Goods { grain: 0, timber: 0, stone: 0, moonsalt: 0 };

    pub const fn of(grain: u64, timber: u64, stone: u64, moonsalt: u64) -> Goods {
        Goods { grain, timber, stone, moonsalt }
    }

    pub fn parts(self) -> [u64; 4] {
        [self.grain, self.timber, self.stone, self.moonsalt]
    }

    pub fn from_parts(parts: [u64; 4]) -> Goods {
        Goods::of(parts[0], parts[1], parts[2], parts[3])
    }

    pub fn is_none(self) -> bool {
        self == Goods::NONE
    }

    /// Whether these goods are enough to pay a cost.
    pub fn covers(self, cost: Goods) -> bool {
        self.short_of(cost).is_none()
    }

    /// What is missing to pay a cost.
    pub fn short_of(self, cost: Goods) -> Goods {
        let (have, want) = (self.parts(), cost.parts());
        Goods::from_parts([0, 1, 2, 3].map(|i| want[i].saturating_sub(have[i])))
    }

    pub fn minus(self, cost: Goods) -> Goods {
        let (have, want) = (self.parts(), cost.parts());
        Goods::from_parts([0, 1, 2, 3].map(|i| have[i].saturating_sub(want[i])))
    }

    pub fn plus(self, more: Goods) -> Goods {
        let (have, add) = (self.parts(), more.parts());
        Goods::from_parts([0, 1, 2, 3].map(|i| have[i].saturating_add(add[i])))
    }

    pub fn times(self, by: u64) -> Goods {
        Goods::from_parts(self.parts().map(|part| part.saturating_mul(by)))
    }
}

/// "320 timber and 100 stone".
impl fmt::Display for Goods {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let named: Vec<String> = self
            .parts()
            .iter()
            .zip(["grain", "timber", "stone", "moonsalt"])
            .filter(|(amount, _)| **amount > 0)
            .map(|(amount, name)| format!("{} {name}", grouped(*amount)))
            .collect();
        match named.len() {
            0 => f.write_str("nothing"),
            1 => f.write_str(&named[0]),
            count => write!(f, "{} and {}", named[..count - 1].join(", "), named[count - 1]),
        }
    }
}

/// A number with its thousands set apart: 12,500.
pub fn grouped(number: u64) -> String {
    let digits = number.to_string();
    let mut out = String::new();
    for (index, digit) in digits.chars().enumerate() {
        if index > 0 && (digits.len() - index) % 3 == 0 {
            out.push(',');
        }
        out.push(digit);
    }
    out
}

/// A length of time as a player reads it: "45 seconds", "3 hours 20 minutes".
pub fn spoken(seconds: i64) -> String {
    let seconds = seconds.max(0);
    let unit = |count: i64, name: &str| format!("{count} {name}{}", if count == 1 { "" } else { "s" });
    let (days, hours, minutes, rest) = (seconds / 86_400, seconds % 86_400 / 3_600, seconds % 3_600 / 60, seconds % 60);
    if days > 0 {
        return if hours > 0 { format!("{} {}", unit(days, "day"), unit(hours, "hour")) } else { unit(days, "day") };
    }
    if hours > 0 {
        return if minutes > 0 { format!("{} {}", unit(hours, "hour"), unit(minutes, "minute")) } else { unit(hours, "hour") };
    }
    if minutes > 0 {
        return if rest > 0 { format!("{} {}", unit(minutes, "minute"), unit(rest, "second")) } else { unit(minutes, "minute") };
    }
    unit(rest, "second")
}

/// What stands in a city. One of each.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
#[repr(u8)]
pub enum Building {
    /// The city's heart: nothing rises higher than it.
    Keep = 1,
    Farm = 2,
    Sawmill = 3,
    Quarry = 4,
    Saltworks = 5,
    /// How much of each good the city can keep.
    Storehouse = 6,
    Barracks = 7,
    Range = 8,
    Stable = 9,
    Workshop = 10,
    Hospital = 11,
    Wall = 12,
    Watchtower = 13,
    Academy = 14,
    Embassy = 15,
    Tavern = 16,
    Market = 17,
    ScoutCamp = 18,
}

/// The highest level anything reaches.
pub const TOP_LEVEL: u32 = 25;

impl Building {
    pub const ALL: [Building; 18] = [
        Building::Keep,
        Building::Farm,
        Building::Sawmill,
        Building::Quarry,
        Building::Saltworks,
        Building::Storehouse,
        Building::Barracks,
        Building::Range,
        Building::Stable,
        Building::Workshop,
        Building::Hospital,
        Building::Wall,
        Building::Watchtower,
        Building::Academy,
        Building::Embassy,
        Building::Tavern,
        Building::Market,
        Building::ScoutCamp,
    ];

    pub fn of(code: u8) -> Option<Building> {
        Building::ALL.into_iter().find(|building| *building as u8 == code)
    }

    pub fn name(self) -> &'static str {
        match self {
            Building::Keep => "Keep",
            Building::Farm => "Farm",
            Building::Sawmill => "Sawmill",
            Building::Quarry => "Quarry",
            Building::Saltworks => "Saltworks",
            Building::Storehouse => "Storehouse",
            Building::Barracks => "Barracks",
            Building::Range => "Archery Range",
            Building::Stable => "Stable",
            Building::Workshop => "Siege Workshop",
            Building::Hospital => "Hospital",
            Building::Wall => "Wall",
            Building::Watchtower => "Watchtower",
            Building::Academy => "Academy",
            Building::Embassy => "Embassy",
            Building::Tavern => "Tavern",
            Building::Market => "Market",
            Building::ScoutCamp => "Scout Camp",
        }
    }

    /// The Keep level at which it may first be built.
    pub fn opens_at(self) -> u32 {
        match self {
            Building::Keep | Building::Farm | Building::Sawmill => 1,
            Building::Quarry | Building::Storehouse | Building::Barracks => 2,
            Building::Wall | Building::Hospital | Building::ScoutCamp => 3,
            Building::Range | Building::Tavern => 4,
            Building::Academy | Building::Embassy => 5,
            Building::Stable => 6,
            Building::Saltworks => 7,
            Building::Market | Building::Watchtower => 8,
            Building::Workshop => 10,
        }
    }

    /// What it costs to raise from nothing to its first level: grain,
    /// timber, stone. Each level after costs more by `GROWTH`.
    fn first_cost(self) -> [u64; 3] {
        match self {
            Building::Keep => [0, 400, 200],
            Building::Farm => [0, 80, 20],
            Building::Sawmill => [60, 20, 30],
            Building::Quarry => [80, 80, 0],
            Building::Saltworks => [300, 300, 300],
            Building::Storehouse => [0, 150, 100],
            Building::Barracks => [150, 200, 50],
            Building::Range => [150, 250, 50],
            Building::Stable => [300, 300, 100],
            Building::Workshop => [400, 600, 400],
            Building::Hospital => [200, 150, 100],
            Building::Wall => [0, 100, 300],
            Building::Watchtower => [0, 200, 300],
            Building::Academy => [200, 300, 300],
            Building::Embassy => [300, 300, 200],
            Building::Tavern => [300, 300, 0],
            Building::Market => [300, 400, 100],
            Building::ScoutCamp => [100, 150, 0],
        }
    }

    /// How long it takes to raise, in thousandths of the Keep's time to
    /// the same level.
    fn share_of_keep(self) -> i64 {
        match self {
            Building::Keep => 1000,
            Building::Farm | Building::Sawmill | Building::Quarry | Building::Saltworks => 300,
            Building::Storehouse => 350,
            Building::Barracks | Building::Range | Building::Stable | Building::Workshop => 500,
            Building::Hospital | Building::Watchtower | Building::Embassy => 400,
            Building::Wall | Building::Academy => 600,
            Building::Tavern | Building::Market => 300,
            Building::ScoutCamp => 250,
        }
    }

    /// How much its level counts toward its city's power.
    fn weight(self) -> u64 {
        match self {
            Building::Keep => 100,
            Building::Wall | Building::Academy => 40,
            Building::Barracks | Building::Range | Building::Stable | Building::Workshop => 30,
            _ => 20,
        }
    }
}

/// How much more each level costs than the last, in hundredths: 1.55 times.
const GROWTH: u64 = 155;

/// The seconds the Keep takes to reach each level from 2 to 25, as
/// written, before the realm's pace: eight seconds to two months.
const KEEP_SECONDS: [i64; 24] = [
    8, 45, 180, 600, 1_500, 3_600, 7_200, 14_400, 28_800, 43_200, 64_800, 86_400, 129_600, 172_800, 259_200, 345_600, 518_400, 691_200, 950_400,
    1_296_000, 1_728_000, 2_419_200, 3_456_000, 5_184_000,
];

/// A number kept to its two leading digits: 1,234 is 1,200.
fn rounded(number: u64) -> u64 {
    let mut unit = 1;
    while number / unit >= 100 {
        unit *= 10;
    }
    number / unit * unit
}

/// What it costs to raise a building to a level from the level below.
pub fn cost(building: Building, level: u32) -> Goods {
    let level = level.clamp(1, TOP_LEVEL);
    let mut parts = building.first_cost();
    for _ in 1..level {
        parts = parts.map(|part| part * GROWTH / 100);
    }
    // From the eleventh level the great works take moonsalt too.
    let moonsalt = if level > 10 { (level as u64 - 10) * (level as u64 - 10) * building.weight() } else { 0 };
    Goods::of(rounded(parts[0]), rounded(parts[1]), rounded(parts[2]), moonsalt)
}

/// How long raising a building to a level takes, in seconds as written.
pub fn seconds(building: Building, level: u32) -> i64 {
    let level = level.clamp(1, TOP_LEVEL);
    // Nothing takes less than three seconds, a first raising among them.
    if level == 1 {
        return 3;
    }
    (KEEP_SECONDS[level as usize - 2] * building.share_of_keep() / 1000).max(3)
}

/// How long something written to take `seconds` takes in a realm of a pace.
pub fn paced(seconds: i64, pace: u32) -> i64 {
    (seconds / pace.max(1) as i64).max(1)
}

/// What a building gives its city each hour at a level, as written.
pub fn yields(building: Building, level: u32) -> Goods {
    let level = level.min(TOP_LEVEL) as u64;
    let grown = |first: u64| first * level * (level + 4) / 5;
    match building {
        // A city's own folk bring in a little whatever stands in it.
        Building::Keep if level > 0 => Goods::of(400, 400, 300, 0),
        Building::Farm => Goods::of(grown(900), 0, 0, 0),
        Building::Sawmill => Goods::of(0, grown(900), 0, 0),
        Building::Quarry => Goods::of(0, 0, grown(600), 0),
        Building::Saltworks => Goods::of(0, 0, 0, grown(150)),
        _ => Goods::NONE,
    }
}

/// How much of each good a city can keep, by its Storehouse's level; none
/// built is level 0.
pub fn holds(storehouse: u32) -> u64 {
    let level = storehouse.min(TOP_LEVEL) as u64;
    30_000 + 40_000 * level * level
}

/// What a building at a level adds to its city's power.
pub fn power(building: Building, level: u32) -> u64 {
    building.weight() * level as u64 * level as u64
}

/// The other building, and its level, that must stand before a building
/// can be raised to a level: the Keep waits on the Wall.
pub fn needs(building: Building, level: u32) -> Option<(Building, u32)> {
    match building {
        Building::Keep if level >= 4 => Some((Building::Wall, level - 1)),
        _ => None,
    }
}

/// What a new city starts with.
pub const STARTING_GOODS: Goods = Goods::of(6_000, 8_000, 6_000, 0);

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn goods_are_counted_paid_and_said() {
        let have = Goods::of(100, 500, 0, 3);
        let cost = Goods::of(80, 820, 100, 0);
        assert!(!have.covers(cost));
        assert_eq!(have.short_of(cost), Goods::of(0, 320, 100, 0));
        assert_eq!(have.short_of(cost).to_string(), "320 timber and 100 stone");
        assert!(have.plus(Goods::of(0, 320, 100, 0)).covers(cost));
        assert_eq!(have.plus(Goods::of(0, 320, 100, 0)).minus(cost), Goods::of(20, 0, 0, 3));
        assert_eq!(Goods::of(1_250_000, 9, 12_000, 1).to_string(), "1,250,000 grain, 9 timber, 12,000 stone and 1 moonsalt");
        assert_eq!(Goods::NONE.to_string(), "nothing");
        assert_eq!(Goods::of(0, 0, 7, 0).to_string(), "7 stone");
        assert_eq!(Goods::of(1, 2, 3, 4).times(3), Goods::of(3, 6, 9, 12));
        assert_eq!(grouped(0), "0");
        assert_eq!(grouped(999), "999");
        assert_eq!(grouped(1_000), "1,000");
    }

    #[test]
    fn time_is_said_plainly() {
        assert_eq!(spoken(0), "0 seconds");
        assert_eq!(spoken(1), "1 second");
        assert_eq!(spoken(45), "45 seconds");
        assert_eq!(spoken(60), "1 minute");
        assert_eq!(spoken(185), "3 minutes 5 seconds");
        assert_eq!(spoken(7_200), "2 hours");
        assert_eq!(spoken(12_000), "3 hours 20 minutes");
        assert_eq!(spoken(86_400), "1 day");
        assert_eq!(spoken(5_184_000), "60 days");
        assert_eq!(spoken(93_600), "1 day 2 hours");
    }

    #[test]
    fn every_building_grows_dearer_and_slower_level_by_level() {
        assert_eq!(Building::ALL.len(), 18);
        for (index, building) in Building::ALL.into_iter().enumerate() {
            assert_eq!(building as u8 as usize, index + 1);
            assert_eq!(Building::of(building as u8), Some(building));
            assert!(!building.name().is_empty());
            assert!((1..=10).contains(&building.opens_at()));
            for level in 2..=TOP_LEVEL {
                let (before, now) = (cost(building, level - 1), cost(building, level));
                assert!(now.parts().iter().zip(before.parts()).all(|(now, before)| *now >= before), "{building:?} {level}");
                assert!(now.grain + now.timber + now.stone > before.grain + before.timber + before.stone, "{building:?} {level}");
                assert!(seconds(building, level) >= seconds(building, level - 1), "{building:?} {level}");
                assert!(power(building, level) > power(building, level - 1));
            }
            assert_eq!(cost(building, 5).moonsalt, 0, "no moonsalt before the eleventh level");
            assert!(cost(building, 11).moonsalt > 0);
        }
        assert_eq!(Building::of(0), None);
        assert_eq!(Building::of(19), None);
        assert_eq!(cost(Building::Keep, 2), Goods::of(0, 620, 310, 0));
        assert_eq!(seconds(Building::Keep, 2), 8);
        assert_eq!(seconds(Building::Keep, 25), 5_184_000, "two months, as written");
        assert_eq!(seconds(Building::Farm, 1), 3);
        assert_eq!(seconds(Building::Farm, 2), 3);
        assert_eq!(seconds(Building::Farm, 10), 28_800 * 3 / 10);
        assert_eq!(paced(3_600, 60), 60);
        assert_eq!(paced(5, 100), 1, "never less than a second");
        assert_eq!(paced(5, 0), 5);
    }

    #[test]
    fn works_yield_more_as_they_rise_and_the_storehouse_holds_more() {
        assert_eq!(yields(Building::Farm, 1), Goods::of(900, 0, 0, 0));
        assert_eq!(yields(Building::Farm, 0), Goods::NONE);
        assert_eq!(yields(Building::Keep, 3), Goods::of(400, 400, 300, 0));
        assert_eq!(yields(Building::Wall, 9), Goods::NONE);
        for building in [Building::Farm, Building::Sawmill, Building::Quarry, Building::Saltworks] {
            for level in 1..=TOP_LEVEL {
                let (before, now) = (yields(building, level - 1), yields(building, level));
                assert!(now.parts().iter().sum::<u64>() > before.parts().iter().sum::<u64>(), "{building:?} {level}");
            }
        }
        assert_eq!(holds(0), 30_000);
        assert!(holds(1) > holds(0));
        assert_eq!(holds(25), holds(40), "no higher than the top");
        assert_eq!(needs(Building::Keep, 3), None);
        assert_eq!(needs(Building::Keep, 4), Some((Building::Wall, 3)));
        assert_eq!(needs(Building::Farm, 9), None);
        assert!(STARTING_GOODS.covers(cost(Building::Keep, 2)), "a new city can raise its Keep at once");
    }
}
