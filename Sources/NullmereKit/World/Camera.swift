import CoreGraphics
import NullmereCore

/// Where the map is looked at from: the world point at the centre of the
/// view, and how many points one world unit (a hex's corner radius) spans.
public struct Camera: Equatable, Sendable {
    public var centerX: Double
    public var centerY: Double
    public var scale: Double

    public static let minimumScale = 9.0
    public static let maximumScale = 96.0

    public init(centerX: Double = 0, centerY: Double = 0, scale: Double = 30) {
        self.centerX = centerX
        self.centerY = centerY
        self.scale = scale
    }

    private static let layout = HexLayout(size: 1)

    public func viewPoint(worldX x: Double, worldY y: Double, in size: CGSize) -> CGPoint {
        CGPoint(x: (x - centerX) * scale + size.width / 2, y: (y - centerY) * scale + size.height / 2)
    }

    public func viewPoint(of hex: Hex, in size: CGSize) -> CGPoint {
        let c = Camera.layout.center(of: hex)
        return viewPoint(worldX: c.x, worldY: c.y, in: size)
    }

    public func world(at point: CGPoint, in size: CGSize) -> (x: Double, y: Double) {
        ((point.x - size.width / 2) / scale + centerX, (point.y - size.height / 2) / scale + centerY)
    }

    public func hex(at point: CGPoint, in size: CGSize) -> Hex {
        let w = world(at: point, in: size)
        return Camera.layout.hex(atX: w.x, y: w.y)
    }

    /// Moves the view by a drag of `dx`, `dy` points.
    public mutating func pan(dx: Double, dy: Double) {
        centerX -= dx / scale
        centerY -= dy / scale
    }

    /// Zooms by `factor`, keeping the world point under `anchor` in place.
    public mutating func zoom(by factor: Double, around anchor: CGPoint, in size: CGSize) {
        let before = world(at: anchor, in: size)
        scale = min(max(scale * factor, Camera.minimumScale), Camera.maximumScale)
        let after = world(at: anchor, in: size)
        centerX += before.x - after.x
        centerY += before.y - after.y
    }

    public mutating func focus(on hex: Hex) {
        let c = Camera.layout.center(of: hex)
        centerX = c.x
        centerY = c.y
    }

    /// Keeps the view's centre over the world.
    public mutating func clamp(toRadius radius: Int) {
        let width = 3.0.squareRoot() * Double(radius)
        let height = 1.5 * Double(radius)
        centerX = min(max(centerX, -width), width)
        centerY = min(max(centerY, -height), height)
    }
}
