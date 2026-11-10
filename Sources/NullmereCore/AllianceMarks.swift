import Foundation

/// Alliance marks (after Rise of Kingdoms' alliance markers): a keeper who
/// leads an alliance marks ground for its Houses (where to gather, where to
/// strike, what to hold, what to beware), with a few words of their own if
/// they will. The alliance's Houses see each mark where it lies, in the world
/// and on the phone's chart, and no other House does. Three at most an
/// alliance, a fourth taking the oldest's place and a mark on marked ground
/// taking that one's; each lapses `AllianceMark.lasts` watches after it was
/// made, and is gone with its alliance. Keepers make them; stewards leave the
/// ground unmarked, so a world they play alone is as it was.
public struct AllianceMark: Codable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable, PlainCases {
        case gather, strike, hold, beware

        /// What it bids the alliance's Houses, as its flag says it.
        public var title: String {
            switch self {
            case .gather: return "Gather here"
            case .strike: return "Strike here"
            case .hold: return "Hold this ground"
            case .beware: return "Beware"
            }
        }

        /// The hue of its light, red, green and blue from 0 to 1, as the
        /// world and the phone's chart draw it: gold to gather, red to
        /// strike, blue to hold, a pale violet to beware.
        public var hue: (red: Float, green: Float, blue: Float) {
            switch self {
            case .gather: return (1.0, 0.78, 0.3)
            case .strike: return (1.0, 0.22, 0.12)
            case .hold: return (0.3, 0.6, 1.0)
            case .beware: return (0.82, 0.72, 1.0)
            }
        }

        /// Its one word, as its button says it.
        public var word: String {
            switch self {
            case .gather: return "Gather"
            case .strike: return "Strike"
            case .hold: return "Hold"
            case .beware: return "Beware"
            }
        }
    }

    public let id: Int
    public let alliance: Int
    public let kind: Kind
    public let at: Hex
    /// The House whose keeper made it, the alliance's leader as it was made.
    public let by: Int
    /// The watch it was made.
    public let made: Int
    /// The leader's own words on it, if any.
    public let words: String?
    /// The steward Houses of the alliance that have answered it, each told
    /// once.
    public internal(set) var heededBy: [Int]?

    public init(id: Int, alliance: Int, kind: Kind, at: Hex, by: Int, made: Int, words: String? = nil) {
        self.id = id
        self.alliance = alliance
        self.kind = kind
        self.at = at
        self.by = by
        self.made = made
        self.words = words
    }

    /// The marks an alliance keeps at once.
    public static let most = 3
    /// The watches a mark stands before it lapses.
    public static let lasts = 24
    /// The longest words a mark carries.
    public static let wordsLimit = 60

    /// What marking ground does, as the keeper is told it before they do.
    public static let explained = "The alliance's Houses see a mark where it lies and hear of it; no other House does. "
        + "Each stands \(lasts) watches, \(most) at most: another takes the oldest's place, and a mark on marked ground that one's."

    /// The watch it lapses.
    public var lapses: Int { made + AllianceMark.lasts }

    /// What it bids, with its maker's words: "Gather here: “Bring the spears.”".
    public var said: String { words.map { "\(kind.title): “\($0)”" } ?? kind.title }
}

extension GameState {
    /// The marks an alliance has made, the oldest first.
    public func marks(of alliance: Int) -> [AllianceMark] {
        allianceMarks?.filter { $0.alliance == alliance } ?? []
    }

    /// The marks a House's alliance has made, as its keeper sees them.
    public func marksSeen(by house: Int) -> [AllianceMark] {
        alliance(of: house).map { marks(of: $0.id) } ?? []
    }

    /// Who made a mark and how long it stands, as its card and the phone
    /// say it: "Marked by House Arden; it lapses in 12 watches."
    public func markMaker(_ mark: AllianceMark) -> String {
        let maker = houses.indices.contains(mark.by) ? houses[mark.by].title : "a fallen House"
        return "Marked by \(maker); it lapses in \(GameState.watches(max(mark.lapses - watch, 1)))."
    }

    /// The marks an alliance has made, each as its Houses' ledgers say it,
    /// the oldest first: "Strike here, on the barrows by Wenholme: “Before
    /// the moon”. Marked by House Arden; it lapses in 24 watches."
    public func marksSaid(of alliance: Int) -> [String] {
        marks(of: alliance).map { mark in
            "\(mark.kind.title), \(placeName(of: mark.at))" + (mark.words.map { ": “\($0)”" } ?? "") + ". " + markMaker(mark)
        }
    }

