import Foundation
import FoundationModels
import NullmereCore
import NullmereCounsel
import os

/// Something that can put a moment of the game into a character's words.
/// Voices only speak: what they say never changes the game, but for a
/// ballad the keeper chooses to sing to the realm, and orders the keeper
/// reads and chooses to give.
public protocol Voice: Sendable {
    func speak(_ moment: VoiceMoment) async -> String?
    /// A few lines of verse for a moment, one to a line; nil from a voice
    /// that makes none.
    func compose(_ moment: VoiceMoment) async -> String?
    /// A keeper's own words written as lines of the order book, given the
    /// briefing of what their House has and knows; nil from a voice that
    /// reads none.
    func read(orders words: String, briefing: String) async -> String?
    /// The same reading, with why the voice wrote no lines where it wrote
    /// none, as the keeper is told it.
    func reading(orders words: String, briefing: String) async -> OrdersHeard
    /// A moment's words, with why the voice gave none where it gave none,
    /// as the keeper is told it.
    func speaking(_ moment: VoiceMoment) async -> WordsHeard
}

extension Voice {
    public func compose(_ moment: VoiceMoment) async -> String? { nil }
    public func read(orders words: String, briefing: String) async -> String? { nil }
    public func reading(orders words: String, briefing: String) async -> OrdersHeard {
        let lines = await read(orders: words, briefing: briefing)
        return OrdersHeard(lines: lines, trouble: lines == nil ? .silent : nil)
    }
    public func speaking(_ moment: VoiceMoment) async -> WordsHeard {
        let words = await speak(moment)
        return WordsHeard(words: words, trouble: words == nil ? .silent : nil)
    }
}

/// What a voice made of a moment: its words, or why it gave none.
public struct WordsHeard: Sendable, Equatable {
    public let words: String?
    public let trouble: CounselTrouble?

    public init(words: String?, trouble: CounselTrouble?) {
        self.words = words
        self.trouble = trouble
    }
}

/// What a voice made of a keeper's own words: the order book's lines it
/// wrote, or why it wrote none.
public struct OrdersHeard: Sendable, Equatable {
    public let lines: String?
    public let trouble: CounselTrouble?

    public init(lines: String?, trouble: CounselTrouble?) {
        self.lines = lines
        self.trouble = trouble
    }
}

/// A moment worth a few spoken words, with everything the speaker may know.
public struct VoiceMoment: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        /// An envoy addressing the player.
        case envoy(proposal: Proposal)
        /// The chronicler recording an entry of the lake's history.
        case chronicle(ChronicleEntry.Kind)
        /// A ballad of a deed, as the halls around the lake would sing it.
        case ballad
        /// What the Still shows a keeper's House in a dream at the dark of
        /// the moon.
        case dream
        /// The riddle of the realm's past the lake sets a keeper's House at
        /// the half moon.
        case riddle
        /// A commander held prisoner, telling their captors a true thing of
        /// their own House.
        case prisoner
        /// A House's few words for its dead, set on the water with the
        /// light of its vigil.
        case vigil
        /// One of the hold's folk at the keeper's gate with a plea.
        case petition
        /// The watchman at the House's watchfire, telling what its light
        /// made out marching dark.
        case watchman
        /// A hamlet's eldest welcoming the House's Lanterns, or the words
        /// cut at a barrow's mouth, once the Lanterns have sought it.
        case find(Find.Kind)
        /// The words cut on the stone of a barrow the House raised over a
        /// field's dead.
        case grave
        /// The Pedlar of the Still calling up from his skiff to the House's
        /// hold, offering his wares.
        case pedlar
        /// The caretaker who kept the House greeting its keeper on their
        /// return, telling what passed while they were away.
        case caretaker
        /// A commander's word to the keeper as they turn to the company
        /// the commander leads.
        case commander
        /// A reeve's word to the keeper as they turn to a hold of theirs.
        case reeve
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
            task = Voicing.envoyTask(proposal)
        case .chronicle:
            task = "Write the chronicler's single line recording this, as it would stand in an old book of the lake. One sentence, at most 30 words."
        case .ballad:
            task = "Make a short ballad of this deed, as the halls around the lake would sing it: four lines, each of at most ten words. "
                + "Reply with the four lines alone, one to a line, with no title."
        case .dream:
            task = Voicing.dreamTask
        case .riddle:
            task = Voicing.riddleTask
        case .prisoner:
            task = Voicing.prisonerTask
        case .vigil:
            task = GameState.vigilWordsAsked
        case .petition:
            task = Voicing.petitionTask
        case .watchman:
            task = Voicing.watchmanTask
        case .find(let kind):
            task = kind == .hamlet ? Voicing.hamletTask : Voicing.barrowTask
        case .grave:
            task = Voicing.graveTask
        case .pedlar:
            task = Voicing.pedlarTask
        case .caretaker:
            task = Voicing.caretakerTask
        case .commander:
            task = Voicing.commanderTask
        case .reeve:
            task = Voicing.reeveTask
        }
        return Voicing.asking(task, facts: facts)
    }
}

