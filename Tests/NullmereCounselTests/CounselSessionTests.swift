import Foundation
import FoundationModels
import XCTest
@testable import NullmereCore
@testable import NullmereCounsel

/// Counsel's session apart from the model's words: why it can't be taken,
/// told plainly and never answered for; the looks and proposals its tools
/// make, as the realm would weigh them; offers given once or set aside; and
/// what the commander recalls brought within the model's context. The words
/// themselves are heard on a real Mac (scripts/check-counsel.sh).
@MainActor
final class CounselSessionTests: XCTestCase {
    /// A keeper's House, its first commander at the head of a company of
    /// war, as the keeper's own view holds it.
    private func counsel() throws -> CommanderCounsel {
        var world = GameState(settings: GameSettings(seedText: "counsel session", houseCount: 4, radius: 18, keepers: 1))
        let me = world.player
        let commander = try XCTUnwrap(world.commanders(of: me).first)
        let seat = try XCTUnwrap(world.seat(of: me))
        let spear = try XCTUnwrap(world.units(of: me).first { $0.kind == .spear })
        if let there = world.unit(at: seat.position), let other = world.unitIndex(there.id) {
            world.units[other].position = spear.position
        }
        world.units[try XCTUnwrap(world.unitIndex(spear.id))].position = seat.position
        try world.perform(.assign(commander: commander.id, unit: spear.id), as: me)
        return try XCTUnwrap(CommanderCounsel(state: world.view(for: me), player: me, commander: commander.id))
    }

    private func session(_ counsel: CommanderCounsel, memory: CounselMemory? = nil,
                         availability: SystemLanguageModel.Availability = .unavailable(.deviceNotEligible)) -> CommanderCounselSession {
        CommanderCounselSession(counsel: counsel, memory: memory ?? CounselMemory(commander: counsel.commander.id, age: 1),
                                availability: { availability })
    }

    /// Each reason the model can't be asked is told as itself.
    func testWhyCounselCantBeTakenIsToldPlainly() {
        XCTAssertNil(CommanderCounselSession.trouble(for: .available))
        XCTAssertEqual(CommanderCounselSession.trouble(for: .unavailable(.deviceNotEligible)), .unavailable(.deviceNotEligible))
        XCTAssertEqual(CommanderCounselSession.trouble(for: .unavailable(.appleIntelligenceNotEnabled)), .unavailable(.appleIntelligenceOff))
        XCTAssertEqual(CommanderCounselSession.trouble(for: .unavailable(.modelNotReady)), .unavailable(.modelNotReady))
        XCTAssertEqual(CommanderCounselSession.trouble(from: CounselTrouble.busy), .busy)
        let other = NSError(domain: "stars", code: 7, userInfo: [NSLocalizedDescriptionKey: "The stars are wrong."])
        XCTAssertEqual(CommanderCounselSession.trouble(from: other), .failed("The stars are wrong."))
    }

    /// Asked where the model can't answer, the commander says nothing: the
    /// keeper is told why, and no words are made up in the model's place.
    func testCounselThatCantBeTakenIsNeverAnsweredFor() throws {
        let counsel = try counsel()
        for availability: SystemLanguageModel.Availability in [.unavailable(.deviceNotEligible), .unavailable(.appleIntelligenceNotEnabled),
                                                               .unavailable(.modelNotReady)] {
            let session = session(counsel, availability: availability)
            let trouble = try XCTUnwrap(session.unavailable)
            session.prewarm()
            session.ask("What do you see?")
            XCTAssertFalse(session.answering)
            XCTAssertEqual(session.lines.map(\.kind), [.trouble])
            XCTAssertEqual(session.lines.first?.text, trouble.said)
            XCTAssertEqual(session.trouble, trouble)
            XCTAssertTrue(session.memory.exchanges.isEmpty, "Nothing said, nothing remembered")
            session.ask("   ")
            XCTAssertEqual(session.lines.count, 1, "Nothing asked, nothing told")
        }
    }

