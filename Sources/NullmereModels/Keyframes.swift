import Foundation

/// Authored motion: a clip as keys set by hand, each part's turn (or its
/// offset) at moments through the clip, and the motion between them drawn
/// through the keys on a smooth curve (a cardinal spline, its tangents
/// taken from the keys either side), round again for a clip that loops,
/// easing to rest at the ends of one that plays once.
struct Track: Sendable {
    enum Kind: Sendable {
        /// Radians about x, y and z, added to the part's turn.
        case turn
        /// An offset, in the body's own units, added to the part's.
        case shift
        /// A swelling or a shrinking, by this much more than it was on each axis.
        case stretch
    }

    /// What the keys' values are measured in, given when the clip is played.
    enum Scale: Sendable {
        /// As written.
        case none
        /// Times the stride of the one playing it: a long-legged walker's
        /// legs swing as far as their pace asks.
        case stride
        /// Times the height of the body: shifts in a body's units.
        case size
        /// Times the height the hips fall through to lie on the ground.
        case drop
    }

    let part: UInt16
    let kind: Kind
    let scale: Scale
    let keys: [(Float, Vec3)]

    init(_ part: UInt16, scale: Scale = .none, _ keys: [(Float, Vec3)]) {
        self.init(part, .turn, scale: scale, keys)
    }

    init(_ part: UInt16, _ kind: Kind, scale: Scale = .none, _ keys: [(Float, Vec3)]) {
        self.part = part
        self.kind = kind
        self.scale = scale
        self.keys = keys
    }

    /// The slope through a key, from the keys either side; flat on any axis
    /// where the key holds the value of a neighbour, so a held pose holds
    /// still, and flat at the ends of a clip played once.
    func tangent(_ index: Int, _ key: (Int) -> (Float, Vec3)) -> Vec3 {
        let here = key(index), before = key(index - 1), after = key(index + 1)
        if before.0 == here.0 || after.0 == here.0 { return .zero }
        var slope = (after.1 - before.1) / (after.0 - before.0)
        for axis in 0..<3 where here.1[axis] == before.1[axis] || here.1[axis] == after.1[axis] {
            slope[axis] = 0
        }
        return slope
    }

    /// The track's value at progress `u`, through its keys.
    func value(at u: Float, loops: Bool) -> Vec3 {
        guard let first = keys.first else { return .zero }
        guard keys.count > 1 else { return first.1 }
        if !loops {
            if u <= first.0 { return first.1 }
            if let last = keys.last, u >= last.0 { return last.1 }
        }
        let count = keys.count
        // The key at an index, keys before and after taken round a loop a
        // period away, or held at the ends of a clip played once.
        func key(_ index: Int) -> (Float, Vec3) {
            if loops {
                let wraps = Int((Float(index) / Float(count)).rounded(.down))
                let k = keys[index - wraps * count]
                return (k.0 + Float(wraps), k.1)
            }
            return keys[min(max(index, 0), count - 1)]
        }
        let v = loops ? u - u.rounded(.down) : u
        // The keys either side of the moment: before the first key of a
        // loop, from the last one a period back.
        var i = loops && v < keys[0].0 ? -1 : 0
        while i < count - 1, keys[i + 1].0 <= v { i += 1 }
        let a = key(i), b = key(i + 1)
        let span = max(b.0 - a.0, 1e-5)
        let t = min(max((v - a.0) / span, 0), 1)
        let ta = tangent(i, key) * span, tb = tangent(i + 1, key) * span
        let t2 = t * t, t3 = t2 * t
        return a.1 * (2 * t3 - 3 * t2 + 1) + ta * (t3 - 2 * t2 + t) + b.1 * (-2 * t3 + 3 * t2) + tb * (t3 - t2)
    }
}

/// A clip authored as keys, part by part.
struct Keyed: Sendable {
    let tracks: [Track]
    let loops: Bool

    init(loops: Bool, _ tracks: [Track]) {
        self.loops = loops
        self.tracks = tracks
    }

    /// Plays the clip at progress `u` into a pose, on top of how it stands.
    func apply(_ p: inout Pose, _ u: Float, stride: Float = 1, size: Float = 0.3, drop: Float = 0) {
        for track in tracks where Int(track.part) < p.joints.count {
            var value = track.value(at: u, loops: loops)
            switch track.scale {
            case .none: break
            case .stride: value *= stride
            case .size: value *= size
            case .drop: value *= drop
            }
            switch track.kind {
            case .turn: p.turn(track.part, x: value.x, y: value.y, z: value.z)
            case .shift: p.shift(track.part, value)
            case .stretch: p.stretch(track.part, Vec3(1, 1, 1) + value)
            }
        }
    }
}

/// Shorthand for writing keys.
@inline(__always) func k(_ t: Float, _ x: Float, _ y: Float = 0, _ z: Float = 0) -> (Float, Vec3) { (t, Vec3(x, y, z)) }
