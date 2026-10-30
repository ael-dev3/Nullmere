import NullmereCore
@testable import NullmereModels
import XCTest

final class MathTests: XCTestCase {
    func assertClose(_ a: Vec3, _ b: Vec3, _ tolerance: Float = 1e-4, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertLessThan((a - b).length, tolerance, "\(a) is not \(b)", file: file, line: line)
    }

    func testATransformAndItsInverseUndoEachOther() throws {
        let m = Mat4.translation(Vec3(1, -2, 3)) * Mat4.rotation(Vec3(0.3, -1.1, 0.7)) * Mat4.scale(Vec3(2, 0.5, 1.5))
        let inverse = try XCTUnwrap(m.inverse)
        let p = Vec3(0.25, 4, -7)
        assertClose(inverse.transformPoint(m.transformPoint(p)), p)
        assertClose((m * inverse).transformPoint(p), p)
        XCTAssertNil(Mat4.scale(Vec3(1, 0, 1)).inverse, "a flattening has no inverse")
    }

    func testTurnsGoTheWaysTheySay() {
        assertClose(Mat4.rotationY(.pi / 2).transformPoint(Vec3(0, 0, 1)), Vec3(1, 0, 0))
        assertClose(Mat4.rotationX(.pi / 2).transformPoint(Vec3(0, 1, 0)), Vec3(0, 0, 1))
        assertClose(Mat4.rotationZ(.pi / 2).transformPoint(Vec3(1, 0, 0)), Vec3(0, 1, 0))
        assertClose(Mat4.rotation(axis: Vec3(0, 1, 0), angle: .pi / 2).transformPoint(Vec3(0, 0, 1)), Vec3(1, 0, 0))
        for direction in [Vec3(1, 1, 0), Vec3(0, -1, 0), Vec3(0, 1, 0), Vec3(-0.3, 0.2, 0.9)] {
            assertClose(Mat4.aligningUp(to: direction).transformDirection(.up), direction.normalized)
        }
        XCTAssertTrue(Mat4.scale(Vec3(-1, 1, 1)).isMirroring)
        XCTAssertFalse(Mat4.rotation(Vec3(1, 2, 3)).isMirroring)
    }

    func testTheCameraLooksAtItsTarget() {
        let eye = Vec3(3, 10, 12), target = Vec3(1, 0, -2)
        let view = Mat4.lookAt(eye: eye, target: target)
        assertClose(view.transformPoint(eye), .zero)
        let seen = view.transformPoint(target)
        XCTAssertLessThan(seen.z, 0, "the camera looks down its own -z")
        XCTAssertEqual(seen.x, 0, accuracy: 1e-4)
        XCTAssertEqual(seen.y, 0, accuracy: 1e-4)
        let projection = Mat4.perspective(fovY: 0.6, aspect: 1.5, near: 0.5, far: 200)
        let near = projection.apply(Vec4(0, 0, -0.5, 1)), far = projection.apply(Vec4(0, 0, -200, 1))
        XCTAssertEqual(near.z / near.w, 0, accuracy: 1e-5)
        XCTAssertEqual(far.z / far.w, 1, accuracy: 1e-5)
        let ortho = Mat4.orthographic(left: -2, right: 4, bottom: -1, top: 3, near: 1, far: 9)
        assertClose(ortho.transformPoint(Vec3(-2, -1, -1)), Vec3(-1, -1, 0))
        assertClose(ortho.transformPoint(Vec3(4, 3, -9)), Vec3(1, 1, 1))
    }

    func testNoiseIsSmoothAndRepeatable() {
        XCTAssertEqual(Noise.value(3.3, -7.1), Noise.value(3.3, -7.1))
        XCTAssertNotEqual(Noise.value(3.3, -7.1, seed: 1), Noise.value(3.3, -7.1, seed: 2))
        for i in 0..<200 {
            let x = Float(i) * 0.37 - 30, y = Float(i % 17) * 0.91 - 8
            for value in [Noise.value(x, y), Noise.fractal(x, y), Noise.ridged(x, y)] {
                XCTAssertGreaterThanOrEqual(value, 0)
                XCTAssertLessThanOrEqual(value, 1)
            }
            XCTAssertLessThan(abs(Noise.value(x, y) - Noise.value(x + 0.001, y)), 0.01, "no seams")
        }
    }
}

