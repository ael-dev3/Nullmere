import Foundation
import NullmereCore

/// The unquiet dead as they are heard from the view (`Keening` in the
/// sound): wherever their lights burn, over a field where they lie unburied
/// and quiet (`UnburiedSight.kindled`) or about the Barrowkin who carry
/// them, thin voices keening, the louder the brighter the lights burn and
/// the nearer the view's middle, from where they lie across the view,
/// coming in as the view comes down to the land. A sound half heard: it
/// carries no further than the lake's lapping, and dead out at the view's
/// edge are silent.
public enum UnquietSound {
    /// How near the view must come for the dead to be heard at all, and how
    /// near before they are heard at their fullest: as near as the lake's
    /// lapping (`ShoreSound`).
    public static let faintest = 24.0
    public static let fullest = 64.0
    /// How brightly the lights heard must burn, together, to keen as loud
    /// as the dead get (`WorldStage.corpseStrength`): a field that will rise,
    /// on the eve of the dark, and half as much again.
    static let full: Float = 1.5
    /// How faint a cue from where they lie would be heard, from nothing
    /// (the hearing's floor) to full, before the dead are heard at all: more
    /// than the fire's, so they are heard only nearer the view's middle.
    static let beyond: Float = 0.4

    /// The dead as heard from `camera`, of the lights burning in `sights`:
    /// how loud, 0 to 1, and from where across the view, -1 (left) to 1
    /// (right); nil where none is heard.
    public static func heard(_ sights: [UnburiedSight], from camera: Camera) -> (level: Float, pan: Float)? {
        let near = Float(min(max((camera.scale - faintest) / (fullest - faintest), 0), 1))
        guard near > 0 else { return nil }
        var total: Float = 0, panned: Float = 0
        for sight in sights {
            let heard = camera.hearing(of: sight.at)
            let nearby = ((heard.gain - 0.3) / 0.7 - beyond) / (1 - beyond)
            guard nearby > 0 else { continue }
            let loud = nearby * WorldStage.corpseStrength(sight)
            total += loud
            panned += loud * heard.pan
        }
        guard total > 0.001 else { return nil }
        return (min(total / full, 1) * near, min(max(panned / total, -1), 1))
    }
}
