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
    private static let mist = Color(red: 0.55, green: 0.63, blue: 0.76)

    /// The far shore's height above the waterline, as a share of the view's
    /// height, at `u` across a view of this aspect (0 at the left, 1 at the
    /// right): the Metal lake's own mesas, worked out here.
    static func mesas(_ u: Double, aspect: Double) -> Double {
        LakeShore.mesas(u * aspect)
    }

    /// The low, nearer bank's height, as the Metal lake draws it.
    static func bank(_ u: Double, aspect: Double) -> Double {
        LakeShore.bank(u * aspect)
    }

    /// A star's colour, as the shader tints them: cold, or now and then warm.
    private static func tint(_ star: Star) -> Color {
        let warmth = (star.x * 9301 + star.altitude * 49297).truncatingRemainder(dividingBy: 1)
        let w = warmth * warmth
        return Color(red: 0.76 + 0.24 * w, green: 0.85 + 0.07 * w, blue: 1.0 - 0.18 * w)
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
                let colour = Self.tint(star)
                context.fill(Path(ellipseIn: sky), with: .color(colour.opacity(0.85 * star.brightness)))
                let mirrored = sky.offsetBy(dx: 0, dy: 2 * rise)
                if mirrored.minY < size.height {
                    // A black mirror gives the stars back nearly whole.
                    context.fill(Path(ellipseIn: mirrored), with: .color(colour.opacity(0.70 * star.brightness)))
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
            // A ridge of heights along the waterline, standing up or mirrored
            // down, at the view's own aspect, as the Metal lake draws it.
            let aspect = Double(size.width / max(size.height, 1))
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
            context.fill(ridge({ Self.mesas($0, aspect: aspect) }, mirrored: false), with: .color(Self.farShore))
            context.fill(ridge({ Self.mesas($0, aspect: aspect) }, mirrored: true), with: .color(Self.farShoreImage))
            context.fill(ridge({ Self.bank($0, aspect: aspect) }, mirrored: false), with: .color(Self.nearBank))
            context.fill(ridge({ Self.bank($0, aspect: aspect) }, mirrored: true), with: .color(Self.nearBankImage))

            // Mist lying on the water at the horizon, as the shader lays it:
            // faint, and fading by two thirds every 3% of the height away.
            let mist = size.height * 0.06
            context.fill(Path(CGRect(x: 0, y: waterline - mist, width: size.width, height: mist * 2)), with: .linearGradient(
                Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: Self.mist.opacity(0.01), location: 0.25),
                    .init(color: Self.mist.opacity(0.03), location: 0.5),
                    .init(color: Self.mist.opacity(0.01), location: 0.75),
                    .init(color: .clear, location: 1),
                ]),
                startPoint: CGPoint(x: 0, y: waterline - mist),
                endPoint: CGPoint(x: 0, y: waterline + mist)
            ))
            // And the shader's vignette, the corners a little darker.
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
                Gradient(stops: [.init(color: .clear, location: 0.45), .init(color: .black.opacity(0.42), location: 1)]),
                center: CGPoint(x: size.width / 2, y: size.height / 2),
                startRadius: 0,
                endRadius: hypot(size.width, size.height) / 2
            ))
        }
        .accessibilityHidden(true)
    }
}