final class MeshTests: XCTestCase {
    /// Every triangle of a convex solid faces away from its middle.
    func assertFacesOut(_ mesh: Mesh, from centre: Vec3, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(mesh.isEmpty, file: file, line: line)
        for (a, b, c) in mesh.triangles {
            let middle = (a.position + b.position + c.position) / 3
            XCTAssertGreaterThan(a.normal.dot(middle - centre), 0, "a face looks inward at \(middle)", file: file, line: line)
            let n = (b.position - a.position).cross(c.position - a.position).normalized
            XCTAssertGreaterThan(n.dot(a.normal), 0.99, "the winding and the normal agree", file: file, line: line)
        }
    }

    func testSolidsFaceOutward() {
        var builder = MeshBuilder()
        builder.box(center: Vec3(1, 2, 3), size: Vec3(2, 1, 0.5), color: Vec3(1, 1, 1))
        XCTAssertEqual(builder.mesh.triangleCount, 12)
        assertFacesOut(builder.mesh, from: Vec3(1, 2, 3))

        var tower = MeshBuilder()
        tower.prism(sides: 7, radius: 0.5, topRadius: 0.3, from: 0, to: 2, color: Vec3(0.5, 0.5, 0.5))
        assertFacesOut(tower.mesh, from: Vec3(0, 1, 0))

        var cone = MeshBuilder()
        cone.cone(sides: 6, radius: 1, to: 2, color: Vec3(1, 0, 0))
        XCTAssertEqual(cone.mesh.triangleCount, 6 + 4, "six sides and a base, its point not doubled")
        assertFacesOut(cone.mesh, from: Vec3(0, 0.5, 0))

        var ball = MeshBuilder()
        ball.sphere(center: Vec3(0, 3, 0), radius: 1, rings: 5, sides: 8, color: Vec3(1, 1, 1))
        assertFacesOut(ball.mesh, from: Vec3(0, 3, 0))

        var roof = MeshBuilder()
        roof.gableRoof(width: 2, depth: 1, base: 0, height: 0.8, color: Vec3(1, 1, 1))
        assertFacesOut(roof.mesh, from: Vec3(0, 0.25, 0))
    }

    func testPlacedAndMirroredSolidsStillFaceOutward() {
        var builder = MeshBuilder()
        let placement = Mat4.translation(Vec3(5, 0, -2)) * Mat4.rotationY(0.8) * Mat4.scale(Vec3(-1, 1, 1))
        builder.place(placement) { $0.box(center: .zero, size: Vec3(1, 1, 1), color: Vec3(1, 1, 1)) }
        assertFacesOut(builder.mesh, from: Vec3(5, 0, -2))
        XCTAssertEqual(builder.transform, .identity, "a placement ends with its body")

        var strut = MeshBuilder()
        strut.strut(from: Vec3(0, 0, 0), to: Vec3(1, 1, 1), radius: 0.05, color: Vec3(1, 1, 1))
        let bounds = strut.mesh.bounds
        XCTAssertGreaterThan(bounds.max.y, 0.95)
        XCTAssertLessThan(bounds.min.y, 0.05)
    }

