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

    /// The fixture arm's JSON and binary buffer, to be changed and packed
    /// again (`glb`).
    private func armParts() throws -> (json: [String: Any], bin: Data) {
        let data = try Asset.bytes(base64: Fixtures.arm)
        func word(_ at: Int) -> Int {
            Int(UInt32(littleEndian: data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: at, as: UInt32.self) }))
        }
        let text = word(12), binary = 20 + text
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data.subdata(in: 20..<binary)) as? [String: Any])
        return (json, data.subdata(in: (binary + 8)..<(binary + 8 + word(binary))))
    }

    /// A glTF binary of a JSON's text and a buffer, each padded as the format asks.
    private func glb(text: Data, bin: Data) -> Data {
        var text = text, bin = bin
        while text.count % 4 != 0 { text.append(0x20) }
        while bin.count % 4 != 0 { bin.append(0) }
        var data = Data()
        for word in [0x4654_6C67, 2, 28 + text.count + bin.count, text.count, 0x4E4F_534A] {
            withUnsafeBytes(of: UInt32(word).littleEndian) { data.append(contentsOf: $0) }
        }
        data.append(text)
        for word in [bin.count, 0x004E_4942] { withUnsafeBytes(of: UInt32(word).littleEndian) { data.append(contentsOf: $0) } }
        data.append(bin)
        return data
    }

    private func glb(_ json: [String: Any], _ bin: Data) throws -> Data {
        glb(text: try JSONSerialization.data(withJSONObject: json), bin: bin)
    }

    /// The arm read from its parts as changed.
    private func arm(_ change: (inout [String: Any], inout Data) throws -> Void, variant: String? = nil,
                     order: [String] = []) throws -> Model {
        var (json, bin) = try armParts()
        try change(&json, &bin)
        return try Asset.model(name: "arm", glb: try glb(json, bin), order: order, variant: variant)
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
        // A clip it has no action for plays its idle, in its own time:
        // halfway through a march, halfway through the idle.
        XCTAssertEqual(model.pose(.march, at: 0.5 * Clip.march.period), model.pose(.idle, at: 0.5 * Clip.idle.period))
        for (a, b) in zip(model.pose(.march, at: 0.2), model.pose(.march, at: 0.2 + Clip.march.period)) {
            XCTAssertLessThan(((a.c3 - b.c3) * (a.c3 - b.c3)).sum(), 1e-8, "and comes round in the clip's")
        }
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

    /// Raised as it is read: at rest, and as each clip moves it, all of it
    /// stands the lift higher, its bones' pivots with it.
    func testItTakesTheLiftItIsGiven() throws {
        let plain = try arm(), raised = try Asset.model(name: "arm", glb: try Asset.bytes(base64: Fixtures.arm), lift: 0.25)
        XCTAssertEqual(raised.mesh.bounds.min.y, 0.25, accuracy: 1e-4)
        XCTAssertEqual(raised.mesh.bounds.max.y, plain.mesh.bounds.max.y + 0.25, accuracy: 1e-4)
        XCTAssertEqual(raised.rig.bones[2].pivot.y, plain.rig.bones[2].pivot.y + 0.25, accuracy: 1e-4)
        for time: Float in [0, 11.0 / 30, 22.0 / 30] {
            XCTAssertLessThan((block(raised, .attack, time) - block(plain, .attack, time) - Vec3(0, 0.25, 0)).length, 1e-4, "at \(time)")
        }
        let scaled = try Asset.model(name: "arm", glb: try Asset.bytes(base64: Fixtures.arm), scale: 0.5, lift: 0.1)
        XCTAssertLessThan((block(scaled, .attack, 22.0 / 30) - Vec3(0, 0.6, 0.6)).length, 2e-3, "scaled about its origin, then lifted")
    }

    /// An action tagged for a variant is that variant's own in place of the
    /// one for all; every other read plays the one for all.
    func testAVariantPlaysItsOwnActions() throws {
        let read = { (variant: String?) in try Asset.model(name: "arm", glb: try Asset.bytes(base64: Fixtures.arm), variant: variant) }
        let plain = try arm(), other = try read("other"), elsewhere = try read("elsewhere")
        XCTAssertLessThan((block(plain, .attack, 22.0 / 30) - Vec3(0, 1, 1.2)).length, 4e-3)
        XCTAssertLessThan((block(other, .attack, 22.0 / 30) - Vec3(0, 1, -1.2)).length, 4e-3, "its own strike, the elbow bent the other way")
        XCTAssertLessThan((block(elsewhere, .attack, 22.0 / 30) - Vec3(0, 1, 1.2)).length, 4e-3, "another variant's: the strike for all")
        XCTAssertEqual(other.pose(.idle, at: 1), plain.pose(.idle, at: 1), "its idle the one for all")
        XCTAssertEqual(try XCTUnwrap(other.skeleton).clips, [.idle, .attack])
        let tiered = try Asset.model(name: "arm", glb: try Asset.bytes(base64: Fixtures.arm), tier: 2)
        XCTAssertEqual(tiered.pose(.attack, at: 0.7), plain.pose(.attack, at: 0.7), "a tier reads no variant's own")
    }

    /// A material given a colour of its own by its name: what it covers in
    /// that colour, the rest as it was made.
    func testItTakesTheColoursItIsGiven() throws {
        let coloured = try Asset.model(name: "arm", glb: try Asset.bytes(base64: Fixtures.arm),
                                       colours: ["house_timber_shaft": Vec3(0.2, 0.4, 0.6)])
        let skin = coloured.mesh.vertices.filter { $0.material == .house }
        XCTAssertFalse(skin.isEmpty)
        XCTAssertTrue(skin.allSatisfy { $0.color == Vec3(0.2, 0.4, 0.6) })
        XCTAssertTrue(coloured.mesh.vertices.filter { $0.material == .metal }.allSatisfy { ($0.color - Vec3(0.7, 0.7, 0.75)).length < 0.01 },
                      "the block as it was made")
    }

    /// A material's grain can be given in place of the one its name gives:
    /// the arm's House timber made stone, its iron left as it was.
    func testItTakesTheGrainsItIsGiven() throws {
        let made = try Asset.model(name: "arm", glb: try Asset.bytes(base64: Fixtures.arm))
        let grained = try Asset.model(name: "arm", glb: try Asset.bytes(base64: Fixtures.arm), grains: ["house_timber_shaft": .stone])
        let shaft = grained.mesh.vertices.filter { $0.material == .house }
        XCTAssertFalse(shaft.isEmpty)
        XCTAssertTrue(made.mesh.vertices.filter { $0.material == .house }.allSatisfy { $0.surface == .timber }, "timber as it was named")
        XCTAssertTrue(shaft.allSatisfy { $0.surface == .stone })
        XCTAssertEqual(grained.mesh.vertices.filter { $0.material == .metal }.map(\.surface),
                       made.mesh.vertices.filter { $0.material == .metal }.map(\.surface), "the block as it was made")
    }

    /// What the package carries is each model's file as it was made: run
    /// Art/embed.py after making a model again.
    func testTheEmbeddedModelsAreTheirFiles() throws {
        let models = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Art/models")
        XCTAssertEqual(try Asset.bytes(base64: Art.spearman), try Data(contentsOf: models.appendingPathComponent("spearman.glb")))
        XCTAssertEqual(try Asset.bytes(base64: Art.archer), try Data(contentsOf: models.appendingPathComponent("archer.glb")))
        XCTAssertEqual(try Asset.bytes(base64: Art.lantern), try Data(contentsOf: models.appendingPathComponent("lantern.glb")))
        XCTAssertEqual(try Asset.bytes(base64: Art.horseman), try Data(contentsOf: models.appendingPathComponent("rider.glb")))
        XCTAssertEqual(try Asset.bytes(base64: Art.heroes), try Data(contentsOf: models.appendingPathComponent("commanders.glb")))
        XCTAssertEqual(try Asset.bytes(base64: Art.engine), try Data(contentsOf: models.appendingPathComponent("mangonel.glb")))
        XCTAssertEqual(try Asset.bytes(base64: Art.settler), try Data(contentsOf: models.appendingPathComponent("founder.glb")))
        for (embedded, file) in [(Art.hollow, "hollow.glb"), (Art.thornwight, "thornwight.glb"), (Art.colossus, "colossus.glb"),
                                 (Art.townsfolk, "folk.glb"), (Art.carters, "carters.glb"), (Art.holdKeep, "keep.glb"),
                                 (Art.seatKeep, "seat.glb"), (Art.wallsFile, "walls.glb"), (Art.townFile, "town.glb"),
                                 (Art.granaryFile, "granary.glb"), (Art.beaconFile, "beacon.glb"),
                                 (Art.forgeFile, "forge.glb"), (Art.saltworksFile, "saltworks.glb"), (Art.quarryFile, "quarry.glb"),
                                 (Art.sawpitFile, "sawpit.glb"), (Art.moonspireFile, "moonspire.glb"),
                                 (Art.musterHallFile, "musterhall.glb"), (Art.hallFile, "hall.glb"),
                                 (Art.archiveFile, "archive.glb"), (Art.infirmaryFile, "infirmary.glb"),
                                 (Art.lodgeFile, "lodge.glb"), (Art.wayhouseFile, "wayhouse.glb"), (Art.lyceumFile, "lyceum.glb"),
                                 (Art.shrinesFile, "shrines.glb"), (Art.storesFile, "stores.glb"),
                                 (Art.sitesFile, "sites.glb"), (Art.lairsFile, "lairs.glb"),
                                 (Art.raisingFile, "raising.glb"), (Art.propsFile, "props.glb"),
                                 (Art.furnishingsFile, "furnishings.glb"), (Art.tokensFile, "tokens.glb"),
                                 (Art.marksFile, "marks.glb"), (Art.furiesFile, "furies.glb")] {
            XCTAssertEqual(try Asset.bytes(base64: embedded), try Data(contentsOf: models.appendingPathComponent(file)), file)
        }
        XCTAssertEqual(try Asset.bytes(base64: Fixtures.arm), try Data(contentsOf: models.appendingPathComponent("fixture-arm.glb")))
    }

    /// A piece's name says the tiers and the variants it is drawn for: a
    /// tier by its number or a span of them, a variant by its name, letters
    /// and then any digits, as a crest's charges and the talents' sigils are
    /// named.
    func testAPiecesNameSaysTheTiersAndVariantsItIsDrawnFor() {
        let charge = Asset.tags("charge@crestCharge3,crestCharge10!fine")
        XCTAssertEqual(charge.name, "charge")
        XCTAssertEqual(charge.variants, ["crestCharge3", "crestCharge10"])
        XCTAssertTrue(charge.fine)
        XCTAssertTrue(charge.drawn(tier: 1, variant: "crestCharge10"))
        XCTAssertFalse(charge.drawn(tier: 1, variant: "crestCharge1"), "Each charge its own")
        XCTAssertEqual(Asset.tags("tower@2-4,5").tiers, [2...4, 5...5])
        XCTAssertEqual(Asset.tags("ring@talentSigil0").variants, ["talentSigil0"])
        XCTAssertTrue(Asset.tags("stub@3rd").always, "Neither a tier nor a variant")
        XCTAssertEqual(Asset.tags("plain").name, "plain")
    }

    func testTheArmPackedAgainIsTheArm() throws {
        let packed = try arm { _, _ in }
        XCTAssertEqual(packed.mesh.vertices, try arm().mesh.vertices, "What the tests change is read as the fixture is")
        XCTAssertEqual(packed.pose(.attack, at: 0.4), try arm().pose(.attack, at: 0.4))
    }

    /// A node may be given as one matrix in place of its parts (glTF's
    /// `matrix`): it stands where the same parts would stand it.
    func testANodeGivenAsAMatrixStandsAsItsPartsWould() throws {
        func nodes(_ json: inout [String: Any], _ change: (inout [String: Any]) -> Void) {
            var all = json["nodes"] as? [[String: Any]] ?? []
            change(&all[4])
            json["nodes"] = all
        }
        let parts = try arm { json, _ in nodes(&json) { $0["translation"] = [0.5, 0, 0.25] } }
        let matrix = try arm { json, _ in nodes(&json) { $0["matrix"] = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0.5, 0, 0.25, 1] } }
        XCTAssertEqual(matrix.mesh.vertices.map(\.position), parts.mesh.vertices.map(\.position))
        XCTAssertNotEqual(matrix.mesh.vertices.map(\.position), try arm().mesh.vertices.map(\.position), "The arm moved by its root")
        for time: Float in [0, 0.4, 1.1] {
            XCTAssertEqual(matrix.pose(.idle, at: time), parts.pose(.idle, at: time))
            XCTAssertEqual(matrix.pose(.attack, at: time), parts.pose(.attack, at: time))
        }
    }

    /// A variant's own action plays in place of the one for all, whichever
    /// the file writes first.
    func testAVariantsOwnActionWinsWhereverItIsWritten() throws {
        let written = try arm({ _, _ in }, variant: "other")
        let ownFirst = try arm({ json, _ in
            let actions = json["animations"] as? [[String: Any]] ?? []
            json["animations"] = [actions[1], actions[0], actions[2]]
        }, variant: "other")
        XCTAssertLessThan((block(ownFirst, .attack, 22.0 / 30) - Vec3(0, 1, -1.2)).length, 4e-3, "its own strike, written first")
        for time: Float in [0.2, 0.7, 1.3] {
            XCTAssertEqual(ownFirst.pose(.attack, at: time), written.pose(.attack, at: time))
        }
    }

    /// Colours painted on its vertices (glTF's `COLOR_0`, here as
    /// normalised integers, as Blender may write them) tint its material's.
    func testColoursPaintedOnItsVerticesTintItsMaterial() throws {
        let tinted = try arm { json, bin in
            var views = json["bufferViews"] as? [[String: Any]] ?? [], accessors = json["accessors"] as? [[String: Any]] ?? []
            var meshes = json["meshes"] as? [[String: Any]] ?? [], buffers = json["buffers"] as? [[String: Any]] ?? []
            views.append(["buffer": 0, "byteOffset": bin.count, "byteLength": 24 * 8])
            for _ in 0..<24 {
                for value: UInt16 in [65535, 32768, 0, 65535] { withUnsafeBytes(of: value.littleEndian) { bin.append(contentsOf: $0) } }
            }
            buffers[0]["byteLength"] = bin.count
            accessors.append(["bufferView": views.count - 1, "componentType": 5123, "normalized": true, "count": 24, "type": "VEC4"])
            var block = meshes[1]["primitives"] as? [[String: Any]] ?? []
            var attributes = block[0]["attributes"] as? [String: Any] ?? [:]
            attributes["COLOR_0"] = accessors.count - 1
            block[0]["attributes"] = attributes
            meshes[1]["primitives"] = block
            json["bufferViews"] = views
            json["accessors"] = accessors
            json["meshes"] = meshes
            json["buffers"] = buffers
        }
        let plain = try arm().mesh.vertices.filter { $0.material == .metal }, painted = tinted.mesh.vertices.filter { $0.material == .metal }
        XCTAssertEqual(painted.count, plain.count)
        for (paint, was) in zip(painted, plain) {
            XCTAssertEqual(paint.color.x, was.color.x, accuracy: 1e-5, "red kept whole")
            XCTAssertLessThan(paint.color.y, was.color.y * 0.8, "green halved, as light")
            XCTAssertEqual(paint.color.z, 0, accuracy: 1e-6, "blue taken away")
        }
        XCTAssertEqual(tinted.mesh.vertices.filter { $0.material != .metal }, try arm().mesh.vertices.filter { $0.material != .metal },
                       "the skin, unpainted, as it was")
    }

    /// glTF's normalised integers read as the spec has them stand for floats.
    func testNormalisedIntegersAreReadAsTheSpecSays() {
        XCTAssertEqual(Asset.float(normalized: 255, componentType: 5121), 1)
        XCTAssertEqual(Asset.float(normalized: 51, componentType: 5121), 0.2)
        XCTAssertEqual(Asset.float(normalized: 65535, componentType: 5123), 1)
        XCTAssertEqual(Asset.float(normalized: 127, componentType: 5120), 1)
        XCTAssertEqual(Asset.float(normalized: -128, componentType: 5120), -1, "the least held at -1")
        XCTAssertEqual(Asset.float(normalized: 32767, componentType: 5122), 1)
        XCTAssertEqual(Asset.float(normalized: -32768, componentType: 5122), -1)
        XCTAssertEqual(Asset.float(normalized: 3, componentType: 5126), 3, "a float as it is")
    }

    /// Triangles written without indices are drawn in the order written.
    func testTrianglesWrittenWithoutIndicesAreDrawnInOrder() throws {
        let unindexed = try arm { json, _ in
            var meshes = json["meshes"] as? [[String: Any]] ?? []
            var block = meshes[1]["primitives"] as? [[String: Any]] ?? []
            block[0]["indices"] = nil
            meshes[1]["primitives"] = block
            json["meshes"] = meshes
        }
        let indexed = try arm()
        let blockFrom = indexed.mesh.vertices.count - 24
        XCTAssertEqual(unindexed.mesh.vertices, indexed.mesh.vertices)
        XCTAssertEqual(Array(unindexed.mesh.indices.suffix(24)), (0..<24).map { UInt32(blockFrom + $0) })
        XCTAssertEqual(unindexed.mesh.indices.count, indexed.mesh.indices.count - 36 + 24)
    }

    /// What claims to be the arm but is written wrongly is refused, never
    /// read as something else.
    func testWhatIsWrittenWronglyIsRefused() throws {
        func refused(_ note: String, _ read: () throws -> Model) {
            XCTAssertThrowsError(try read(), note) { error in
                guard case .malformed? = error as? Asset.Failure else { return XCTFail("\(note): \(error)") }
            }
        }
        let bin = try armParts().bin
        refused("its JSON broken") { try Asset.model(name: "x", glb: glb(text: Data("{ \"nodes\": [".utf8), bin: bin)) }
        refused("an accessor running past its buffer") {
            try arm { json, _ in
                var accessors = json["accessors"] as? [[String: Any]] ?? []
                accessors[2]["count"] = 100_000
                json["accessors"] = accessors
            }
        }
        refused("an action's keys too few for its times") {
            try arm { json, _ in
                var actions = json["animations"] as? [[String: Any]] ?? []
                var samplers = actions[2]["samplers"] as? [[String: Any]] ?? []
                samplers[1]["output"] = 9
                actions[2]["samplers"] = samplers
                json["animations"] = actions
            }
        }
        refused("a bone asked for that it hasn't") { try arm({ _, _ in }, order: ["wing"]) }
        refused("a bone asked for before the one it hangs from") { try arm({ _, _ in }, order: ["lower"]) }
        XCTAssertNoThrow(try arm({ _, _ in }, order: ["upper", "lower"]), "the bones it has, each after the one it hangs from")
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
