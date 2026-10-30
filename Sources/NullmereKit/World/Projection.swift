import CoreGraphics
import NullmereCore
import NullmereModels
import NullmereWorld

extension GameSession {
    /// The height of a hex's heart, the water's face over the lake: where
    /// what stands in it stands. Worked out once for each map.
    func groundHeight(of hex: Hex) -> Double {
        guard let index = state.map.index(of: hex) else { return Double(max(relief.height(of: hex), Relief.waterline)) }
        if heartHeights.count != state.map.count {
            heartHeights = state.map.hexes.map { Double(max(relief.height(of: $0), Relief.waterline)) }
        }
        return heartHeights[index]
    }

    /// Where a hex shows in the view: its heart, on the land or the water,
    /// lifted by `lift` world units.
    func viewPoint(of hex: Hex, in size: CGSize, lift: Double = 0) -> CGPoint {
        camera.viewPoint(of: hex, height: groundHeight(of: hex) + lift, in: size)
    }

    /// Where a point of a hex shows in the view, at the hex's height.
    func viewPoint(worldX x: Double, worldY y: Double, onHex hex: Hex, in size: CGSize) -> CGPoint {
        camera.viewPoint(worldX: x, worldY: y, height: groundHeight(of: hex), in: size)
    }

    /// The hex under a point of the view, where the eye's ray meets the
    /// land or the water.
    func hex(at point: CGPoint, in size: CGSize) -> Hex {
        camera.hex(at: point, in: size, relief: relief)
    }
}
