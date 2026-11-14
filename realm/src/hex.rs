//! The world's ground: hexes, each known by two whole numbers, east (`q`)
//! and south-east (`r`), with the lake's heart at 0, 0.

/// A hex of the world.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct Hex {
    pub q: i32,
    pub r: i32,
}

/// The six steps from a hex to its neighbours, east first, turning
/// counter-clockwise.
pub const STEPS: [Hex; 6] = [
    Hex { q: 1, r: 0 },
    Hex { q: 1, r: -1 },
    Hex { q: 0, r: -1 },
    Hex { q: -1, r: 0 },
    Hex { q: -1, r: 1 },
    Hex { q: 0, r: 1 },
];

impl Hex {
    pub const fn new(q: i32, r: i32) -> Hex {
        Hex { q, r }
    }

    /// The hex as one number, for a table's key: both parts fit in sixteen
    /// bits either side of zero.
    pub fn packed(self) -> u64 {
        (((self.q + 32768) as u64) << 16) | ((self.r + 32768) as u64)
    }

    pub fn unpacked(packed: u64) -> Hex {
        Hex { q: ((packed >> 16) & 0xFFFF) as i32 - 32768, r: (packed & 0xFFFF) as i32 - 32768 }
    }

    /// How many steps lie between two hexes.
    pub fn distance(self, other: Hex) -> u32 {
        let (dq, dr) = (self.q - other.q, self.r - other.r);
        ((dq.abs() + dr.abs() + (dq + dr).abs()) / 2) as u32
    }

    /// How far the hex lies from the lake's heart.
    pub fn length(self) -> u32 {
        self.distance(Hex::new(0, 0))
    }

    pub fn neighbours(self) -> [Hex; 6] {
        STEPS.map(|step| Hex::new(self.q + step.q, self.r + step.r))
    }

    /// The hexes exactly `radius` steps away, in a ring, starting to the
    /// south-west and turning counter-clockwise; the hex itself for none.
    pub fn ring(self, radius: u32) -> Vec<Hex> {
        if radius == 0 {
            return vec![self];
        }
        let radius = radius as i32;
        let mut at = Hex::new(self.q + STEPS[4].q * radius, self.r + STEPS[4].r * radius);
        let mut ring = Vec::with_capacity(6 * radius as usize);
        for side in 0..6 {
            for _ in 0..radius {
                ring.push(at);
                at = Hex::new(at.q + STEPS[side].q, at.r + STEPS[side].r);
            }
        }
        ring
    }

    /// Every hex within `radius` steps, nearest first.
    pub fn within(self, radius: u32) -> Vec<Hex> {
        (0..=radius).flat_map(|ring| self.ring(ring)).collect()
    }

    /// Where the hex's heart lies on the flat map, in units of a hex's
    /// width across its flats over the square root of three (the clients'
    /// own layout): x east, y south.
    pub fn centre(self) -> (f64, f64) {
        (3f64.sqrt() * (self.q as f64 + self.r as f64 / 2.0), 1.5 * self.r as f64)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hexes_pack_into_a_key_and_back() {
        for hex in [Hex::new(0, 0), Hex::new(-128, 128), Hex::new(300, -7), Hex::new(-32768, 32767)] {
            assert_eq!(Hex::unpacked(hex.packed()), hex);
        }
        assert_ne!(Hex::new(1, 0).packed(), Hex::new(0, 1).packed());
    }

    #[test]
    fn rings_and_distances_agree() {
        let heart = Hex::new(3, -2);
        assert_eq!(heart.ring(0), vec![heart]);
        for radius in 1..6u32 {
            let ring = heart.ring(radius);
            assert_eq!(ring.len() as u32, 6 * radius);
            assert!(ring.iter().all(|hex| hex.distance(heart) == radius));
            let mut unique = ring.clone();
            unique.sort();
            unique.dedup();
            assert_eq!(unique.len(), ring.len());
        }
        assert_eq!(heart.within(4).len(), 1 + 3 * 4 * 5);
        assert!(heart.neighbours().iter().all(|hex| hex.distance(heart) == 1));
        assert_eq!(Hex::new(4, -1).length(), 4);
        assert_eq!(Hex::new(-3, 5).length(), 5);
    }
}