    func testPartsMaterialsAndSwayAreCarried() {
        var builder = MeshBuilder()
        builder.with(part: 3, material: .foliage, sway: 1) {
            $0.swayRange = (0, 1)
            $0.cone(sides: 5, radius: 0.5, to: 1, color: Vec3(0, 1, 0))
        }
        builder.box(center: .zero, size: Vec3(1, 1, 1), color: Vec3(1, 1, 1))
        let leaves = builder.mesh.vertices.filter { $0.material == .foliage }
        XCTAssertFalse(leaves.isEmpty)
        XCTAssertTrue(leaves.allSatisfy { $0.part == 3 })
        XCTAssertEqual(leaves.map(\.sway).max() ?? 0, 1, accuracy: 1e-5, "the tip sways fully")
        XCTAssertEqual(leaves.map(\.sway).min() ?? 1, 0, accuracy: 1e-5, "the foot stands")
        XCTAssertEqual(builder.mesh.parts, [0, 3])
        XCTAssertNil(builder.swayRange, "the sway's range ends with its body")
        XCTAssertEqual(builder.material, .plain)
    }

    func testTheGPUReadsVerticesAsTheShadersDeclareThem() {
        XCTAssertEqual(MemoryLayout<PackedVertex>.size, 24)
        XCTAssertEqual(MemoryLayout<PackedVertex>.stride, 24)
        XCTAssertEqual(MemoryLayout<PackedVertex>.offset(of: \.normalMaterial), 12)
        XCTAssertEqual(MemoryLayout<PackedVertex>.offset(of: \.colorSway), 16)
        XCTAssertEqual(MemoryLayout<PackedVertex>.offset(of: \.part), 20)
        XCTAssertEqual(MemoryLayout<PackedVertex>.offset(of: \.surfaceCode), 22)
        XCTAssertEqual(MemoryLayout<Mat4>.size, 64)
        let vertex = MeshVertex(position: Vec3(1.5, -2, 3), normal: Vec3(0.3, 0.9, -0.2), color: Vec3(0.2, 0.6, 1),
                                part: 7, material: .metal, sway: 0.4, surface: .slate)
        let packed = PackedVertex(vertex)
        XCTAssertEqual(packed.position, vertex.position)
        XCTAssertLessThan((packed.normal - vertex.normal.normalized).length, 0.02)
        XCTAssertLessThan((packed.color - vertex.color).length, 0.01)
        XCTAssertEqual(packed.material, .metal)
        XCTAssertEqual(packed.sway, 0.4, accuracy: 0.01)
        XCTAssertEqual(packed.part, 7)
        XCTAssertEqual(packed.surface, .slate)
    }

    func testSurfacesTakeTheGrainOfWhatTheyAreMadeOf() {
        XCTAssertEqual(Surface.of(Palette.stone), .stone)
        XCTAssertEqual(Surface.of(Palette.stonePale.mix(Palette.stone, 0.4)), .stone, "Mixed between two stones, still stone")
        XCTAssertEqual(Surface.of(Palette.timberGrey), .timber)
        XCTAssertEqual(Surface.of(Palette.thatch), .thatch)
        XCTAssertEqual(Surface.of(Palette.slate), .slate)
        XCTAssertEqual(Surface.of(Palette.yard), .earth)
        XCTAssertEqual(Surface.of(Palette.iron), .smooth, "Iron, though near dark stone, is smooth")
        XCTAssertEqual(Surface.of(Palette.house), .smooth)
        XCTAssertEqual(Surface.of(Vec3(0.9, 0.1, 0.1)), .smooth, "A colour of no grain")
        XCTAssertEqual(Surface.allCases.map(\.rawValue), [0, 1, 2, 3, 4, 5])

        var builder = MeshBuilder()
        builder.box(center: .zero, size: Vec3(1, 1, 1), color: Palette.stone)
        XCTAssertTrue(builder.mesh.vertices.allSatisfy { $0.surface == .stone })
        builder.material = .glow
        builder.box(center: .zero, size: Vec3(1, 1, 1), color: Palette.stone)
        XCTAssertEqual(builder.mesh.vertices.last?.surface, .smooth, "What glows shows its light, not its grain")
        builder.material = .plain
        builder.surface = .thatch
        builder.box(center: .zero, size: Vec3(1, 1, 1), color: Palette.wool)
        XCTAssertEqual(builder.mesh.vertices.last?.surface, .thatch, "A grain asked for is the grain given")

        // A keep is mostly stone; a company's soldiers mostly smooth.
        func share(_ surface: Surface, of key: ModelKey) -> Double {
            let vertices = Library.model(key).mesh.vertices
            return Double(vertices.filter { $0.surface == surface }.count) / Double(max(vertices.count, 1))
        }
        XCTAssertGreaterThan(share(.stone, of: .keep(seat: true)), 0.4)
        XCTAssertGreaterThan(share(.timber, of: .scaffold), 0.6)
        XCTAssertGreaterThan(share(.smooth, of: .figure(.spear, tier: 1)), 0.5)
    }

