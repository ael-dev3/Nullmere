import Foundation
import FoundationModels
import NullmereCore
import NullmereCounsel

/// Counsel heard from this Mac's own model, as a keeper takes it: a lake
/// some watches on, the keeper's first commander at the head of their first
/// company of war, asked in turn what they see, how the House stands and
/// what they would have done, then asked again and stopped as they begin.
/// Every answer is held to counsel's rules: spoken at all, short, grave, no
/// talk of games, players or models, and no number that neither the
/// briefing nor the commander's looks told it. The commander must have
/// looked before answering at least once, the orders it put forward must be
/// ones the realm would take, it must remember what was said, and a stopped
/// answer must stop. scripts/check-counsel.sh asks it through the app, as a
/// keeper's Mac runs it, and writes what was heard and how long it took.
public enum CounselCheck {
    /// Words counsel never says.
    static let forbidden = ["game", "player", "turn", "rule", "model", "tool", "ai", "artificial", "assistant"]
    /// The verdict a report ends with when counsel kept every rule.
    public static let passed = "Counsel kept to its rules."
    /// The questions asked, in turn.
    static let questions = ["What do you see about you?",
                            "How does our House stand?",
                            "What would you have your company do? Put it forward if you would."]

    public struct Report: Sendable {
        public let text: String
        public let failures: [String]
        /// Whether the model could not be asked at all.
        public let unavailable: Bool
    }

    /// The lake counsel is taken on: thirty watches of a lake, the keeper's
    /// first commander set at the head of their first company of war.
    static func world() -> (GameState, commander: Int)? {
        var state = GameState(settings: GameSettings(seedText: "counsel", houseCount: 6, radius: 22, keepers: 1))
        for _ in 0..<30 where state.outcome == nil {
            _ = state.stewardTurn(for: state.player)
            _ = state.endWatch()
        }
        let me = state.player
        guard let commander = state.commanders(of: me).first(where: { !$0.isWounded(at: state.watch) }) else { return nil }
        if !state.units(of: me).contains(where: { $0.leader == commander.id }),
           let unit = state.units(of: me).first(where: { $0.kind.isMilitary && $0.leader == nil
               && state.assignRefusal(of: commander.id, to: $0.id, as: me) == nil }) {
            _ = try? state.perform(.assign(commander: commander.id, unit: unit.id), as: me)
        }
        return (state, commander.id)
    }

    /// What an answer broke of counsel's rules.
    static func problems(of answer: String, facts: String) -> [String] {
        var problems: [String] = []
        let words = answer.split(separator: " ").count
        if words > 90 { problems.append("\(words) words") }
        if answer.contains("!") { problems.append("an exclamation") }
        let said = Set(answer.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
        for word in forbidden where said.contains(word) || said.contains(word + "s") {
            problems.append("speaks of \"\(word)\"")
        }
        for number in answer.split(whereSeparator: { !$0.isNumber }) where !facts.contains(number) {
            problems.append("invents the number \(number)")
        }
        return problems
    }

    @MainActor
    public static func run(availability: (() -> SystemLanguageModel.Availability)? = nil) async -> Report {
        guard let (world, commander) = world(),
              let counsel = CommanderCounsel(state: world.view(for: world.player), player: world.player, commander: commander) else {
            return Report(text: "No commander to take counsel of.", failures: ["no commander"], unavailable: false)
        }
        let session = CommanderCounselSession(counsel: counsel, memory: CounselMemory(commander: commander, age: 1), availability: availability)
        if let trouble = session.unavailable {
            return Report(text: "Apple's on-device model on this Mac, not ready (\(trouble.said))", failures: [], unavailable: true)
        }
        session.prewarm()
        let named = "\(counsel.commander.name), \(counsel.commander.archetype.named)"
        var text = ["Counsel of \(named), heard from Apple's on-device model on this Mac", ""]
        var failures: [String] = []
        var looked = 0
        for question in questions {
            let before = session.lines.count
            session.ask(question)
            while session.answering { try? await Task.sleep(for: .milliseconds(50)) }
            let heard = session.lines.dropFirst(before)
            text.append("Keeper: \(question)")
            for line in heard where line.kind == .look {
                text.append("  (\(line.text))")
                looked += 1
            }
            let facts = ([counsel.briefing] + (await session.told())).joined(separator: "\n")
            if let answer = heard.last(where: { $0.kind == .commander }) {
                let broke = problems(of: answer.text, facts: facts)
                text.append("\(counsel.commander.name): \(answer.text)")
                if let timing = session.timing {
                    text.append(String(format: "  first words %.2f s, all of it %.2f s", timing.firstWords, timing.whole))
                }
                failures += broke.map { "\(question) \($0)" }
                if !broke.isEmpty { text.append("  BROKE: " + broke.joined(separator: "; ")) }
            } else {
                let why = heard.last(where: { $0.kind == .trouble })?.text ?? "no answer"
                text.append("  NO ANSWER: \(why)")
                failures.append("\(question) went unanswered: \(why)")
            }
            text.append("")
        }
        if looked == 0 { failures.append("the commander never looked before answering") }
        for offer in session.offers {
            text.append("Put forward: \(offer.proposal.told) (\(offer.proposal.line))")
            if !offer.proposal.isGiven { failures.append("put forward an order the realm would refuse: \(offer.proposal.line)") }
        }
        if session.offers.isEmpty { text.append("Put forward: nothing") }
        if session.memory.exchanges.count != questions.count {
            failures.append("remembers \(session.memory.exchanges.count) exchanges of \(questions.count)")
        }
        // Stopped as it begins: the answer stops, and says so.
        let before = session.lines.count
        session.ask("Tell me of every company you know, at length.")
        let asked = Date()
        while session.answering, session.partial?.isEmpty != false, Date().timeIntervalSince(asked) < 20 {
            try? await Task.sleep(for: .milliseconds(20))
        }
        session.stop()
        while session.answering { try? await Task.sleep(for: .milliseconds(20)) }
        let stopped = session.lines.dropFirst(before).contains { $0.kind == .trouble && $0.text == "Stopped." }
        text.append(stopped ? "Stopped as it began: it stopped." : "Stopped as it began: it did not stop.")
        if !stopped { failures.append("a stopped answer did not stop") }
        text.append("")
        text.append(failures.isEmpty ? passed : "Broken: \(failures.count)")
        return Report(text: text.joined(separator: "\n"), failures: failures, unavailable: false)
    }
}
