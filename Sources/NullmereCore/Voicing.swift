import Foundation

/// What every voice of the realm keeps to when a device's own model gives
/// it words, on the Mac and the phone alike.
public enum Voicing {
    /// The voices' instructions, given the model with every moment.
    public static let instructions = """
    You give voice to characters in Nullmere Online, a game of great Houses around a vast \
    black lake of dead, perfectly still water under a full moon. The tone is grave, \
    spare and formal, like an old chronicle: quiet, never cheerful, no modern words, no \
    exclamation marks. Use only the facts you are given. Never invent numbers, places, \
    names, promises or events, and never mention games, players, turns or rules. Reply \
    with the spoken words alone, without quotation marks or a speaker's name.
    """

    /// A moment as a voice is asked to speak it: what to say, then what is
    /// known, a fact to a line.
    public static func asking(_ task: String, facts: [String]) -> String {
        task + "\n\nWhat is known:\n" + facts.map { "- \($0)" }.joined(separator: "\n")
    }
}

extension Voicing {
    /// One of the realm's characters given words by a device's own model,
    /// on the Mac and the phone alike: what the model is asked to do, and
    /// the realm's own facts it keeps to, a fact to a line.
    public struct Moment: Equatable, Sendable {
        public let task: String
        public let facts: [String]

        public init(task: String, facts: [String]) {
            self.task = task
            self.facts = facts
        }

        /// What the model is asked.
        public var prompt: String { Voicing.asking(task, facts: facts) }
    }

    /// A character's words as a device's model gave them, held as the Mac
    /// and the phone alike show them: the first line alone, a speaker's
    /// name and quotes dropped, no exclamations, at most 280 characters cut
    /// at a full stop; nil for what is too short to be words.
    public static func cleaned(_ text: String) -> String? {
        var line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let firstBreak = line.firstIndex(of: "\n") {
            line = String(line[..<firstBreak])
        }
        // "Envoy: …" or "The Chronicler: …"
        if let colon = line.firstIndex(of: ":"), line[..<colon].split(separator: " ").count <= 3 {
            line = String(line[line.index(after: colon)...])
        }
        line = line.trimmingCharacters(in: CharacterSet(charactersIn: "\"“”'‘’ ").union(.whitespaces))
        line = line.replacingOccurrences(of: "!", with: ".")
        guard line.count >= 8 else { return nil }
        if line.count > 280 {
            let cut = line.prefix(280)
            line = (cut.lastIndex(of: ".").map { String(cut[...$0]) }) ?? String(cut) + "…"
        }
        return line
    }

    /// While a device's model gives one of the realm's characters words, as
    /// the Mac and the phone tell it: "Apple's on-device model gives the
    /// envoy words… 1.4 s".
    public static func atWork(_ who: String, seconds: Double) -> String {
        "Apple's on-device model gives \(who) words… " + String(format: "%.1f s", max(0, seconds))
    }

    /// A moment keyed as the device keeps its words: "envoy-12",
    /// "dream-40", "riddle-30", "prisoner-7-25-2".
    public struct Keyed: Equatable, Sendable {
        public let key: String
        public let moment: Moment

        public init(key: String, moment: Moment) {
            self.key = key
            self.moment = moment
        }
    }

    /// An envoy of a steward's House, speaking its offer to the keeper.
    public static func envoyTask(_ proposal: Proposal) -> String {
        let offer: String
        switch proposal {
        case .peace: offer = "an end to the war between their House and the player's"
        case .pact: offer = "a pact: shared sight and no war between the Houses"
        case .fealty: offer = "their House's fealty: beaten, they would serve the player's House as its vassal"
        case .tribute: offer = "tribute: a fifth of the player's stores, or their companies will march"
        case .trade: offer = "a trade of stores, on the terms given"
        }
        let verb = proposal == .tribute ? "demanding" : "offering"
        return "Speak as the envoy, addressing the player's House directly, \(verb) \(offer). One or two sentences, at most 40 words."
    }

    /// The Still telling the dreamer what it showed them.
    public static let dreamTask = "Speak as the still black lake itself, to one who wakes from a dream at the dark of the moon: tell them what the water "
        + "showed them, keeping every name and number as given. Two sentences, at most 40 words."

    /// The Still setting the half moon's riddle of the realm's past.
    public static let riddleTask = "Speak as the still black lake itself, setting a riddle of the realm's past at the half moon: ask whose House did "
        + "what is told, keeping every name and number as given and the blank ——— where the name was taken out. "
        + "One or two sentences, at most 40 words."

