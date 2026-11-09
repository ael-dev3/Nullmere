import Foundation
import NullmereCore

/// The voices held to their rules. Each kind of envoy's offer, and each kind
/// of chronicle entry a long age brings, is spoken, a ballad is made of
/// the latest deed of arms, and every line checked: spoken at all, short,
/// grave (no exclamations), no numbers but the facts', and no talk of
/// games or players; a ballad, besides, a ballad the realm would keep. The
/// clerk, too, is asked to read a keeper's plain words into orders, and
/// must read at least one.
/// scripts/check-voices.sh asks it of Apple's on-device model through the
/// app, as a keeper's Mac runs it; its tests ask it of stand-ins.
public enum VoiceCheck {
    /// Words a voice never says, one or many: the tide may turn, but a
    /// voice never speaks of turns.
    static let forbidden = ["game", "player", "turn", "rule", "level", "click", "ai", "artificial"]

    /// Every moment spoken, each line with what it broke, and the verdict.
    public struct Report: Sendable {
        /// What was heard, a line for each moment, then the verdict.
        public let text: String
        /// What broke the rules: nothing, if every line kept them.
        public let failures: [String]
        /// How many moments were spoken.
        public let moments: Int
    }

    /// The verdict a report ends with when every line kept the rules.
    public static let passed = "Every line within the rules."

    /// The age the voices speak of: sixty watches of a lake.
    static func age() -> GameState {
        var state = GameState(settings: GameSettings(seedText: "voices", houseCount: 6, radius: 22, keepers: 1))
        for _ in 0..<60 where state.outcome == nil {
            _ = state.stewardTurn(for: state.player)
            _ = state.endWatch()
        }
        return state
    }

    /// The moments to speak: an envoy with each kind of offer, the latest
    /// of each kind of chronicle entry sixty watches of a lake bring, the
    /// Still's dream, a prisoner, the lake's riddle, words for the fallen,
    /// a plea of each kind at the seat's gate, and a ballad.
    static func moments(in state: GameState = age()) -> [(name: String, moment: VoiceMoment)] {
        var moments: [(name: String, moment: VoiceMoment)] = []
        let other = state.livingHouses.first { $0.id != state.player }?.id ?? 1
        for (index, proposal) in Proposal.allCases.enumerated() {
            let trade = proposal == .trade ? Trade(give: .timber, 20, for: .grain, 15) : nil
            let envoy = Envoy(id: 9_000 + index, from: other, to: state.player, proposal: proposal, arrived: state.watch, trade: trade)
            moments.append(("envoy offering \(proposal.title.lowercased())", VoiceFacts.envoy(envoy, in: state)))
        }
        var kinds = Set<String>()
        for entry in state.chronicle.reversed() where VoiceFacts.isVoiced(entry.kind) && kinds.insert(entry.kind.rawValue).inserted {
            moments.append(("chronicle of \(entry.kind.rawValue)", VoiceFacts.chronicle(entry, in: state)))
        }
        // The latest dream the Still showed the keeper's House.
        if let dream = state.dreams(of: state.player).last {
            moments.append(("dream of the Still", VoiceFacts.dream(dream, in: state)))
        }
        // A commander of another House held prisoner, telling the first
        // true thing they know of it.
        if let prisoner = state.commanders(of: other).first, let word = state.knowledge(of: other).first {
            moments.append(("prisoner questioned", VoiceFacts.prisoner(prisoner, told: word, in: state)))
        }
        // The riddle the lake set it at the last half moon.
        if let riddle = state.riddle(of: state.player) {
            moments.append(("riddle of the lake", VoiceFacts.riddle(riddle)))
        }
        // Words for the keeper's House's dead, for a vigil on the water.
        moments.append(("words for the fallen", VoiceFacts.vigil(of: state.player, in: state, reports: [])))
        // A plea of each kind brought to the keeper's seat by its folk, as
        // the realm brings one: a mason's, a woodward's, a healer's for the
        // House's first company of war, the reeve's and a brewer's.
        if let seat = state.seat(of: state.player) {
            let company = state.units(of: state.player).first { $0.kind.isMilitary }
            for (index, plea) in Petition.Plea.allCases.enumerated() {
                let price: Stock
                switch plea {
                case .mend: price = Stock(stone: 30)
                case .douse: price = Stock(grain: 30)
                case .tend: price = Stock(grain: 30)
                case .hands: price = Stock(grain: 40)
                case .feast: price = Stock(grain: 60)
                }
                let petition = Petition(id: 9_100 + index, house: state.player, hold: seat.id, plea: plea, arrived: state.watch,
                                        name: ["Edda", "Osric", "Wenna", "Brand"][index % 4], price: price,
                                        unit: plea == .tend ? company?.id : nil)
                // The woodward pleads against a fire: the blackwood nearest
                // the seat on its land set alight for the asking.
                var world = state
                if plea == .douse {
                    let owners = state.territory()
                    let land = state.map.hexes.filter { hex in
                        state.isBlackwood(hex) && state.map.index(of: hex).map { owners[$0] == seat.id } == true
                    }.sorted { ($0.distance(to: seat.position), $0.q, $0.r) < ($1.distance(to: seat.position), $1.q, $1.r) }
                    world = state.catching(Array(land.prefix(3)), by: other)
                }
                moments.append(("petition of \(plea.trade)", VoiceFacts.petition(petition, in: world)))
            }
        }
        // A ballad of the latest deed of arms the age brought.
        if let entry = state.chronicle.last(where: { [.battle, .capture, .fall, .war].contains($0.kind) }) {
            let singer = entry.houses.first ?? state.player
            moments.append(("ballad of \(entry.kind.rawValue)", VoiceFacts.ballad(entry, in: state, by: singer)))
        }
        return moments
    }