    func testAppendingMovesTheOtherMesh() {
        var part = MeshBuilder()
        part.box(center: .zero, size: Vec3(1, 1, 1), color: Vec3(1, 1, 1))
        var whole = Mesh()
        whole.append(part.mesh)
        whole.append(part.mesh, transform: .translation(Vec3(10, 0, 0)))
        XCTAssertEqual(whole.triangleCount, 24)
        XCTAssertEqual(whole.bounds.max.x, 10.5, accuracy: 1e-5)
        XCTAssertTrue(whole.indices.allSatisfy { Int($0) < whole.vertices.count })
    }
}

final class RigTests: XCTestCase {
    func testAPartTurnsAboutItsPivotAndCarriesItsChildren() {
        var rig = Rig()
        let arm = rig.add("arm", pivot: Vec3(0, 1, 0))
        let hand = rig.add("hand", parent: Int(arm), pivot: Vec3(1, 1, 0))
        XCTAssertEqual(rig.index(of: "hand"), Int(hand))
        var joints = [Joint](repeating: .rest, count: rig.count)
        joints[Int(arm)] = Joint(rotation: Vec3(0, 0, .pi / 2))
        let pose = rig.pose(joints)
        let pivot = pose[Int(arm)].transformPoint(Vec3(0, 1, 0))
        XCTAssertLessThan((pivot - Vec3(0, 1, 0)).length, 1e-5, "the shoulder stays put")
        let fingertip = pose[Int(hand)].transformPoint(Vec3(1, 1, 0))
        XCTAssertLessThan((fingertip - Vec3(0, 2, 0)).length, 1e-5, "the hand swings up with the arm")
        XCTAssertEqual(rig.pose([]), [Mat4](repeating: .identity, count: 3), "with no joints, all stands at rest")
    }

    func testAModelPosesItsClips() {
        var rig = Rig()
        rig.add("blade", pivot: .zero)
        let model = Model(name: "blade", mesh: Mesh(), rig: rig) { clip, time in
            [.rest, Joint(offset: Vec3(0, clip == .march ? time : 0, 0))]
        }
        XCTAssertEqual(model.pose(.march, at: 2)[1].transformPoint(.zero), Vec3(0, 2, 0))
        XCTAssertEqual(model.pose(.idle, at: 2)[1].transformPoint(.zero), .zero)
        XCTAssertEqual(Model(name: "stone", mesh: Mesh()).pose(.idle, at: 1), [.identity])
    }
}

final class ReliefTests: XCTestCase {
    static let state = GameState(settings: GameSettings(seedText: "relief", houseCount: 6, radius: 14))
    static let relief = Relief(map: state.map)

    func testEachHexStandsAtItsTerrainsHeight() {
        let map = ReliefTests.state.map
        for hex in map.hexes {
            let tile = map[hex]!
            let height = ReliefTests.relief.height(of: hex)
            switch tile.terrain {
            case .still: XCTAssertLessThan(height, -0.5, "\(hex)")
            case .shallows: XCTAssertLessThan(height, 0, "\(hex) lies under the water")
            case .spine: XCTAssertGreaterThan(height, 1.2, "\(hex)")
            case .strand, .saltFlat: XCTAssertGreaterThan(height, 0, "\(hex) stands dry")
            case .greyfield, .blackwood, .barrow: XCTAssertGreaterThan(height, 0.1, "\(hex)")
            }
        }
    }

