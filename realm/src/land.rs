//! The land of the world, grown from the realm's seed: a still black lake
//! at its heart, shores and plains and woods about it, and a ring of
//! mountains closing it in.
//!
//! The land is kept in the database as chunks, sixteen hexes by sixteen,
//! one byte a hex, and every client draws it from those bytes. Nothing
//! here uses anything but whole numbers and the four plain operations on
//! fractions, so the same seed grows the same land wherever it is run.

use crate::hex::Hex;

/// What ground a hex is. The numbers are the ones the clients' renderer
/// already knows these grounds by (`Terrain` in Sources/NullmereCore, in
/// the order of its cases), so the land's bytes draw as they are.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(u8)]
pub enum Ground {
    /// The lake's deep water: nothing crosses it.
    Deep = 0,
    /// Water shallow enough to wade.
    Shallows = 1,
    /// Sand along the water.
    Strand = 2,
    /// Pale salt flats, where moonsalt is worked.
    Salt = 3,
    /// Open grass: the plain cities are raised on.
    Plain = 4,
    /// Woodland.
    Wood = 5,
    /// Dry heath over old graves.
    Heath = 6,
    /// Bare mountain: nothing crosses it.
    Mountain = 7,
}

impl Ground {
    pub fn of(code: u8) -> Ground {
        match code {
            0 => Ground::Deep,
            1 => Ground::Shallows,
            2 => Ground::Strand,
            3 => Ground::Salt,
            4 => Ground::Plain,
            5 => Ground::Wood,
            6 => Ground::Heath,
            _ => Ground::Mountain,
        }
    }

    /// Whether an army may march over it.
    pub fn is_open(self) -> bool {
        !matches!(self, Ground::Deep | Ground::Mountain)
    }

    /// Whether a city may be raised on it.
    pub fn is_buildable(self) -> bool {
        matches!(self, Ground::Plain | Ground::Heath | Ground::Strand)
    }
}

/// A chunk's side, in hexes.
pub const CHUNK: i32 = 16;

/// The chunk a hex lies in, as its table's key, and where in the chunk.
pub fn chunk_of(hex: Hex) -> (u64, usize) {
    let (cq, cr) = (hex.q.div_euclid(CHUNK), hex.r.div_euclid(CHUNK));
    let (iq, ir) = (hex.q.rem_euclid(CHUNK), hex.r.rem_euclid(CHUNK));
    (Hex::new(cq, cr).packed(), (ir * CHUNK + iq) as usize)
}

/// The hex at a place in a chunk.
pub fn hex_in(chunk: u64, index: usize) -> Hex {
    let corner = Hex::unpacked(chunk);
    Hex::new(corner.q * CHUNK + (index as i32 % CHUNK), corner.r * CHUNK + (index as i32 / CHUNK))
}

/// A number from 0 to 1 for a whole point of a grid, the same for the same
/// seed and point.
fn lattice(seed: u64, x: i64, y: i64) -> f64 {
    let mut z = seed ^ (x as u64).wrapping_mul(0x9E37_79B9_7F4A_7C15) ^ (y as u64).wrapping_mul(0xC2B2_AE3D_27D4_EB4F);
    z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
    z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
    z ^= z >> 31;
    (z >> 11) as f64 / (1u64 << 53) as f64
}

/// Smooth noise from 0 to 1 over the flat map, its features `scale` across.
fn noise(seed: u64, x: f64, y: f64, scale: f64) -> f64 {
    let (x, y) = (x / scale, y / scale);
    let (x0, y0) = (x.floor(), y.floor());
    let (fx, fy) = (x - x0, y - y0);
    let (sx, sy) = (fx * fx * (3.0 - 2.0 * fx), fy * fy * (3.0 - 2.0 * fy));
    let (ix, iy) = (x0 as i64, y0 as i64);
    let top = lattice(seed, ix, iy) * (1.0 - sx) + lattice(seed, ix + 1, iy) * sx;
    let bottom = lattice(seed, ix, iy + 1) * (1.0 - sx) + lattice(seed, ix + 1, iy + 1) * sx;
    top * (1.0 - sy) + bottom * sy
}

