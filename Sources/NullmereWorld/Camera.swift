import Foundation
import NullmereCore
import NullmereModels

/// Where the world is looked at from: the point of the map at the middle
/// of the view, how near (how many points one world unit spans there), how
/// far the view leans from looking straight down, and which way it faces.
/// The world is seen in perspective: what is nearer the foot of the view
/// is nearer the eye.
public struct Camera: Equatable, Sendable {
    /// The map point at the middle of the view: x east, y south.
    public var centerX: Double
    public var centerY: Double
    /// Points one world unit spans at the middle of the view.
    public var scale: Double
    /// How far the view leans from looking straight down, in radians.
    public var tilt: Double
    /// Which way the view faces, in radians: zero looks north, a quarter
    /// turn looks west.
    public var heading: Double

    public static let minimumScale = 9.0
    /// Close enough to see a company's every figure.
    public static let maximumScale = 180.0
    public static let minimumTilt = 0.25
    public static let maximumTilt = 1.0
    public static let defaultTilt = 0.72
    /// The height of the view's field, in radians.
    public static let fieldOfView = 0.6

    public init(centerX: Double = 0, centerY: Double = 0, scale: Double = 30, tilt: Double = Camera.defaultTilt,
                heading: Double = 0) {
        self.centerX = centerX
        self.centerY = centerY
        self.scale = scale
        self.tilt = tilt
        self.heading = heading
    }

    private static let layout = HexLayout(size: 1)

    // MARK: The eye

    /// Points and directions worked out in double precision: a drag of a
    /// few points moves the view by exactly what it should.
    typealias Point = SIMD3<Double>

    /// How far the eye is from the middle of the view.
    public func distance(in size: CGSize) -> Double {
        max(Double(size.height), 1) / (2 * scale * tan(Camera.fieldOfView / 2))
    }

    /// The point the eye looks at: the middle of the view, on the water's face.
    public var focus: Vec3 { Vec3(Float(centerX), 0, Float(centerY)) }

    var focusPoint: Point { Point(centerX, 0, centerY) }

    /// From the middle of the view toward the eye.
    var towardEye: Point { Point(sin(tilt) * sin(heading), cos(tilt), sin(tilt) * cos(heading)) }

    /// The view's right, along the ground.
    var right: Point { Point(cos(heading), 0, -sin(heading)) }

    /// The view's up, square to its right and its line of sight.
    var up: Point {
        let r = right, f = -towardEye
        return Point(r.y * f.z - r.z * f.y, r.z * f.x - r.x * f.z, r.x * f.y - r.y * f.x)
    }

    func eyePoint(in size: CGSize) -> Point { focusPoint + towardEye * distance(in: size) }

    public func eye(in size: CGSize) -> Vec3 {
        let e = eyePoint(in: size)
        return Vec3(Float(e.x), Float(e.y), Float(e.z))
    }

    public func viewMatrix(in size: CGSize) -> Mat4 {
        let u = up
        return Mat4.lookAt(eye: eye(in: size), target: focus, up: Vec3(Float(u.x), Float(u.y), Float(u.z)))
    }

    public func projectionMatrix(in size: CGSize) -> Mat4 {
        let d = Float(distance(in: size))
        let aspect = Float(max(size.width, 1) / max(size.height, 1))
        return Mat4.perspective(fovY: Float(Camera.fieldOfView), aspect: aspect, near: max(d * 0.02, 0.05), far: d * 4 + 20)
    }

    public func viewProjection(in size: CGSize) -> Mat4 {
        projectionMatrix(in: size) * viewMatrix(in: size)
    }

    // MARK: From the world to the view, and back

    /// Where a point of the world shows in the view, from its top left;
    /// a point behind the eye is put far outside it.
    public func viewPoint(worldX x: Double, worldY y: Double, height: Double = 0, in size: CGSize) -> CGPoint {
        let toPoint = Point(x, height, y) - eyePoint(in: size)
        let forward = -towardEye
        let depth = (toPoint * forward).sum()
        guard depth > 1e-9 else { return CGPoint(x: -100_000, y: -100_000) }
        let spread = tan(Camera.fieldOfView / 2)
        let width = max(Double(size.width), 1), height = max(Double(size.height), 1)
        let across = (toPoint * right).sum() / depth / (spread * width / height)
        let upward = (toPoint * up).sum() / depth / spread
        return CGPoint(x: (across + 1) / 2 * width, y: (1 - upward) / 2 * height)
    }

    public func viewPoint(of hex: Hex, height: Double = 0, in size: CGSize) -> CGPoint {
        let c = Camera.layout.center(of: hex)
        return viewPoint(worldX: c.x, worldY: c.y, height: height, in: size)
    }

    /// The ray from the eye through a point of the view, in double precision.
    func rayPoint(through point: CGPoint, in size: CGSize) -> (origin: Point, direction: Point) {
        let width = max(Double(size.width), 1), height = max(Double(size.height), 1)
        let ndcX = 2 * Double(point.x) / width - 1, ndcY = 1 - 2 * Double(point.y) / height
        let spread = tan(Camera.fieldOfView / 2)
        let direction = -towardEye + right * (ndcX * spread * width / height) + up * (ndcY * spread)
        let length = (direction * direction).sum().squareRoot()
        return (eyePoint(in: size), direction / length)
    }