/// Speaks through Apple's on-device model with the Foundation Models
/// framework. Each line gets a fresh session, so nothing accumulates.
public struct OnDeviceVoice: Voice {
    private static let logger = Logger(subsystem: "online.nullmere.game", category: "voices")

    static let instructions = Voicing.instructions

    /// What the House's clerk is told: to write the keeper's words as the
    /// order book's lines, and nothing else.
    static let clerk = OrderClerk.instructions

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

    /// The model's state in words: ready, or why it isn't.
    public static var availability: String {
        let availability = SystemLanguageModel.default.availability
        if case .available = availability { return "ready" }
        return "not ready (\(availability))"
    }

    /// One answer from Apple's on-device model, in a fresh session: the
    /// clerk reads closely, where the voices speak freely.
    private static func askTheModel(instructions: String, prompt: String) async throws -> String {
        let session = LanguageModelSession(instructions: instructions)
        let options = instructions == clerk ? GenerationOptions(temperature: 0.1, maximumResponseTokens: 200)
            : GenerationOptions(temperature: 0.8, maximumResponseTokens: 160)
        let response = try await session.respond(to: prompt, options: options)
        return response.content
    }

    public func speak(_ moment: VoiceMoment) async -> String? {
        await speaking(moment).words
    }

    /// A moment's words from the model, or why there were none: not ready
    /// on this Mac, an answer in no shape to speak, or the model's own
    /// trouble as counsel names it.
    public func speaking(_ moment: VoiceMoment) async -> WordsHeard {
        guard isReady() else { return WordsHeard(words: nil, trouble: OnDeviceVoice.trouble() ?? .unavailable(.modelNotReady)) }
        do {
            let words = Self.clean(try await respond(OnDeviceVoice.instructions, moment.prompt))
            return WordsHeard(words: words, trouble: words == nil ? .garbled : nil)
        } catch {
            OnDeviceVoice.logger.notice("A voice stayed silent: \(String(describing: error), privacy: .public)")
            return WordsHeard(words: nil, trouble: CommanderCounselSession.trouble(from: error, availability: { SystemLanguageModel.default.availability }))
        }
    }

