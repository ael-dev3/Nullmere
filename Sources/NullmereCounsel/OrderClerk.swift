import Foundation
import FoundationModels
import NullmereCore

/// The House's clerk, on the Mac and the phone alike: writes a keeper's own
/// words as lines of the realm's order book through Apple's on-device model,
/// given the briefing of what their House has and knows. The model only
/// reads: each line is then read against the keeper's own view into the
/// order the realm would take or why it wouldn't, and nothing is given
/// until the keeper gives it. Where the model can't read them (the device
/// can't run it, Apple Intelligence is off, it isn't ready, it fails or is
/// slow), the words are read as the order book's lines as written, and the
/// keeper is told why; no other model, and no words made up in its place.
public struct OrderClerk: Sendable {
    /// What the clerk is told: to write the keeper's words as the order
    /// book's lines, and nothing else.
    public static let instructions = """
    You are the clerk of a great House in Nullmere Online. Its keeper tells you in their own words \
    what they would have done; you write it as lines of the House's order book, in exactly the forms \
    given, one order to a line, at most six lines. Name each company by its handle alone, C1, C2 and \
    so on, as the briefing numbers them, and every place, hold, House, work, store and kind of company \
    exactly as the briefing names it. What the keeper would have done while they are away goes in the \
    WHILE AWAY lines. Write only the lines: no numbering, no quotation marks, no words of your \
    own. If the keeper asks for nothing the forms can order, reply NONE.
    """

    /// Seconds the clerk is given before its reading is given up.
    public static let patience: Double = 25

    /// Why the model can't be asked now, or nil when it can.
    let trouble: @Sendable () -> CounselTrouble?
    /// The asking itself: Apple's on-device model, or for tests a stand-in.
    let respond: @Sendable (_ prompt: String) async throws -> String
    let patience: Double

    /// The clerk of Apple's on-device model on this device.
    public init() {
        self.init(trouble: { CommanderCounselSession.trouble(for: SystemLanguageModel.default.availability) }) { prompt in
            try await OrderClerk.askTheModel(prompt)
        }
    }

    /// One answer from Apple's on-device model, in a fresh session, read
    /// closely.
    private static func askTheModel(_ prompt: String) async throws -> String {
        let session = LanguageModelSession(instructions: OrderClerk.instructions)
        let options = GenerationOptions(temperature: 0.1, maximumResponseTokens: 200)
        return try await session.respond(to: prompt, options: options).content
    }

    init(trouble: @escaping @Sendable () -> CounselTrouble?, patience: Double = OrderClerk.patience,
         respond: @escaping @Sendable (_ prompt: String) async throws -> String) {
        self.trouble = trouble
        self.respond = respond
        self.patience = patience
    }

    /// Before the keeper writes: why the model can't read their words here,
    /// and that they will be read as the order book's lines; nil when it can.
    public var unavailable: String? { trouble()?.ordersReadAsWritten }

    /// The keeper's words read against `world`, their view as the briefing
    /// tells it, so the companies' handles hold: by the model where it can
    /// read them, else as written; nothing read if the reading is stopped.
    public func read(_ words: String, in world: GameState, player: Int) async -> SpokenOrders.Reading {
        if let trouble = trouble() {
            return SpokenOrders.reading(words, answer: nil, trouble: trouble, seconds: nil, in: world, player: player)
        }
        let prompt = SpokenOrders.asking(words, in: world, player: player)
        let began = Date()
        do {
            let answer = try await OrderClerk.within(patience) { [respond] in try await respond(prompt) }
            if Task.isCancelled { return .stopped }
            return SpokenOrders.reading(words, answer: answer, trouble: nil, seconds: Date().timeIntervalSince(began), in: world, player: player)
        } catch {
            if Task.isCancelled || error is CancellationError { return .stopped }
            // Silent, the model asked again why it can't read now, if it says.
            let failed = CommanderCounselSession.trouble(from: error)
            return SpokenOrders.reading(words, answer: nil, trouble: failed == .silent ? (trouble() ?? failed) : failed, seconds: nil,
                                        in: world, player: player)
        }
    }

    /// The work's result, or `CounselTrouble.slow` once `seconds` pass first.
    static func within(_ seconds: Double, _ work: @escaping @Sendable () async throws -> String) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask { try await work() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(max(seconds, 0) * 1_000_000_000))
                throw CounselTrouble.slow
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw CounselTrouble.slow }
            return first
        }
    }
}
