import Foundation
import FoundationModels
import NullmereCore

/// Words written by Apple's on-device model on this device, on the phone
/// as on the Mac, from the realm's own facts and under the voices' rules,
/// held to the words the realm carries: a House's few words for its dead,
/// for its vigil on the water (`GameState.vigilFacts`), or the words of one
/// of the realm's characters, an envoy, the Still or a prisoner
/// (`Voicing.Moment`). Where the model can't write them (the device can't
/// run it, Apple Intelligence is off, it isn't ready, it fails or is slow),
/// why, and no words made up in their place.
public typealias VigilWriter = ModelWriter

public struct ModelWriter: Sendable {
    /// What came of the asking: the words and how long the model took, or
    /// why there were none; both nil where the writing was stopped.
    public struct Written: Sendable, Equatable {
        public let words: String?
        public let trouble: CounselTrouble?
        public let seconds: Double?

        /// The writing stopped by the keeper: nothing written, nothing wrong.
        public static let stopped = Written(words: nil, trouble: nil, seconds: nil)
    }

    /// Seconds the model is given before its writing is given up.
    public static let patience: Double = 25

    /// Why the model can't be asked now, or nil when it can.
    let trouble: @Sendable () -> CounselTrouble?
    /// The asking itself: Apple's on-device model, or for tests a stand-in.
    let respond: @Sendable (_ prompt: String) async throws -> String
    let patience: Double

    /// The writer of Apple's on-device model on this device.
    public init() {
        self.init(trouble: { CommanderCounselSession.trouble(for: SystemLanguageModel.default.availability) }) { prompt in
            try await ModelWriter.askTheModel(prompt)
        }
    }

    init(trouble: @escaping @Sendable () -> CounselTrouble?, patience: Double = ModelWriter.patience,
         respond: @escaping @Sendable (_ prompt: String) async throws -> String) {
        self.trouble = trouble
        self.respond = respond
        self.patience = patience
    }

    /// One answer from Apple's on-device model, in a fresh session, under
    /// the voices' rules.
    private static func askTheModel(_ prompt: String) async throws -> String {
        let session = LanguageModelSession(instructions: Voicing.instructions)
        let options = GenerationOptions(temperature: 0.8, maximumResponseTokens: 120)
        return try await session.respond(to: prompt, options: options).content
    }

    /// Before the keeper asks: why the model can't write words for their
    /// dead here; nil when it can.
    public var unavailable: String? { trouble()?.unwritten }

    /// Why the model can give the realm's characters no words of their own
    /// here, the realm's plain words standing alone; nil when it can.
    public var unvoiced: String? { trouble()?.unvoiced }

    /// The words for a House's dead, from its count of its fallen and where
    /// and when its reports say they fell, in `world`, the keeper's view.
    /// They go to the realm with the vigil, so they are held to the words
    /// the realm carries (`Envoy.carried`).
    public func write(for house: Int, in world: GameState, reports: [BattleReport]) async -> Written {
        await write(Voicing.Moment(task: GameState.vigilWordsAsked, facts: world.vigilFacts(of: house, reports: reports))) { answer in
            Envoy.carried(answer.trimmingCharacters(in: CharacterSet(charactersIn: "\"“”'‘’*").union(.whitespacesAndNewlines)))
        }
    }

    /// The words of one of the realm's characters: asked of the model as
    /// `moment.prompt`, timed, held as the Mac holds its voices' words
    /// (`Voicing.cleaned`); they stay on the device.
    public func write(_ moment: Voicing.Moment) async -> Written {
        await write(moment, held: Voicing.cleaned)
    }

    /// The asking itself, the answer held as `held` holds it: nil for no
    /// words worth the name.
    private func write(_ moment: Voicing.Moment, held: (String) -> String?) async -> Written {
        if let trouble = trouble() { return Written(words: nil, trouble: trouble, seconds: nil) }
        let prompt = moment.prompt
        let began = Date()
        do {
            let answer = try await OrderClerk.within(patience) { [respond] in try await respond(prompt) }
            if Task.isCancelled { return .stopped }
            let words = held(answer)
            return Written(words: words, trouble: words == nil ? .garbled : nil, seconds: Date().timeIntervalSince(began))
        } catch {
            if Task.isCancelled || error is CancellationError { return .stopped }
            return Written(words: nil, trouble: CommanderCounselSession.trouble(from: error), seconds: nil)
        }
    }
}