    public func compose(_ moment: VoiceMoment) async -> String? {
        guard isReady() else { return nil }
        do {
            return Self.verse(try await respond(OnDeviceVoice.instructions, moment.prompt))
        } catch {
            OnDeviceVoice.logger.notice("A ballad stayed unmade: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    public func read(orders words: String, briefing: String) async -> String? {
        await reading(orders: words, briefing: briefing).lines
    }

    /// The keeper's words read by the model, or why they weren't: not ready
    /// on this Mac, or the model's own trouble as counsel names it.
    public func reading(orders words: String, briefing: String) async -> OrdersHeard {
        guard isReady() else { return OrdersHeard(lines: nil, trouble: OnDeviceVoice.trouble() ?? .unavailable(.modelNotReady)) }
        do {
            return OrdersHeard(lines: try await respond(OnDeviceVoice.clerk, Self.orders(words, briefing: briefing)), trouble: nil)
        } catch {
            OnDeviceVoice.logger.notice("Orders went unread: \(String(describing: error), privacy: .public)")
            return OrdersHeard(lines: nil, trouble: CommanderCounselSession.trouble(from: error, availability: { SystemLanguageModel.default.availability }))
        }
    }

    /// Why Apple's on-device model can't be asked on this Mac now, or nil.
    static func trouble() -> CounselTrouble? {
        CommanderCounselSession.trouble(for: SystemLanguageModel.default.availability)
    }

    /// What the clerk is asked: the briefing, then the keeper's words.
    static func orders(_ words: String, briefing: String) -> String {
        briefing + "\n\nThe keeper says:\n" + words.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A ballad's lines as the realm would keep them, from what the model
    /// said: a title, numbering and quotes dropped, no exclamations; nil
    /// when what is left is no ballad.
    static func verse(_ text: String) -> String? {
        var lines = text.split(whereSeparator: \.isNewline).map { line -> String in
            var kept = line.trimmingCharacters(in: .whitespaces)
            // "1. ", "2) ", "- " or "• " before a line.
            if let space = kept.firstIndex(of: " "), kept[..<space].allSatisfy({ $0.isNumber || ".)-•*".contains($0) }),
               kept[..<space].contains(where: { !$0.isNumber }) {
                kept = String(kept[space...])
            }
            kept = kept.trimmingCharacters(in: CharacterSet(charactersIn: "\"“”'‘’*_ ").union(.whitespaces))
            return kept.replacingOccurrences(of: "!", with: ".")
        }.filter { !$0.isEmpty }
        // "The Ballad of the Grey Ford", "Title: …", "Verse:" above the lines.
        if let first = lines.first?.lowercased(), first.hasPrefix("the ballad") || first.hasPrefix("ballad") || first.hasPrefix("title")
            || first.hasSuffix(":") {
            lines.removeFirst()
        }
        return GameState.sung(lines.prefix(GameState.balladLines.upperBound).joined(separator: "\n"))?.joined(separator: "\n")
    }

    /// Trims what models like to add: quotes, a speaker's name, stray
    /// lines; as the phone holds its own model's words (`Voicing.cleaned`).
    static func clean(_ text: String) -> String? { Voicing.cleaned(text) }
}

enum VoiceFacts {
    /// A riddle, for the Still to set: the line of the past with its name
    /// taken out, and when. The name itself the model is never given.
    static func riddle(_ riddle: Riddle) -> VoiceMoment {
        VoiceMoment(kind: .riddle, facts: Voicing.riddle(riddle).facts)
    }

    /// A prisoner questioned: who they are, whose, and the true thing they tell.
    static func prisoner(_ prisoner: Commander, told word: String, in state: GameState) -> VoiceMoment {
        VoiceMoment(kind: .prisoner, facts: state.voiced(prisoner: prisoner, told: word).facts)
    }

    /// Words for a House's dead, for its vigil: whose they were, how many
    /// of its companies of war fell, and where and when its last battles
    /// cost it companies, as its own reports tell them.
    static func vigil(of house: Int, in state: GameState, reports: [BattleReport]) -> VoiceMoment {
        VoiceMoment(kind: .vigil, facts: state.vigilFacts(of: house, reports: reports))
    }

    /// A dream, for the Still to tell: what it showed, plainly, and when.
    static func dream(_ dream: Dream, in state: GameState) -> VoiceMoment {
        VoiceMoment(kind: .dream, facts: state.voiced(dream).facts)
    }

    /// A plea at the gate: who brings it, what the folk ask and would do,
    /// and what turning it away would cost.
    static func petition(_ petition: Petition, in state: GameState) -> VoiceMoment {
        VoiceMoment(kind: .petition, facts: state.voiced(petition).facts)
    }

    /// What a watchfire's light made out marching dark, for its watchman to
    /// tell: where the fire burns, whose company passed, how many and
    /// where, and how its House stands with the keeper's.
    static func watchman(_ sighting: Watchfire.Sighting, fire: Hex, for house: Int, in state: GameState) -> VoiceMoment {
        VoiceMoment(kind: .watchman, facts: state.voiced(sighting, fire: fire, for: house).facts)
    }

    /// A hamlet's folk or a barrow's stones, once the House's Lanterns have
    /// sought it, from what the realm's chronicle says came of it; nothing
    /// before.
    static func find(_ find: Find, by house: Int, in state: GameState) -> VoiceMoment? {
        state.voiced(find, by: house).map { VoiceMoment(kind: .find(find.kind), facts: $0.facts) }
    }

    /// A barrow the House raised: who raised it and when, over how many,
    /// whose dead and where they fell. Nil for another House's.
    static func grave(_ grave: Grave, by house: Int, in state: GameState) -> VoiceMoment? {
        state.voiced(grave, for: house).map { VoiceMoment(kind: .grave, facts: $0.facts) }
    }

    /// The pedlar lying off the House's hold, for his call from the water:
    /// where he lies, what he still offers and for what, what he has sold,
    /// and when he poles away.
    static func pedlar(_ pedlar: Pedlar, in state: GameState) -> VoiceMoment {
        VoiceMoment(kind: .pedlar, facts: state.voiced(pedlar).facts)
    }

    /// What passed while the keeper was away, for the caretaker who kept
    /// their House to tell on their return.
    static func caretaker(_ report: AwayReport, house: Int, in state: GameState) -> VoiceMoment {
        let title = state.houses.indices.contains(house) ? state.houses[house].title : ""
        return VoiceMoment(kind: .caretaker, facts: report.voiced(house: title).facts)
    }

    /// A commander's word on the company they lead, for the commander to
    /// give as the keeper turns to it; nil unless they lead it at its head.
    static func commander(_ counsel: CommanderCounsel) -> VoiceMoment? {
        counsel.word.map { VoiceMoment(kind: .commander, facts: $0.facts) }
    }

    /// A reeve's word on a hold of the keeper's, for the reeve to give as
    /// the keeper turns to it; nil unless the hold is the House's own.
    static func reeve(of hold: Int, for house: Int, in state: GameState) -> VoiceMoment? {
        state.reeveWord(of: hold, for: house).map { VoiceMoment(kind: .reeve, facts: $0.facts) }
    }

    static func envoy(_ envoy: Envoy, in state: GameState) -> VoiceMoment {
        VoiceMoment(kind: .envoy(proposal: envoy.proposal), facts: state.voiced(envoy).facts)
    }

    /// A ballad of a Chronicle entry, as a House's keeper would have it
    /// sung: the deed, when it was, and whose hall sings it.
    static func ballad(_ entry: ChronicleEntry, in state: GameState, by house: Int) -> VoiceMoment {
        var facts = [entry.text, "It happened in watch \(entry.watch) after the Houses took their seats."]
        if state.houses.indices.contains(house) {
            facts.append("It is sung in the hall of \(state.houses[house].title), of the \(state.heritage(of: house).title).")
        }
        return VoiceMoment(kind: .ballad, facts: facts)
    }

    static func chronicle(_ entry: ChronicleEntry, in state: GameState) -> VoiceMoment {
        VoiceMoment(kind: .chronicle(entry.kind), facts: [entry.text, "It happened in watch \(entry.watch) after the Houses took their seats."])
    }

    /// The entries worth the chronicler's own words.
    static func isVoiced(_ kind: ChronicleEntry.Kind) -> Bool {
        switch kind {
        case .war, .peace, .pact, .betrayal, .capture, .fall, .greatWork, .ending, .tribute, .battle: return true
        case .beginning, .founding, .discovery, .omen, .gift, .trade, .seating, .learning, .commander, .hunt, .alliance, .rally, .happening,
             .edict, .title, .augury, .whisper: return false
        }
    }
}
