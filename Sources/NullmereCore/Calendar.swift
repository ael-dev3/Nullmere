/// The realm's calendar (after Rise of Kingdoms' events calendar): what is
/// coming over the watches ahead, foretold from the courses the realm keeps:
/// each happening by its kind, the ford's opening and its closing, the
/// Still Hour, the half moons' riddles, the dark's dreams, the Ring's
/// honours at the full, the eclipse, and the keeper's own pedlar. Every
/// keeper's copy foretells it as the realm does, for it needs nothing the
/// keeper can't see.
public struct CalendarEntry: Equatable, Sendable, Identifiable {
    public enum Kind: Equatable, Sendable {
        case happening(HappeningKind)
        case happeningEnds(HappeningKind)
        case fordOpens, fordCloses, stillHour, riddle, dreams, ringHonours, eclipse, pedlar
    }

    public var id: String { "\(watch)-\(title)" }
    public let watch: Int
    public let kind: Kind

    public var title: String {
        switch kind {
        case .happening(let kind): return "\(kind.title) begins"
        case .happeningEnds(let kind): return "\(kind.title) ends"
        case .fordOpens: return "The ford lies bare"
        case .fordCloses: return "The water comes back over the ford"
        case .stillHour: return "The Still Hour"
        case .riddle: return "The lake's riddle"
        case .dreams: return "The Still dreams"
        case .ringHonours: return "The Ring's honours"
        case .eclipse: return "The moon is eaten"
        case .pedlar: return "Your pedlar comes"
        }
    }
}

extension GameState {
    /// How far ahead the calendar foretells.
    public static let calendarSpan = 30

    /// What is coming from the next watch over `span` watches, in the order
    /// it comes; for a House, with its own pedlar.
    public func calendar(for house: Int, span: Int = GameState.calendarSpan) -> [CalendarEntry] {
        var entries: [CalendarEntry] = []
        for at in (watch + 1)...(watch + span) {
            if let number = Happening.number(beginningAt: at) {
                entries.append(CalendarEntry(watch: at, kind: .happening(Happening.kind(number: number, from: dealt.firstHappening))))
            }
            if let happening, happening.ends == at {
                entries.append(CalendarEntry(watch: at, kind: .happeningEnds(happening.kind)))
            }
            if GameState.fordOpen(at: at), !GameState.fordOpen(at: at - 1) {
                entries.append(CalendarEntry(watch: at, kind: .fordOpens))
            }
            if !GameState.fordOpen(at: at), GameState.fordOpen(at: at - 1) {
                entries.append(CalendarEntry(watch: at, kind: .fordCloses))
            }
            if GameState.isStillHour(at: at) { entries.append(CalendarEntry(watch: at, kind: .stillHour)) }
            if GameState.riddleMoons.contains(GameState.moonAge(at: at)) { entries.append(CalendarEntry(watch: at, kind: .riddle)) }
            if GameState.moonAge(at: at) == GameState.dreamingMoon { entries.append(CalendarEntry(watch: at, kind: .dreams)) }
            if GameState.moonAge(at: at) == 0, ring != nil { entries.append(CalendarEntry(watch: at, kind: .ringHonours)) }
            if GameState.isEclipse(at: at) { entries.append(CalendarEntry(watch: at, kind: .eclipse)) }
            if houses.indices.contains(house), houses[house].isPlayer, GameState.pedlarComes(to: house, from: at) == at {
                entries.append(CalendarEntry(watch: at, kind: .pedlar))
            }
        }
        return entries
    }
}
