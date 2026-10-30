import Foundation

public extension Clip {
    /// How long a round of the clip lasts, in seconds, the same for every
    /// model. Idle, march, attack and gather loop with this period: a
    /// model at `t` stands as it does at `t + period`, so the renderer can
    /// phase figures by adding a fraction of it. The death plays once over
    /// this time and then lies still, its last moment held.
    var period: Float {
        switch self {
        case .idle: return 4
        case .march: return 1
        case .attack: return 1.5
        case .death: return 1.5
        case .gather: return 2
        }
    }

    /// Whether it plays over and over; the death plays once.
    var loops: Bool { self != .death }

    /// How far into the clip a moment lies, 0 up to 1: taken round for a
    /// looping clip, held at its ends for the death.
    func progress(at time: Float) -> Float {
        let u = time / period
        guard u.isFinite else { return 0 }
        if loops { return u - u.rounded(.down) }
        return min(max(u, 0), 1)
    }
}

/// How each part stands at a moment, built up a turn at a time.
struct Pose {
    var joints: [Joint]

    init(count: Int) {
        joints = Array(repeating: .rest, count: count)
    }

    /// Turns a part further about its pivot, radians about x, y and z.
    mutating func turn(_ part: UInt16, x: Float = 0, y: Float = 0, z: Float = 0) {
        joints[Int(part)].rotation += Vec3(x, y, z)
    }

    mutating func shift(_ part: UInt16, _ offset: Vec3) {
        joints[Int(part)].offset += offset
    }

    mutating func stretch(_ part: UInt16, _ scale: Vec3) {
        joints[Int(part)].scale *= scale
    }

    mutating func stretch(_ part: UInt16, _ scale: Float) {
        stretch(part, Vec3(repeating: scale))
    }

    /// Shrinks a part to nothing about its pivot: a tool put away.
    mutating func hide(_ part: UInt16) {
        joints[Int(part)].scale = Vec3(repeating: Motion.hidden)
    }

    /// The x turn of a part and everything it hangs from, so a held thing
    /// can be kept at an angle whatever the arm does.
    func pitch(through parts: [UInt16]) -> Float {
        parts.reduce(0) { $0 + joints[Int($1)].rotation.x }
    }
}

/// The arithmetic clips are written with.
enum Motion {
    /// The scale of a part put away: small enough to vanish, large enough
    /// to keep its transform invertible.
    static let hidden: Float = 0.001

    static func smooth(_ t: Float) -> Float {
        let c = min(max(t, 0), 1)
        return c * c * (3 - 2 * c)
    }

    /// A sine running `cycles` times through a clip's progress `u`.
    static func wave(_ u: Float, cycles: Float = 1, phase: Float = 0) -> Float {
        Float(sin(Double(2 * Float.pi * (u * cycles + phase))))
    }

    /// A cosine running `cycles` times through `u`.
    static func cosine(_ u: Float, cycles: Float = 1, phase: Float = 0) -> Float {
        Float(cos(Double(2 * Float.pi * (u * cycles + phase))))
    }

    /// A value through keyframes at moments of a clip's progress, eased
    /// from one to the next and held past the first and the last.
    static func key(_ u: Float, _ frames: [(Float, Float)]) -> Float {
        guard var previous = frames.first else { return 0 }
        if u <= previous.0 { return previous.1 }
        for frame in frames.dropFirst() {
            if u <= frame.0 {
                let t = (u - previous.0) / max(frame.0 - previous.0, 1e-6)
                return previous.1 + (frame.1 - previous.1) * smooth(t)
            }
            previous = frame
        }
        return previous.1
    }
}
