import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The voices' rules, held against stand-ins as scripts/check-voices.sh
/// holds Apple's on-device model to them: a voice that keeps them passes,
/// and each way of breaking them is caught and named.
final class VoiceCheckTests: XCTestCase {
    /// Speaks every moment in the same grave line, which keeps every rule,
    /// sets every riddle keeping its blank, and makes every ballad the
    /// same two.
    private struct Steady: Voice {
        func speak(_ moment: VoiceMoment) async -> String? {
            moment.kind == .riddle ? "Whose House was it, ———, that the water remembers?"
                : "The water keeps its silence, and the Houses watch the shore."
        }

        func compose(_ moment: VoiceMoment) async -> String? {
            "The moon lay still upon the water,\nand the shore remembered."
        }

        func read(orders words: String, briefing: String) async -> String? {
            "1. FORTIFY C1\nAnd nothing more."
        }
    }

    /// Never answers, as a model that isn't ready.
    private struct Silent: Voice {
        func speak(_ moment: VoiceMoment) async -> String? { nil }
    }

    func testAVoiceWithinTheRulesPasses() async throws {
        let report = await VoiceCheck.run(Steady(), source: "a stand-in")
        XCTAssertEqual(report.failures, [])
        XCTAssertGreaterThanOrEqual(report.moments, Proposal.allCases.count + 2, "Envoys and chronicle entries enough to hear")
        XCTAssertTrue(report.text.hasPrefix("Nullmere Online's voices, spoken by a stand-in."), report.text)
        XCTAssertTrue(report.text.hasSuffix(VoiceCheck.passed), report.text)
        let told = report.text.components(separatedBy: "\n")
        let heard = told.filter { $0.hasSuffix("s): The water keeps its silence, and the Houses watch the shore.") }
        let sung = told.filter { $0.hasPrefix("ballad of ") && $0.hasSuffix("s): The moon lay still upon the water, / and the shore remembered.") }
        let asked = told.filter { $0.hasPrefix("riddle of the lake ") && $0.hasSuffix("s): Whose House was it, ———, that the water remembers?") }
        XCTAssertEqual(sung.count, 1, "A ballad made of the latest deed of arms, its lines on one")
        let moments = VoiceCheck.moments()
        let riddles = moments.filter { $0.moment.kind == .riddle }.count
        XCTAssertLessThanOrEqual(riddles, 1)
        XCTAssertEqual(asked.count, riddles, "The riddle the lake set at the last half moon, if the House stood to be set one")
        XCTAssertEqual(heard.count + sung.count + asked.count, report.moments, "A line told for every moment")
        for proposal in Proposal.allCases {
            XCTAssertTrue(report.text.contains("envoy offering \(proposal.title.lowercased())"), "An envoy offering \(proposal.title)")
        }
        XCTAssertEqual(told.filter { $0.hasPrefix("words for the fallen (") }.count, 1, "Words asked for the House's dead")
        // The watchman at a watchfire by the seat, asked of a foe's company
        // made out marching dark, as the session asks him.
        XCTAssertEqual(told.filter { $0.hasPrefix("watchman's word (") }.count, 1, "The watchman's word asked")
        let watchman = try XCTUnwrap(moments.first { $0.moment.kind == .watchman }).moment
        XCTAssertTrue(watchman.prompt.hasPrefix(Voicing.watchmanTask), watchman.prompt)
        XCTAssertTrue(watchman.facts.contains { $0.hasSuffix("marching dark, its torches doused.") }, "\(watchman.facts)")
        // A hamlet's eldest and a barrow's stones, asked as the session asks
        // them once the House's Lanterns have sought each.
        XCTAssertEqual(told.filter { $0.hasPrefix("words of a hamlet's eldest (") }.count, 1, "A hamlet's folk asked")
        XCTAssertEqual(told.filter { $0.hasPrefix("words at a barrow's mouth (") }.count, 1, "A barrow's stones asked")
        let folk = moments.filter { if case .find = $0.moment.kind { return true } else { return false } }
        XCTAssertEqual(folk.map(\.moment.kind), [.find(.hamlet), .find(.barrow)])
        XCTAssertTrue(folk[0].moment.prompt.hasPrefix(Voicing.hamletTask), folk[0].moment.prompt)
        XCTAssertTrue(folk[1].moment.prompt.hasPrefix(Voicing.barrowTask), folk[1].moment.prompt)
        // A commander's word on the company they lead, and the reeve's on the
        // seat, asked as the session asks them when the keeper turns to each.
        XCTAssertEqual(told.filter { $0.hasPrefix("a commander's word (") }.count, 1, "A commander's word asked")
        XCTAssertEqual(told.filter { $0.hasPrefix("the reeve's word (") }.count, 1, "The reeve's word asked")
        XCTAssertEqual(told.filter { $0.hasPrefix("the Lanterns' word (") }.count, 1, "The Lanterns' word asked")
        let lanterns = try XCTUnwrap(moments.first { $0.moment.kind == .scout }).moment
        XCTAssertTrue(lanterns.prompt.hasPrefix(Voicing.scoutTask), lanterns.prompt)
        XCTAssertTrue(lanterns.facts.first?.hasPrefix("Your Lanterns scouted ") == true, "\(lanterns.facts)")
        let commander = try XCTUnwrap(moments.first { $0.moment.kind == .commander }).moment
        XCTAssertTrue(commander.prompt.hasPrefix(Voicing.commanderTask), commander.prompt)
        let reeve = try XCTUnwrap(moments.first { $0.moment.kind == .reeve }).moment
        XCTAssertTrue(reeve.prompt.hasPrefix(Voicing.reeveTask), reeve.prompt)
        XCTAssertEqual(told.filter { $0.hasPrefix("the steward's welcome (") }.count, 1, "The steward's welcome asked")
        let welcome = try XCTUnwrap(moments.first { $0.moment.kind == .steward }).moment
        XCTAssertTrue(welcome.prompt.hasPrefix(Voicing.stewardTask), welcome.prompt)
        // A plea of each kind at the seat's gate, its petitioner heard as the
        // card asks for their words.
        for plea in Petition.Plea.allCases {
            XCTAssertEqual(told.filter { $0.hasPrefix("petition of \(plea.trade) (") }.count, 1, "A plea brought by \(plea.trade)")
        }
        let pleas = moments.filter { $0.moment.kind == .petition }
        XCTAssertEqual(pleas.count, Petition.Plea.allCases.count)
        XCTAssertTrue(pleas.allSatisfy { $0.moment.prompt.hasPrefix(Voicing.petitionTask) }, "Asked as the card asks")
        // The clerk asked to read the keeper's words, its answer on one line;
        // and stopped a moment in, back at once.
        XCTAssertEqual(told.filter { $0.hasPrefix("orders read (") && $0.hasSuffix("s): 1. FORTIFY C1 / And nothing more.") }.count, 1, report.text)
        XCTAssertEqual(told.filter { $0.hasPrefix("orders stopped 0.3 s in: back in ") && $0.hasSuffix(" s") }.count, 1, report.text)
        XCTAssertEqual(told.filter { $0.hasPrefix("petition of a mason stopped 0.3 s in: back in ") }.count, 1, report.text)
        let age = VoiceCheck.age()
        let (words, briefing) = try XCTUnwrap(VoiceCheck.orders(in: age))
        XCTAssertTrue(words.hasPrefix("Have C"), words)
        XCTAssertTrue(words.hasSuffix("and raise a Granary at \(try XCTUnwrap(age.seat(of: age.player)).name)."), words)
        XCTAssertEqual(briefing, SpokenOrders.briefing(for: age, player: age.player))
    }

