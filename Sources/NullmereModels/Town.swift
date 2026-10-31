import Foundation
import NullmereCore

/// The town about a hold (see `HoldLayout.town`): the homes of its folk,
/// their windows lit at night; the lanes between its works; its well, its
/// fields and, at a seat, its market. Built of stone, timber, thatch and
/// slate, which the stage gives the hold's people's colours, each home's
/// door in its House's colour. Small and lean, for a hold has dozens; each
/// faces +z, toward the lane it stands on, and stands on y = 0.
public enum Town: String, CaseIterable, Sendable {
    /// A small home, whitewashed under a steep thatch.
    case cottage
    /// A long low home of weathered planks under thatch, its woodpile at
    /// the gable.
    case longhouse
    /// A tall home of two storeys, stone below and timber-framed above,
    /// under slate.
    case townhouse
    /// A round home of wattle under a cone of thatch.
    case roundhouse
    /// The ward's well: a ring of stone, a windlass under a little roof.
    case well
    /// A strip field: ridged furrows of grain, fenced about.
    case field
    /// A length of lane, a unit long from x = -0.5 to 0.5: trodden earth
    /// with flat stones set in it, stretched to the length it runs.
    case lane
    /// A stall at a seat's market, its awning in the House's colour.
    case stall

    /// The homes, for the town's lots.
    public static let homes: [Town] = [.cottage, .longhouse, .townhouse, .roundhouse]

    /// How far it reaches from its foot on the ground: within it, nothing
    /// else of the town stands.
    public var footprint: Float {
        switch self {
        case .cottage: return 0.1
        case .longhouse: return 0.13
        case .townhouse: return 0.09
        case .roundhouse: return 0.08
        case .well: return 0.06
        case .field: return 0.22
        case .lane: return 0.06
        case .stall: return 0.07
        }
    }

    static func build(_ piece: Town, name: String) -> Model {
        var b = MeshBuilder()
        switch piece {
        case .cottage: cottage(&b)
        case .longhouse: longhouse(&b)
        case .townhouse: townhouse(&b)
        case .roundhouse: roundhouse(&b)
        case .well: well(&b)
        case .field: field(&b)
        case .lane: lane(&b)
        case .stall: stall(&b)
        }
        return Model(name: name, mesh: b.mesh)
    }

    /// A door in the House's colour.
    private static func door(_ b: inout MeshBuilder, _ center: Vec3, width: Float, height: Float) {
        b.with(material: .house) {
            $0.door(center, width: width, height: height, facing: 0, color: Palette.house)
        }
    }

    static func cottage(_ b: inout MeshBuilder) {
        b.box(min: Vec3(-0.085, -0.05, -0.055), max: Vec3(0.085, 0.07, 0.055), color: Palette.stoneWhite)
        // Corner posts and a sill beam of dark timber.
        for x in [Float(-0.085), 0.085] {
            b.box(center: Vec3(x, 0.035, 0.055), size: Vec3(0.014, 0.07, 0.012), color: Palette.timberDark)
        }
        b.box(center: Vec3(0, 0.07, 0.055), size: Vec3(0.18, 0.012, 0.012), color: Palette.timberDark)
        b.gableRoof(width: 0.17, depth: 0.11, base: 0.07, height: 0.08, color: Palette.thatch, overhang: 0.014)
        door(&b, Vec3(-0.03, 0.026, 0.057), width: 0.028, height: 0.052)
        b.window(Vec3(0.037, 0.038, 0.056), width: 0.026, height: 0.022, facing: 0)
        b.box(center: Vec3(0.055, 0.12, -0.02), size: Vec3(0.024, 0.08, 0.024), color: Palette.stone)
    }

    static func longhouse(_ b: inout MeshBuilder) {
        b.box(min: Vec3(-0.12, -0.05, -0.045), max: Vec3(0.12, 0.058, 0.045), color: Palette.timberGrey)
        b.gableRoof(width: 0.24, depth: 0.09, base: 0.058, height: 0.07, color: Palette.thatch, overhang: 0.016)
        door(&b, Vec3(0.05, 0.022, 0.047), width: 0.028, height: 0.046)
        for x in [Float(-0.035), -0.085] {
            b.window(Vec3(x, 0.034, 0.046), width: 0.02, height: 0.016, facing: 0)
        }
        // Firewood stacked against the west gable.
        for (index, y) in [Float(0.012), 0.012, 0.03].enumerated() {
            let z = index == 2 ? Float(0) : (index == 0 ? -0.014 : 0.014)
            b.limb(from: Vec3(-0.128, y, z - 0.03), to: Vec3(-0.128, y, z + 0.03), radius: 0.009, sides: 4, color: Palette.bark)
        }
    }

    static func townhouse(_ b: inout MeshBuilder) {
        // Stone below.
        b.box(min: Vec3(-0.065, -0.05, -0.055), max: Vec3(0.065, 0.07, 0.055), color: Palette.stone)
        // Timber-framed above, jutting out over the lane.
        b.box(min: Vec3(-0.07, 0.07, -0.058), max: Vec3(0.07, 0.15, 0.068), color: Palette.stoneWhite)
        for x in [Float(-0.07), -0.024, 0.024, 0.07] {
            b.box(center: Vec3(x, 0.11, 0.068), size: Vec3(0.01, 0.08, 0.006), color: Palette.timberDark)
        }
        for y in [Float(0.072), 0.148] {
            b.box(center: Vec3(0, y, 0.068), size: Vec3(0.144, 0.01, 0.006), color: Palette.timberDark)
        }
        b.place(.translation(Vec3(0, 0, 0.005))) {
            $0.gableRoof(width: 0.14, depth: 0.126, base: 0.15, height: 0.075, color: Palette.slate, overhang: 0.01)
        }
        door(&b, Vec3(-0.025, 0.03, 0.057), width: 0.03, height: 0.06)
        b.window(Vec3(0.03, 0.04, 0.056), width: 0.024, height: 0.026, facing: 0)
        for x in [Float(-0.047), 0.047] {
            b.window(Vec3(x, 0.112, 0.07), width: 0.022, height: 0.03, facing: 0)
        }
        b.box(center: Vec3(-0.05, 0.2, -0.03), size: Vec3(0.024, 0.07, 0.024), color: Palette.stoneDark)
    }