    func testTheLandHasNoSeams() {
        let relief = ReliefTests.relief
        var x: Float = -20
        while x < 20 {
            var z: Float = -18
            while z < 18 {
                let here = relief.height(atX: x, z: z)
                XCTAssertLessThan(abs(here - relief.height(atX: x + 0.002, z: z)), 0.05, "a cliff at \(x), \(z)")
                XCTAssertLessThan(abs(here - relief.height(atX: x, z: z + 0.002)), 0.05, "a cliff at \(x), \(z)")
                z += 0.173
            }
            x += 0.211
        }
    }

    func testThreeHeartsSurroundEveryPoint() {
        for (x, z) in [(Float(0.1), Float(0.2)), (3.7, -2.2), (-11.3, 8.9), (0, 0)] {
            let around = Relief.surrounding(x: x, z: z)
            XCTAssertEqual(around.count, 3)
            XCTAssertEqual(around.reduce(0) { $0 + $1.weight }, 1, accuracy: 1e-5)
            XCTAssertTrue(around.allSatisfy { $0.weight >= -1e-5 })
            let nearest = around.max { $0.weight < $1.weight }!.hex
            XCTAssertEqual(nearest, HexLayout(size: 1).hex(atX: Double(x), y: Double(z)), "the strongest is the hex it lies in")
        }
    }

    func testTheSpineClimbsBeyondTheMap() {
        let relief = ReliefTests.relief
        let edge = relief.heartHeight(Hex(15, 0)), further = relief.heartHeight(Hex(19, 0))
        XCTAssertGreaterThan(edge, 1.2)
        XCTAssertGreaterThan(further, edge)
        XCTAssertEqual(relief.terrain(of: Hex(40, 0)), .spine)
    }

    func testARayFindsTheLandOrTheWater() throws {
        let relief = ReliefTests.relief
        for (x, z) in [(Float(2), Float(3)), (-6, 1), (0, -9)] {
            let hit = try XCTUnwrap(relief.intersect(origin: Vec3(x, 30, z), direction: Vec3(0, -1, 0)))
            XCTAssertEqual(hit.y, max(relief.height(atX: x, z: z), Relief.waterline), accuracy: 0.01)
            XCTAssertEqual(hit.x, x, accuracy: 1e-4)
        }
        let slanted = try XCTUnwrap(relief.intersect(origin: Vec3(-20, 25, 20), direction: Vec3(1, -1.2, -0.8)))
        XCTAssertEqual(slanted.y, max(relief.height(atX: slanted.x, z: slanted.z), 0), accuracy: 0.02)
        XCTAssertNil(relief.intersect(origin: Vec3(0, 30, 0), direction: Vec3(0, 1, 0)), "looking up finds nothing")
        XCTAssertEqual(relief.intersect(origin: Vec3(0, -5, 0), direction: Vec3(0, -1, 0)), Vec3(0, -5, 0), "already under")
    }

    func testTheLandsMeshFollowsTheRelief() {
        let terrain = TerrainMesh(relief: ReliefTests.relief, spacing: 0.5)
        XCTAssertEqual(terrain.mesh.vertices.count, terrain.columns * terrain.rows)
        XCTAssertEqual(terrain.mesh.triangleCount, 2 * (terrain.columns - 1) * (terrain.rows - 1))
        XCTAssertTrue(terrain.mesh.indices.allSatisfy { Int($0) < terrain.mesh.vertices.count })
        XCTAssertTrue(terrain.mesh.vertices.allSatisfy { $0.normal.y > 0 }, "the land faces the sky")
        for (a, b, c) in terrain.mesh.triangles.prefix(500) {
            let n = (b.position - a.position).cross(c.position - a.position)
            XCTAssertGreaterThan(n.y, 0, "wound counter-clockwise seen from above")
        }
        for (x, z) in [(Float(1.3), Float(-2.6)), (-7, 5.5), (10, 10)] {
            XCTAssertEqual(terrain.height(atX: x, z: z), ReliefTests.relief.height(atX: x, z: z), accuracy: 0.12)
        }
        let low = terrain.mesh.bounds.min, high = terrain.mesh.bounds.max
        XCTAssertLessThan(low.x, -Relief.hexSpacing * 14.5)
        XCTAssertGreaterThan(high.x, Relief.hexSpacing * 14.5)
        XCTAssertLessThan(low.y, -0.5, "the lake bed")
        XCTAssertGreaterThan(high.y, 1.8, "the Spine's heights")
        let salt = terrain.mesh.vertices.filter { $0.part == Terrain.saltFlat.code }
        if !salt.isEmpty {
            XCTAssertGreaterThan(salt.map { $0.color.x }.reduce(0, +) / Float(salt.count), 0.6, "salt is white")
        }
    }
}

