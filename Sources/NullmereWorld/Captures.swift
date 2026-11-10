import Foundation
import NullmereCore
import NullmereModels

extension WorldStage {
    /// Seconds a hold seen taken shows its banners changed at its keep.
    public static let captureSeconds: Float = 7
    /// Where the banners of a hold taken are planted, from its heart:
    /// toward the eye and a little to the side, clear of its keep and of an
    /// alliance's mark (`markBannerOffset`).
    public static let captureOffset = (x: Float(-0.36), z: Float(0.34))

    /// When the old House's banner is all lowered, when the taker's begins
    /// to rise, and when it stands.
    static let captureLowered: Float = 1.2
    static let captureRaising: Float = 1.4
    public static let captureStanding: Float = 2.8

    /// How much of each banner shows `age` seconds after a hold was seen
    /// taken, from 0 (all sunk into the earth) to 1: the old House's
    /// lowered by `captureLowered`, the taker's raised from
    /// `captureRaising` to `captureStanding` and standing after; and how
    /// strongly the taker's shows, fading over the last second of
    /// `captureSeconds`. Eased at each end.
    public static func captureShowing(age: Float) -> (old: Float, new: Float, fade: Float) {
        func eased(_ x: Float) -> Float {
            let t = min(max(x, 0), 1)
            return t * t * (3 - 2 * t)
        }
        return (old: 1 - eased(age / captureLowered),
                new: eased((age - captureRaising) / (captureStanding - captureRaising)),
                fade: 1 - min(max(age - (captureSeconds - 1), 0), 1))
    }

    /// How tall a war banner stands, pole and all, from its foot.
    static let bannerHeight: Float = {
        let bounds = Library.model(.hostBanner).mesh.bounds
        return bounds.max.y - bounds.min.y
    }()

    /// The banners of holds seen taken lately (`captureSeconds`), each `age`
    /// seconds since, planted at its keep: the banner of the House it was
    /// taken from (`from`, none where it was no House's) lowered into the
    /// earth, then the taker's raised out of it, standing a while and
    /// fading. The earth hides what of them is sunk.
    public func captures(_ taken: [(at: Hex, from: Vec4?, by: Vec4, age: Float)]) -> [ModelBatch] {
        guard !taken.isEmpty else { return [] }
        let height = WorldStage.bannerHeight
        var placed: [(ModelKey, ModelInstance)] = []
        for capture in taken where capture.age >= 0 && capture.age < WorldStage.captureSeconds {
            let centre = Relief.centre(of: capture.at)
            let x = centre.x + WorldStage.captureOffset.x, z = centre.z + WorldStage.captureOffset.z
            let foot = ground(atX: x, z: z) - Scatter.sink
            let turn = Mat4.rotationY(WorldStage.phase(of: capture.at, salt: 97) * 0.4 - 0.2)
            let hex = SIMD2(Int32(capture.at.q), Int32(capture.at.r))
            let showing = WorldStage.captureShowing(age: capture.age)
            if let from = capture.from, showing.old > 0 {
                placed.append((.hostBanner, ModelInstance(model: .translation(Vec3(x, foot - (1 - showing.old) * height, z)) * turn,
                                                          colour: from, phase: WorldStage.phase(of: capture.at, salt: 98),
                                                          hex: hex, flags: ModelInstance.alwaysShown)))
            }
            if showing.new > 0, showing.fade > 0 {
                placed.append((.hostBanner, ModelInstance(model: .translation(Vec3(x, foot - (1 - showing.new) * height, z)) * turn,
                                                          colour: capture.by, opacity: showing.fade,
                                                          phase: WorldStage.phase(of: capture.at, salt: 99),
                                                          hex: hex, flags: ModelInstance.alwaysShown)))
            }
        }
        return WorldStage.batches(placed)
    }
}