/// The ground at a hex of a world of a radius, grown from a seed.
pub fn ground(seed: u64, radius: u32, hex: Hex) -> Ground {
    let (x, y) = hex.centre();
    let far = hex.length() as f64 / radius.max(1) as f64;
    // The shore wanders: the lake and the mountains each keep a ragged edge.
    let wander = noise(seed, x, y, 9.0) * 0.6 + noise(seed ^ 0xA1, x, y, 3.5) * 0.4 - 0.5;
    let lake = 0.2 + wander * 0.07;
    let rim = 0.93 + wander * 0.05;
    if far > rim {
        return Ground::Mountain;
    }
    if far < lake - 0.035 {
        return Ground::Deep;
    }
    if far < lake {
        return Ground::Shallows;
    }
    if far < lake + 0.02 {
        return Ground::Strand;
    }
    // Inland: woods where it is wet, heath where it is dry, salt in rare
    // pale pans, ridges of mountain here and there, and plain between.
    let wet = noise(seed ^ 0xB2, x, y, 14.0) * 0.65 + noise(seed ^ 0xB3, x, y, 5.0) * 0.35;
    let dry = noise(seed ^ 0xC4, x, y, 17.0) * 0.7 + noise(seed ^ 0xC5, x, y, 6.0) * 0.3;
    let ridge = noise(seed ^ 0xD6, x, y, 22.0);
    let crest = (ridge - 0.5).abs();
    if crest < 0.018 && far > lake + 0.12 && noise(seed ^ 0xD7, x, y, 7.0) > 0.38 {
        return Ground::Mountain;
    }
    if dry > 0.74 && wet < 0.45 {
        return Ground::Salt;
    }
    if wet > 0.6 {
        return Ground::Wood;
    }
    if dry > 0.6 {
        return Ground::Heath;
    }
    Ground::Plain
}

/// Every chunk that holds a hex of a world of a radius, each with its
/// bytes; hexes of a chunk beyond the world are mountain.
pub fn chunks(seed: u64, radius: u32) -> Vec<(u64, Vec<u8>)> {
    let reach = radius as i32;
    let (low, high) = ((-reach).div_euclid(CHUNK), reach.div_euclid(CHUNK));
    let mut all = Vec::new();
    for cr in low..=high {
        for cq in low..=high {
            let key = Hex::new(cq, cr).packed();
            let mut any = false;
            let bytes: Vec<u8> = (0..(CHUNK * CHUNK) as usize)
                .map(|index| {
                    let hex = hex_in(key, index);
                    if hex.length() > radius {
                        Ground::Mountain as u8
                    } else {
                        any = true;
                        ground(seed, radius, hex) as u8
                    }
                })
                .collect();
            if any {
                all.push((key, bytes));
            }
        }
    }
    all
}

/// The most hexes a search for a way looks at before giving up.
const SEARCH_LIMIT: usize = 60_000;

