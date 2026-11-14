//! Prints a realm's land as a picture (a plain PPM on standard output), to
//! judge by eye what a seed grows: `cargo run --example land -- 42 128 > land.ppm`.

use realm::hex::Hex;
use realm::land::{ground, Ground};

fn main() {
    let mut arguments = std::env::args().skip(1);
    let seed: u64 = arguments.next().and_then(|s| s.parse().ok()).unwrap_or(42);
    let radius: u32 = arguments.next().and_then(|s| s.parse().ok()).unwrap_or(128);
    let scale = 3.0;
    let side = ((2 * radius + 3) as f64 * 3f64.sqrt() * scale) as usize;
    let mut pixels = vec![[18u8, 20, 28]; side * side];
    for hex in Hex::new(0, 0).within(radius) {
        let (x, y) = hex.centre();
        let colour = match ground(seed, radius, hex) {
            Ground::Deep => [10, 14, 26],
            Ground::Shallows => [58, 86, 96],
            Ground::Strand => [204, 184, 130],
            Ground::Salt => [226, 222, 204],
            Ground::Plain => [112, 150, 70],
            Ground::Wood => [44, 88, 48],
            Ground::Heath => [160, 138, 84],
            Ground::Mountain => [112, 108, 110],
        };
        let (px, py) = ((x * scale) as i64 + side as i64 / 2, (y * scale) as i64 + side as i64 / 2);
        for dy in -2..=2i64 {
            for dx in -2..=2i64 {
                let (ax, ay) = (px + dx, py + dy);
                if ax >= 0 && ay >= 0 && (ax as usize) < side && (ay as usize) < side {
                    pixels[ay as usize * side + ax as usize] = colour;
                }
            }
        }
    }
    println!("P3\n{side} {side}\n255");
    for pixel in pixels {
        println!("{} {} {}", pixel[0], pixel[1], pixel[2]);
    }
}
