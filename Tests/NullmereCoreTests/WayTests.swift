import Foundation
import XCTest
@testable import NullmereCore

/// A march keeps its way: found when the company sets out, walked pace by
/// pace, and found anew only when its next step is shut.
final class WayTests: XCTestCase {
    /// A small lake where every House has its keeper, so no steward stirs,
    /// walked pace by pace, and the keeper's Spears bound for open ground
    /// seven tiles off, the way there greyfield all along: a step a move.
    private func marching(_ seed: String) throws -> (state: GameState, spear: Int, destination: Hex) {
        var state = Scene.world(seed, houses: 3, radius: 16)
        for index in state.houses.indices { state.houses[index].isPlayer = true }
        state.pacing = Pacing()
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me)).position
        state.reveal(around: seat, range: 10, for: me)
        let spear = try XCTUnwrap(state.units(of: me).first { $0.kind == .spear })
        let destination = try XCTUnwrap(state.map.hexes.first { hex in
            hex.distance(to: spear.position) == 7 && state.map[hex]?.terrain.isPassable == true && state.isClear(hex)
                && state.wild(at: hex) == nil && state.site(at: hex) == nil && state.path(for: spear, to: hex) != nil
        })
        for hex in try XCTUnwrap(state.path(for: spear, to: destination)) where state.hold(at: hex) == nil {
            state.map.set(hex, Tile(terrain: .greyfield))
        }
        return (state, spear.id, destination)
    }

    func testAMarchKeepsItsWayFromPaceToPace() throws {
        var (state, spear, destination) = try marching("a way kept")
        _ = try state.perform(.move(unit: spear, to: destination), as: state.player)
        // Its first steps taken at once, it walks on at the next watch's paces.
        _ = state.endWatch()
        let unit = try XCTUnwrap(state.unit(spear))
        let way = try XCTUnwrap(unit.way, "A company on the march keeps the rest of its way")
        XCTAssertEqual(way.last, destination)
        XCTAssertEqual(way[0].distance(to: unit.position), 1)
        XCTAssertEqual(state.keptWay(of: unit), way)

        // Pace by pace it walks the way it kept, step for step.
        var walked: [Hex] = []
        for pace in 1..<GameState.pacesPerWatch {
            let before = try XCTUnwrap(state.unit(spear)).position
            _ = state.walk(to: pace)
            let after = try XCTUnwrap(state.unit(spear)).position
            if after != before { walked.append(after) }
        }
        XCTAssertFalse(walked.isEmpty, "It walks at the paces")
        XCTAssertEqual(walked, Array(way.prefix(walked.count)), "Step for step the way it kept")
        let left = try XCTUnwrap(state.unit(spear)?.way)
        XCTAssertEqual(left, Array(way.dropFirst(walked.count)), "What is left of it, kept")
    }

    func testAStepShutIsGoneRound() throws {
        var (state, spear, destination) = try marching("a way shut")
        let me = state.player
        _ = try state.perform(.move(unit: spear, to: destination), as: me)
        _ = state.endWatch()
        let way = try XCTUnwrap(state.unit(spear)?.way)
        // Another of the keeper's companies comes to stand in the next step.
        let other = try XCTUnwrap(state.units(of: me).first { $0.id != spear && $0.destination == nil })
        let blocked = way[0]
        state.units[try XCTUnwrap(state.unitIndex(other.id))].position = blocked
        XCTAssertTrue(state.isShut(blocked, for: try XCTUnwrap(state.unit(spear))))

        var moved = false
        for pace in 1..<GameState.pacesPerWatch where !moved {
            let before = try XCTUnwrap(state.unit(spear)).position
            _ = state.walk(to: pace)
            let now = try XCTUnwrap(state.unit(spear))
            moved = now.position != before
            if moved {
                XCTAssertNotEqual(now.position, blocked, "Never into the company standing in its way")
                XCTAssertEqual(now.destination, destination, "Still bound where it was")
                XCTAssertEqual(now.way?.last, destination, "Its way found anew, round the company")
                XCTAssertFalse(now.way?.contains(blocked) ?? true)
            }
        }
        XCTAssertTrue(moved, "It goes round rather than waiting")
    }

    func testAnOrderToWhereItIsBoundKeepsItsWayUnlessItIsShut() throws {
        var (state, spear, destination) = try marching("a way ordered again")
        let me = state.player
        _ = try state.perform(.move(unit: spear, to: destination), as: me)
        let unit = try XCTUnwrap(state.unit(spear))
        let way = try XCTUnwrap(unit.way)
        XCTAssertEqual(state.keptWay(of: unit, to: destination), way, "Ordered there again, it keeps its way")
        XCTAssertNil(state.keptWay(of: unit, to: way[0]), "Ordered elsewhere, it seeks one")

        // With its next step shut, the way is sought anew.
        let other = try XCTUnwrap(state.units(of: me).first { $0.id != spear && $0.destination == nil })
        state.units[try XCTUnwrap(state.unitIndex(other.id))].position = way[0]
        XCTAssertNil(state.keptWay(of: try XCTUnwrap(state.unit(spear)), to: destination))
    }

    func testACompanyThatStopsKeepsNoWay() throws {
        var (state, spear, destination) = try marching("a way ended")
        let me = state.player
        _ = try state.perform(.move(unit: spear, to: destination), as: me)
        XCTAssertNotNil(state.unit(spear)?.way)
        // Called to stand where it is, it stops: its way goes as the watch turns.
        let index = try XCTUnwrap(state.unitIndex(spear))
        state.units[index].destination = nil
        _ = state.endWatch()
        XCTAssertNil(state.unit(spear)?.way)
        XCTAssertNil(state.keptWay(of: try XCTUnwrap(state.unit(spear))))
    }

    func testNoViewCarriesAWay() throws {
        var (state, spear, destination) = try marching("a way unseen")
        let me = state.player
        _ = try state.perform(.move(unit: spear, to: destination), as: me)
        XCTAssertNotNil(state.unit(spear)?.way)
        for house in state.houses.indices {
            XCTAssertTrue(state.view(for: house).units.allSatisfy { $0.way == nil }, "Not even the keeper's own")
        }
        // The keeper is still told where their company goes.
        let march = try XCTUnwrap(state.marches(seenBy: me).first { $0.unit == spear })
        XCTAssertEqual(march.route.last, destination)
    }

    func testAWayIsWrittenShortAndReadBack() throws {
        var (state, spear, destination) = try marching("a way written")
        _ = try state.perform(.move(unit: spear, to: destination), as: state.player)
        let unit = try XCTUnwrap(state.unit(spear))
        let way = try XCTUnwrap(unit.way)
        let data = try JSONEncoder().encode(unit)
        let written = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let text = try XCTUnwrap(written["way"] as? String)
        XCTAssertEqual(text, March.way(of: way), "Its first hex and a digit a step")
        XCTAssertEqual(try JSONDecoder().decode(NullmereCore.Unit.self, from: data), unit)

        // A company with no way writes none, as before ways were kept.
        var stood = unit
        stood.way = nil
        let plain = try XCTUnwrap(JSONSerialization.jsonObject(with: try JSONEncoder().encode(stood)) as? [String: Any])
        XCTAssertNil(plain["way"])

        // An unreadable way is refused.
        var broken = written
        broken["way"] = "a way"
        XCTAssertThrowsError(try JSONDecoder().decode(NullmereCore.Unit.self, from: JSONSerialization.data(withJSONObject: broken)))
    }
}