    /// The tools' looks tell what the keeper's view tells and are shown as
    /// looks; an order put forward is weighed as the realm weighs it, and
    /// only one it would take waits on the keeper.
    func testTheToolsLookAndProposeAsTheRealmWeighs() async throws {
        let counsel = try counsel()
        let bench = CounselBench(counsel)
        let unit = try XCTUnwrap(counsel.company)
        let handle = try XCTUnwrap(counsel.handle(of: unit))
        let report = await bench.report(on: handle)
        XCTAssertEqual(report, counsel.report(on: handle))
        let look = await bench.lookAround(within: 30)
        XCTAssertEqual(look, counsel.lookAround(within: 8))
        let affairs = await bench.affairs()
        XCTAssertEqual(affairs, counsel.affairs)
        let given = await bench.propose("fortify", company: handle, place: "")
        XCTAssertTrue(given.hasPrefix("Put forward to your keeper:"))
        let refused = await bench.propose("march", company: "C99", place: "Anywhere")
        XCTAssertTrue(refused.hasPrefix("That cannot be ordered:"))
        let taken = await bench.taken()
        XCTAssertEqual(taken.looks.count, 4, "Three looks and an order weighed and refused: \(taken.looks)")
        XCTAssertTrue(taken.looks.last?.contains("cannot be ordered") == true)
        XCTAssertEqual(taken.proposals.map(\.command), [.fortify(unit: unit.id)])
        let again = await bench.taken()
        XCTAssertTrue(again.looks.isEmpty && again.proposals.isEmpty, "Each taken once")
        let told = await bench.told
        XCTAssertEqual(told, [report, look, affairs, given, refused])
        // Renewed, the looks tell the world as it now stands.
        var moved = counsel.state
        let index = try XCTUnwrap(moved.unitIndex(unit.id))
        moved.units[index].fortified = true
        await bench.renew(try XCTUnwrap(CommanderCounsel(state: moved, player: counsel.player, commander: counsel.commander.id)))
        let after = await bench.report(on: handle)
        XCTAssertTrue(after.contains("dug in"), after)
    }

    /// An offer is given once, or set aside, and never both.
    func testAnOfferIsGivenOnceOrSetAside() async throws {
        let counsel = try counsel()
        let session = session(counsel)
        let handle = try XCTUnwrap(counsel.company.flatMap(counsel.handle(of:)))
        _ = await session.bench.propose("fortify", company: handle, place: "")
        _ = await session.bench.propose("halt", company: handle, place: "")
        await session.takeFromBench()
        XCTAssertEqual(session.offers.count, 2)
        XCTAssertEqual(session.offers.map(\.state), [.waiting, .waiting])
        let first = session.offers[0], second = session.offers[1]
        XCTAssertEqual(session.give(first), first.proposal.command)
        XCTAssertNil(session.give(first), "Given once")
        session.setAside(second)
        XCTAssertNil(session.give(second), "Set aside, never given")
        XCTAssertEqual(session.offers.map(\.state), [.given, .setAside])
        XCTAssertNil(session.give(CommanderCounselSession.Offer(id: 999, proposal: first.proposal)), "None such")
        XCTAssertEqual(session.lines.filter { $0.kind == .look }.count, 0)
    }

    /// What the commander recalls goes with what they are told, within the
    /// share of the model's context counsel may bring; answers lose the
    /// quotes a model sets about them.
    func testWhatIsRecalledIsBroughtWithinTheContext() throws {
        let counsel = try counsel()
        var memory = CounselMemory(commander: counsel.commander.id, age: 1)
        memory.remember("Where is the enemy?", "Two tiles east, my keeper.", at: 3)
        let session = session(counsel, memory: memory)
        XCTAssertTrue(session.instructions.hasPrefix(counsel.instructions))
        XCTAssertTrue(session.instructions.contains(counsel.briefing))
        XCTAssertTrue(session.instructions.contains("What you recall of earlier counsel with your keeper:"))
        XCTAssertTrue(session.instructions.contains("Two tiles east, my keeper."))
        XCTAssertFalse(self.session(counsel).instructions.contains("What you recall"))
        XCTAssertEqual(CommanderCounselSession.cleaned("  \u{201C}Hold the ford.\u{201D}\n"), "Hold the ford.")
        // New facts, as the watch turns.
        var turned = counsel.state
        turned.watch += 1
        session.renew(try XCTUnwrap(CommanderCounsel(state: turned, player: counsel.player, commander: counsel.commander.id)))
        XCTAssertEqual(session.counsel.state.watch, counsel.state.watch + 1)
        session.stop()
    }
}