    /// A mark's words as it carries them: one line of plain speech, at
    /// most `AllianceMark.wordsLimit` characters; nil for none.
    public static func markWords(_ text: String?) -> String? {
        guard let text, let carried = Envoy.carried(text) else { return nil }
        let kept = String(carried.prefix(AllianceMark.wordsLimit)).trimmingCharacters(in: .whitespaces)
        return kept.isEmpty ? nil : kept
    }

    /// Why a House can't mark that ground for its alliance, if it can't:
    /// only a keeper who leads one, or is one of its officers, may, on
    /// ground their House has seen.
    public func markRefusal(at hex: Hex, as house: Int) -> RuleError? {
        guard houses.indices.contains(house), houses[house].isPlayer, !houses[house].isEliminated else { return .notAKeeper }
        guard let alliance = alliance(of: house) else { return .notInAlliance }
        guard alliance.manages(house) else { return .notAllianceOfficer }
        guard let index = map.index(of: hex) else { return .notApplicable }
        let explored = houses[house].explored
        guard explored.indices.contains(index), explored[index] else { return .unexplored }
        return nil
    }

    /// A keeper leading an alliance, or an officer of it, marks ground for
    /// it: a mark already on that ground gives way to the new one, and with
    /// three standing the oldest does.
    mutating func markGround(_ hex: Hex, _ kind: AllianceMark.Kind, words: String?, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = markRefusal(at: hex, as: house) { throw refusal }
        let alliance = alliance(of: house)!.id
        var kept = allianceMarks ?? []
        var events: [GameEvent] = kept.filter { $0.alliance == alliance && $0.at == hex }.map { .markLifted($0, lapsed: false) }
        kept.removeAll { $0.alliance == alliance && $0.at == hex }
        if let oldest = kept.first(where: { $0.alliance == alliance }), kept.filter({ $0.alliance == alliance }).count >= AllianceMark.most {
            kept.removeAll { $0.id == oldest.id }
            events.append(.markLifted(oldest, lapsed: false))
        }
        let mark = AllianceMark(id: takeID(), alliance: alliance, kind: kind, at: hex, by: house, made: watch, words: GameState.markWords(words))
        allianceMarks = kept + [mark]
        events.append(.groundMarked(mark))
        return events
    }

    /// Why a House can't lift a mark, if it can't: only the leader of the
    /// alliance that made it, or one of its officers, may.
    public func unmarkRefusal(_ id: Int, as house: Int) -> RuleError? {
        guard let mark = allianceMarks?.first(where: { $0.id == id }) else { return .notApplicable }
        guard let alliance = alliance(of: house), alliance.id == mark.alliance else { return .notInAlliance }
        guard alliance.manages(house) else { return .notAllianceOfficer }
        return nil
    }

    /// An alliance's leader, or one of its officers, lifts one of its marks.
    mutating func unmarkGround(_ id: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = unmarkRefusal(id, as: house) { throw refusal }
        let mark = allianceMarks!.first { $0.id == id }!
        allianceMarks?.removeAll { $0.id == id }
        if allianceMarks?.isEmpty == true { allianceMarks = nil }
        return [.markLifted(mark, lapsed: false)]
    }

    /// A steward House of the alliance answers one of its marks, told to
    /// the alliance once.
    mutating func heedMark(_ id: Int, by house: Int) -> [GameEvent] {
        guard let index = allianceMarks?.firstIndex(where: { $0.id == id }),
              !(allianceMarks![index].heededBy ?? []).contains(house) else { return [] }
        allianceMarks![index].heededBy = (allianceMarks![index].heededBy ?? []) + [house]
        return [.markHeeded(allianceMarks![index], by: house)]
    }

    /// As the watch turns: marks past their time lapse, told to their
    /// alliance, and those of an alliance no more are gone with it.
    mutating func lapseMarks() -> [GameEvent] {
        guard let marks = allianceMarks else { return [] }
        let standing = Set((alliances ?? []).map(\.id))
        let lapsed = marks.filter { standing.contains($0.alliance) && watch >= $0.lapses }
        let kept = marks.filter { standing.contains($0.alliance) && watch < $0.lapses }
        allianceMarks = kept.isEmpty ? nil : kept
        return lapsed.map { .markLifted($0, lapsed: true) }
    }
}
