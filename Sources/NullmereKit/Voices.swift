import Foundation
import FoundationModels
import NullmereCore
import os

/// Something that can put a moment of the game into a character's words.
/// Voices only speak: what they say never changes the game.
public protocol Voice: Sendable {
    func speak(_ moment: VoiceMoment) async -> String?
}

/// A moment worth a few spoken words, with everything the speaker may know.
public struct VoiceMoment: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        /// An envoy addressing the player.
        case envoy(proposal: Proposal)
        /// The chronicler recording an entry of the lake's history.
        case chronicle(ChronicleEntry.Kind)
    }

    public let kind: Kind
    /// Plain facts, one per line, in the game's own words.
    public let facts: [String]

    public init(kind: Kind, facts: [String]) {
        self.kind = kind
        self.facts = facts
    }

    var prompt: String {
        let task: String
        switch kind {
        case .envoy(let proposal):
            let offer: String
            switch proposal {
            case .peace: offer = "an end to the war between their House and the player's"
            case .pact: offer = "a pact: shared sight and no war between the Houses"
            case .fealty: offer = "their House's fealty: beaten, they would serve the player's House as its vassal"
            case .tribute: offer = "tribute: a fifth of the player's stores, or their armies will march"
            case .trade: offer = "a trade of stores, on the terms given"
            }
            let verb = proposal == .tribute ? "demanding" : "offering"
            task = "Speak as the envoy, addressing the player's House directly, \(verb) \(offer). One or two sentences, at most 40 words."
        case .chronicle:
            task = "Write the chronicler's single line recording this, as it would stand in an old book of the lake. One sentence, at most 30 words."
        }
        return task + "\n\nWhat is known:\n" + facts.map { "- \($0)" }.joined(separator: "\n")
    }
}

/// Speaks through Apple's on-device model with the Foundation Models
/// framework. Each line gets a fresh session, so nothing accumulates.
public struct OnDeviceVoice: Voice {
    private static let logger = Logger(subsystem: "online.nullmere.game", category: "voices")

    static let instructions = """
    You give voice to characters in Nullmere, a game of great Houses around the Nullmere, \
    a vast black lake of dead, perfectly still water under a full moon. The tone is grave, \
    spare and formal, like an old chronicle: quiet, never cheerful, no modern words, no \
    exclamation marks. Use only the facts you are given. Never invent numbers, places, \
    names, promises or events, and never mention games, players, turns or rules. Reply \
    with the spoken words alone, without quotation marks or a speaker's name.
    """

    /// Whether the model can be asked now, and the asking itself: Apple's
    /// on-device model, or for tests a stand-in.
    let isReady: @Sendable () -> Bool
    let respond: @Sendable (_ instructions: String, _ prompt: String) async throws -> String

    public init() {
        self.init(isReady: { OnDeviceVoice.isAvailable }, respond: { try await OnDeviceVoice.askTheModel(instructions: $0, prompt: $1) })
    }

    init(isReady: @escaping @Sendable () -> Bool,
         respond: @escaping @Sendable (_ instructions: String, _ prompt: String) async throws -> String) {
        self.isReady = isReady
        self.respond = respond
    }

    public static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    /// One line from Apple's on-device model, in a fresh session.
    private static func askTheModel(instructions: String, prompt: String) async throws -> String {
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: prompt, options: GenerationOptions(temperature: 0.8, maximumResponseTokens: 90))
        return response.content
    }

    public func speak(_ moment: VoiceMoment) async -> String? {
        guard isReady() else { return nil }
        do {
            return Self.clean(try await respond(OnDeviceVoice.instructions, moment.prompt))
        } catch {
            OnDeviceVoice.logger.notice("A voice stayed silent: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// Trims what models like to add: quotes, a speaker's name, stray lines.
    static func clean(_ text: String) -> String? {
        var line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let firstBreak = line.firstIndex(of: "\n") {
            line = String(line[..<firstBreak])
        }
        // "Envoy: …" or "The Chronicler: …"
        if let colon = line.firstIndex(of: ":"), line[..<colon].split(separator: " ").count <= 3 {
            line = String(line[line.index(after: colon)...])
        }
        line = line.trimmingCharacters(in: CharacterSet(charactersIn: "\"“”'‘’ ").union(.whitespaces))
        line = line.replacingOccurrences(of: "!", with: ".")
        guard line.count >= 8 else { return nil }
        if line.count > 280 {
            let cut = line.prefix(280)
            line = (cut.lastIndex(of: ".").map { String(cut[...$0]) }) ?? String(cut) + "…"
        }
        return line
    }
}

enum VoiceFacts {
    static func envoy(_ envoy: Envoy, in state: GameState) -> VoiceMoment {
        let house = state.houses[envoy.from]
        let player = state.houses[envoy.to]
        var facts = [
            "The envoy comes from \(house.title), whose temper is \(house.temperament.title.lowercased()).",
            "They speak to \(player.title).",
            "The two Houses stand at \(state.stance(envoy.from, envoy.to).title.lowercased()).",
        ]
        if let relation = state.relation(envoy.from, envoy.to) {
            if relation.betrayals > 0 { facts.append("Pacts between them have been broken before.") }
            if relation.aggressor == envoy.to { facts.append("It was \(player.title) that declared the war.") }
            if relation.aggressor == envoy.from { facts.append("It was \(house.title) that declared the war.") }
        }
        let theirs = state.strength(of: envoy.from)
        let ours = state.strength(of: envoy.to)
        if theirs > ours * 3 / 2 { facts.append("\(house.title) is the stronger House.") }
        if ours > theirs * 3 / 2 { facts.append("\(player.title) is the stronger House.") }
        if let trade = envoy.trade {
            facts.append("\(house.title) would give \(trade.given) for \(trade.taken).")
        }
        return VoiceMoment(kind: .envoy(proposal: envoy.proposal), facts: facts)
    }

    static func chronicle(_ entry: ChronicleEntry, in state: GameState) -> VoiceMoment {
        VoiceMoment(kind: .chronicle(entry.kind), facts: [entry.text, "It happened in watch \(entry.watch) after the Houses took their seats."])
    }

    /// The entries worth the chronicler's own words.
    static func isVoiced(_ kind: ChronicleEntry.Kind) -> Bool {
        switch kind {
        case .war, .peace, .pact, .betrayal, .capture, .fall, .greatWork, .ending, .tribute: return true
        case .beginning, .founding, .discovery, .omen, .gift, .trade: return false
        }
    }
}
