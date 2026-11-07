import Foundation

/// What came of reading a keeper's own words into the order book, on the
/// Mac or the phone: read by the device's own model, given the briefing of
/// what the House has and knows, or read as the order book's lines as they
/// are written where the model couldn't read them, and said why, plainly.
/// Either way each line is read against the keeper's own view into the
/// order the realm would take or why it wouldn't (`SpokenOrders.read`), and
/// nothing is given until the keeper gives it.
extension SpokenOrders {
    public struct Reading: Equatable, Sendable {
        /// The lines read, each with its order or why it can't be given.
        public let lines: [Line]
        /// Read by the device's model, not as written.
        public let byModel: Bool
        /// Why the model didn't read them, as the keeper is told it.
        public let trouble: String?
        /// How long the model took to read them.
        public let seconds: Double?
        /// Stopped by the keeper before the model answered: nothing read.
        public let stopped: Bool

        /// The lines whose orders the realm would take as read.
        public var takeable: [Line] { lines.filter { $0.command != nil && $0.why == nil } }

        public init(lines: [Line], byModel: Bool, trouble: String?, seconds: Double?, stopped: Bool = false) {
            self.lines = lines
            self.byModel = byModel
            self.trouble = trouble
            self.seconds = seconds
            self.stopped = stopped
        }

        /// A reading the keeper stopped: nothing read, nothing to give.
        public static let stopped = Reading(lines: [], byModel: false, trouble: nil, seconds: nil, stopped: true)

        /// What the reading came to, in a line: how many orders and by
        /// whom they were read, or why none.
        public var summary: String {
            if stopped { return "Stopped: nothing was read." }
            let by = byModel ? seconds.map { String(format: "Read by Apple's on-device model in %.1f s", $0) } ?? "Read by Apple's on-device model"
                : "Read as the order book's lines, as written"
            if lines.isEmpty { return "\(by): no order in them." }
            let takes = takeable.count
            return "\(by): \(takes) of \(lines.count) \(lines.count == 1 ? "order" : "orders") the realm would take."
        }
    }

    /// The keeper's words read: as the model wrote them into the order
    /// book's lines (`answer`), or, where it couldn't (`trouble`), as the
    /// keeper wrote them.
    public static func reading(_ words: String, answer: String?, trouble: CounselTrouble?, seconds: Double?,
                               in state: GameState, player: Int) -> Reading {
        if let answer {
            return Reading(lines: read(answer, in: state, player: player), byModel: true, trouble: nil, seconds: seconds)
        }
        return Reading(lines: read(words, in: state, player: player), byModel: false,
                       trouble: (trouble ?? .unavailable(.modelNotReady)).unreadOrders, seconds: nil)
    }

    /// What the model is asked: the briefing, then the keeper's words.
    public static func asking(_ words: String, in state: GameState, player: Int) -> String {
        briefing(for: state, player: player) + "\n\nThe keeper says:\n" + words.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension CounselTrouble {
    /// Why the keeper's words weren't read by the device's model, as they
    /// are told it: each reason as itself, and that their words were read
    /// as the order book's lines instead.
    public var unreadOrders: String {
        whyOrdersUnread + ", so your words were read as the order book's lines, as written."
    }

    /// Before the keeper writes, why the device's model can't read their
    /// words, and that they will be read as the order book's lines.
    public var ordersReadAsWritten: String {
        whyOrdersUnread + ", so your words are read as the order book's lines, as written."
    }

    private var whyOrdersUnread: String {
        let why: String
        switch self {
        case .unavailable(.deviceNotEligible): why = "This device can't run Apple's on-device model"
        case .unavailable(.appleIntelligenceOff):
            #if os(iOS)
            why = "Apple Intelligence is turned off in Settings"
            #else
            why = "Apple Intelligence is turned off in System Settings"
            #endif
        case .unavailable(.modelNotReady): why = "Apple's on-device model is still downloading or preparing"
        case .unavailable(.systemTooOld): why = "Apple's on-device model needs a newer system than this one"
        case .refused: why = "Apple's on-device model would not read those words"
        case .language: why = "Apple's on-device model can't make out that language here"
        case .busy: why = "Apple's on-device model is busy with another answer"
        case .tooLong: why = "Those words were more than Apple's on-device model can read at once"
        case .garbled: why = "Apple's on-device model's answer came out in no shape to read"
        case .assetsMissing: why = "Apple's on-device model's files are not yet on this device"
        case .slow: why = "No answer came from Apple's on-device model in time"
        case .failed(let what): why = "Apple's on-device model couldn't read them (\(what))"
        }
        return why
    }
}