final class SmallPartsTests: XCTestCase {
    func testFacesTurnToLookOutward() {
        var builder = MeshBuilder()
        let square = [Vec3(0, 0, 0), Vec3(1, 0, 0), Vec3(1, 0, 1), Vec3(0, 0, 1)]
        builder.face(square, outward: Vec3(0, 1, 0), color: Vec3(1, 1, 1))
        builder.face(square, outward: Vec3(0, -1, 0), color: Vec3(1, 1, 1))
        builder.face(Array(square.prefix(2)), outward: .up, color: Vec3(1, 1, 1))
        builder.polygon(Array(square.prefix(2)), color: Vec3(1, 1, 1))
        let normals = builder.mesh.vertices.map(\.normal)
        XCTAssertEqual(normals.count, 12, "two faces of two triangles; a line is no face")
        XCTAssertEqual(normals.filter { $0.y > 0.99 }.count, 6)
        XCTAssertEqual(normals.filter { $0.y < -0.99 }.count, 6)
        XCTAssertEqual(builder.mesh.packed.count, 12)
    }

    func testTheLandFacesUpWhereItIsFlatAndTiltsOnSlopes() {
        let relief = ReliefTests.relief
        let flat = relief.normal(atX: 0, z: 0)
        XCTAssertGreaterThan(flat.y, 0.5)
        XCTAssertEqual(flat.length, 1, accuracy: 1e-4)
        let spine = Relief.centre(of: Hex(14, 0))
        XCTAssertLessThan(relief.normal(atX: spine.x - 1, z: spine.z).y, 0.999, "mountainsides lean")
    }

    func testSmallMatrixHelpers() {
        let m = Mat4.translation(Vec3(1, 2, 3))
        XCTAssertEqual(m.transposed.transposed, m)
        XCTAssertEqual(m.transposed.c0.w, 1)
        let flat = Mat4.scale(Vec3(1, 0, 1))
        XCTAssertEqual(flat.normalMatrix, flat, "a flattening keeps its normals as they are")
        XCTAssertEqual(Vec3.zero.normalized, .zero)
        XCTAssertEqual(Mat4(Vec4(1, 0, 0, 0), Vec4(0, 1, 0, 0), Vec4(0, 0, 1, 0), Vec4(0, 0, 0, 0)).transformPoint(Vec3(2, 3, 4)),
                       Vec3(2, 3, 4), "a point at infinity is left where it is")
    }

    func testKeysNameWhatTheyShow() {
        let keys: [ModelKey] = [.figure(.spear, tier: 2), .keep(seat: true), .keep(seat: false), .walls(level: 3),
                                .work(.granary, level: 1), .scaffold, .furnishing(.fir), .prop(.arrow)]
        XCTAssertEqual(keys.map(\.description), ["spear 2", "seat keep", "keep", "walls 3", "granary 1", "scaffold", "fir", "arrow"])
        let piece = Piece(key: .scaffold, transform: .identity, hex: Hex(1, 2))
        XCTAssertEqual(piece.hex, Hex(1, 2))
        XCTAssertEqual(piece.key, .scaffold)
    }
}
