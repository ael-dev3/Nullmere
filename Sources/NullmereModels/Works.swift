import Foundation
import NullmereCore

/// Every work at every level, standing on y = 0 and facing +z toward the
/// keep, each level grander than the last. Each fits within
/// `HoldLayout.workRadius` of its foot.
enum Works {
    static func build(_ kind: BuildingKind, level: Int, name: String) -> Model {
        trade(kind, level: level, name: name)
    }

    /// The work itself, its family's own at its level.
    static func trade(_ kind: BuildingKind, level: Int, name: String) -> Model {
        switch kind {
        case .granary: return Art.work(Art.granaryFile, level: level, name: name)
        case .sawpit: return Art.work(Art.sawpitFile, level: level, name: name)
        case .quarry: return Art.work(Art.quarryFile, level: level, name: name)
        case .saltworks: return Art.work(Art.saltworksFile, level: level, name: name)
        case .musterHall: return Art.work(Art.musterHallFile, level: level, name: name)
        case .walls: return Art.walls(level: level, name: name)
        case .beacon: return Art.work(Art.beaconFile, level: level, name: name)
        case .infirmary: return Art.work(Art.infirmaryFile, level: level, name: name)
        case .moonspire: return Art.work(Art.moonspireFile, level: level, name: name)
        case .archive: return Art.work(Art.archiveFile, level: level, name: name)
        case .forge: return Art.work(Art.forgeFile, level: level, name: name)
        case .wayhouse: return Art.work(Art.wayhouseFile, level: level, name: name)
        case .lodge: return Art.work(Art.lodgeFile, level: level, name: name)
        }
    }

    // MARK: Forge

    /// How high a Forge's chimney stands at a level.
    static func forgeChimneyHeight(_ level: Int) -> Float {
        [0.3, 0.36, 0.42, 0.5, 0.56][min(max(level, 1), 5) - 1]
    }

    /// Where smoke rises from a Forge's chimney.
    static func forgeChimney(_ level: Int) -> Vec3 {
        Vec3(-0.13, forgeChimneyHeight(level), -0.12)
    }

    // MARK: Infirmary

    /// Where the Infirmary's ward smokes, from the second level
    /// (Art/blender/infirmary.py builds its chimney there).
    static func infirmaryChimney(_ level: Int) -> Vec3? {
        switch level {
        case 2, 3: return Vec3(0.05, 0.22, -0.135)
        case 4: return Vec3(0.08, 0.22, -0.175)
        case 5: return Vec3(0.09, 0.24, -0.16)
        default: return nil
        }
    }

    // MARK: Saltworks

    /// Where the Saltworks' boiling house smokes, at the levels that have one
    /// (Art/blender/saltworks.py builds its chimney there).
    static func saltworksChimney(_ level: Int) -> Vec3? {
        guard (3...4).contains(level) else { return nil }
        return Vec3(-0.06, 0.25, -0.145)
    }
}
