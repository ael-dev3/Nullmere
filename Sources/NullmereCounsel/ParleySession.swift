import Combine
import Foundation
import FoundationModels
import NullmereCore
import os

/// Where what is put to the keeper goes while the model speaks: the parley
/// as it stands (renewed as the realm moves on), and each thing put to the
/// keeper since the session last asked. An actor, for the model calls its
/// tool away from the main thread.
public actor ParleyBench {
    public private(set) var parley: any Parley
    private var looks: [String] = []
    private var proposals: [CounselProposal] = []

    public init(_ parley: any Parley) {
        self.parley = parley
    }

    /// New facts, as the watch turns or the keeper's answers land.
    public func renew(_ parley: any Parley) {
        self.parley = parley
    }

    /// Something put to the keeper, weighed as the realm weighs every order:
    /// put to them if it can be given, and the one who put it told either
    /// way.
    public func putAnswer(_ answer: String) -> String {
        let proposal = parley.putAnswer(answer)
        if proposal.isGiven {
            proposals.append(proposal)
            return "Put to the keeper: \(proposal.told) \(parley.whenPut)"
        }
        looks.append("Weighed \(proposal.told), which cannot be given: \(proposal.why ?? "the realm would not take it")")
        return "That cannot be put to the keeper: \(proposal.why ?? "the realm would not take it.")"
    }

    /// What was weighed and put to the keeper since last asked; forgotten here.
    public func taken() -> (looks: [String], proposals: [CounselProposal]) {
        defer {
            looks.removeAll()
            proposals.removeAll()
        }
        return (looks, proposals)
    }
}

/// The envoy's one tool: the keeper's answer put to them to give, never
/// given by the envoy.
struct PutAnswerToKeeper: Tool {
    let bench: ParleyBench
    let name = "putAnswerToKeeper"
    let description = "Puts the keeper's answer to your House's terms to them, for them to give: accept your House's offer, "
        + "refuse it, or half (offer half a demand of tribute in its place). Use it only once the keeper has said their answer."

    @Generable
    struct Arguments {
        @Guide(description: "The keeper's answer: accept, refuse or half")
        var answer: String
    }

    func call(arguments: Arguments) async throws -> String {
        await bench.putAnswer(arguments.answer)
    }
}

/// A prisoner's one tool: what the keeper would do with them put to the
/// keeper to give, never given by the prisoner.
struct PutToKeeper: Tool {
    let bench: ParleyBench
    let name = "putToKeeper"
    let description = "Puts what the keeper would do with you to them, for them to give: question (they question you, and the realm "
        + "says what true thing you tell) or let go (they let you go home). Use it only once the keeper has said it."

    @Generable
    struct Arguments {
        @Guide(description: "What the keeper would do: question or let go")
        var deed: String
    }

    func call(arguments: Arguments) async throws -> String {
        await bench.putAnswer(arguments.deed)
    }
}

/// A petitioner's one tool: the keeper's answer to the plea put to them to
/// give, never given by the petitioner.
struct PutPleaToKeeper: Tool {
    let bench: ParleyBench
    let name = "putPleaToKeeper"
    let description = "Puts the keeper's answer to your plea to them, for them to give: grant (they grant it, paying what your "
        + "folk ask) or turn away (they turn it away). Use it only once the keeper has said their answer."

    @Generable
    struct Arguments {
        @Guide(description: "The keeper's answer: grant or turn away")
        var answer: String
    }

    func call(arguments: Arguments) async throws -> String {
        await bench.putAnswer(arguments.answer)
    }
}

/// A parley with an envoy waiting on the keeper, a commander the keeper's
/// House holds prisoner or a petitioner at the gate, spoken by Apple's
/// on-device model on this device and nowhere else: a conversation the model
/// holds while it lasts, grounded in the keeper's own view of the realm,
/// with the one tool that puts the keeper's answer, or what they would do
/// with the prisoner, to them to give. Each answer streams as it is spoken
/// and may be stopped; one slow to begin is given up; trouble is told
/// plainly and never answered for; when the parley outgrows what the model
/// holds, it is begun afresh from what was said. Once the one parleyed with
/// has gone, nothing more is asked of them.
@MainActor
public final class ParleySession: ObservableObject {
    public typealias Line = CommanderCounselSession.Line
    public typealias Offer = CommanderCounselSession.Offer
    public typealias Timing = CommanderCounselSession.Timing

    /// Whom the parley is with.
    public let subject: ParleySubject
    @Published public private(set) var lines: [Line] = []
    @Published public private(set) var offers: [Offer] = []
    /// The answer as it is being spoken.
    @Published public private(set) var partial: String?
    @Published public private(set) var answering = false
    @Published public private(set) var trouble: CounselTrouble?
    @Published public private(set) var timing: Timing?
    /// Whether the one parleyed with has gone: an envoy answered or gone
    /// home unanswered, a prisoner let go, ransomed or slipped away.
    @Published public private(set) var gone = false
    public private(set) var parley: any Parley
    /// What was said, the keeper's words and the answers, for the parley to
    /// be begun afresh from.
    public private(set) var exchanges: [CounselMemory.Exchange] = []

    let bench: ParleyBench
    private let model: SystemLanguageModel
    private let availability: () -> SystemLanguageModel.Availability
    private var session: LanguageModelSession?
    private var task: Task<Void, Never>?
    private var watchdog: Task<Void, Never>?
    private var firstWords: Date?
    private var gaveUp = false
    private var since: [String] = []
    private var made = 0