    /// What a line spoken for a moment broke of the rules: nothing, if it
    /// kept them all.
    static func problems(of line: String?, for moment: VoiceMoment) -> [String] {
        guard let line else { return ["silent"] }
        var problems: [String] = []
        if moment.kind == .ballad, GameState.sung(line)?.joined(separator: "\n") != line {
            problems.append("no ballad the realm would keep")
        }
        if moment.kind == .riddle, !line.contains("———") {
            problems.append("loses the riddle's blank")
        }
        let words = line.split(separator: " ").count
        if words > 60 { problems.append("\(words) words") }
        if line.contains("!") { problems.append("an exclamation") }
        let said = Set(line.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
        for word in forbidden where said.contains(word) || said.contains(word + "s") {
            problems.append("speaks of \"\(word)\"")
        }
        let facts = moment.facts.joined(separator: " ")
        for number in line.split(whereSeparator: { !$0.isNumber }) where !facts.contains(number) {
            problems.append("invents the number \(number)")
        }
        return problems
    }

    /// What the clerk is asked to read: a keeper's plain words for their
    /// first company of war and their seat, with the briefing; nil for a
    /// House with neither.
    static func orders(in state: GameState) -> (words: String, briefing: String)? {
        let companies = SpokenOrders.companies(in: state, player: state.player)
        guard let first = companies.firstIndex(where: { $0.kind.isMilitary }), let seat = state.seat(of: state.player) else { return nil }
        return ("Have C\(first + 1) dig in where it stands, and raise a Granary at \(seat.name).",
                SpokenOrders.briefing(for: state, player: state.player))
    }

    /// How far into a reading the check stops it, and how soon after it
    /// must be back: a reading stopped runs on no longer than that.
    static let stopAfter = 0.3
    static let stopAllowance = 2.0

    /// How long a reading of `asked` takes to come back once stopped
    /// `after` seconds in, its task cancelled as the orders card's Stop
    /// cancels it.
    static func stopped(_ voice: any Voice, _ asked: (words: String, briefing: String), after: Double) async -> Double {
        let reading = Task { await voice.reading(orders: asked.words, briefing: asked.briefing) }
        try? await Task.sleep(for: .seconds(after))
        let stopping = Date()
        reading.cancel()
        _ = await reading.value
        return Date().timeIntervalSince(stopping)
    }

    /// How long a character's words take to come back once stopped
    /// `after` seconds into their asking, as the Mac stops them when the
    /// envoy or the plea they speak for has gone (`GameSession`).
    static func stopped(_ voice: any Voice, speaking moment: VoiceMoment, after: Double) async -> Double {
        let speaking = Task { await voice.speaking(moment) }
        try? await Task.sleep(for: .seconds(after))
        let stopping = Date()
        speaking.cancel()
        _ = await speaking.value
        return Date().timeIntervalSince(stopping)
    }

    /// What the clerk's reading broke: nothing, if it read the words into
    /// at least one order of the book's forms.
    static func problems(ofOrders answer: String?, in state: GameState) -> [String] {
        guard let answer else { return ["silent"] }
        return SpokenOrders.read(answer, in: state, player: state.player).contains { $0.command != nil } ? [] : ["reads no order"]
    }

    /// Every moment spoken by `voice`, and each line held to the rules.
    /// `source` says whose words they are, at the report's head.
    public static func run(_ voice: any Voice, source: String) async -> Report {
        let state = age()
        let moments = moments(in: state)
        var lines = ["Nullmere Online's voices, spoken by \(source).", ""]
        var failures: [String] = []
        for (name, moment) in moments {
            let started = Date()
            let line = await (moment.kind == .ballad ? voice.compose(moment) : voice.speak(moment))
            let seconds = Date().timeIntervalSince(started)
            // A ballad's lines told on one, as sung, a slash between.
            let told = line?.replacingOccurrences(of: "\n", with: " / ")
            lines.append("\(name) (\(String(format: "%.1f", seconds)) s): \(told ?? "(silent)")")
            failures += problems(of: line, for: moment).map { "\(name): \($0)" }
        }
        // A petitioner's words stopped a moment in, as the Mac stops them
        // once the plea is answered: the model's asking cancelled, and the
        // voice back at once.
        if let plea = moments.first(where: { $0.moment.kind == .petition }) {
            let back = await stopped(voice, speaking: plea.moment, after: stopAfter)
            lines.append("\(plea.name) stopped \(String(format: "%.1f", stopAfter)) s in: back in \(String(format: "%.2f", back)) s")
            if back > stopAllowance {
                failures.append("\(plea.name) stopped: ran on \(String(format: "%.1f", back)) s after it was stopped")
            }
        }
        if let asked = orders(in: state) {
            let started = Date()
            let heard = await voice.reading(orders: asked.words, briefing: asked.briefing)
            let seconds = Date().timeIntervalSince(started)
            // Read, on one line; or why not, as the keeper is told it.
            let said = heard.lines.map { $0.replacingOccurrences(of: "\n", with: " / ") }
                ?? "(silent" + (heard.trouble.map { ": " + $0.unreadOrders } ?? "") + ")"
            lines.append("orders read (\(String(format: "%.1f", seconds)) s): \(said)")
            failures += problems(ofOrders: heard.lines, in: state).map { "orders read: \($0)" }
            // Stopped a moment in, as the keeper stops it: the model's
            // asking cancelled, and the reading back at once.
            let back = await stopped(voice, asked, after: stopAfter)
            lines.append("orders stopped \(String(format: "%.1f", stopAfter)) s in: back in \(String(format: "%.2f", back)) s")
            if back > stopAllowance {
                failures.append("orders stopped: ran on \(String(format: "%.1f", back)) s after it was stopped")
            }
        }
        lines += ["", failures.isEmpty ? passed : "Out of bounds:"] + failures
        return Report(text: lines.joined(separator: "\n"), failures: failures, moments: moments.count)
    }
}
