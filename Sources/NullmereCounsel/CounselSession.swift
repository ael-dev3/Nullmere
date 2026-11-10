import Combine
import Foundation
import FoundationModels
import NullmereCore
import os

/// What the commander's looks and proposals are made of, shared by the
/// tools the model calls and the session that shows them: the counsel as
/// it stands (renewed as the watch turns), each look taken and each order
/// put forward since the session last asked. An actor, for the model calls
/// its tools away from the main thread.
public actor CounselBench {
    public private(set) var counsel: CommanderCounsel
    private var looks: [String] = []
    private var proposals: [CounselProposal] = []
    /// Everything the looks told the model, in order: what its words may
    /// rest on beside the briefing.
    public private(set) var told: [String] = []

    public init(_ counsel: CommanderCounsel) {
        self.counsel = counsel
    }

    /// New facts, as the watch turns or the keeper's orders land.
    public func renew(_ counsel: CommanderCounsel) {
        self.counsel = counsel
    }

    public func report(on handle: String) -> String {
        looks.append("Looked at \(handle.trimmingCharacters(in: .whitespacesAndNewlines))")
        return kept(counsel.report(on: handle))
    }

    public func lookAround(within tiles: Int) -> String {
        looks.append("Looked about their company, \(min(max(tiles, 1), 8)) tiles out")
        return kept(counsel.lookAround(within: tiles))
    }

    public func affairs() -> String {
        looks.append("Weighed the House's affairs")
        return kept(counsel.affairs)
    }

    public func house(named name: String) -> String {
        looks.append("Looked at \(name.trimmingCharacters(in: .whitespacesAndNewlines))")
        return kept(counsel.report(onHouse: name))
    }

    public func alliance() -> String {
        looks.append("Looked to the alliance")
        return kept(counsel.allianceReport)
    }

    private func kept(_ said: String) -> String {
        told.append(said)
        return said
    }

    /// An order weighed as the realm weighs one: put to the keeper if it can
    /// be given, and the commander told either way.
    public func propose(_ action: String, company: String, place: String) -> String {
        let proposal = counsel.propose(action, company: company, place: place)
        if proposal.isGiven {
            proposals.append(proposal)
        } else {
            looks.append("Weighed \(proposal.told), which cannot be ordered: \(proposal.why ?? "the realm would not take it")")
        }
        return kept(proposal.answer)
    }

    /// What was looked at and put forward since last asked; forgotten here.
    public func taken() -> (looks: [String], proposals: [CounselProposal]) {
        defer {
            looks.removeAll()
            proposals.removeAll()
        }
        return (looks, proposals)
    }
}

/// A company of the House, told by its handle.
struct CompanyReport: Tool {
    let bench: CounselBench
    let name = "reportOnCompany"
    let description = "Tells what one company of your House is and where it stands, by its handle: C1, C2 and so on."

    @Generable
    struct Arguments {
        @Guide(description: "The company's handle, such as C1")
        var handle: String
    }

    func call(arguments: Arguments) async throws -> String {
        await bench.report(on: arguments.handle)
    }
}

/// What the House sees about the commander's company.
struct LookAbout: Tool {
    let bench: CounselBench
    let name = "lookAboutYourCompany"
    let description = "Tells what your House sees about the company you lead: other Houses' companies, holds, holy sites and lairs, the nearest first."

    @Generable
    struct Arguments {
        @Guide(description: "How many tiles about your company to look, from 1 to 8")
        var tiles: Int
    }

    func call(arguments: Arguments) async throws -> String {
        await bench.lookAround(within: arguments.tiles)
    }
}

/// The House's affairs.
struct HouseAffairs: Tool {
    let bench: CounselBench
    let name = "yourHousesAffairs"
    let description = "Tells your House's holds, companies and stores, and the Houses it is at war with or in a pact with."

    @Generable
    struct Arguments {
        @Guide(description: "What you want to know of: holds, stores or wars")
        var about: String
    }

    func call(arguments: Arguments) async throws -> String {
        await bench.affairs()
    }
}

/// Another House, as the keeper's own view tells it.
struct HouseReport: Tool {
    let bench: CounselBench
    let name = "reportOnAHouse"
    let description = "Tells what your House knows of another House, by its name: where it stands by might and by foes slain, "
        + "its alliance, how it stands with your House, its holds and its seat."

    @Generable
    struct Arguments {
        @Guide(description: "The House's name, such as House Orren")
        var house: String
    }

    func call(arguments: Arguments) async throws -> String {
        await bench.house(named: arguments.house)
    }
}

/// The House's alliance, as the keeper's own view tells it.
struct AllianceReport: Tool {
    let bench: CounselBench
    let name = "yourAlliance"
    let description = "Tells of your House's alliance: who leads it and its officers, its Houses, where it stands, the ground it has "
        + "marked, its side's rallies gathering, its study, its works and coffers, allies' works your House may help and its shares "
        + "of spoils; or, sworn to none, the alliances that have invited it."

