import Foundation
@testable import NullmereModels
import XCTest

/// Models made in Blender, read from glTF binary: the importer's test arm
/// (Art/blender/fixture_arm.py), two bones under a skin of smooth weights,
/// a block carried by the forearm, two materials and two actions.
final class AssetTests: XCTestCase {
    private func arm(scale: Float = 1) throws -> Model {
        try Asset.model(name: "arm", glb: try Asset.bytes(base64: Fixtures.arm), scale: scale)
    }

    /// The block's middle, as the model stands at a moment of a clip.
    private func block(_ model: Model, _ clip: Clip, _ time: Float) -> Vec3 {
        let pose = model.pose(clip, at: time)
        let metal = model.mesh.vertices.filter { $0.material == .metal }
        return metal.reduce(Vec3.zero) { $0 + $1.posed(pose) } / Float(max(metal.count, 1))
    }

    func testTheArmReadsAsItsSkeletonAndSkin() throws {
        let model = try arm()
        XCTAssertEqual(model.name, "arm")
        XCTAssertEqual(model.rig.bones.map(\.name), ["root", "upper", "lower"], "Parent first, after the rig's root")
        XCTAssertEqual(model.rig.bones[2].parent, 1, "The forearm hangs from the upper arm")
        XCTAssertEqual(model.rig.bones[2].pivot.y, 1, accuracy: 1e-4, "The elbow a unit up, Blender's up made the world's")
        let skeleton = try XCTUnwrap(model.skeleton)
        XCTAssertEqual(skeleton.clips, [.idle, .attack])
        XCTAssertEqual(try XCTUnwrap(skeleton.duration(of: .attack)), Clip.attack.period, accuracy: 1e-4)
        XCTAssertEqual(try XCTUnwrap(skeleton.duration(of: .idle)), Clip.idle.period, accuracy: 1e-4)
        XCTAssertNil(model.motion, "Moved by its skeleton, not by code")
    }

    func testItStandsAtRestAsItWasMade() throws {
        let model = try arm()
        for (index, m) in model.pose(.idle, at: 0).enumerated() {
            let off = [m.c0 - Mat4.identity.c0, m.c1 - Mat4.identity.c1, m.c2 - Mat4.identity.c2, m.c3 - Mat4.identity.c3]
                .map { ($0 * $0).sum() }.reduce(0, +)
            XCTAssertLessThan(off, 1e-6, "Bone \(index) unmoved at rest")
        }
        let mesh = model.mesh
        XCTAssertTrue(mesh.indices.allSatisfy { Int($0) < mesh.vertices.count })
        XCTAssertEqual(mesh.indices.count % 3, 0)
        let bounds = mesh.bounds
        XCTAssertEqual(bounds.max.y, 2.35, accuracy: 1e-3, "The block's top over the forearm's end")
        XCTAssertEqual(bounds.min.y, 0, accuracy: 1e-3, "The arm's foot on the ground")
        XCTAssertTrue(mesh.vertices.allSatisfy { abs($0.normal.length - 1) < 1e-3 }, "Unit normals")
    }

    func testTheSkinBendsWithBothBonesAtTheElbow() throws {
        let model = try arm()
        let skin = model.mesh.vertices.filter { $0.material == .house }
        XCTAssertFalse(skin.isEmpty)
        let elbow = skin.filter { abs($0.position.y - 1) < 0.15 }
        XCTAssertTrue(elbow.contains { $0.blend > 0.2 && $0.blend < 0.8 && $0.part != $0.part2 },
                      "Skin at the elbow weighed by both bones")
        let wrist = skin.filter { $0.position.y > 1.9 }
        XCTAssertTrue(wrist.allSatisfy { $0.part == 2 && $0.blend < 0.1 }, "At the wrist, the forearm's alone")
        // The block is carried whole by the forearm.
        let metal = model.mesh.vertices.filter { $0.material == .metal }
        XCTAssertEqual(metal.count, 24)
        XCTAssertTrue(metal.allSatisfy { $0.part == 2 && $0.blend == 0 })
    }

    func testItsActionsMoveItAsTheyWereMade() throws {
        let model = try arm()
        XCTAssertLessThan((block(model, .idle, 0) - Vec3(0, 2.2, 0)).length, 1e-3)
        // At the thrust's height the forearm is turned forward a quarter
        // turn, about the elbow: the block before the arm, a unit up.
        let thrust = block(model, .attack, 22.0 / 30)
        XCTAssertLessThan((thrust - Vec3(0, 1, 1.2)).length, 2e-3, "\(thrust)")
        // And back at the end.
        XCTAssertLessThan((block(model, .attack, Clip.attack.period * 0.999) - Vec3(0, 2.2, 0)).length, 0.02)
        // Halfway between keys, halfway round: turned through 45 degrees.
        let between = block(model, .attack, 11.0 / 30)
        XCTAssertEqual(atan2(between.z, between.y - 1), Float.pi / 4, accuracy: 0.03, "\(between)")
        // A clip it has no action for plays its idle.
        XCTAssertEqual(model.pose(.march, at: 0.5), model.pose(.idle, at: 0.5))
        // A looping clip comes round.
        let once = model.pose(.attack, at: 0.4), again = model.pose(.attack, at: 0.4 + Clip.attack.period)
        for (a, b) in zip(once, again) {
            XCTAssertLessThan(((a.c3 - b.c3) * (a.c3 - b.c3)).sum(), 1e-8)
        }
    }