    /// A riddle, for the Still to set: the line of the past with its name
    /// taken out, and when; the name itself the model is never given.
    public static func riddle(_ riddle: Riddle) -> Moment {
        Moment(task: riddleTask, facts: [riddle.line, "It is the half moon."])
    }

    /// A captured commander telling their captors a true thing of their House.
    public static let prisonerTask = "Speak as the captured commander, questioned by their captors and telling them, against their will, the one thing "
        + "about their own House that is told here, keeping every name and number as given. One or two sentences, at most 40 words."
}

extension GameState {
    /// An envoy, for the device's model to give words: whose House sends
    /// it and its temper, to whom, how the two Houses stand and have dealt,
    /// which is the stronger, and a trade's terms.
    public func voiced(_ envoy: Envoy) -> Voicing.Moment {
        let house = houses[envoy.from]
        let player = houses[envoy.to]
        var facts = [
            "The envoy comes from \(house.title), whose temper is \(house.temperament.title.lowercased()).",
            "They speak to \(player.title).",
            "The two Houses stand at \(stance(envoy.from, envoy.to).title.lowercased()).",
        ]
        if let relation = relation(envoy.from, envoy.to) {
            if relation.betrayals > 0 { facts.append("Pacts between them have been broken before.") }
            if relation.aggressor == envoy.to { facts.append("It was \(player.title) that declared the war.") }
            if relation.aggressor == envoy.from { facts.append("It was \(house.title) that declared the war.") }
        }
        let theirs = strength(of: envoy.from)
        let ours = strength(of: envoy.to)
        if theirs > ours * 3 / 2 { facts.append("\(house.title) is the stronger House.") }
        if ours > theirs * 3 / 2 { facts.append("\(player.title) is the stronger House.") }
        if let trade = envoy.trade {
            facts.append("\(house.title) would give \(trade.given) for \(trade.taken).")
        }
        return Voicing.Moment(task: Voicing.envoyTask(envoy.proposal), facts: facts)
    }

    /// A dream, for the Still to tell: what it showed, plainly, and when.
    public func voiced(_ dream: Dream) -> Voicing.Moment {
        Voicing.Moment(task: Voicing.dreamTask, facts: [told(dream), "It is the dark of the moon."])
    }

    /// A riddle, for the Still to set: the line of the past with its name
    /// taken out, and when. The name itself the model is never given.
    public func voiced(_ riddle: Riddle) -> Voicing.Moment { Voicing.riddle(riddle) }

    /// A prisoner questioned: who they are, whose, and the true thing they tell.
    public func voiced(prisoner: Commander, told word: String) -> Voicing.Moment {
        let house = houses.indices.contains(prisoner.owner) ? houses[prisoner.owner].title : "a fallen House"
        return Voicing.Moment(task: Voicing.prisonerTask, facts: ["\(prisoner.name), \(prisoner.archetype.named) of \(house), is held prisoner.", word])
    }

    /// The moments a keeper's device gives words to, keyed as it keeps
    /// them, in their view of the world: envoys of stewards' Houses waiting
    /// on them (a keeper's envoy carries their own words), what the Still
    /// showed the House, its riddle while unanswered, and what each
    /// prisoner it holds last told.
    public func voicedMoments(for house: Int) -> [Voicing.Keyed] {
        var moments: [Voicing.Keyed] = []
        for envoy in envoys where envoy.to == house && houses.indices.contains(envoy.from) && !houses[envoy.from].isPlayer {
            moments.append(Voicing.Keyed(key: "envoy-\(envoy.id)", moment: voiced(envoy)))
        }
        for dream in dreams(of: house) {
            moments.append(Voicing.Keyed(key: "dream-\(dream.watch)", moment: voiced(dream)))
        }
        if let riddle = riddle(of: house), riddle.answered == nil {
            moments.append(Voicing.Keyed(key: "riddle-\(riddle.set)", moment: voiced(riddle)))
        }
        for prisoner in prisoners(heldBy: house) {
            guard let captive = prisoner.captive, let word = captive.told?.last else { continue }
            moments.append(Voicing.Keyed(key: GameState.voiceKey(of: prisoner, captive), moment: voiced(prisoner: prisoner, told: word)))
        }
        return moments
    }

    /// The key of what a prisoner last told, in this captivity of theirs.
    public static func voiceKey(of prisoner: Commander, _ captive: Captivity) -> String {
        "prisoner-\(prisoner.id)-\(captive.since)-\(captive.questioned)"
    }
}