    func testEachWayOfBreakingTheRulesIsNamed() {
        let moment = VoiceMoment(kind: .chronicle(.war), facts: ["House Aurel and House Brann are at war since watch 12."])
        XCTAssertEqual(VoiceCheck.problems(of: "Since watch 12 they war.", for: moment), [])
        XCTAssertEqual(VoiceCheck.problems(of: nil, for: moment), ["silent"])
        XCTAssertEqual(VoiceCheck.problems(of: "War, at last!", for: moment), ["an exclamation"])
        XCTAssertEqual(VoiceCheck.problems(of: Array(repeating: "still", count: 61).joined(separator: " "), for: moment), ["61 words"])
        XCTAssertEqual(VoiceCheck.problems(of: "The game of Houses goes on.", for: moment), ["speaks of \"game\""])
        XCTAssertEqual(VoiceCheck.problems(of: "Their turns are long.", for: moment), ["speaks of \"turn\""])
        XCTAssertEqual(VoiceCheck.problems(of: "The tide turned at the return of the moon.", for: moment), [],
                       "Words that only hold a forbidden one are the voices' own")
        XCTAssertEqual(VoiceCheck.problems(of: "Since watch 13 they war.", for: moment), ["invents the number 13"])
        let ballad = VoiceMoment(kind: .ballad, facts: ["A battle at the Grey Ford."])
        XCTAssertEqual(VoiceCheck.problems(of: "The ford ran red,\nand the moon looked on.", for: ballad), [])
        XCTAssertEqual(VoiceCheck.problems(of: "The ford ran red.", for: ballad), ["no ballad the realm would keep"], "One line is no ballad")
        // The clerk must read the words into at least one order.
        let state = GameState(settings: GameSettings(seedText: "a clerk checked", houseCount: 4, radius: 16, keepers: 1))
        XCTAssertEqual(VoiceCheck.problems(ofOrders: "FORTIFY C1", in: state), [])
        XCTAssertEqual(VoiceCheck.problems(ofOrders: nil, in: state), ["silent"])
        XCTAssertEqual(VoiceCheck.problems(ofOrders: "The spears will dig in, my lord.", in: state), ["reads no order"])
        XCTAssertEqual(VoiceCheck.problems(ofOrders: "FORTIFY C99", in: state), ["reads no order"], "A company the House hasn't")
    }

