import LauncherCore
import SwiftUI

/// A still rendition of the lake drawn with SwiftUI, for when the Metal
/// scene cannot run.
struct LakeFallbackView: View {
    var horizon: Double

    private static let stars = StarCatalog.stars(count: 320, seed: 0x4E55_4C4C)

    private static let zenith = Color(red: 0.004, green: 0.006, blue: 0.012)
    private static let skyLow = Color(red: 0.060, green: 0.076, blue: 0.104)
    private static let waterHigh = Color(red: 0.050, green: 0.063, blue: 0.088)
    private static let waterLow = Color(red: 0.003, green: 0.004, blue: 0.008)
    private static let moonlight = Color(red: 0.58, green: 0.68, blue: 0.86)
    private static let moonFace = Color(red: 0.93, green: 0.95, blue: 0.98)

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
                    context.fill(Path(ellipseIn: mirrored), with: .color(.white.opacity(0.35 * star.brightness)))
                }
            }

            // The moon and its reflection.
            let radius = size.height * LakeComposition.moonRadius
            let moonRise = size.height * LakeComposition.moonY - size.height * horizon
            let moon = CGPoint(x: size.width * LakeComposition.moonX, y: waterline - moonRise)
            let reflection = CGPoint(x: moon.x, y: waterline + moonRise)
            for (center, strength) in [(moon, 1.0), (reflection, 0.55)] {
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
        }
        .accessibilityHidden(true)
    }
}
