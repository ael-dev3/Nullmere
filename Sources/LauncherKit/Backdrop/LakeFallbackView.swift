import LauncherCore
import SwiftUI

/// A still rendition of the lake drawn with SwiftUI, for when the Metal
/// scene cannot run.
struct LakeFallbackView: View {
    var horizon: Double
    /// 1 sinks the moon's image under a panel, as the Metal lake does.
    var veil: Double = 0

    private static let stars = StarCatalog.stars(count: 320, seed: 0x4E55_4C4C)

    private static let zenith = Color(red: 0.004, green: 0.006, blue: 0.012)
    private static let skyLow = Color(red: 0.060, green: 0.076, blue: 0.104)
    private static let waterHigh = Color(red: 0.050, green: 0.063, blue: 0.088)
    private static let waterLow = Color(red: 0.003, green: 0.004, blue: 0.008)
    private static let moonlight = Color(red: 0.58, green: 0.68, blue: 0.86)
    private static let moonFace = Color(red: 0.93, green: 0.95, blue: 0.98)
    private static let farShore = Color(red: 0.034, green: 0.043, blue: 0.061)
    private static let nearBank = Color(red: 0.009, green: 0.012, blue: 0.018)
    /// The shore as the water gives it back: a little darker, as deep
    /// water reflects a little less than all.
    private static let farShoreImage = Color(red: 0.027, green: 0.034, blue: 0.049)
    private static let nearBankImage = Color(red: 0.007, green: 0.010, blue: 0.014)

    /// Smooth value noise along a line, 0...1.
    private static func noise(_ x: Double) -> Double {
        func hash(_ i: Double) -> Double {
            let v = sin(i * 127.1 + 311.7) * 43_758.5453
            return v - v.rounded(.down)
        }
        let i = x.rounded(.down), f = x - i
        let u = f * f * (3 - 2 * f)
        return hash(i) + (hash(i + 1) - hash(i)) * u
    }

    private static func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = min(max((x - a) / (b - a), 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// A rise from 0 to 1 between `a - slope` and `a`, and down again
    /// between `b` and `b + slope`.
    private static func plateau(_ u: Double, from a: Double, to b: Double, slope: Double) -> Double {
        smoothstep(a - slope, a, u) * (1 - smoothstep(b, b + slope, u))
    }

    /// The far shore's height above the waterline, as a share of the view's
    /// height, at `u` across the view (0 at the left, 1 at the right), as
    /// the Metal lake composes it: low hills, a shelf, and the broad,
    /// flat-topped mesa beside the moon, no higher than `nm_mesas` draws.
    static func mesas(_ u: Double) -> Double {
        let hills = 0.010 + 0.006 * noise(u * 9 + 4)
        let shelf = 0.028 * plateau(u, from: 0.20, to: 0.47, slope: 0.05)
        let mesa = 0.046 * plateau(u, from: 0.45, to: 0.72, slope: 0.035)
        return max(hills, shelf, mesa) + 0.0012 * noise(u * 60)
    }

    /// The low, nearer bank's height, as `nm_bank` draws it.
    static func bank(_ u: Double) -> Double {
        0.0018 + 0.006 * smoothstep(0.35, 0.75, noise(u * 5 + 1))
    }

    var body: some View {
        Canvas(opaque: true) { context, size in
            let waterline = size.height * (1 - horizon)
            let skyRect = CGRect(x: 0, y: 0, width: size.width, height: waterline)
            let waterRect = CGRect(x: 0, y: waterline, width: size.width, height: size.height - waterline)

            context.fill(Path(skyRect), with: .linearGradient(
                Gradient(colors: [Self.zenith, Self.skyLow]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: waterline)
            ))
            context.fill(Path(waterRect), with: .linearGradient(
                Gradient(colors: [Self.waterHigh, Self.waterLow]),
                startPoint: CGPoint(x: 0, y: waterline),
                endPoint: CGPoint(x: 0, y: size.height)
            ))

            // Stars, and their reflections where they fall inside the view.
            for star in Self.stars {
                let rise = star.altitude * waterline
                let x = star.x * size.width
                let r = star.radius
                let sky = CGRect(x: x - r, y: waterline - rise - r, width: 2 * r, height: 2 * r)
                context.fill(Path(ellipseIn: sky), with: .color(.white.opacity(0.85 * star.brightness)))
                let mirrored = sky.offsetBy(dx: 0, dy: 2 * rise)
                if mirrored.minY < size.height {
                    // A black mirror gives the stars back nearly whole.
                    context.fill(Path(ellipseIn: mirrored), with: .color(.white.opacity(0.70 * star.brightness)))
                }
            }

            // The moon and its reflection.
            let radius = size.height * LakeComposition.moonRadius
            let moonRise = size.height * LakeComposition.moonY - size.height * horizon
            let moon = CGPoint(x: size.width * LakeComposition.moonX, y: waterline - moonRise)
            let reflection = CGPoint(x: moon.x, y: waterline + moonRise)
            for (center, strength) in [(moon, 1.0), (reflection, 0.85 * (1 - min(max(veil, 0), 1)))] where strength > 0 {
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - radius * 12, y: center.y - radius * 12, width: radius * 24, height: radius * 24)),
                    with: .radialGradient(
                        Gradient(colors: [Self.moonlight.opacity(0.22 * strength), .clear]),
                        center: center,
                        startRadius: radius,
                        endRadius: radius * 12
                    )
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(Self.moonFace.opacity(strength))
                )
            }

            // The far shore, flat-topped mesas and a darker bank before
            // them, standing in front of the moon's glow, and their image
            // in the water.
            // A ridge of heights along the waterline, standing up or mirrored down.
            func ridge(_ height: (Double) -> Double, mirrored: Bool) -> Path {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: waterline))
                for step in stride(from: 0.0, through: Double(size.width), by: 2) {
                    let rise = CGFloat(height(step / Double(size.width))) * size.height
                    path.addLine(to: CGPoint(x: step, y: mirrored ? waterline + rise : waterline - rise))
                }
                path.addLine(to: CGPoint(x: size.width, y: waterline))
                path.closeSubpath()
                return path
            }
            context.fill(ridge(Self.mesas, mirrored: false), with: .color(Self.farShore))
            context.fill(ridge(Self.mesas, mirrored: true), with: .color(Self.farShoreImage))
            context.fill(ridge(Self.bank, mirrored: false), with: .color(Self.nearBank))
            context.fill(ridge(Self.bank, mirrored: true), with: .color(Self.nearBankImage))
        }
        .accessibilityHidden(true)
    }
}
