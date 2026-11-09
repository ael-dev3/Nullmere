import Foundation
import NullmereCore
import NullmereModels

/// The hamlets and barrows the keeper's House has found in the mist, as the
/// world draws them: a hamlet's homes standing about its well, their doors
/// in the free folk's weathered brown, its strip field beside them and the
/// smoke of its hearth; a barrow's great grassed mound, larger than any the
/// barrows' ground bears, the stones of its open mouth before it, two
/// standing and a third laid across them. What grows on their ground gives
/// way to them, as it does to a site or a lair.
extension WorldStage {
    /// How far from its hex's middle a hamlet's homes stand.
    public static let hamletRing: Float = 0.36
    /// How much larger than the barrows' own a found barrow's mound is.
    public static let barrowMoundScale: Float = 1.7
    /// The free folk's doors: weathered brown, no House's colour.
    public static let freeFolkDoor = Vec4(0.42, 0.33, 0.24, 1)
    /// How far a barrow's mouth stands out from its mound's middle, at the
    /// foot of the mound, and how far apart its two standing stones are.
    public static let barrowMouth: Float = 0.58, barrowMouthWidth: Float = 0.28
    /// A standing stone as its model stands, for laying one across two.
    static let standingStone = Library.model(.furnishing(.standingStone)).mesh.bounds

    /// Each hamlet and barrow drawn, and where a hamlet's hearth smokes.
    public func finds(_ finds: [(kind: Find.Kind, hex: Hex)]) -> (batches: [ModelBatch], hearths: [Hearth]) {
        var placed: [(ModelKey, ModelInstance)] = []
        var hearths: [Hearth] = []
        for find in finds {
            let centre = Relief.centre(of: find.hex)
            let turn = WorldStage.phase(of: find.hex, salt: 67) * .pi * 2
            let hex = SIMD2(Int32(find.hex.q), Int32(find.hex.r))
            /// Sets `key` down at `bearing` and `distance` from the middle
            /// (turned with the find), facing `facing`.
            func put(_ key: ModelKey, bearing: Float, distance: Float, facing: Float, scale: Float, lift: Float = 0,
                     laid: Mat4 = .identity, colour: Vec4? = nil) -> Vec3 {
                let angle = turn + bearing
                let x = centre.x + distance * Float(sin(Double(angle))), z = centre.z + distance * Float(cos(Double(angle)))
                let at = Vec3(x, ground(atX: x, z: z) - Scatter.sink + lift, z)
                var instance = ModelInstance(model: .translation(at) * .rotationY(facing) * .scale(scale) * laid,
                                             phase: WorldStage.phase(of: find.hex, salt: 71), hex: hex)
                if let colour { instance.colour = colour }
                placed.append((key, instance))
                return at
            }
            switch find.kind {
            case .hamlet:
                // Three homes facing their well, of the kinds the land's folk build.
                let homes = Town.homes.filter { $0 != .townhouse }
                for index in 0..<3 {
                    let bearing = Float(index) * 2 * .pi / 3
                    let kind = homes[(index + Int(WorldStage.phase(of: find.hex, salt: 73) * 3)) % homes.count]
                    _ = put(.town(kind), bearing: bearing, distance: WorldStage.hamletRing, facing: turn + bearing + .pi,
                            scale: HoldLayout.grandeur, colour: WorldStage.freeFolkDoor)
                }
                let well = put(.town(.well), bearing: 0, distance: 0, facing: turn, scale: HoldLayout.grandeur)
                // Its field out past the homes, between two of them.
                _ = put(.town(.field), bearing: .pi / 3, distance: WorldStage.hamletRing + 0.26, facing: turn + .pi / 3,
                        scale: 1)
                hearths.append(Hearth(point: well + Vec3(0, 0.12, 0), hex: find.hex))
            case .barrow:
                // The mound, and before it the stones of its mouth.
                _ = put(.furnishing(.barrowMound), bearing: 0, distance: 0, facing: turn, scale: WorldStage.barrowMoundScale)
                let mouth = WorldStage.barrowMouth, apart = WorldStage.barrowMouthWidth / 2
                let upright: Float = 0.8, across: Float = 0.7, stone = WorldStage.standingStone
                let feet = [Float(-1), 1].map { side in
                    put(.furnishing(.standingStone), bearing: atan2(side * apart, mouth), distance: (mouth * mouth + apart * apart).squareRoot(),
                        facing: turn, scale: upright).y
                }
                // The third laid on its side across their tops, its length
                // along the mouth, resting on the higher where the ground slopes.
                let middle = (stone.min.y + stone.max.y) / 2
                let x = centre.x + mouth * Float(sin(Double(turn))), z = centre.z + mouth * Float(cos(Double(turn)))
                let under = ground(atX: x, z: z) - Scatter.sink
                _ = put(.furnishing(.standingStone), bearing: 0, distance: mouth, facing: turn, scale: across,
                        lift: (feet.max() ?? under) - under + upright * stone.max.y - across * stone.min.x,
                        laid: .rotationZ(.pi / 2) * .translation(Vec3(0, -middle, 0)))
            }
        }
        return (WorldStage.batches(placed), hearths)
    }
}
