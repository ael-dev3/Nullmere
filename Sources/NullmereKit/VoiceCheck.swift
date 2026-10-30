import Foundation
import NullmereCore

/// The voices held to their rules. Each kind of envoy's offer, and each kind
/// of chronicle entry a long age brings, is spoken, and every line checked:
/// spoken at all, short, grave (no exclamations), no numbers but the facts',
/// and no talk of games or players. scripts/check-voices.sh asks it of
/// Apple's on-device model through the app, as a keeper's Mac runs it; its
/// tests ask it of stand-ins.
public enum VoiceCheck {
    /// Words a voice never says, one or many: the tide may turn, but a
    /// voice never speaks of turns.
    static let forbidden = ["game", "player", "turn", "rule", "level", "click", "ai", "artificial"]

    /// Every moment spoken, each line with what it broke, and the verdict.
    public struct Report: Sendable {
        /// What was heard, a line for each moment, then the verdict.
        public let text: String
        /// What broke the rules: nothing, if every line kept them.
        public let failures: [String]
        /// How many moments were spoken.
        public let moments: Int
    }

    /// The verdict a report ends with when every line kept the rules.
    public static let passed = "Every line within the rules."

    /// The moments to speak: an envoy with each kind of offer, and the latest
    /// of each kind of chronicle entry sixty watches of a lake bring.
    static func moments() -> [(name: String, moment: VoiceMoment)] {
        var state = GameState(settings: GameSettings(seedText: "voices", houseCount: 6, radius: 22, keepers: 1))
        for _ in 0..<60 where state.outcome == nil {
            _ = state.stewardTurn(for: state.player)
            _ = state.endWatch()
        }
        var moments: [(name: String, moment: VoiceMoment)] = []
        let other = state.livingHouses.first { $0.id != state.player }?.id ?? 1
        for (index, proposal) in Proposal.allCases.enumerated() {
            let trade = proposal == .trade ? Trade(give: .timber, 20, for: .grain, 15) : nil
            let envoy = Envoy(id: 9_000 + index, from: other, to: state.player, proposal: proposal, arrived: state.watch, trade: trade)
            moments.append(("envoy offering \(proposal.title.lowercased())", VoiceFacts.envoy(envoy, in: state)))
        }
        var kinds = Set<String>()
        for entry in state.chronicle.reversed() where VoiceFacts.isVoiced(entry.kind) && kinds.insert(entry.kind.rawValue).inserted {
            moments.append(("chronicle of \(entry.kind.rawValue)", VoiceFacts.chronicle(entry, in: state)))
        }
        return moments
    }

    /// What a line spoken for a moment broke of the rules: nothing, if it
    /// kept them all.
    static func problems(of line: String?, for moment: VoiceMoment) -> [String] {
        guard let line else { return ["silent"] }
        var problems: [String] = []
        let words = line.split(separator: " ").count
        if words > 60 { problems.append("\(words) words") }
        if line.contains("!") { problems.append("an exclamation") }
        let said = Set(line.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
        for word in forbidden where said.contains(word) || said.contains(word + "s") {
            problems.append("speaks of \"\(word)\"")
        }
        let facts = moment.facts.joined(separator: " ")
        for number in line.split(whereSeparator: { !$0.isNumber }) where !facts.contains(number) {
            problems.append("invents the number \(number)")
        }
        return problems
    }

    /// Every moment spoken by `voice`, and each line held to the rules.
    /// `source` says whose words they are, at the report's head.
    public static func run(_ voice: any Voice, source: String) async -> Report {
        let moments = moments()
        var lines = ["Nullmere Online's voices, spoken by \(source).", ""]
        var failures: [String] = []
        for (name, moment) in moments {
            let started = Date()
            let line = await voice.speak(moment)
            let seconds = Date().timeIntervalSince(started)
            lines.append("\(name) (\(String(format: "%.1f", seconds)) s): \(line ?? "(silent)")")
            failures += problems(of: line, for: moment).map { "\(name): \($0)" }
        }
        lines += ["", failures.isEmpty ? passed : "Out of bounds:"] + failures
        return Report(text: lines.joined(separator: "\n"), failures: failures, moments: moments.count)
    }
}