    /// The ray from the eye through a point of the view.
    public func ray(through point: CGPoint, in size: CGSize) -> (origin: Vec3, direction: Vec3) {
        let (o, d) = rayPoint(through: point, in: size)
        return (Vec3(Float(o.x), Float(o.y), Float(o.z)), Vec3(Float(d.x), Float(d.y), Float(d.z)))
    }

    /// The map point under a point of the view, on the level of `height`;
    /// above the horizon, the furthest the view could reach that way.
    public func world(at point: CGPoint, in size: CGSize, height: Double = 0) -> (x: Double, y: Double) {
        let (origin, direction) = rayPoint(through: point, in: size)
        let reach = 50 * distance(in: size)
        var t = reach
        if direction.y < -1e-9 {
            t = min((height - origin.y) / direction.y, reach)
        }
        let p = origin + direction * t
        return (p.x, p.z)
    }

    /// The hex under a point of the view, on the water's level.
    public func hex(at point: CGPoint, in size: CGSize) -> Hex {
        let w = world(at: point, in: size)
        return Camera.layout.hex(atX: w.x, y: w.y)
    }

    /// The hex under a point of the view, where the ray meets the land.
    public func hex(at point: CGPoint, in size: CGSize, relief: Relief) -> Hex {
        let (origin, direction) = ray(through: point, in: size)
        guard let hit = relief.intersect(origin: origin, direction: direction, reach: Float(6 * distance(in: size))) else {
            return hex(at: point, in: size)
        }
        return Camera.layout.hex(atX: Double(hit.x), y: Double(hit.z))
    }

    /// The hex at the middle of the view.
    public var centreHex: Hex {
        Camera.layout.hex(atX: centerX, y: centerY)
    }

    // MARK: Moving the view

    /// Moves the view by a drag of `dx`, `dy` points: the ground under the
    /// middle of the view follows the pointer.
    public mutating func pan(dx: Double, dy: Double, in size: CGSize) {
        let middle = CGPoint(x: size.width / 2, y: size.height / 2)
        let before = world(at: middle, in: size)
        let after = world(at: CGPoint(x: middle.x + dx, y: middle.y + dy), in: size)
        // Toward the horizon a drag could fling the view: no step goes
        // further than the view is wide.
        var stepX = before.x - after.x, stepY = before.y - after.y
        let longest = Double(max(size.width, size.height)) / scale
        let length = (stepX * stepX + stepY * stepY).squareRoot()
        if length > longest {
            stepX *= longest / length
            stepY *= longest / length
        }
        centerX += stepX
        centerY += stepY
    }

    /// A view of a usual size, for moving the view by keys, which have no
    /// view to measure.
    public static let usualView = CGSize(width: 1280, height: 800)

    /// Moves the view by `dx`, `dy` points of a usual view: the keys' pan.
    public mutating func pan(dx: Double, dy: Double) {
        pan(dx: dx, dy: dy, in: Camera.usualView)
    }

    /// How far the view leans at a scale, left to itself: down on the
    /// whole map from afar, toward the horizon close in among the models.
    public static func leaning(at scale: Double) -> Double {
        let t = min(max(log(scale / minimumScale) / log(maximumScale / minimumScale), 0), 1)
        return 0.55 + 0.42 * t
    }

    /// Takes the scale to `scale * factor`, the view leaning as the scale
    /// does and keeping whatever lean the keeper gave it.
    private mutating func rescale(by factor: Double) {
        let lean = tilt - Camera.leaning(at: scale)
        scale = min(max(scale * factor, Camera.minimumScale), Camera.maximumScale)
        tilt = min(max(Camera.leaning(at: scale) + lean, Camera.minimumTilt), Camera.maximumTilt)
    }

    /// Zooms by `factor` about the middle of the view: the keys' zoom.
    public mutating func zoom(by factor: Double) {
        rescale(by: factor)
    }

    /// Zooms by `factor`, keeping the map point under `anchor` in place.
    public mutating func zoom(by factor: Double, around anchor: CGPoint, in size: CGSize) {
        let before = world(at: anchor, in: size)
        rescale(by: factor)
        let after = world(at: anchor, in: size)
        centerX += before.x - after.x
        centerY += before.y - after.y
    }

    /// Turns the view about its middle by `angle` radians: a positive
    /// angle carries the eye from the south round toward the east.
    public mutating func turn(by angle: Double) {
        heading = (heading + angle).truncatingRemainder(dividingBy: 2 * .pi)
    }

    /// Leans the view further from (or nearer to) looking straight down.
    public mutating func lean(by angle: Double) {
        tilt = min(max(tilt + angle, Camera.minimumTilt), Camera.maximumTilt)
    }

    public mutating func focus(on hex: Hex) {
        let c = Camera.layout.center(of: hex)
        centerX = c.x
        centerY = c.y
    }

    /// Keeps the view's middle over the world.
    public mutating func clamp(toRadius radius: Int) {
        let width = 3.0.squareRoot() * Double(radius)
        let height = 1.5 * Double(radius)
        centerX = min(max(centerX, -width), width)
        centerY = min(max(centerY, -height), height)
    }
}