    func testAVoiceThatBreaksTheRulesFailsWithEachBreachNamed() async {
        let report = await VoiceCheck.run(Silent(), source: "silence")
        XCTAssertEqual(report.failures.count, report.moments + 1, "Every moment silent, and the clerk")
        XCTAssertEqual(report.failures.last, "orders read: silent")
        XCTAssertTrue(report.text.contains("s): (silent: " + CounselTrouble.silent.unreadOrders + ")"), "Why, as the keeper is told it: \(report.text)")
        XCTAssertTrue(report.failures.allSatisfy { $0.hasSuffix(": silent") }, "\(report.failures)")
        XCTAssertTrue(report.text.contains("\nOut of bounds:\n"), report.text)
        XCTAssertFalse(report.text.hasSuffix(VoiceCheck.passed))
    }

    /// A petitioner's words stopped a moment in come back at once from a
    /// voice that heeds being stopped; one that speaks on regardless is named.
    func testACharactersWordsStoppedComeBackAtOnceOrAreNamed() async throws {
        struct Heeding: Voice {
            func speak(_ moment: VoiceMoment) async -> String? {
                try? await Task.sleep(for: .seconds(30))
                return nil
            }
        }
        /// Half a second to every plea, unless stopped: then on regardless,
        /// well past the allowance.
        struct Heedless: Voice {
            func speak(_ moment: VoiceMoment) async -> String? {
                guard moment.kind == .petition else { return "The water keeps its silence, and the Houses watch the shore." }
                try? await Task.sleep(for: .seconds(0.5))
                if Task.isCancelled {
                    await withCheckedContinuation { done in
                        DispatchQueue.global().asyncAfter(deadline: .now() + VoiceCheck.stopAllowance + 3) { done.resume() }
                    }
                }
                return "We would mend it, keeper."
            }
        }
        let moment = try XCTUnwrap(VoiceCheck.moments().first { $0.moment.kind == .petition }).moment
        let heeded = await VoiceCheck.stopped(Heeding(), speaking: moment, after: 0.05)
        XCTAssertLessThan(heeded, 1, "Back at once")
        let report = await VoiceCheck.run(Heedless(), source: "a voice that won't stop")
        XCTAssertTrue(report.text.contains("\npetition of a mason stopped 0.3 s in: back in "), report.text)
        XCTAssertEqual(report.failures.filter { $0.hasPrefix("petition of a mason stopped: ran on ") }.count, 1, "\(report.failures)")
    }

    /// A reading stopped a moment in comes back at once from a clerk that
    /// heeds being stopped; one that reads on regardless is named.
    func testAReadingStoppedComesBackAtOnceOrIsNamed() async throws {
        struct Heeding: Voice {
            func speak(_ moment: VoiceMoment) async -> String? { nil }
            func read(orders words: String, briefing: String) async -> String? {
                try? await Task.sleep(for: .seconds(30))
                return nil
            }
        }
        struct Heedless: Voice {
            func speak(_ moment: VoiceMoment) async -> String? { nil }
            func read(orders words: String, briefing: String) async -> String? {
                // Well past the allowance, however late the stop comes on a
                // loaded runner.
                await withCheckedContinuation { done in
                    DispatchQueue.global().asyncAfter(deadline: .now() + VoiceCheck.stopAllowance + 3) { done.resume() }
                }
                return "FORTIFY C1"
            }
        }
        let asked = try XCTUnwrap(VoiceCheck.orders(in: VoiceCheck.age()))
        let heeded = await VoiceCheck.stopped(Heeding(), asked, after: 0.05)
        XCTAssertLessThan(heeded, 1, "Back at once")
        let report = await VoiceCheck.run(Heedless(), source: "a clerk that won't stop")
        XCTAssertEqual(report.failures.filter { $0.hasPrefix("orders stopped: ran on ") }.count, 1, "\(report.failures)")
    }

    /// The model's state as the report's head tells it: ready exactly when
    /// the voices can be asked.
    func testTheModelsStateIsToldAsItIs() {
        XCTAssertEqual(OnDeviceVoice.availability == "ready", OnDeviceVoice.isAvailable, OnDeviceVoice.availability)
        XCTAssertFalse(OnDeviceVoice.availability.isEmpty)
    }
}
