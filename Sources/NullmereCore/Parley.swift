import Foundation

/// Whom a keeper may parley with in their own words through Apple's
/// on-device model on the Mac or the phone (beyond Rise of Kingdoms, whose
/// envoys and captives never speak).
public enum ParleySubject: Hashable, Sendable {
    /// A steward's envoy waiting on the keeper's answer, by its id.
    case envoy(Int)
    /// A commander the keeper's House holds prisoner, by their id.
    case prisoner(Int)

    /// What the keeper does with what is put to them, as its button says
    /// it on the Mac and the phone: an envoy's answer given, an order for a
    /// prisoner given.
    public var giving: String {
        switch self {
        case .envoy: return "Give the answer"
        case .prisoner: return "Give the order"
        }
    }
}

/// A parley as the model holds it and the keeper sees it: who speaks, from
/// the realm's own facts alone as the keeper's view tells them, and the one
/// thing they may put to the keeper to give, weighed as the order book
/// weighs its line; what comes of it is the realm's to decide. Spoken only
/// by the device's own model, and nothing in its place.
public protocol Parley: Sendable {
    /// Whom the parley is with.
    var subject: ParleySubject { get }
    /// The keeper's view of the realm the parley is grounded in.
    var state: GameState { get }
    /// The keeper's House.
    var player: Int { get }
    /// Who speaks, as the parley's title names them: "The envoy of House
    /// Venn", "Mabyn the Grey".
    var speaker: String { get }
    /// Who they are, as a sentence names them: "the envoy of House Venn",
    /// "Mabyn the Grey".
    var named: String { get }
    /// What the keeper addresses: "the envoy", "the prisoner".
    var addressed: String { get }
    /// For whom the device's model speaks, as the foot says it: "an
    /// envoy", "a prisoner".
    var spokenFor: String { get }
    /// Beneath their name: what an envoy carries and its House's temper;
    /// whose a prisoner is and their level.
    var subtitle: String { get }
    /// What the keeper is told of them, as their card or row tells it.
    var summary: String { get }
    /// What the model is told: who it speaks as, what it keeps to, and how
    /// it puts something to the keeper.
    var instructions: String { get }
    /// The facts as the model is given them.
    var briefing: String { get }
    /// What the keeper is told as the parley opens.
    var opening: String { get }
    /// What the one spoken with is told once something is put to the
    /// keeper: who decides, and what follows.
    var whenPut: String { get }
    /// Something put to the keeper, weighed as the order book weighs its
    /// line; told why not where it can't be.
    func putAnswer(_ answer: String) -> CounselProposal
    /// What changed in the parley's facts as the realm moved on, since the
    /// parley as it stood before; nil for nothing new.
    func news(since before: any Parley) -> ParleyNews?
}

/// What changed in a parley as the realm moved on: what the one spoken with
/// is told when the keeper next speaks, and what the keeper is shown of it
/// at once, if anything.
public struct ParleyNews: Equatable, Sendable {
    public let told: String
    public let shown: String?

    public init(told: String, shown: String? = nil) {
        self.told = told
        self.shown = shown
    }
}

/// What every parley shares.
public enum Parleys {
    /// The parley a keeper may hold with whom it names, as the realm now
    /// stands in their view; nil where there is none to be had.
    public static func parley(_ subject: ParleySubject, in state: GameState, player: Int) -> (any Parley)? {
        switch subject {
        case .envoy(let id): return EnvoyParley(state: state, player: player, envoy: id)
        case .prisoner(let id): return PrisonerParley(state: state, player: player, prisoner: id)
        }
    }

    /// The facts as a model is given them.
    public static func briefing(_ facts: [String]) -> String {
        "What you know:\n" + facts.map { "- \($0)" }.joined(separator: "\n")
    }

    /// What was said earlier in a parley, for the model to recall when it
    /// is begun afresh: the last exchanges, the keeper's words and the
    /// answers; nil for none.
    public static func recalled(_ exchanges: [CounselMemory.Exchange]) -> String? {
        guard !exchanges.isEmpty else { return nil }
        return exchanges.suffix(recalledExchanges).map { "The keeper: \($0.asked)\nYou: \($0.answered)" }
            .joined(separator: "\n")
    }

    /// The most exchanges recalled when a parley is begun afresh.
    public static let recalledExchanges = 4

    /// The footing of a parley on the Mac or the phone: who speaks for the
    /// one parleyed with and how long it took, or that nothing speaks in
    /// their place.
    public static func foot(on device: String, canAsk: Bool, for whom: String, firstWords: Double? = nil, whole: Double? = nil) -> String {
        guard canAsk else { return "Only Apple's on-device model speaks for \(whom), and nothing speaks in its place" }
        let spoken = "Spoken by Apple's on-device model on this \(device)"
        guard let firstWords, let whole else { return spoken }
        return spoken + String(format: " · first words %.1f s, all of it %.1f s", firstWords, whole)
    }
}
