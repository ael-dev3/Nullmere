import Foundation

/// The world's pictures for the interface painted: a portrait or a vista
/// read back from the renderer is laid on as paint. Its colours go on in
/// strokes that keep to the forms, each spot taking the calmest of the
/// four patches about it, as a painter's knife lays it; dark ink is drawn
/// along its edges; and the weave of a canvas runs under it all, its
/// corners in shadow.
public enum Painting {
    /// How far a stroke reaches, in pixels, for a picture this wide: a
    /// pixel for a portrait, two for a vista, each still showing its
    /// windows and its carts.
    public static func stroke(forWidth width: Int) -> Int {
        width >= 256 ? 2 : 1
    }

    /// Paints pixels of four bytes each (blue, green, red, then alpha, its
    /// colour premultiplied by it), row by row from the top, in place.
    /// Pixels that are not a whole picture of that size are left as they
    /// are.
    public static func paint(bgra pixels: inout [UInt8], width: Int, height: Int) {
        guard width > 0, height > 0, pixels.count == width * height * 4 else { return }
        strokes(bgra: &pixels, width: width, height: height, reach: stroke(forWidth: width))
        ink(bgra: &pixels, width: width, height: height)
        canvas(bgra: &pixels, width: width, height: height)
    }

    // MARK: Strokes

    /// Each spot takes the mean colour of the calmest of the four patches
    /// that meet at it, each `reach` pixels on a side and more: a flat
    /// field stays as it was, an edge stays sharp, and fine noise is laid
    /// down in strokes.
    public static func strokes(bgra pixels: inout [UInt8], width: Int, height: Int, reach: Int) {
        guard width > 0, height > 0, pixels.count == width * height * 4, reach > 0 else { return }
        let stride = width + 1
        // Sums over every rectangle from the corner: of each colour, of
        // light and of light squared.
        var sums = [[Double]](repeating: [Double](repeating: 0, count: stride * (height + 1)), count: 5)
        for y in 0..<height {
            var row = [Double](repeating: 0, count: 5)
            for x in 0..<width {
                let at = (y * width + x) * 4
                let b = Double(pixels[at]), g = Double(pixels[at + 1]), r = Double(pixels[at + 2])
                let light = luminance(b, g, r)
                row[0] += b
                row[1] += g
                row[2] += r
                row[3] += light
                row[4] += light * light
                for channel in 0..<5 {
                    sums[channel][(y + 1) * stride + x + 1] = sums[channel][y * stride + x + 1] + row[channel]
                }
            }
        }
        func total(_ channel: Int, _ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int) -> Double {
            let table = sums[channel]
            return table[(y1 + 1) * stride + x1 + 1] - table[y0 * stride + x1 + 1] - table[(y1 + 1) * stride + x0] + table[y0 * stride + x0]
        }
        var painted = pixels
        for y in 0..<height {
            for x in 0..<width {
                let quarters = [(-1, -1), (1, -1), (-1, 1), (1, 1)].map { dx, dy in
                    let x0 = max(0, min(x, x + dx * reach)), x1 = min(width - 1, max(x, x + dx * reach))
                    let y0 = max(0, min(y, y + dy * reach)), y1 = min(height - 1, max(y, y + dy * reach))
                    let n = Double((x1 - x0 + 1) * (y1 - y0 + 1))
                    let mean = total(3, x0, y0, x1, y1) / n
                    return (variance: total(4, x0, y0, x1, y1) / n - mean * mean, x0: x0, y0: y0, x1: x1, y1: y1)
                }
                // The calmest; of two as calm, the first.
                let best = quarters.dropFirst().reduce(quarters[0]) { $1.variance < $0.variance - 1e-9 ? $1 : $0 }
                let n = Double((best.x1 - best.x0 + 1) * (best.y1 - best.y0 + 1))
                let at = (y * width + x) * 4
                for channel in 0..<3 {
                    let mean = total(channel, best.x0, best.y0, best.x1, best.y1) / n
                    painted[at + channel] = min(pixels[at + 3], UInt8(max(0, min(255, mean.rounded()))))
                }
            }
        }
        pixels = painted
    }

    // MARK: Ink

    /// Dark ink along the edges: where the light changes sharply, darker,
    /// as far as `depth` of the colour; flat fields untouched.
    public static func ink(bgra pixels: inout [UInt8], width: Int, height: Int, depth: Double = 0.3) {
        guard width > 2, height > 2, pixels.count == width * height * 4 else { return }
        var light = [Double](repeating: 0, count: width * height)
        for index in light.indices {
            let at = index * 4
            light[index] = luminance(Double(pixels[at]), Double(pixels[at + 1]), Double(pixels[at + 2]))
        }
        func l(_ x: Int, _ y: Int) -> Double { light[min(max(y, 0), height - 1) * width + min(max(x, 0), width - 1)] }
        for y in 0..<height {
            for x in 0..<width {
                let gx = (l(x + 1, y - 1) + 2 * l(x + 1, y) + l(x + 1, y + 1)) - (l(x - 1, y - 1) + 2 * l(x - 1, y) + l(x - 1, y + 1))
                let gy = (l(x - 1, y + 1) + 2 * l(x, y + 1) + l(x + 1, y + 1)) - (l(x - 1, y - 1) + 2 * l(x, y - 1) + l(x + 1, y - 1))
                let edge = min(1, max(0, ((gx * gx + gy * gy).squareRoot() - inkFrom) / inkSpan))
                guard edge > 0 else { continue }
                let at = (y * width + x) * 4
                for channel in 0..<3 {
                    pixels[at + channel] = UInt8((Double(pixels[at + channel]) * (1 - depth * edge)).rounded())
                }
            }
        }
    }

    /// How sharp a change of light begins to take ink, and over how much
    /// more it takes it fully, in the steps of a byte across three pixels.
    static let inkFrom = 60.0, inkSpan = 160.0

    // MARK: Canvas

    /// The canvas under the paint: a fine weave in the light, and the
    /// corners in shadow, each colour changed by no more than a sixth.
    public static func canvas(bgra pixels: inout [UInt8], width: Int, height: Int) {
        guard width > 0, height > 0, pixels.count == width * height * 4 else { return }
        for y in 0..<height {
            for x in 0..<width {
                let at = (y * width + x) * 4
                let u = width > 1 ? Double(x) / Double(width - 1) * 2 - 1 : 0
                let v = height > 1 ? Double(y) / Double(height - 1) * 2 - 1 : 0
                let weave = 0.025 * sin(Double(x) * 1.9) * sin(Double(y) * 1.9) + 0.02 * (grain(x, y) - 0.5)
                let shade = 1 - 0.06 * (u * u + v * v)
                let factor = (1 + weave) * shade
                for channel in 0..<3 {
                    let value = (Double(pixels[at + channel]) * factor).rounded()
                    pixels[at + channel] = min(pixels[at + 3], UInt8(max(0, min(255, value))))
                }
            }
        }
    }

    /// The canvas's grain at a pixel, from 0 to 1, the same for the same pixel.
    static func grain(_ x: Int, _ y: Int) -> Double {
        var h = UInt32(truncatingIfNeeded: x &* 374_761_393 &+ y &* 668_265_263)
        h = (h ^ (h >> 13)) &* 1_274_126_177
        return Double((h ^ (h >> 16)) & 0xFFFF) / 65_535
    }

    /// The light of a colour, as the eye weighs blue, green and red.
    static func luminance(_ b: Double, _ g: Double, _ r: Double) -> Double {
        0.114 * b + 0.587 * g + 0.299 * r
    }
}