    static func roundhouse(_ b: inout MeshBuilder) {
        b.lathe([(0.06, -0.05), (0.06, 0.055)], sides: 8, color: Palette.timberGrey)
        b.cone(sides: 8, radius: 0.076, from: 0.055, to: 0.145, color: Palette.thatch)
        door(&b, Vec3(0, 0.024, 0.06), width: 0.028, height: 0.048)
        b.window(onRound: 0.06, y: 0.032, angle: 0.4, width: 0.016, height: 0.014)
    }

    static func well(_ b: inout MeshBuilder) {
        // A ring of stone with dark water in it.
        b.lathe([(0.042, -0.04), (0.042, 0.036), (0.032, 0.036), (0.032, 0.012)], sides: 8, color: Palette.stone)
        b.lathe([(0.032, 0.012), (0.0, 0.012)], sides: 8, color: Palette.loam)
        // Two posts, a windlass between them, a bucket on its rope, a roof over all.
        for x in [Float(-0.036), 0.036] {
            b.limb(from: Vec3(x, 0.03, 0), to: Vec3(x, 0.115, 0), radius: 0.006, sides: 4, color: Palette.timber)
        }
        b.limb(from: Vec3(-0.036, 0.085, 0), to: Vec3(0.036, 0.085, 0), radius: 0.006, sides: 4, color: Palette.timberPale)
        b.limb(from: Vec3(0, 0.085, 0), to: Vec3(0, 0.055, 0), radius: 0.0015, sides: 3, color: Palette.linen)
        b.place(.translation(Vec3(0, 0.045, 0))) {
            $0.lathe([(0.009, 0), (0.011, 0.014)], sides: 5, color: Palette.timberDark)
        }
        b.place(.translation(Vec3(0, 0.115, 0))) {
            $0.gableRoof(width: 0.1, depth: 0.06, base: 0, height: 0.035, color: Palette.slate, overhang: 0.008)
        }
    }

    static func field(_ b: inout MeshBuilder) {
        b.box(min: Vec3(-0.19, -0.06, -0.12), max: Vec3(0.19, 0.004, 0.12), color: Palette.loam)
        b.with(material: .foliage, sway: 0.6) {
            $0.swayRange = (0.0, 0.05)
            for row in 0..<5 {
                let z = Float(row) * 0.046 - 0.092
                $0.beam(from: Vec3(-0.17, 0.004, z), to: Vec3(0.17, 0.004, z), width: 0.026, depth: 0.03,
                        color: row % 2 == 0 ? Palette.grain : Palette.straw)
            }
        }
        Stores.fence(&b, [Vec3(-0.19, 0, -0.12), Vec3(0.19, 0, -0.12), Vec3(0.19, 0, 0.12)])
    }

    static func lane(_ b: inout MeshBuilder) {
        // Sunk deep enough to lie on a slope without lifting off it.
        b.box(min: Vec3(-0.5, -0.05, -0.05), max: Vec3(0.5, 0.005, 0.05), color: Palette.yard)
        for index in 0..<4 {
            let jitter = Noise.unit(Int32(index), 5, 0x1A9E)
            b.box(center: Vec3(-0.375 + Float(index) * 0.25, 0.006, (jitter - 0.5) * 0.04), size: Vec3(0.07, 0.004, 0.04),
                  color: Palette.stonePale.mix(Palette.stone, jitter))
        }
    }

    static func stall(_ b: inout MeshBuilder) {
        b.box(min: Vec3(-0.05, 0.03, -0.028), max: Vec3(0.05, 0.038, 0.028), color: Palette.timberPale)
        for x in [Float(-0.045), 0.045] {
            for z in [Float(-0.024), 0.024] {
                b.limb(from: Vec3(x, 0, z), to: Vec3(x, 0.03, z), radius: 0.004, sides: 3, color: Palette.timber)
            }
            b.limb(from: Vec3(x, 0, -0.034), to: Vec3(x, 0.1, -0.034), radius: 0.004, sides: 3, color: Palette.timber)
        }
        b.with(material: .house) {
            $0.place(.translation(Vec3(0, 0.09, 0)) * .rotationX(0.32)) {
                $0.box(center: Vec3(0, 0, 0.004), size: Vec3(0.12, 0.005, 0.08), color: Palette.house)
            }
        }
        // Wares: a sack, a basket of salt, a pile of loaves.
        b.sack(at: Vec3(-0.025, 0.038, 0), size: 0.014, seed: 3)
        b.place(.translation(Vec3(0.02, 0.038, 0))) {
            $0.lathe([(0.012, 0), (0.016, 0.012)], sides: 5, color: Palette.reed)
        }
        b.sphere(center: Vec3(0.02, 0.05, 0), radius: 0.011, rings: 2, sides: 5, color: Palette.moonsalt)
    }
}
