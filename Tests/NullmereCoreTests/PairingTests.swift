import Foundation
import XCTest
@testable import NullmereCore

/// Two commanders to a company (RoK's primary and secondary): the second
/// rides only with a leader, adds half its edges, a point more to attack
/// and defence when the two are of one kind, learns at half the pace and
/// is carried home wounded with the leader when the company falls.
final class PairingTests: XCTestCase {
    private func world() throws -> (GameState, me: Int, lead: Int, second: Int, spear: Int) {
        var state = Scene.world("pairings")
        let me = state.player
        var random = SeededRandom(seed: 7)
        let lead = try XCTUnwrap(state.commanders(of: me).first).id
        let second = try XCTUnwrap(state.raiseCommander(for: me, archetype: state.commander(lead)?.archetype, using: &random)).id
        let seat = try XCTUnwrap(state.seat(of: me))
        let spear = try XCTUnwrap(state.units(of: me).first { $0.kind == .spear })
        if let there = state.unit(at: seat.position), let other = state.unitIndex(there.id) {
            state.units[other].position = spear.position
        }
        state.units[try XCTUnwrap(state.unitIndex(spear.id))].position = seat.position
        for id in [lead, second] {
            state.commanders![try XCTUnwrap(state.commanderIndex(id))].experience = Commander.experience(forLevel: 12)
        }
        return (state, me, lead, second, spear.id)
    }

    private func refusal(_ command: Command, in state: GameState, as house: Int) -> RuleError? {
        var trial = state
        do {
            try trial.perform(command, as: house)
            return nil
        } catch {
            return error
        }
    }

    func testASecondRidesOnlyWithALeaderAndAddsHalfItsEdge() throws {
        var (state, me, lead, second, spear) = try world()
        XCTAssertEqual(refusal(.assignSecond(commander: second, unit: spear), in: state, as: me), .needsLeaderFirst)
        try state.perform(.assign(commander: lead, unit: spear), as: me)
        let unit = try XCTUnwrap(state.unit(spear))
        let alone = state.bonus(.attack(.spear), for: unit)
        let edge = state.edge(.attack, of: try XCTUnwrap(state.commander(second)))
        try state.perform(.assignSecond(commander: second, unit: spear), as: me)
        let paired = state.bonus(.attack(.spear), for: try XCTUnwrap(state.unit(spear)))
        XCTAssertEqual(paired, alone + edge / 2 + 1, "Half the second's edge, and a point for a pair of one kind")
        XCTAssertEqual(state.company(ledBy: second)?.id, spear, "The second rides with that company")
        XCTAssertEqual(refusal(.assignSecond(commander: second, unit: spear), in: state, as: me), .commanderLeads)
        XCTAssertEqual(refusal(.assign(commander: second, unit: spear), in: state, as: me), .commanderLeads, "Nor leads another while it rides second")
        XCTAssertEqual(state.problems(), [])
    }

    func testThePairLearnsTogetherAndFallsTogether() throws {
        var (state, me, lead, second, spear) = try world()
        try state.perform(.assign(commander: lead, unit: spear), as: me)
        try state.perform(.assignSecond(commander: second, unit: spear), as: me)
        let leadBefore = try XCTUnwrap(state.commander(lead)).experience
        let secondBefore = try XCTUnwrap(state.commander(second)).experience
        _ = state.teach(try XCTUnwrap(state.unit(spear)), 100)
        let leadGained = try XCTUnwrap(state.commander(lead)).experience - leadBefore
        let secondGained = try XCTUnwrap(state.commander(second)).experience - secondBefore
        XCTAssertGreaterThan(leadGained, 0)
        XCTAssertEqual(secondGained, leadGained / 2, accuracy: 1, "The second learns at half the pace")
        let wounded = state.woundCommander(of: try XCTUnwrap(state.unit(spear)))
        XCTAssertEqual(wounded.count, 2, "Both carried home")
        XCTAssertTrue(try XCTUnwrap(state.commander(second)).isWounded(at: state.watch))
    }

    func testReleasingTheLeaderLeavesTheSecondInCommand() throws {
        var (state, me, lead, second, spear) = try world()
        try state.perform(.assign(commander: lead, unit: spear), as: me)
        try state.perform(.assignSecond(commander: second, unit: spear), as: me)
        try state.perform(.unassign(commander: lead), as: me)
        let unit = try XCTUnwrap(state.unit(spear))
        XCTAssertEqual(unit.leader, second)
        XCTAssertNil(unit.second)
        try state.perform(.unassign(commander: second), as: me)
        XCTAssertNil(try XCTUnwrap(state.unit(spear)).leader)
        // Saved and read again, a pairing stands.
        try state.perform(.assign(commander: lead, unit: spear), as: me)
        try state.perform(.assignSecond(commander: second, unit: spear), as: me)
        let read = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(read.unit(spear)?.second, second)
    }

    /// A steward with a commander to spare and no company left to lead
    /// sends it to ride second with a led company beside its holds.
    func testAStewardPairsACommanderItCannotOtherwiseUse() throws {
        var (state, me, lead, second, spear) = try world()
        try state.perform(.assign(commander: lead, unit: spear), as: me)
        // Every other company of war led already, or gone.
        state.units.removeAll { $0.owner == me && $0.kind.isMilitary && $0.id != spear }
        _ = RivalMind(house: me).appointCommanders(in: &state)
        XCTAssertEqual(state.unit(spear)?.second, second)
    }
}