    @Generable
    struct Arguments {
        @Guide(description: "What you want to know of: its Houses, marks, rallies, study or works")
        var about: String
    }

    func call(arguments: Arguments) async throws -> String {
        await bench.alliance()
    }
}

/// An order put to the keeper, never given by the commander.
struct ProposeOrder: Tool {
    let bench: CounselBench
    let name = "proposeAnOrder"
    let description = "Puts an order for a company of your House to your keeper, who decides whether to give it. "
        + "Only march, strike, fortify, halt, drill, raise (a tier, by a Muster Hall of your House where the company stands), "
        + "kindle (set the blackwood where the company stands alight), "
        + "douse (its torches, to march dark: a tile slower, seen by other Houses only close by), light (its torches again), "
        + "wait (lie in wait in the blackwood, marching dark, and spring upon the first foe at war that comes within reach), "
        + "bury (the dead lying unburied where the company stands), gather (a store, at the nearest site of it the company may work), "
        + "recall (from the land's work, home with its load), scout (another House's hold, with Lanterns near it), "
        + "reinforce (keep the gates of a hold of your House or an ally's) or rally (join a rally of your side still gathering)."

    @Generable
    struct Arguments {
        @Guide(description: "What the company is to do: march, strike, fortify, halt, drill, raise, kindle, douse, light, wait, bury, gather, recall, scout, reinforce or rally")
        var action: String
        @Guide(description: "The company's handle, such as C1")
        var company: String
        @Guide(description: "For march or strike, the place by its name as you were told it; for gather, the store: grain, timber, stone or moonsalt; for scout or reinforce, the hold; for rally, its target or empty; otherwise empty")
        var place: String
    }

    func call(arguments: Arguments) async throws -> String {
        await bench.propose(arguments.action, company: arguments.company, place: arguments.place)
    }
}

/// Counsel with one of the keeper's commanders, spoken by Apple's on-device
/// model on this device and nowhere else: a conversation the model holds
/// while it lasts, grounded in what the keeper's own view tells, with looks
/// it may take and orders it may only put forward. Each answer streams as
/// it is spoken and may be stopped; one slow to begin is given up; trouble
/// is told plainly and never answered for; when the counsel outgrows what
/// the model holds, it is begun afresh from what the commander remembers.
@MainActor
public final class CommanderCounselSession: ObservableObject {
    /// A line of the counsel, as it is shown.
    public struct Line: Identifiable, Equatable, Sendable {
        public enum Kind: Equatable, Sendable {
            case keeper, commander, look, trouble
        }

        public let id: Int
        public let kind: Kind
        public let text: String

        public init(id: Int, kind: Kind, text: String) {
            self.id = id
            self.kind = kind
            self.text = text
        }
    }

    /// An order the commander put forward, waiting on the keeper.
    public struct Offer: Identifiable, Equatable, Sendable {
        public enum State: Equatable, Sendable {
            case waiting, given, setAside
        }

        public let id: Int
        public let proposal: CounselProposal
        public internal(set) var state: State

        public init(id: Int, proposal: CounselProposal, state: State = .waiting) {
            self.id = id
            self.proposal = proposal
            self.state = state
        }
    }

    /// How long an answer took: to its first words, and whole.
    public struct Timing: Equatable, Sendable {
        public let firstWords: Double
        public let whole: Double
    }

    /// The commander taking counsel.
    public let id: Int
    @Published public private(set) var lines: [Line] = []
    @Published public private(set) var offers: [Offer] = []
    /// The answer as it is being spoken.
    @Published public private(set) var partial: String?
    @Published public private(set) var answering = false
    @Published public private(set) var trouble: CounselTrouble?
    @Published public private(set) var timing: Timing?
    public private(set) var memory: CounselMemory
    public private(set) var counsel: CommanderCounsel
    /// Where what the commander remembers is kept, after each answer.
    public var onRemember: ((CounselMemory) -> Void)?

    let bench: CounselBench
    private let model: SystemLanguageModel
    private let availability: () -> SystemLanguageModel.Availability
    private var session: LanguageModelSession?
    private var task: Task<Void, Never>?
    private var watchdog: Task<Void, Never>?
    private var firstWords: Date?
    private var gaveUp = false
    private var since: [String] = []
    private var made = 0