    /// Seconds an answer may take to begin before it is given up: this
    /// parley's own, less in a test of giving up.
    var firstWordsLimit = CommanderCounselSession.firstWordsTimeout
    /// Where an answer's words come from in place of the model, in tests of
    /// how a parley shows an answer as it streams, stops it, gives it up and
    /// tells its trouble: each element the answer so far. Never set in the
    /// game, where every answer is Apple's on-device model's own.
    var speaker: ((String) -> AsyncThrowingStream<String, Error>)?
    static let logger = Logger(subsystem: "online.nullmere.game", category: "parley")

    public init(parley: any Parley, model: SystemLanguageModel = .default,
                availability: (() -> SystemLanguageModel.Availability)? = nil) {
        subject = parley.subject
        self.parley = parley
        self.model = model
        self.availability = availability ?? { model.availability }
        bench = ParleyBench(parley)
    }

    /// Why the one parleyed with can't be spoken with now, or nil when the
    /// model can be asked.
    public var unavailable: CounselTrouble? {
        CommanderCounselSession.trouble(for: availability())
    }

    /// What the model is told: who it speaks as, what they know, and what
    /// was said so far when the parley is begun afresh.
    var instructions: String {
        var text = parley.instructions + "\n\n" + parley.briefing
        if let recalled = Parleys.recalled(exchanges) {
            text += "\n\nWhat was said so far in this parley:\n" + recalled
        }
        return text
    }

    /// The one tool of whom the parley is with.
    private var tool: any Tool {
        switch subject {
        case .envoy: return PutAnswerToKeeper(bench: bench)
        case .prisoner: return PutToKeeper(bench: bench)
        case .petition: return PutPleaToKeeper(bench: bench)
        }
    }

    private func makeSession() -> LanguageModelSession {
        let made = LanguageModelSession(model: model, tools: [tool], instructions: instructions)
        session = made
        return made
    }

    /// Readies the model as the parley opens, so the first answer begins
    /// sooner.
    public func prewarm() {
        // A stand-in speaker leaves no model to warm.
        guard unavailable == nil, speaker == nil, !gone else { return }
        (session ?? makeSession()).prewarm()
    }

    private func add(_ kind: Line.Kind, _ text: String) {
        made += 1
        lines.append(Line(id: made, kind: kind, text: text))
    }

    /// Speaks to the one parleyed with, in the keeper's own words.
    public func ask(_ words: String) {
        let asked = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !asked.isEmpty, !answering, !gone else { return }
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
        // What came to pass since the keeper last spoke, told with what they say.
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
                // Outgrown: begun afresh from what was said.
                session = nil
                answered = try await respond(prompt)
            }
            await takeFromBench()
            let said = CommanderCounselSession.cleaned(answered)
            guard !said.isEmpty else { throw CounselTrouble.garbled }
            add(.commander, said)
            exchanges.append(CounselMemory.Exchange(watch: parley.state.watch, asked: asked, answered: said))
            if exchanges.count > CounselMemory.kept { exchanges.removeFirst(exchanges.count - CounselMemory.kept) }
            let done = Date()
            let first = (firstWords ?? done).timeIntervalSince(began), whole = done.timeIntervalSince(began)
            timing = Timing(firstWords: first, whole: whole)
            ParleySession.logger.info("The parley answered in \(whole, format: .fixed(precision: 2)) s, first words after \(first, format: .fixed(precision: 2)) s")
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
            ParleySession.logger.notice("The parley gave no answer: \(String(describing: error), privacy: .public)")
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
        // Stopped, it is stopped, however its stream ended: what came of it
        // is never taken for the answer.
        try Task.checkCancellation()
        return text
    }

    /// What was weighed and put to the keeper, shown as it comes.
    func takeFromBench() async {
        let taken = await bench.taken()
        for look in taken.looks { add(.look, look) }
        for proposal in taken.proposals {
            made += 1
            offers.append(Offer(id: made, proposal: proposal, state: .waiting))
        }
    }

    /// Stops the answer being spoken.
    public func stop() {
        task?.cancel()
    }

    /// The parley as the realm now stands: the one parleyed with told what
    /// changed when next the keeper speaks, and the keeper shown at once what
    /// is theirs to see (what a prisoner questioned told); or, with them
    /// gone, ended, said once.
    public func renew(_ renewed: (any Parley)?) {
        guard let renewed, renewed.subject == subject else {
            guard !gone else { return }
            gone = true
            stop()
            add(.look, "\(parley.speaker) has gone.")
            return
        }
        if let news = renewed.news(since: parley) {
            since.append(news.told)
            if let shown = news.shown { add(.look, shown) }
        }
        parley = renewed
        let bench = self.bench
        Task { await bench.renew(renewed) }
    }

    /// The keeper gives what was put to them: the order to carry out, once,
    /// and the one who put it told of it next the keeper speaks.
    public func give(_ offer: Offer) -> Command? {
        guard let index = offers.firstIndex(where: { $0.id == offer.id }), offers[index].state == .waiting,
              let command = offers[index].proposal.command else { return nil }
        offers[index].state = .given
        since.append("The keeper gave the answer: \(offers[index].proposal.told)")
        return command
    }

    /// The keeper sets something put to them aside, and the one who put it
    /// is told of it.
    public func setAside(_ offer: Offer) {
        guard let index = offers.firstIndex(where: { $0.id == offer.id }), offers[index].state == .waiting else { return }
        offers[index].state = .setAside
        since.append("The keeper set aside the answer you put to them: \(offers[index].proposal.told)")
    }
}