    func testItEasesFromClipToClip() throws {
        let model = try arm()
        let skeleton = try XCTUnwrap(model.skeleton)
        let at: Float = 22.0 / 30
        XCTAssertEqual(skeleton.pose(.attack, at: at, from: .idle, at: 0, weight: 0), model.pose(.attack, at: at), "Nothing of the old clip")
        let all = skeleton.pose(.attack, at: at, from: .idle, at: 0, weight: 1)
        for (a, b) in zip(all, model.pose(.idle, at: 0)) {
            XCTAssertLessThan(((a.c3 - b.c3) * (a.c3 - b.c3)).sum(), 1e-8, "All of the old clip")
        }
        // Halfway: the forearm half turned toward the thrust.
        let half = skeleton.pose(.attack, at: at, from: .idle, at: 0, weight: 0.5)
        let metal = model.mesh.vertices.filter { $0.material == .metal }
        let middle = metal.reduce(Vec3.zero) { $0 + $1.posed(half) } / Float(metal.count)
        XCTAssertEqual(atan2(middle.z, middle.y - 1), Float.pi / 4, accuracy: 0.03, "\(middle)")
    }

    func testItsMaterialsAreTheWorldsByTheirNames() throws {
        let model = try arm()
        let skin = try XCTUnwrap(model.mesh.vertices.first { $0.material == .house })
        XCTAssertEqual(skin.surface, .timber, "house_timber_shaft: the House's colour, timber's grain")
        XCTAssertLessThan((skin.color - Vec3(0.5, 0.4, 0.3)).length, 0.01, "Its colour in sRGB, as it was chosen")
        let block = try XCTUnwrap(model.mesh.vertices.first { $0.material == .metal })
        XCTAssertEqual(block.surface, .smooth)
        XCTAssertLessThan((block.color - Vec3(0.7, 0.7, 0.75)).length, 0.01)
        XCTAssertTrue(model.mesh.packed.allSatisfy { $0.material != nil }, "Packs for the GPU")
    }

    func testItTakesTheScaleItIsGiven() throws {
        let model = try arm(scale: 0.5)
        XCTAssertEqual(model.mesh.bounds.max.y, 1.175, accuracy: 1e-3)
        XCTAssertEqual(model.rig.bones[2].pivot.y, 0.5, accuracy: 1e-4)
        XCTAssertLessThan((block(model, .attack, 22.0 / 30) - Vec3(0, 0.5, 0.6)).length, 2e-3)
    }

    /// What the package carries is each model's file as it was made: run
    /// Art/embed.py after making a model again.
    func testTheEmbeddedModelsAreTheirFiles() throws {
        let models = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Art/models")
        XCTAssertEqual(try Asset.bytes(base64: Art.spearman), try Data(contentsOf: models.appendingPathComponent("spearman.glb")))
        XCTAssertEqual(try Asset.bytes(base64: Art.archer), try Data(contentsOf: models.appendingPathComponent("archer.glb")))
        XCTAssertEqual(try Asset.bytes(base64: Fixtures.arm), try Data(contentsOf: models.appendingPathComponent("fixture-arm.glb")))
    }

    func testWhatIsNotAModelIsRefusedAsSuch() throws {
        XCTAssertThrowsError(try Asset.model(name: "x", glb: Data("not a model at all".utf8))) { error in
            XCTAssertEqual(error as? Asset.Failure, .notGLB)
        }
        // glTF's header over a chunk that runs past the file's end.
        var broken = Data()
        for word: UInt32 in [0x4654_6C67, 2, 40, 200, 0x4E4F_534A] { withUnsafeBytes(of: word.littleEndian) { broken.append(contentsOf: $0) } }
        XCTAssertThrowsError(try Asset.model(name: "x", glb: broken)) { error in
            guard case .malformed? = error as? Asset.Failure else { return XCTFail("\(error)") }
        }
        XCTAssertEqual(Asset.Failure.notGLB.description, "Not a glTF binary file.")
        XCTAssertThrowsError(try Asset.bytes(base64: "%%%"))
    }
}