    /// Seconds an answer may take to begin before it is given up.
    public static let firstWordsTimeout: Double = 25
    /// This counsel's own: the same, but less in a test of giving up.
    var firstWordsLimit = CommanderCounselSession.firstWordsTimeout
    /// Where an answer's words come from in place of the model, in tests of
    /// how counsel shows an answer as it streams, stops it, gives it up and
    /// tells its trouble: each element the answer so far. Never set in the
    /// game, where every answer is Apple's on-device model's own.
    var speaker: ((String) -> AsyncThrowingStream<String, Error>)?
    static let logger = Logger(subsystem: "online.nullmere.game", category: "counsel")

    public init(counsel: CommanderCounsel, memory: CounselMemory, model: SystemLanguageModel = .default,
                availability: (() -> SystemLanguageModel.Availability)? = nil) {
        id = counsel.commander.id
        self.counsel = counsel
        self.memory = memory
        self.model = model
        self.availability = availability ?? { model.availability }
        bench = CounselBench(counsel)
    }

    /// Why counsel can't be taken now, or nil when the model can be asked.
    public var unavailable: CounselTrouble? {
        CommanderCounselSession.trouble(for: availability())
    }

    public nonisolated static func trouble(for availability: SystemLanguageModel.Availability) -> CounselTrouble? {
        switch availability {
        case .available:
            return nil
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return .unavailable(.deviceNotEligible)
            case .appleIntelligenceNotEnabled:
                return .unavailable(.appleIntelligenceOff)
            case .modelNotReady:
                return .unavailable(.modelNotReady)
            @unknown default:
                return .unavailable(.modelNotReady)
            }
        }
    }

    /// The trouble an error stands for, where the system said nothing of
    /// why told by the model's own word on why it can't be asked now, if it
    /// has one, asked again after the failure (Apple Intelligence turned off
    /// meanwhile, the model gone unready); else as the error stands.
    public nonisolated static func trouble(from error: Error, availability: () -> SystemLanguageModel.Availability) -> CounselTrouble {
        let told = CommanderCounselSession.trouble(from: error)
        guard told == .silent, let reason = CommanderCounselSession.trouble(for: availability()) else { return told }
        return reason
    }

    /// The trouble an error from the model, or one of its tools, stands for.
    public nonisolated static func trouble(from error: Error) -> CounselTrouble {
        if let error = error as? CounselTrouble { return error }
        if let error = error as? LanguageModelSession.GenerationError {
            if case .exceededContextWindowSize = error { return .tooLong }
            if case .assetsUnavailable = error { return .assetsMissing }
            if case .guardrailViolation = error { return .refused }
            if case .refusal = error { return .refused }
            if case .unsupportedLanguageOrLocale = error { return .language }
            if case .rateLimited = error { return .busy }
            if case .concurrentRequests = error { return .busy }
            if case .decodingFailure = error { return .garbled }
            if case .unsupportedGuide = error { return .garbled }
            return .told(error.localizedDescription)
        }
        if let error = error as? LanguageModelSession.ToolCallError {
            if case .failed(let said) = CounselTrouble.told(error.localizedDescription) {
                return .failed("a look failed: \(said)")
            }
            return .failed("a look failed")
        }
        return .told(error.localizedDescription)
    }

    /// What the model is told: the commander, the briefing, and what they
    /// recall of earlier counsel, within the model's context.
    var instructions: String {
        let room = CounselBudget.recall(context: model.contextSize, instructions: counsel.instructions, briefing: counsel.briefing)
        var text = counsel.instructions + "\n\n" + counsel.briefing
        if let recalled = memory.recalled(within: room) {
            text += "\n\nWhat you recall of earlier counsel with your keeper:\n" + recalled
        }
        return text
    }

    private func makeSession() -> LanguageModelSession {
        let tools: [any Tool] = [CompanyReport(bench: bench), LookAbout(bench: bench), HouseAffairs(bench: bench), HouseReport(bench: bench),
                                 AllianceReport(bench: bench), ProposeOrder(bench: bench)]
        let made = LanguageModelSession(model: model, tools: tools, instructions: instructions)
        session = made
        return made
    }

    /// Readies the model as the counsel opens, so the first answer begins
    /// sooner.
    public func prewarm() {
        // A stand-in speaker leaves no model to warm.
        guard unavailable == nil, speaker == nil else { return }
        (session ?? makeSession()).prewarm()
    }

    private func add(_ kind: Line.Kind, _ text: String) {
        made += 1
        lines.append(Line(id: made, kind: kind, text: text))
    }

    /// Asks the commander, in the keeper's own words.
    public func ask(_ words: String) {
        let asked = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !asked.isEmpty, !answering else { return }
        if let unavailable {
            trouble = unavailable
            add(.trouble, unavailable.said)
            return
        }
        add(.keeper, asked)
        trouble = nil
        answering = true
        partial = ""
        firstWords = nil
        gaveUp = false
        let began = Date()
        // What the keeper did since they last spoke, told with what they say.
        let prompt = since.isEmpty ? asked : "Since you last spoke: " + since.joined(separator: " ") + "\n\n" + asked
        since.removeAll()
        task = Task { [weak self] in
            await self?.answer(prompt, asked: asked, began: began)
        }
        watchdog = Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.firstWordsLimit ?? CommanderCounselSession.firstWordsTimeout))
            guard let self, !Task.isCancelled, self.answering, self.firstWords == nil else { return }
            self.gaveUp = true
            self.task?.cancel()
        }
    }

    private func answer(_ prompt: String, asked: String, began: Date) async {
        defer {
            watchdog?.cancel()
            answering = false
            partial = nil
        }
        do {
            let answered: String
            do {
                answered = try await respond(prompt)
            } catch let error where CommanderCounselSession.trouble(from: error) == .tooLong {
                // Outgrown: begun afresh from what the commander remembers.
                session = nil
                answered = try await respond(prompt)
            }
            await takeFromBench()
            let said = CommanderCounselSession.cleaned(answered)
            guard !said.isEmpty else { throw CounselTrouble.garbled }
            add(.commander, said)
            memory.remember(asked, said, at: counsel.state.watch)
            onRemember?(memory)
            let done = Date()
            let first = (firstWords ?? done).timeIntervalSince(began), whole = done.timeIntervalSince(began)
            timing = Timing(firstWords: first, whole: whole)
            CommanderCounselSession.logger.info("Counsel answered in \(whole, format: .fixed(precision: 2)) s, first words after \(first, format: .fixed(precision: 2)) s")
        } catch {
            await takeFromBench()
            let trouble: CounselTrouble = error is CancellationError || Task.isCancelled
                ? (gaveUp ? .slow : .failed("stopped by the keeper"))
                : CommanderCounselSession.trouble(from: error, availability: availability)
            if trouble == .failed("stopped by the keeper") {
                add(.trouble, "Stopped.")
            } else {
                self.trouble = trouble
                add(.trouble, trouble.said)
            }
            CommanderCounselSession.logger.notice("Counsel gave no answer: \(String(describing: error), privacy: .public)")
        }
    }

    private func respond(_ prompt: String) async throws -> String {
        var text = ""
        if let speaker {
            for try await snapshot in speaker(prompt) {
                try Task.checkCancellation()
                if firstWords == nil { firstWords = Date() }
                text = snapshot
                partial = text
                await takeFromBench()
            }
        } else {
            let session = self.session ?? makeSession()
            let options = GenerationOptions(temperature: 0.5, maximumResponseTokens: CounselBudget.answerTokens)
            for try await snapshot in session.streamResponse(to: prompt, options: options) {
                try Task.checkCancellation()
                if firstWords == nil { firstWords = Date() }
                text = snapshot.content
                partial = text
                await takeFromBench()
            }
        }
        // Stopped, it is stopped, however its stream ended: what came of
        // it is never taken for the answer, nor remembered.
        try Task.checkCancellation()
        return text
    }

    /// Everything the commander's looks told the model this counsel.
    public func told() async -> [String] {
        await bench.told
    }

    /// The looks taken and orders put forward, shown as they come.
    func takeFromBench() async {
        let taken = await bench.taken()
        for look in taken.looks { add(.look, look) }
        for proposal in taken.proposals {
            made += 1
            offers.append(Offer(id: made, proposal: proposal, state: .waiting))
        }
    }

    /// An answer as it is shown: trimmed of the quotes a model likes to set
    /// about it.
    nonisolated static func cleaned(_ text: String) -> String {
        text.trimmingCharacters(in: CharacterSet(charactersIn: "\"“”").union(.whitespacesAndNewlines))
    }

    /// Stops the answer being spoken.
    public func stop() {
        task?.cancel()
    }

    /// New facts as the watch turns: the commander's looks tell the realm as
    /// it now stands.
    public func renew(_ counsel: CommanderCounsel) {
        self.counsel = counsel
        let bench = self.bench
        Task { await bench.renew(counsel) }
    }

    /// The keeper gives an order the commander put forward: the order to
    /// carry out, once, and the commander told of it next they speak.
    public func give(_ offer: Offer) -> Command? {
        guard let index = offers.firstIndex(where: { $0.id == offer.id }), offers[index].state == .waiting,
              let command = offers[index].proposal.command else { return nil }
        offers[index].state = .given
        since.append("Your keeper gave the order: \(offers[index].proposal.told)")
        return command
    }

    /// The keeper sets an order aside, and the commander is told of it.
    public func setAside(_ offer: Offer) {
        guard let index = offers.firstIndex(where: { $0.id == offer.id }), offers[index].state == .waiting else { return }
        offers[index].state = .setAside
        since.append("Your keeper set aside your proposal: \(offers[index].proposal.told)")
    }
}
