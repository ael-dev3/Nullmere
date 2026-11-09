import Foundation
import NullmereCore

/// The blackwood burning as it is heard from the view (`Blaze` in the
/// sound): the more of it alight about the view's middle the louder, from
/// where it burns across the view, coming in as the view comes down to the
/// land. A fire's roar carries further than the lake's lapping, so it is
/// heard from the lake's own view, faint; wood the House has not seen
/// burning is not heard.
public enum FireSound {
    /// How near the view must come for the fire to be heard at all, and how
    /// near before it is heard at its fullest.
    public static let faintest = 16.0
    public static let fullest = 48.0
    /// How many tiles alight about the view's middle sound as loud as fire
    /// gets.
    static let full: Float = 3
    /// How faint a cue from where it burns would be heard, from nothing
    /// (the hearing's floor) to full, before the fire is heard at all.
    static let beyond: Float = 0.2

    /// The fire as heard from `camera`, of the tiles alight in `burning`
    /// the House knows: how loud, 0 to 1, and from where across the view,
    /// -1 (left) to 1 (right); nil where none is heard.
    public static func heard(_ burning: [Hex], from camera: Camera) -> (level: Float, pan: Float)? {
        let near = Float(min(max((camera.scale - faintest) / (fullest - faintest), 0), 1))
        guard near > 0 else { return nil }
        var total: Float = 0, panned: Float = 0
        for hex in burning {
            let heard = camera.hearing(of: hex)
            // The hearing's floor is for cues far off, and it falls slowly:
            // a fire more than a view's width from its middle is silent.
            let nearby = ((heard.gain - 0.3) / 0.7 - FireSound.beyond) / (1 - FireSound.beyond)
            guard nearby > 0 else { continue }
            total += nearby
            panned += nearby * heard.pan
        }
        guard total > 0.001 else { return nil }
        return (min(total / full, 1) * near, min(max(panned / total, -1), 1))
    }
}
