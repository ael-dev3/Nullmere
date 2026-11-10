import Foundation

/// What envoys remember: how the last envoy one House sent another was
/// answered, and how many of its envoys that House has turned away this
/// age. The realm keeps it wherever a keeper is one of the two, as it keeps
/// every answer, and only those two Houses are told it. The next envoy
/// comes knowing it: its words are given it (`voiced(_:)`), and the keeper
/// is told it on the envoy's card, on the Mac and the phone alike
/// (`remembered(_:for:)`).
public struct EnvoyAnswer: Codable, Equatable, Sendable {
    public enum Answer: String, Codable, Sendable {
        case accepted
        case refused
        /// Left waiting until it went home: an envoy unanswered is an
        /// envoy refused.
        case unanswered
        /// A demand of tribute met with half of it, which its steward took
        /// (`GameState.bargain`).
        case halved
    }

    /// The House the envoys came from.
    public let from: Int
    /// The House that answered them.
    public let to: Int
    /// What the last of them came for.
    public var proposal: Proposal
    /// The watch it was answered, or went home unanswered.
    public var watch: Int
    public var answer: Answer
    /// How many of `from`'s envoys `to` has turned away or left
    /// unanswered this age.
    public var turnedAway: Int

    public init(from: Int, to: Int, proposal: Proposal, watch: Int, answer: Answer, turnedAway: Int) {
        self.from = from
        self.to = to
        self.proposal = proposal
        self.watch = watch
        self.answer = answer
        self.turnedAway = turnedAway
    }

    /// How it was answered, by `who` ("you", "they", a House's title): "you
    /// swore it", "they paid it", "House Aurel turned it away".
    public func said(by who: String) -> String {
        switch answer {
        case .unanswered: return "\(who) sent no answer"
        case .halved: return "\(who) paid half of it"
        case .refused: return proposal == .tribute ? "\(who) refused it" : "\(who) turned it away"
        case .accepted:
            switch proposal {
            case .peace: return "\(who) made peace"
            case .pact: return "\(who) swore it"
            case .fealty: return "\(who) accepted it"
            case .tribute: return "\(who) paid it"
            case .trade: return "\(who) took it"
            }
        }
    }
}

extension Proposal {
    /// What an envoy came for, as a line of memory says it: "asking for
    /// peace", "offering a pact", "demanding tribute".
    public var cameFor: String {
        switch self {
        case .peace: return "asking for peace"
        case .pact: return "offering a pact"
        case .fealty: return "offering fealty"
        case .tribute: return "demanding tribute"
        case .trade: return "offering a trade"
        }
    }
}

extension GameState {
    /// How `to` answered the last envoy `from` sent it this age, if any.
    public func lastAnswer(from: Int, to: Int) -> EnvoyAnswer? {
        answers?.first { $0.from == from && $0.to == to }
    }

    /// Keeps how an envoy from `from` to `to` was answered, where a keeper
    /// is one of the two: stewards' dealings among themselves are their
    /// own, and a realm of a thousand Houses keeps only what its keepers
    /// had a part in.
    mutating func remember(_ proposal: Proposal, from: Int, to: Int, answer: EnvoyAnswer.Answer) {
        guard houses.indices.contains(from), houses.indices.contains(to),
              houses[from].isPlayer || houses[to].isPlayer else { return }
        var kept = answers ?? []
        let turnedAway = answer == .accepted || answer == .halved ? 0 : 1
        if let index = kept.firstIndex(where: { $0.from == from && $0.to == to }) {
            kept[index].proposal = proposal
            kept[index].watch = watch
            kept[index].answer = answer
            kept[index].turnedAway += turnedAway
        } else {
            kept.append(EnvoyAnswer(from: from, to: to, proposal: proposal, watch: watch, answer: answer, turnedAway: turnedAway))
        }
        answers = kept
    }

    /// What `player` is told on an envoy's card of the dealings before it:
    /// how they answered the last envoy its House sent them, how many they
    /// have turned away, and how its House answered the last of theirs.
    /// Nil before any.
    public func remembered(_ envoy: Envoy, for player: Int) -> String? {
        guard houses.indices.contains(envoy.from) else { return nil }
        let house = houses[envoy.from].title
        var lines: [String] = []
        if let theirs = lastAnswer(from: envoy.from, to: player) {
            var line = "\(house)'s last envoy, in watch \(theirs.watch), came \(theirs.proposal.cameFor), and \(theirs.said(by: "you"))."
            if theirs.turnedAway > 1 { line += " You have turned away \(theirs.turnedAway) of their envoys this age." }
            lines.append(line)
        }
        if let ours = lastAnswer(from: player, to: envoy.from) {
            lines.append("Your last envoy to them, in watch \(ours.watch), came \(ours.proposal.cameFor), and \(ours.said(by: "they")).")
        }
        return lines.isEmpty ? nil : lines.joined(separator: " ")
    }

    /// The dealings before an envoy, as the model voicing it is told them.
    func rememberedFacts(_ envoy: Envoy) -> [String] {
        guard houses.indices.contains(envoy.from), houses.indices.contains(envoy.to) else { return [] }
        let sender = houses[envoy.from].title, keeper = houses[envoy.to].title
        var facts: [String] = []
        if let theirs = lastAnswer(from: envoy.from, to: envoy.to) {
            facts.append("\(sender)'s last envoy to \(keeper), in watch \(theirs.watch), came \(theirs.proposal.cameFor), "
                         + "and \(theirs.said(by: keeper)).")
            if theirs.turnedAway > 1 { facts.append("\(keeper) has turned away \(theirs.turnedAway) of \(sender)'s envoys this age.") }
        }
        if let ours = lastAnswer(from: envoy.to, to: envoy.from) {
            facts.append("\(keeper)'s last envoy to \(sender), in watch \(ours.watch), came \(ours.proposal.cameFor), "
                         + "and \(ours.said(by: sender)).")
        }
        return facts
    }
}