/// The shortest way over open ground from one hex to another, both ends
/// among its hexes; none where there is no way, or either end is closed.
pub fn way(seed: u64, radius: u32, from: Hex, to: Hex) -> Option<Vec<Hex>> {
    use std::cmp::Reverse;
    use std::collections::{BinaryHeap, HashMap};
    let open = |hex: Hex| hex.length() <= radius && ground(seed, radius, hex).is_open();
    if !open(from) || !open(to) {
        return None;
    }
    if from == to {
        return Some(vec![from]);
    }
    // A* over the hexes, each step the same cost, the straight distance
    // left as its guide; ties broken by the hex's own number, so the same
    // two ends always give the same way.
    let mut came: HashMap<Hex, (Hex, u32)> = HashMap::new();
    let mut frontier = BinaryHeap::new();
    came.insert(from, (from, 0));
    frontier.push(Reverse((from.distance(to), 0u32, from.packed())));
    while let Some(Reverse((_, gone, packed))) = frontier.pop() {
        let at = Hex::unpacked(packed);
        if at == to {
            let mut way = vec![to];
            let mut back = to;
            while back != from {
                back = came[&back].0;
                way.push(back);
            }
            way.reverse();
            return Some(way);
        }
        if came[&at].1 < gone {
            continue;
        }
        if came.len() > SEARCH_LIMIT {
            return None;
        }
        for next in at.neighbours() {
            if !open(next) {
                continue;
            }
            let steps = gone + 1;
            if came.get(&next).is_none_or(|(_, known)| steps < *known) {
                came.insert(next, (at, steps));
                frontier.push(Reverse((steps + next.distance(to), steps, next.packed())));
            }
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_way_is_found_round_the_lake_and_never_through_it() {
        let (seed, radius) = (42, 64);
        let open: Vec<Hex> = Hex::new(0, 0).within(radius).into_iter().filter(|hex| ground(seed, radius, *hex).is_open()).collect();
        // Two shores of the lake, opposite each other.
        let west = *open.iter().filter(|hex| hex.r == 0 && hex.q < 0).max_by_key(|hex| hex.q).unwrap();
        let east = *open.iter().filter(|hex| hex.r == 0 && hex.q > 0).min_by_key(|hex| hex.q).unwrap();
        let found = way(seed, radius, west, east).expect("a way round the lake");
        assert_eq!((found[0], *found.last().unwrap()), (west, east));
        assert!(found.windows(2).all(|pair| pair[0].distance(pair[1]) == 1), "step by step");
        assert!(found.iter().all(|hex| ground(seed, radius, *hex).is_open()), "over open ground alone");
        assert!(found.len() as u32 - 1 >= west.distance(east), "no shorter than the straight line");
        assert_eq!(way(seed, radius, west, east), Some(found.clone()), "the same way every time");
        let back = way(seed, radius, east, west).unwrap();
        assert_eq!(back.len(), found.len(), "as long back as there");

        assert_eq!(way(seed, radius, west, west), Some(vec![west]));
        assert_eq!(way(seed, radius, west, Hex::new(0, 0)), None, "nothing walks into the deep");
        assert_eq!(way(seed, radius, Hex::new(0, 0), west), None);
        assert_eq!(way(seed, radius, west, Hex::new(radius as i32 + 5, 0)), None, "nor off the world");

        // Open land next to open land is one step.
        let near = west.neighbours().into_iter().find(|hex| ground(seed, radius, *hex).is_open()).unwrap();
        assert_eq!(way(seed, radius, west, near), Some(vec![west, near]));
    }

    #[test]
    fn every_hex_has_its_place_in_one_chunk() {
        for hex in [Hex::new(0, 0), Hex::new(15, 15), Hex::new(16, 0), Hex::new(-1, -1), Hex::new(-17, 40)] {
            let (chunk, index) = chunk_of(hex);
            assert!(index < 256);
            assert_eq!(hex_in(chunk, index), hex);
        }
        assert_eq!(chunk_of(Hex::new(-1, -1)).0, Hex::new(-1, -1).packed());
        assert_eq!(chunk_of(Hex::new(-1, -1)).1, 255);
    }

    #[test]
    fn the_same_seed_grows_the_same_land() {
        let (a, b) = (chunks(42, 64), chunks(42, 64));
        assert_eq!(a, b);
        assert_ne!(a, chunks(43, 64));
        assert!(a.iter().all(|(_, bytes)| bytes.len() == 256));
        // Every hex of the world is in exactly one chunk.
        let world = Hex::new(0, 0).within(64);
        let mut seen = 0;
        for hex in &world {
            let (chunk, index) = chunk_of(*hex);
            let bytes = &a.iter().find(|(key, _)| *key == chunk).expect("its chunk is kept").1;
            assert_eq!(Ground::of(bytes[index]), ground(42, 64, *hex));
            seen += 1;
        }
        assert_eq!(seen, 1 + 3 * 64 * 65);
    }

    #[test]
    fn a_lake_lies_at_the_heart_and_mountains_close_the_world() {
        for seed in [1u64, 42, 2026] {
            let radius = 96;
            assert_eq!(ground(seed, radius, Hex::new(0, 0)), Ground::Deep, "the lake's heart is deep water");
            let rim = Hex::new(0, 0).ring(radius);
            assert!(rim.iter().all(|hex| ground(seed, radius, *hex) == Ground::Mountain), "nothing walks off the world");
            let world = Hex::new(0, 0).within(radius);
            let count = |wanted: fn(Ground) -> bool| world.iter().filter(|hex| wanted(ground(seed, radius, **hex))).count() as f64 / world.len() as f64;
            let buildable = count(Ground::is_buildable);
            let water = count(|g| matches!(g, Ground::Deep | Ground::Shallows));
            let wood = count(|g| g == Ground::Wood);
            assert!(buildable > 0.35, "room for cities: {buildable}");
            assert!((0.02..0.08).contains(&water), "a lake, not a sea: {water}");
            assert!((0.1..0.4).contains(&wood), "woods, not one forest: {wood}");
            // A shore all round the lake: no deep water touches dry land.
            for hex in &world {
                if ground(seed, radius, *hex) == Ground::Deep {
                    for next in hex.neighbours() {
                        let beside = ground(seed, radius, next);
                        assert!(matches!(beside, Ground::Deep | Ground::Shallows), "{hex:?} is deep beside {beside:?}");
                    }
                }
            }
        }
    }
}
