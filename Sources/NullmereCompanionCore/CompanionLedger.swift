import NullmereCore

/// What a keeper's phone shows of their House, read from the view the
/// realm gave them, as the phone's screens list it: its companies and what
/// each is about, with the orders each may be given now; its holds and what
/// they raise; its stores; its alliance and the words said there and to
/// the whole realm; and the realm's chronicle. Each order is offered where
/// it would do something, as cheaply as the screen is drawn; the session
/// holds the one given to the rules before it goes, and the realm, which
/// sees all, decides.
public struct CompanionLedger: Equatable, Sendable {
    /// A company of the House.
    public struct Company: Equatable, Identifiable, Sendable {
        public let id: Int
        /// As the order book names it: kind, tier and where it stands.
        public let name: String
        public let troops: String
        /// Its commander, if one leads it.
        public let leader: String?
        /// What it is about, in a few words.
        public let doing: String
        /// The orders it may be given now, each the realm would take.
        public let orders: [Order]
        /// The holds of the House it may march to now.
        public let marches: [Order]
        /// What it may strike from where it stands: the wilds, and the
        /// companies and holds of Houses at war with this one, in its reach.
        public let strikes: [Order]
        /// The nearest sites of the land it may be sent to gather at.
        public let gathers: [Order]
        /// The rallies of the House's side it may be sent to now.
        public let rallies: [Order]
        /// The nearest of its allies' seats whose gates it may keep.
        public let gates: [Order]
    }

    /// An order offered: what it says, and the command it gives.
    public struct Order: Equatable, Identifiable, Sendable {
        public let title: String
        public let command: Command
        public var id: String { title }
    }

    /// A hold of the House.
    public struct Hold: Equatable, Identifiable, Sendable {
        public let id: Int
        public let name: String
        public let isSeat: Bool
        /// What it raises and musters, and how long each has to go.
        public let work: [String]
        /// The companies it may muster now, at the first tier, the House
        /// able to pay for them.
        public let musters: [Order]
        /// The works it may raise a level now, the House able to pay.
        public let works: [Order]
        /// Its Infirmary while any lie in its beds, as the Mac tells it:
        /// "Infirmary, 2 of 4 beds: Spears II · Bows I, healing".
        public var infirmary: String? = nil
        /// Healing those still waiting, for what it costs, where the rules
        /// would pay for it now.
        public var heal: Order? = nil
        /// The House's letter to the age to come, where this hold keeps it.
        public var letterKept: String? = nil
        /// Whether a letter to the age to come may be sealed here: the
        /// House has sealed none this age, and may.
        public var maySealLetter: Bool = false
        /// Whether a bottle may be set on the water here: a hold on the
        /// shore, none cast from the House this watch.
        public var mayCastBottle: Bool = false
    }

    /// A bottle set on the water from a hold, with these words, signed or
    /// not, where the rules would take it.
    public static func casting(_ words: String, from hold: Int, signed: Bool, world: GameState, player: Int) -> Order? {
        world.castRefusal(words, from: hold, as: player) == nil
            ? Order(title: "Cast the bottle, for \(GameState.bottleCost)", command: .castBottle(words: words, from: hold, signed: signed)) : nil
    }

    /// A letter to the age to come sealed in a hold, in these words, where
    /// the rules would take it.
    public static func sealing(_ words: String, in hold: Int, world: GameState, player: Int) -> Order? {
        world.sealRefusal(words, in: hold, as: player) == nil
            ? Order(title: "Seal the letter, for \(GameState.letterCost)", command: .sealLetter(words: words, hold: hold)) : nil
    }

    /// A line said in the alliance or to the realm.
    public struct Said: Equatable, Identifiable, Sendable {
        public let id: Int
        public let from: String
        public let text: String
        public let watch: Int
        /// Said by this keeper's own House.
        public let isOwn: Bool
        /// Another keeper's line reported to the realm's steward, as the
        /// Mac's Words report it, where the rules would take the report.
        public var report: Order? = nil
        /// Reported by the House already.
        public var reported: Bool = false
    }

    /// One of the House's commanders, who may be asked for counsel: free,
    /// at the head of a company, wounded or held prisoner, as the Mac's
    /// commanders board orders them.
    public struct Commander: Equatable, Identifiable, Sendable {
        public let id: Int
        public let name: String
        /// Their kind and level.
        public let title: String
        /// How they stand: the company they lead, their wound or their captor.
        public let standing: String
        /// A commander held by another House speaks only to their captors.
        public let canCounsel: Bool
        /// The House's companies of war they may take up now: unled, at or
        /// beside one of the House's holds.
        public let leads: [Order]
        /// The companies they may ride second with now, beside their leader.
        public let seconds: [Order]
        /// Their company left, to ride home, while they lead or ride second.
        public let home: Order?
        /// The next ranks of their talents they may learn now, a point each.
        public let talents: [Order]
        /// The pieces of the House's armoury they may take up, from whoever
        /// wears them.
        public let gear: [Order]
        /// Held prisoner by another House: their ransom, where the House's
        /// stores would pay it now.
        public var ransom: Order? = nil
        /// What they wear, slot by slot, each with Take off.
        public var worn: [GearPiece] = []
        /// Their stars, as the Mac's Commanders tell them: "2 of 5 stars ·
        /// Next star: 20 sculptures, 24 kept".
        public var stars: String = ""
        /// A star raised, where the House keeps sculptures enough.
        public var raiseStar: Order? = nil
    }

    /// The Ring, as the Mac's Commanders tell it: where the House stands,
    /// its last bouts, its strongest line to stand, and the other keepers'
    /// lines, each with its standing and weight and a challenge where the
    /// rules would take one now.
    public struct TheRing: Equatable, Sendable {
        /// Another keeper's House standing a line.
        public struct Rival: Equatable, Identifiable, Sendable {
            public let id: Int
            public let name: String
            /// Its standing and what its line weighs.
            public let line: String
            public let challenge: Order?
        }

        public let standing: String
        /// The House's last bouts, the latest last.
        public let bouts: [String]
        /// The House's heaviest commanders stood as its line, where that
        /// would change the line it stands.
        public let stand: Order?
        public let rivals: [Rival]
    }

    /// An oath in force between the House and another, as the Mac's Houses
    /// tell it on the other's line, with whom it is between.
    public struct SwornOath: Equatable, Identifiable, Sendable {
        public let id: Int
        /// "Your oath to House Quell: peace until watch 40", ", renounced"
        /// once it is; or, sworn to the House, "House Quell's oath to you:
        /// 30 grain each watch until watch 40".
        public let terms: String
        /// Renounced with notice, where the House swore it and has not yet.
        public let renounce: Order?
    }

    /// A piece of the House's gear, as the Mac's Commanders tell it: worn
    /// on its commander's line, with Take off; or kept in the armoury, with
    /// each commander free to take it up and Break up for its moonsalt.
    public struct GearPiece: Equatable, Identifiable, Sendable {
        public let id: Int
        /// "Weapon: Fine Moonblade" worn, "Fine Moonblade · weapon" kept.
        public let title: String
        /// What it gives.
        public let effect: String
        /// Worn: taken off, back to the armoury.
        public let takeOff: Order?
        /// Kept: each commander free to take it up.
        public let arm: [Order]
        /// Kept: broken up for its moonsalt.
        public let breakUp: Order?
        /// The moonsalt it breaks up for.
        public let scrap: Int
    }

    /// The House's armoury, as the Mac's Commanders tell it: how full it
    /// is, and the pieces no commander wears.
    public struct Armoury: Equatable, Sendable {
        /// "Armoury · 3 of 12".
        public let heading: String
        public let kept: [GearPiece]
        /// Said where no piece is kept.
        public var none: String? { kept.isEmpty ? GameState.noGearSaid : nil }
    }

    /// The House's Forge, as the Mac's Commanders tell it: how fine it
    /// works, the makings the House keeps, and each piece of the three sets
    /// at the finest it makes, what it gives and takes, with Forge where
    /// the rules would forge it now.
    public struct Forge: Equatable, Sendable {
        public struct Piece: Equatable, Identifiable, Sendable {
            public var id: String { title }
            /// Its kind and the slot it is worn in.
            public let title: String
            /// What it gives, and what forging it takes.
            public let said: String
            public let forge: Order?
        }

        public struct GearLine: Equatable, Identifiable, Sendable {
            public var id: String { name }
            public let name: String
            /// What wearing its pieces together gives.
            public let effect: String
            public let pieces: [Piece]
        }

        /// "Forge · level II", or "Forge" where the House has none.
        public let heading: String
        public let makings: String
        /// How to come by a Forge, where the House has none.
        public let none: String?
        public let sets: [GearLine]

        /// How many pieces the House may forge now.
        public var forgeable: Int { sets.reduce(0) { $0 + $1.pieces.filter { $0.forge != nil }.count } }
    }

    /// The realm's law, as the Mac's Houses tell it: the edict before the
    /// realm, its tally, and the House's vote, or Aye and Nay where the
    /// rules would take its vote now; the edicts holding the realm; and
    /// the edicts the House may put to it now, each for its cost.
    public struct Law: Equatable, Sendable {
        /// An edict the House may put to the realm now.
        public struct Proposal: Equatable, Identifiable, Sendable {
            public var id: String { heading }
            /// "The Moon's Peace".
            public let heading: String
            /// What it would forbid, as a sentence.
            public let law: String
            public let order: Order
        }

        /// The edict before the realm, as the House is told it, and the vote
        /// on it as it stands.
        public let before: String?
        public let tally: String?
        /// How the House voted on it, once it has.
        public let voted: String?
        /// Aye and Nay, while the House may vote.
        public let votes: [Order]
        /// The edicts holding the realm, each in a line.
        public let inForce: [String]
        public let proposals: [Proposal]

        /// Said when no edict is before the realm or holds it.
        public static let none = "No edict holds the realm."

        /// Whether there is anything to tell or do: an edict before the
        /// realm or holding it, or one the House may put.
        public var isEmpty: Bool { before == nil && inForce.isEmpty && proposals.isEmpty }
    }

    /// A commander of another House the House holds prisoner, as the Mac's
    /// Commanders list them: whose, how long until they slip away, the last
    /// true thing they told, and what the rules would let the House do with
    /// them now.
    public struct Prisoner: Equatable, Identifiable, Sendable {
        public let id: Int
        public let name: String
        /// Whose they are, and their level: "of House Wenmor, level 2".
        public let of: String
        /// How long until they slip away.
        public let held: String
        /// The last true thing they told, plainly; nil before they are
        /// questioned.
        public let told: String?
        /// Questioned, where the rules would question them now: once a watch.
        public let question: Order?
        /// Let go home, for nothing.
        public let release: Order
    }

    /// An envoy waiting on the keeper's answer: whose, what it offers in
    /// the words the Mac tells it, the words its House sent with it, how
    /// long it waits, and the answers the rules take.
    public struct Envoy: Equatable, Identifiable, Sendable {
        public let id: Int
        public let from: String
        public let offer: String
        public let terms: String
        public let words: String?
        public let waits: String
        /// Nil while the keeper hasn't what it asks.
        public let accept: Order?
        public let refuse: Order
        /// A steward's demand of tribute, refused, is war at once.
        public let refusingIsWar: Bool
    }

    /// An item of the House's satchel: how many it keeps, what one does, and
    /// the uses the rules would take now.
    public struct Item: Equatable, Identifiable, Sendable {
        public var id: String { kind.rawValue }
        public let kind: ItemKind
        /// So many of it, in words: "2 Salt Hourglasses".
        public let count: String
        public let effect: String
        public let uses: [Order]
    }

    /// Another House as the phone's dealings list it: how it stands with the
    /// keeper's, the envoys the rules would carry to it now, and war, which
    /// the phone asks again before it is declared.
    public struct Dealing: Equatable, Identifiable, Sendable {
        public let id: Int
        public let name: String
        public let stance: String
        public let envoys: [Order]
        /// Gifts of the House's stores the rules would let it send now, as
        /// much as a House takes in gifts in a watch.
        public let gifts: [Order]
        public let war: Order?
        /// Whether it may be offered a trade: no trade crosses a war.
        public let mayTrade: Bool
        /// The House's own envoys on the road to it, each waiting on its
        /// answer, as the Mac's Houses tell them.
        public let waiting: [String]
    }

    /// An offer of trade being made to another House, as the Mac's trade
    /// popover makes one: how its terms weigh and who answers them, or why
    /// they can't be offered, in the rules' words (`Trade.offerSaid`, or
    /// the rules' refusal of the offer); and the offer, where the rules
    /// would take it.
    public struct Trading: Equatable, Sendable {
        public let said: String
        public let offer: Order?
    }

    /// The offer of these terms to that House, from the keeper's House.
    public static func trading(_ trade: Trade, with house: Int, in world: GameState, player: Int) -> Trading {
        guard world.houses.indices.contains(player), world.houses.indices.contains(house) else {
            return Trading(said: RuleError.unknownHouse.description, offer: nil)
        }
        let stock = world.houses[player].stock
        if let problem = trade.problem(with: stock) { return Trading(said: problem, offer: nil) }
        let command = Command.offerTrade(trade, to: house, words: nil)
        if let refusal = world.refusal(of: command, as: player) { return Trading(said: refusal.description, offer: nil) }
        return Trading(said: trade.offerSaid(stock: stock, keeper: world.houses[house].isPlayer),
                       offer: Order(title: "Offer \(trade) to \(world.houses[house].title)", command: command))
    }

    /// The caretaker's standing orders, kept by the realm for while the
    /// keeper is away: what it does by them as the keeper is told it, and
    /// the orders that would change them, each one the rules take.
    public struct Standing: Equatable, Sendable {
        /// "While you are away, your caretaker musters only Spears."
        public let said: String
        /// The one kind of company of war it musters, each kind it doesn't now.
        public let musters: [Order]
        /// The work it raises first wherever it can, each it doesn't now.
        public let raises: [Order]
        /// Every company kept home; peace made or none; tribute paid or
        /// none; and the orders cleared, the House kept as it sees fit.
        public let others: [Order]
    }

    /// A letter between the keeper's House and another keeper's, as the Mac
    /// lines it: "From House Seris: …", or "To House Seris: …".
    public struct Letter: Equatable, Identifiable, Sendable {
        public let id: Int
        public let line: String
        /// Written to the keeper's House, not by it.
        public let incoming: Bool
    }

    /// Another keeper's House the keeper's may write to.
    public struct Correspondent: Equatable, Identifiable, Sendable {
        public let id: Int
        public let name: String
    }

    /// The Spine: the House's next stage, and who may venture up it now.
    public struct Spine: Equatable, Sendable {
        /// Its next stage, what its host weighs and its spoils, and whether
        /// the House has ventured this watch; or every stage the House's.
        public let said: String
        /// A line of the House's strongest free commanders, then each alone,
        /// each where the rules would send it.
        public let ventures: [Order]
    }

    /// The Pedlar of the Still's wares, while he lies off one of the House's
    /// holds: where he lies and when he poles away, and each ware.
    public struct Wares: Equatable, Sendable {
        public let said: String
        public let wares: [Ware]
    }

    /// One of the pedlar's wares: what it is and what he asks, or that it is
    /// sold; bought where the rules would sell it now, or why not.
    public struct Ware: Equatable, Identifiable, Sendable {
        public let id: Int
        public let title: String
        public let buy: Order?
        public let why: String?
    }

    /// The Lyceum's next question the House hasn't answered, while it sits,
    /// as the Mac sets it: one at a time, its four answers to choose from.
    public struct Asked: Equatable, Sendable {
        /// "2 of 5".
        public let place: String
        public let text: String
        public let answers: [Order]
    }

    /// A prophecy of the Augury, as the Mac's Realm panel tells it: who
    /// foretold what and by when, how it stands, and a stake to lay
    /// backing it or against it where the rules take one.
    public struct Foretold: Equatable, Identifiable, Sendable {
        public let id: Int
        public let said: String
        public let standing: String
        public let back: Order?
        public let standAgainst: Order?
    }

    /// A holy site the House has found, as the Mac's Realm panel tells it:
    /// who holds it, and what it gives and where.
    public struct HolySite: Equatable, Identifiable, Sendable {
        public let id: Int
        public let title: String
        public let held: String
        public let said: String
        /// Held by the House or an ally.
        public let isFriendly: Bool
    }

    /// The titles of the Spire, as the Mac's Realm panel tells them: who
    /// names them, each borne and by which House, and whether the House
    /// names them itself.
    public struct Titles: Equatable, Sendable {
        public struct Borne: Equatable, Sendable {
            public let title: String
            public let house: String
            public let effect: String
            public let isBoon: Bool
        }

        public let giver: String
        public let borne: [Borne]
        /// The House holds the broken Spire and names the realm's titles.
        public let mayName: Bool
        /// Told in an age with a broken Spire found, or while any title is borne.
        public let shown: Bool
    }

    /// The House's orders naming a House among `houses` to a title, each
    /// where the rules would take it.
    public static func naming(_ title: Title, among houses: [Int], in world: GameState, player: Int) -> [Order] {
        houses.filter { world.bestowRefusal(title, on: $0, as: player) == nil }.map { house in
            Order(title: "Name \(world.houses[house].title) \(title.title)", command: .bestow(title, on: house))
        }
    }

    /// A whisper heard on the water, as the Mac's Realm panel tells it,
    /// and how it stands for the House.
    public struct Heard: Equatable, Identifiable, Sendable {
        public let id: Int
        public let said: String
        public let standing: String
        /// Found false, its teller named.
        public let unmasked: Bool
    }

    /// The whispers told on the phone, the latest first.
    public static let whispersShown = 5

    /// The whispers the House would let loose of these choices: the one,
    /// or for a host one at each hold of that House it knows, each where
    /// the rules would take it, or why none would be.
    public struct Whispering: Equatable, Sendable {
        public let whispers: [Order]
        public let why: String?
    }

    /// What the House may whisper of these choices; nil until a House is
    /// chosen.
    public static func whispering(_ kind: Whisper.Kind, house: Int?, in world: GameState, player: Int) -> Whispering? {
        guard let house else { return nil }
        let holds: [Int?] = kind == .host ? world.holds.filter { $0.owner == house }.map { Optional($0.id) } : [nil]
        let claims = holds.compactMap { Whisper.claim(kind, house: house, hold: $0) }
        let taken = claims.filter { world.whisperRefusal($0, as: player) == nil }.map { claim in
            Order(title: "Whisper that \(world.told(claim)), for \(GameState.whisperCost)", command: .whisper(claim))
        }
        return Whispering(whispers: taken, why: taken.isEmpty ? claims.first.flatMap { world.whisperRefusal($0, as: player)?.description } : nil)
    }

    /// A prophecy of the House's own being made: what it would foretell,
    /// said as the Mac's Augury says it, and Foretell where the rules
    /// would take it, or why not.
    public struct Foretelling: Equatable, Sendable {
        public let said: String
        public let foretell: Order?
        public let why: String?
    }

    /// The prophecy the House would speak of these choices, looking as far
    /// ahead and staking as much as the Mac's Augury does; nil until the
    /// choices are enough.
    public static func foretelling(_ kind: Prophecy.Kind, first: Int?, second: Int?, in world: GameState, player: Int) -> Foretelling? {
        guard let claim = world.claim(kind, first: first, second: second) else { return nil }
        let until = world.watch + Prophecy.lookedAhead, stake = Prophecy.stakeLaid
        let refusal = world.prophecyRefusal(claim, until: until, moonsalt: stake, as: player)
        return Foretelling(said: world.foretellingSaid(claim, until: until, moonsalt: stake),
                           foretell: refusal == nil ? Order(title: "Foretell it, staking \(stake) moonsalt",
                                                            command: .prophesy(claim, until: until, moonsalt: stake)) : nil,
                           why: refusal?.description)
    }

    /// The riddle the lake has set the House at the half moon, as the Mac's
    /// Realm panel sets it: how it stands, the line with its name taken
    /// out, and each name to answer while it may.
    public struct Remembering: Equatable, Sendable {
        public let standing: String
        public let line: String
        public let answers: [Order]
    }

    /// The watch's labours and the happening, as the Mac's Realm panel
    /// tells them: what counts, how far the House has come, what is next.
    public struct Course: Equatable, Sendable {
        /// A labour as it stands, "Muster companies: 0 of 1", and whether done.
        public struct Line: Equatable, Sendable {
            public let text: String
            public let done: Bool
        }
        /// How the labours stand, "1 of 3 done this watch · vigour 10 of 20
        /// for the next chest"; nil while the House is set none.
        public let labours: String?
        public let tasks: [Line]
        /// The happening under way and what counts in it, or when the next
        /// begins.
        public let happening: String?
        /// The House's points and place in the happening under way.
        public let standing: String?
    }

    /// The Lantern Inn: the House's keys, and the chests it may open now.
    public struct Inn: Equatable, Sendable {
        /// The keys the House holds, and a word where one more would be lost.
        public let keys: String
        /// A silver chest opened with a key; a gold one with a key, or for
        /// moonsalt without one; each where the rules would open it.
        public let opens: [Order]
    }

    /// A question among the alliances waiting on the keeper's answer: an
    /// alliance's invitation to the House, or a House asking to join the
    /// alliance it leads, with the answers the rules take.
    public struct Answer: Equatable, Identifiable, Sendable {
        public let id: String
        public let question: String
        /// Nil while the alliance couldn't take the House: full, or one of
        /// its Houses at war with it, as `unable` says.
        public let accept: Order?
        public let refuse: Order
        /// Why it can't be accepted now, where it can't.
        public let unable: String?
    }

    public let house: String
    public let watch: Int
    /// Envoys waiting on the keeper, the first come first.
    public let envoys: [Envoy]
    /// Companies of Houses at war gathered near the House's holds, as the
    /// walls' watchmen tell it.
    public let gatherings: [String]
    /// What still waits for the keeper's orders, as the Mac's top bar says
    /// it: "2 companies wait · 1 hold idle"; nil when nothing does.
    public let waiting: String?
    /// How the House's veil of the Still stands, in the Mac's words.
    public let veil: String
    /// Whether the veil lies over the House's holds now.
    public let veiled: Bool
    /// Why the veil can't be drawn now, where its words don't say so: the
    /// moonsalt the House is short of, as the Mac's seat record says it.
    public let veilShort: String?
    /// Drawing the veil over the House's holds, where the rules would now.
    public let drawVeil: Order?
    public let companies: [Company]
    public let commanders: [Commander]
    /// The commanders of other Houses the House holds prisoner.
    public let prisoners: [Prisoner]
    /// The realm's law, and the House's say in it.
    public let law: Law
    /// The House in the Ring.
    public let ring: TheRing
    /// The House's Forge.
    public let forge: Forge
    /// The House's armoury.
    public let armoury: Armoury
    /// The oaths the House has sworn, and those sworn to it.
    public let oathsSworn: [SwornOath]
    public let oathsToUs: [SwornOath]

    /// What waits in the Ring and up the Spine, said on the Army tab's way
    /// to them: keepers' lines to challenge, or the House's line to stand,
    /// and the watch's venture up the Spine not yet made; nothing where
    /// nothing waits.
    public var venturesWaiting: [String] {
        var said: [String] = []
        let challenges = ring.rivals.filter { $0.challenge != nil }.count
        if challenges > 0 {
            said.append(challenges == 1 ? "A keeper's line to challenge in the Ring" : "\(challenges) keepers' lines to challenge in the Ring")
        } else if ring.stand != nil {
            said.append("Your commanders may stand a line in the Ring")
        }
        if !spine.ventures.isEmpty { said.append("This watch's venture up the Spine still to make") }
        let pieces = forge.forgeable
        if pieces > 0 { said.append(pieces == 1 ? "A piece of gear the Forge may make" : "\(pieces) pieces of gear the Forge may make") }
        return said
    }
    /// Whether the realm's law, any oath or the Augury has anything to
    /// tell the House, or the House may foretell, so the way to their page
    /// is offered.
    public var hasRealmMatters: Bool {
        !law.isEmpty || !oathsSworn.isEmpty || !oathsToUs.isEmpty || !prophecies.isEmpty || !whispers.isEmpty || titles.shown || !holySites.isEmpty || mayForetell
    }

    /// The Frontier's season as the Mac's Realm panel tells it to a keeper
    /// at home (`FrontierNews.said`), with the House's levy, and how its
    /// kingdoms stand; nil while the realm borders no Frontier.
    /// Where a keeper crosses to the Frontier from: their Mac, whose world
    /// goes there with their House.
    public static let crossedFromTheMac = "Your House crosses from your Mac's Realm panel."

    public func frontier(_ news: FrontierNews?) -> (said: String, standings: String)? {
        guard let news else { return nil }
        return (news.said(atFrontier: false, levy: levy), news.standingsSaid)
    }

    /// What waits on the House in the realm beyond it, said on the Alliance
    /// tab's way there: the Sundering while it is fought, a vote to cast on
    /// the edict before the realm, and prophecies open to its stake.
    public var realmWaiting: [String] {
        var said: [String] = []
        if let ends = sunderingEnds { said.append("The shores war as kingdoms until the \(briefOrdinal(ends)) watch") }
        if !law.votes.isEmpty { said.append("A vote to cast on the edict before the realm") }
        let open = prophecies.filter { $0.back != nil }.count
        if open > 0 { said.append(open == 1 ? "A prophecy open to your stake" : "\(open) prophecies open to your stake") }
        return said
    }

    /// Help for each ally with works, musters or study under way the
    /// House hasn't helped yet.
    public let helps: [Order]
    public let holds: [Hold]
    /// The study under way at the House's Archive, and how long it has to go.
    public let studying: String?
    /// The studies the House may begin now, its stores able to pay: none
    /// while one is under way.
    public let studies: [Order]
    /// Each store, and what it gains as the watch turns, as the Mac's top
    /// bar tells it (GameState.gain): below nothing where it loses.
    public let stores: [(resource: Resource, amount: Int, gain: Int)]
    /// How much of each store the House's holds keep, what barter can
    /// bring it up to.
    public let storage: Int
    /// The House's satchel, a stack a kind, as the Mac's panels use it:
    /// hourglasses for the holds with work or a muster to hasten and for the
    /// study, caches while the stores have room, ward stones for the holds
    /// whose ward isn't whole, and draughts while a company is hurt.
    public let satchel: [Item]
    /// The alliance, by name, and its Houses, the leader first.
    public let alliance: String?
    public let allies: [String]
    public let allianceWords: [Said]
    public let realmWords: [Said]
    /// The realm's chronicle, the latest first.
    public let chronicle: [String]
    /// The alliances' invitations to the House while it is sworn to none,
    /// as the Mac's Alliance panel shows them (`GameState.allianceBoard`).
    public let invitations: [Answer]
    /// For the leader of the House's alliance, the Houses asking to join.
    public let requests: [Answer]
    /// The alliances the House, sworn to none, may ask to join now, those
    /// whose leaders' seats are nearest first, and none that invited it.
    public let asks: [Order]
    /// For the leader, the Houses it may invite now, the nearest first.
    public let invites: [Order]
    /// The House's alliance to leave, while it is sworn to one.
    public let leave: Order?
    /// For the leader, each of its alliance's other Houses to cast out.
    public let castOut: [Order]
    /// What the House's alliance keeps of its own, while it is sworn to one.
    public let allianceOwn: AllianceOwn?

    /// What the House's alliance keeps of its own, as the Mac's Alliance
    /// panel tells it: its standards, hall, coffers, storehouse and yards;
    /// and, once the storehouse stands whole, what the House has laid up
    /// there, with what it may lay up or take back now.
    public struct AllianceOwn: Equatable, Sendable {
        public let lines: [String]
        /// What the House has laid up, once the storehouse stands whole.
        public let laidUp: String?
        public let layUp: [Order]
        /// Each measure the House may take back now, and all it laid up.
        public let takeBack: [Order]
    }
    /// The Houses nearest the keeper's seat, the nearest first, and the
    /// dealings the rules would take with each.
    public let dealings: [Dealing]
    /// The most Houses the phone deals with at once: the nearest.
    public static let dealtWith = 12
    /// The caretaker's standing orders, and the orders that would change them.
    public let standing: Standing
    /// The Lantern Inn's keys and the chests the House may open.
    public let inn: Inn
    /// The pedlar's wares, while he lies off one of the House's holds.
    public let pedlar: Wares?
    /// What waits at the market, the Lantern Inn and in the satchel, a few
    /// words each, for the House tab's way to them; none where nothing
    /// waits there but barter.
    public let errands: [String]
    /// The watch's labours and the happening.
    public let course: Course
    /// The Lyceum's next question for the House, while it sits.
    public let lyceum: Asked?
    /// The riddle of the Remembering, while the House has one.
    public let remembering: Remembering?
    /// The Augury's prophecies, the latest first.
    public let prophecies: [Foretold]
    /// Whether the House may foretell: a keeper's, with no prophecy of its
    /// own still open.
    public let mayForetell: Bool
    /// The whispers heard on the water, the latest first.
    public let whispers: [Heard]
    /// The titles of the Spire.
    public let titles: Titles
    /// The holy sites the House has found.
    public let holySites: [HolySite]
    /// How the Sundering stands for the House, as the Mac's Realm panel
    /// tells it (`GameState.sunderingSaid`).
    public let sundering: String
    /// The watch the Sundering under way ends; nil while none is fought.
    public let sunderingEnds: Int?
    /// The House's companies of war: its levy, were it to cross to the
    /// Frontier from its Mac.
    public let levy: Int
    /// The Spine's next stage, and who may venture up it now.
    public let spine: Spine
    /// The House's letters with other keepers, the latest first.
    public let letters: [Letter]
    /// The keepers' Houses it may write to: those it has letters with, the
    /// latest first, then the nearest, at most `dealtWith`.
    public let correspondents: [Correspondent]
    /// The latest reports shown open; the earlier ones folded beneath them.
    public static let reportsOpen = 3

    /// The line the Houses nearest are folded behind: how many, and how
    /// many stand at war with the keeper's House or are sworn to its
    /// alliance.
    public static func dealingsLine(_ dealings: [Dealing]) -> String {
        let war = dealings.filter { $0.stance.hasPrefix("At war") }.count
        let sworn = dealings.filter { $0.stance.hasPrefix("Sworn") }.count
        var line = dealings.count == 1 ? "The House nearest" : "The \(dealings.count) Houses nearest"
        var told: [String] = []
        if war > 0 { told.append("\(war) at war with yours") }
        if sworn > 0 { told.append("\(sworn) of your alliance") }
        if !told.isEmpty { line += ": " + told.joined(separator: ", ") }
        return line
    }
    /// The alliance's studies, as the Mac's Alliance panel tells them: the
    /// study it pursues and what is still to give toward its next grade, or
    /// that it pursues none, and what it has learned together.
    public let allianceLore: [String]
    /// For the alliance's leader, the studies it may set the alliance to
    /// pursue, at their next grade.
    public let pursuits: [Order]
    /// What the House may give toward the study pursued, from its stores:
    /// all the grade still needs, or as much of each store it lacks.
    public let allianceGifts: [Order]
    /// The rallies the House may call now, as the Mac's panels call them:
    /// on the lairs it has found within its rung and the holds it knows of
    /// Houses at war with it, the nearest first, each gathering two watches
    /// at the House's hold with a Muster Hall nearest it.
    public let calls: [Order]

    /// The watches a rally called from the phone gathers.
    public static let rallyGathering = 2

    /// The most alliances offered to ask, and Houses to invite, at once.
    public static let alliancesOffered = 6

    /// The most lines of words and of the chronicle shown.
    public static let linesShown = 30

    public static func == (a: CompanionLedger, b: CompanionLedger) -> Bool {
        a.house == b.house && a.watch == b.watch && a.envoys == b.envoys && a.gatherings == b.gatherings
            && a.veil == b.veil && a.veiled == b.veiled && a.veilShort == b.veilShort && a.drawVeil == b.drawVeil && a.waiting == b.waiting
            && a.companies == b.companies && a.commanders == b.commanders && a.prisoners == b.prisoners && a.law == b.law && a.ring == b.ring && a.forge == b.forge && a.armoury == b.armoury && a.oathsSworn == b.oathsSworn && a.oathsToUs == b.oathsToUs && a.helps == b.helps
            && a.holds == b.holds && a.studying == b.studying && a.studies == b.studies
            && a.stores.map(\.amount) == b.stores.map(\.amount) && a.stores.map(\.gain) == b.stores.map(\.gain) && a.storage == b.storage && a.satchel == b.satchel && a.alliance == b.alliance && a.allies == b.allies
            && a.allianceWords == b.allianceWords && a.realmWords == b.realmWords && a.chronicle == b.chronicle
            && a.invitations == b.invitations && a.requests == b.requests && a.asks == b.asks && a.invites == b.invites
            && a.leave == b.leave && a.castOut == b.castOut && a.allianceOwn == b.allianceOwn && a.calls == b.calls
            && a.allianceLore == b.allianceLore && a.pursuits == b.pursuits && a.allianceGifts == b.allianceGifts
            && a.dealings == b.dealings && a.standing == b.standing && a.inn == b.inn
            && a.letters == b.letters && a.correspondents == b.correspondents && a.pedlar == b.pedlar && a.spine == b.spine
            && a.errands == b.errands && a.course == b.course && a.lyceum == b.lyceum && a.remembering == b.remembering && a.prophecies == b.prophecies && a.mayForetell == b.mayForetell && a.whispers == b.whispers && a.titles == b.titles && a.holySites == b.holySites
            && a.sundering == b.sundering && a.sunderingEnds == b.sunderingEnds && a.levy == b.levy
    }

    /// What waits on the keeper on the House tab, for its badge: envoys to
    /// answer, companies of Houses at war gathered near its holds, holds
    /// with wounded in their beds the House may pay to heal, the Lyceum's
    /// questions while it sits, and the Remembering's riddle unanswered.
    public var houseWaiting: Int {
        envoys.count + gatherings.count + holds.filter { $0.heal != nil }.count + (lyceum == nil ? 0 : 1)
            + (remembering?.answers.isEmpty == false ? 1 : 0)
    }

    /// What waits on them on the Alliance tab, for its badge: invitations
    /// and Houses asking to join to answer, allies' work to help, and a
    /// vote on the realm's law to cast.
    public var allianceWaiting: Int { invitations.count + requests.count + helps.count + (law.votes.isEmpty ? 0 : 1) }

    /// What waits on them on the Army tab, for its badge: commanders with a
    /// talent to learn or a star to raise, the watch's venture up the Spine
    /// not yet made, and prisoners to question.
    public var armyWaiting: Int {
        commanders.filter { !$0.talents.isEmpty || $0.raiseStar != nil }.count + (spine.ventures.isEmpty ? 0 : 1)
            + prisoners.filter { $0.question != nil }.count
    }

    /// The House's stores as one stock.
    public var stock: Stock {
        var stock = Stock()
        for store in stores { stock[store.resource] = store.amount }
        return stock
    }

    /// The House's Forge as it is told it, at the finest the Forge makes,
    /// and each piece the rules would forge now.
    static func forge(in world: GameState, player: Int) -> Forge {
        let level = world.forgeLevel(of: player)
        let heading = level > 0 ? "Forge · level \(BuildingKind.numeral(level))" : "Forge"
        guard level > 0, let quality = GearQuality.forged(atLevel: level) else {
            return Forge(heading: heading, makings: world.makingsSaid(of: player), none: GameState.noForgeSaid, sets: [])
        }
        let sets = GearSet.allCases.map { set in
            Forge.GearLine(name: set.name, effect: set.effect.prefix(1).uppercased() + set.effect.dropFirst() + ".", pieces: set.pieces.map { kind in
                let piece = Gear(id: 0, kind: kind, quality: quality, owner: player)
                let command = Command.forge(kind, quality: quality)
                return Forge.Piece(title: "\(kind.title) · \(kind.slot.title.lowercased())",
                                   said: "\(piece.effect). Takes \(world.recipeSaid(kind, quality, for: player)).",
                                   forge: world.refusal(of: command, as: player) == nil ? Order(title: "Forge a \(piece.title)", command: command) : nil)
            })
        }
        return Forge(heading: heading, makings: world.makingsSaid(of: player), none: nil, sets: sets)
    }

    /// The House in the Ring as it is told it, and the orders the rules
    /// would take for it there now.
    static func ring(in world: GameState, player: Int) -> TheRing {
        let bouts = (world.ring?.bouts ?? []).filter { $0.challenger == player || $0.defender == player }.suffix(3)
        let strongest = world.strongestRingLine(of: player)
        let names = strongest.compactMap { world.commander($0)?.name }
        let listed = names.count <= 1 ? names.joined() : names.dropLast().joined(separator: ", ") + " and " + names.last!
        let stand = !strongest.isEmpty && world.ringLine(of: player) != strongest && world.ringLineRefusal(strongest, as: player) == nil
            ? Order(title: "Stand \(listed) in the Ring", command: .standInTheRing(strongest)) : nil
        let rivals = world.ringRanks.filter { $0 != player }.map { other in
            TheRing.Rival(id: other, name: world.houses[other].title, line: world.ringLineSaid(of: other),
                          challenge: world.challengeRefusal(of: other, as: player) == nil
                            ? Order(title: "Challenge \(world.houses[other].title)", command: .challenge(house: other)) : nil)
        }
        return TheRing(standing: world.ringStandingSaid(of: player), bouts: bouts.map { world.boutSaid($0, to: player) },
                       stand: stand, rivals: rivals)
    }

    /// The realm's law as `player`'s House is told it, and the orders the
    /// rules would take for it now: a vote on the edict before the realm,
    /// and each edict it may put, for its cost.
    static func law(in world: GameState, player: Int) -> Law {
        let open = world.edictInVote
        let votes: [Order] = open.map { edict in
            guard world.voteRefusal(on: edict.id, as: player) == nil else { return [] }
            return [Order(title: "Vote aye on \(edict.kind.title)", command: .voteEdict(edict: edict.id, aye: true)),
                    Order(title: "Vote nay on \(edict.kind.title)", command: .voteEdict(edict: edict.id, aye: false))]
        } ?? []
        let proposals = EdictKind.allCases.filter { world.edictRefusal($0, as: player) == nil }.map { kind in
            Law.Proposal(heading: kind.heading, law: kind.lawSaid,
                         order: Order(title: "Put \(kind.title) to the realm, for \(GameState.edictCost)", command: .proposeEdict(kind: kind)))
        }
        return Law(before: open.map { world.beforeTheRealmSaid($0, to: player) }, tally: open.map { world.tallySaid($0) },
                   voted: open.flatMap { world.voteSaid(on: $0, by: player) }, votes: votes,
                   inForce: world.edictsInForce.map { world.inForceSaid($0) }, proposals: proposals)
    }

    /// The ledger of `player`'s House in their view of the world.
    public init(world: GameState, player: Int) {
        let houses = world.houses
        func title(_ house: Int) -> String { houses.indices.contains(house) ? houses[house].title : "The wilds" }
        house = title(player)
        watch = world.watch
        envoys = world.envoys.filter { $0.to == player }.sorted { ($0.arrived, $0.id) < ($1.arrived, $1.id) }.map { envoy in
            let left = world.watchesWaiting(of: envoy)
            return Envoy(id: envoy.id, from: title(envoy.from), offer: envoy.proposal.title, terms: world.terms(of: envoy, for: player),
                         words: envoy.words, waits: left == 1 ? "Leaves after this watch" : "Waits \(left) watches",
                         accept: world.canKeepTerms(of: envoy, for: player)
                            ? Order(title: "Accept", command: .answer(envoy: envoy.id, accept: true)) : nil,
                         refuse: Order(title: "Refuse", command: .answer(envoy: envoy.id, accept: false)),
                         refusingIsWar: world.refusingIsWar(envoy))
        }
        gatherings = world.gatherings(against: player).map(world.words(of:))
        veil = world.veilSaid(of: player)
        veiled = world.isVeiled(player)
        veilShort = world.veilShortSaid(of: player)
        waiting = world.waitingSaid(for: player)
        drawVeil = world.veilRefusal(as: player) == nil ? Order(title: "Draw the veil", command: .drawVeil) : nil
        let holds = world.holds(of: player).sorted { ($0.isSeat ? 0 : 1, $0.id) < ($1.isSeat ? 0 : 1, $1.id) }
        // The House's companies told apart where two would be named alike.
        let names = SpokenOrders.distinctNames(in: world, player: player)
        func named(_ unit: Unit) -> String { names[unit.id] ?? SpokenOrders.named(unit, in: world) }
        companies = SpokenOrders.companies(in: world, player: player).map { unit in
            // Each order where it would do something: dig in a company of war
            // not dug in, halt one on the march, call home one gathering or
            // carrying, drill one the rules would drill, and march to the
            // House's other holds.
            let gathering: Bool = { if case .gather? = unit.errand { return true }; return unit.load != nil }()
            let offered: [(String, Command, Bool)] = [
                ("Fortify", .fortify(unit: unit.id), unit.kind.isMilitary && !unit.fortified && unit.destination == nil && unit.errand == nil),
                ("Halt", .halt(unit: unit.id), unit.destination != nil),
                ("Recall", .recall(unit: unit.id), gathering),
                ("Drill", .drill(unit: unit.id), unit.kind.isMilitary && unit.drillAt == nil && world.drillRefusal(of: unit) == nil),
            ]
            // Lanterns within reach of another House's hold scout it, the
            // nearest first, as the Mac offers it, where the rules would.
            let scouts: [Order] = unit.kind == .lantern && unit.movesLeft > 0
                ? world.holds.filter { $0.owner != player && $0.position.distance(to: unit.position) <= GameState.scoutReach }
                    .sorted { ($0.position.distance(to: unit.position), $0.id) < ($1.position.distance(to: unit.position), $1.id) }
                    .filter { world.refusal(of: .scout(unit: unit.id, hold: $0.id), as: player) == nil }
                    .map { Order(title: "Scout \($0.name)", command: .scout(unit: unit.id, hold: $0.id)) }
                : []
            let orders = offered.filter(\.2).map { Order(title: $0.0, command: $0.1) } + scouts
            let marches = holds.filter { $0.position != unit.position && unit.destination != $0.position }.map { hold in
                Order(title: "March to \(hold.name)", command: .move(unit: unit.id, to: hold.position))
            }
            return Company(id: unit.id, name: named(unit), troops: GameState.counted(world.troops(of: unit)),
                           leader: unit.leader.flatMap { world.commander($0)?.name }, doing: CompanionLedger.doing(unit, in: world, for: player),
                           orders: orders, marches: marches, strikes: CompanionLedger.strikes(for: unit, in: world, player: player),
                           gathers: CompanionLedger.gathers(for: unit, in: world, player: player),
                           rallies: CompanionLedger.rallies(for: unit, in: world, player: player),
                           gates: CompanionLedger.gates(for: unit, in: world, player: player))
        }
        let war = world.units(of: player).filter { $0.kind.isMilitary }.sorted { $0.id < $1.id }
        let held = world.gear(of: player)
        let sculptures = world.sculptures(of: player)
        commanders = world.commandersBoard(for: player).lines.map { line in
            let standing: String
            if let captor = line.heldBy {
                standing = "Held prisoner by \(title(captor))"
            } else if let wounded = line.woundedFor {
                standing = wounded == 1 ? "Wounded: whole again next watch" : "Wounded: whole again in \(wounded) watches"
            } else if let unit = line.leads {
                standing = "Leads the \(named(unit))"
            } else {
                standing = "Free to lead a company of war"
            }
            // Each order where the rules would take it: a company taken up or
            // ridden with, home again, a talent learned, a piece worn.
            let id = line.commander.id
            let leads = war.filter { world.assignRefusal(of: id, to: $0.id, as: player) == nil }.map { unit in
                Order(title: "Lead the \(named(unit))", command: .assign(commander: id, unit: unit.id))
            }
            let seconds = war.filter { world.secondRefusal(of: id, to: $0.id, as: player) == nil }.map { unit in
                Order(title: "Ride second with the \(named(unit))", command: .assignSecond(commander: id, unit: unit.id))
            }
            let riding = war.contains { $0.leader == id || $0.second == id }
            let talents = Talent.allCases.filter { line.commander.learnRefusal(of: $0) == nil }.map { talent in
                Order(title: "Learn \(talent.title) \(BuildingKind.numeral(line.commander.rank(of: talent) + 1))",
                      command: .learnTalent(commander: id, talent: talent))
            }
            let gear: [Order] = line.heldBy != nil ? [] : held.filter { $0.wornBy != id }.map { piece in
                let from = piece.wornBy.flatMap { world.commander($0)?.name }.map { ", from \($0)" } ?? ""
                return Order(title: "Wear the \(piece.title)\(from)", command: .wear(gear: piece.id, commander: id))
            }
            let ransom = line.heldBy != nil && world.ransomRefusal(id, as: player) == nil
                ? Order(title: "Ransom for \(GameState.ransom(for: line.commander))", command: .ransom(commander: id)) : nil
            // What they wear, slot by slot, each piece taken off back to the armoury.
            let worn = held.filter { $0.wornBy == id }.sorted { $0.slot.rawValue < $1.slot.rawValue }.map { piece in
                GearPiece(id: piece.id, title: piece.wornSaid, effect: piece.effect,
                          takeOff: Order(title: "Take the \(piece.title) off \(line.commander.name)", command: .takeOff(gear: piece.id)),
                          arm: [], breakUp: nil, scrap: piece.scrap)
            }
            return Commander(id: id, name: line.commander.name, title: "\(line.commander.archetype.title) · level \(line.level)",
                             standing: standing, canCounsel: line.heldBy == nil, leads: leads, seconds: seconds,
                             home: riding ? Order(title: "Ride home", command: .unassign(commander: id)) : nil,
                             talents: talents, gear: gear, ransom: ransom, worn: worn,
                             stars: "\(line.commander.starCount) of \(NullmereCore.Commander.mostStars) stars · "
                                + line.commander.starsSaid(kept: sculptures),
                             raiseStar: world.starRefusal(of: id, as: player) == nil
                                ? Order(title: "Raise \(line.commander.name) to \(line.commander.starCount + 1) stars", command: .raiseStar(commander: id))
                                : nil)
        }
        // The armoury: each piece no commander wears, to arm any commander
        // free to take it up, or to break up for its moonsalt.
        let free = commanders.filter(\.canCounsel)
        armoury = Armoury(heading: world.armourySaid(of: player), kept: held.filter { $0.wornBy == nil }.map { piece in
            GearPiece(id: piece.id, title: piece.keptSaid, effect: piece.effect, takeOff: nil,
                      arm: free.map { Order(title: "Arm \($0.name)", command: .wear(gear: piece.id, commander: $0.id)) },
                      breakUp: Order(title: "Break up the \(piece.title) for \(piece.scrap) moonsalt", command: .breakUp(gear: piece.id)),
                      scrap: piece.scrap)
        })
        law = CompanionLedger.law(in: world, player: player)
        ring = CompanionLedger.ring(in: world, player: player)
        forge = CompanionLedger.forge(in: world, player: player)
        // Oaths, as the Mac's Houses tell them on the other House's line,
        // renounced with notice where the House swore one and has not yet.
        oathsSworn = world.oaths(by: player).map { oath in
            SwornOath(id: oath.id, terms: "Your oath to \(title(oath.to)): \(world.heldSaid(oath))",
                      renounce: world.renounceRefusal(oath.id, as: player) == nil
                        ? Order(title: "Renounce the oath of \(oath.swornSaid) to \(title(oath.to))", command: .renounce(oath: oath.id)) : nil)
        }
        oathsToUs = world.oathsInForce.filter { $0.to == player && $0.by != player }.map { oath in
            SwornOath(id: oath.id, terms: "\(title(oath.by))'s oath to you: \(world.heldSaid(oath))", renounce: nil)
        }
        prisoners = world.prisoners(heldBy: player).sorted { $0.id < $1.id }.compactMap { prisoner in
            guard let captive = prisoner.captive else { return nil }
            let question = world.questionRefusal(prisoner.id, as: player) == nil
                ? Order(title: "Question \(prisoner.name)", command: .question(commander: prisoner.id)) : nil
            return Prisoner(id: prisoner.id, name: prisoner.name, of: world.prisonerOf(prisoner), held: captive.leftSaid(at: world.watch),
                            told: captive.told?.last, question: question,
                            release: Order(title: "Let \(prisoner.name) go home", command: .release(commander: prisoner.id)))
        }
        self.holds = holds.map { hold in
            var work: [String] = []
            if let project = hold.project {
                work.append("Raising \(project.kind.title) \(BuildingKind.numeral(project.targetLevel)), "
                    + CompanionLedger.watches(project.watchesLeft))
            }
            if let training = hold.training {
                work.append("Mustering \(training.kind.title) \(BuildingKind.numeral(training.musteredTier)), "
                    + CompanionLedger.watches(training.watchesLeft))
            }
            let (infirmary, heal) = CompanionLedger.infirmary(at: hold, in: world, player: player)
            let sealed = world.letter(sealedBy: player)
            // Any words will do to ask whether one may be sealed here at all.
            let maySeal = sealed == nil && world.sealRefusal("A letter", in: hold.id, as: player) == nil
            return Hold(id: hold.id, name: hold.name, isSeat: hold.isSeat, work: work,
                        musters: CompanionLedger.musters(at: hold, in: world, player: player),
                        works: CompanionLedger.works(at: hold, in: world, player: player),
                        infirmary: infirmary, heal: heal,
                        letterKept: sealed.flatMap { $0.holdID == hold.id ? $0.keptSaid : nil }, maySealLetter: maySeal,
                        mayCastBottle: world.castRefusal("A bottle", from: hold.id, as: player) == nil)
        }
        let pursuit = houses.indices.contains(player) ? houses[player].research.pursuit : nil
        studying = pursuit.map { "Studying \($0.study.title) \(BuildingKind.numeral($0.grade)), " + CompanionLedger.watches($0.watchesLeft) }
        studies = CompanionLedger.studies(in: world, player: player)
        let stock = houses.indices.contains(player) ? houses[player].stock : .zero
        let gain = houses.indices.contains(player) ? world.gain(of: player) : [:]
        stores = Resource.allCases.map { ($0, stock[$0], gain[$0] ?? 0) }
        let room = world.storage(of: player)
        storage = room
        let hurt = world.units(of: player).contains { $0.health < 100 }
        satchel = world.satchel(of: player).map { stack in
            let uses: [Order]
            switch stack.kind {
            case .hourglass:
                let works = holds.filter { ($0.project?.watchesLeft ?? 0) > 1 || ($0.training?.watchesLeft ?? 0) > 1 }.map { hold in
                    Order(title: "Hasten \(hold.name)", command: .useItem(.hourglass, hold: hold.id))
                }
                let study = (pursuit?.watchesLeft ?? 0) > 1 ? [Order(title: "Hasten the study", command: .useItem(.hourglass, hold: nil))] : []
                uses = works + study
            case .grainCache, .timberCache, .stoneCache, .moonsaltCache:
                let fits = Resource.allCases.contains { stack.kind.stores[$0] > 0 && stock[$0] < room }
                uses = fits ? [Order(title: "Open it", command: .useItem(stack.kind, hold: nil))] : []
            case .wardStone:
                uses = holds.filter { $0.ward < $0.maximumWard }.map { hold in
                    Order(title: "Make the ward of \(hold.name) whole", command: .useItem(.wardStone, hold: hold.id))
                }
            case .mendingDraught:
                uses = hurt ? [Order(title: "Share it out", command: .useItem(.mendingDraught, hold: nil))] : []
            }
            let effect = stack.kind.effect
            return Item(kind: stack.kind, count: stack.kind.counted(stack.count).lineBegun, effect: effect.prefix(1).uppercased() + effect.dropFirst(),
                        uses: uses)
        }
        let allied = world.alliance(of: player)
        alliance = allied?.name
        let sworn = allied.map { [$0.leader] + $0.members.filter { $0 != allied?.leader } } ?? []
        allies = sworn.map(title)
        helps = sworn.filter { $0 != player }.compactMap { ally in
            let count = world.helpable(by: player, for: ally)
            return count > 0 ? Order(title: "Help \(title(ally)), \(count) under way", command: .help(house: ally)) : nil
        }
        let said = world.wordsSaid.filter { $0.removed != true }
        func lines(_ words: [Word]) -> [Said] {
            words.suffix(CompanionLedger.linesShown).map { word in
                Said(id: word.id, from: title(word.from), text: word.text, watch: word.watch, isOwn: word.from == player,
                     report: world.reportRefusal(word.id, as: player) == nil
                        ? Order(title: "Report to the realm's steward", command: .reportWord(word: word.id)) : nil,
                     reported: world.wordReports.contains { $0.word == word.id && $0.by == player })
            }
        }
        allianceWords = allied.map { alliance in lines(said.filter { $0.alliance == alliance.id }) } ?? []
        realmWords = lines(said.filter { $0.alliance == nil })
        chronicle = world.chronicle.suffix(CompanionLedger.linesShown).reversed().map(\.text)

        // The alliances, as the Mac's Alliance panel reads them: what waits
        // on the House's answer, whom it may ask or invite, and leaving.
        let board = world.allianceBoard(for: player)
        func canJoin(_ house: Int, _ alliance: Alliance) -> Bool {
            alliance.members.count < board.limit && !alliance.members.contains { world.isAtWar(house, $0) }
        }
        let home = world.seat(of: player)?.position
        func distance(_ house: Int) -> Int {
            guard let home, let seat = world.seat(of: house) else { return Int.max }
            return home.distance(to: seat.position)
        }
        invitations = board.invitations.map { invited in
            Answer(id: "invited by \(invited.id)", question: "\(invited.titled) invites your House to join it.",
                   accept: canJoin(player, invited)
                       ? Order(title: "Join \(invited.name)", command: .answerInvitation(alliance: invited.id, accept: true)) : nil,
                   refuse: Order(title: "Decline \(invited.name)", command: .answerInvitation(alliance: invited.id, accept: false)),
                   unable: canJoin(player, invited) ? nil : "It is full, or one of its Houses is at war with yours.")
        }
        requests = board.alliance.map { own in
            board.asking.map { asker in
                Answer(id: "asked by \(asker)", question: "\(title(asker)) asks to join \(own.name).",
                       accept: canJoin(asker, own) ? Order(title: "Admit \(title(asker))", command: .answerRequest(house: asker, accept: true)) : nil,
                       refuse: Order(title: "Refuse \(title(asker))", command: .answerRequest(house: asker, accept: false)),
                       unable: canJoin(asker, own) ? nil : "Your alliance is full, or one of its Houses is at war with it.")
            }
        } ?? []
        let invitedBy = Set(board.invitations.map(\.id))
        asks = board.others.filter { $0.refusal == nil && !invitedBy.contains($0.alliance.id) }.map(\.alliance)
            .sorted { (distance($0.leader), $0.id) < (distance($1.leader), $1.id) }
            .prefix(CompanionLedger.alliancesOffered)
            .map { Order(title: "Ask to join \($0.name)", command: .askToJoin(alliance: $0.id)) }
        invites = board.invitable.sorted { (distance($0), $0) < (distance($1), $1) }
            .prefix(CompanionLedger.alliancesOffered)
            .map { Order(title: "Invite \(title($0))", command: .inviteToAlliance(house: $0)) }
        leave = board.alliance.map { Order(title: "Leave \($0.name)", command: .leaveAlliance) }
        castOut = board.alliance.map { own in
            sworn.filter { $0 != player && world.refusal(of: .expel(house: $0), as: player) == nil }.map { other in
                Order(title: "Cast \(title(other)) out of \(own.name)", command: .expel(house: other))
            }
        } ?? []
        allianceOwn = allied.map { own in
            let laid = world.laidUp(by: player)
            let whole = world.wholeStorehouse(for: player) != nil
            let layUp = whole ? Storehouse.measures.filter { world.layUpRefusal($0, by: player) == nil }.map {
                Order(title: "Lay up \($0)", command: .layUp($0))
            } : []
            var takeBack = whole ? Storehouse.measures.filter { world.takeBackRefusal($0, by: player) == nil }.map {
                Order(title: "Take back \($0)", command: .takeBack($0))
            } : []
            if whole, !laid.isZero, world.takeBackRefusal(laid, by: player) == nil {
                takeBack.append(Order(title: "Take back all you laid up", command: .takeBack(laid)))
            }
            return AllianceOwn(lines: [world.standardsSaid(of: own), world.hallSaid(of: own), world.coffersSaid(of: own),
                                       world.storehouseSaid(of: own), world.yardsSaid(of: own)],
                               laidUp: whole ? Storehouse.laidUpSaid(laid) : nil, layUp: layUp, takeBack: takeBack)
        }
        calls = CompanionLedger.calls(in: world, player: player, holds: holds)
        // The alliance's studies, as the Mac's Alliance panel reads them.
        dealings = CompanionLedger.dealings(in: world, player: player)
        standing = CompanionLedger.standing(in: world, player: player)
        inn = CompanionLedger.inn(in: world, player: player)
        (letters, correspondents) = CompanionLedger.letters(in: world, player: player)
        pedlar = CompanionLedger.pedlar(in: world, player: player)
        spine = CompanionLedger.spine(in: world, player: player)
        errands = CompanionLedger.errands(in: world, player: player, satchel: satchel)
        course = CompanionLedger.course(in: world, player: player)
        lyceum = CompanionLedger.lyceum(in: world, player: player)
        prophecies = world.prophecies.reversed().map { prophecy in
            let stake = Prophecy.stakeLaid
            let open = prophecy.isOpen && world.stakeRefusal(on: prophecy.id, moonsalt: stake, as: player) == nil
            return Foretold(id: prophecy.id, said: world.prophecySaid(prophecy, to: player), standing: prophecy.standingSaid(at: world.watch),
                            back: open ? Order(title: "Back it with \(stake) moonsalt",
                                               command: .stake(prophecy: prophecy.id, backs: true, moonsalt: stake)) : nil,
                            standAgainst: open ? Order(title: "Stand against it with \(stake) moonsalt",
                                                       command: .stake(prophecy: prophecy.id, backs: false, moonsalt: stake)) : nil)
        }
        sundering = world.sunderingSaid(for: player)
        sunderingEnds = world.sundering.flatMap { $0.settled ? nil : $0.ends }
        levy = world.units(of: player).filter(\.kind.isMilitary).count
        holySites = world.holySites.map { shrine in
            HolySite(id: shrine.id, title: shrine.title, held: world.shrineHolderSaid(shrine, to: player), said: world.shrineSaid(shrine),
                     isFriendly: shrine.holder.map { $0 == player || world.areAllied($0, player) } == true)
        }
        titles = Titles(giver: world.titleGiverSaid(to: player),
                        borne: world.titlesBorne.map { borne in
                            Titles.Borne(title: borne.title.title, house: borne.house == player ? "Your House" : title(borne.house),
                                         effect: borne.title.effect, isBoon: borne.title.isBoon)
                        },
                        mayName: world.titleGiver == player,
                        shown: world.holySites.contains { $0.kind == .brokenSpire } || !world.titlesBorne.isEmpty)
        whispers = world.whispersHeard.suffix(CompanionLedger.whispersShown).reversed().map { whisper in
            Heard(id: whisper.id, said: world.whisperSaid(whisper), standing: world.whisperStandingSaid(whisper, to: player),
                  unmasked: whisper.unmasked)
        }
        mayForetell = world.houses.indices.contains(player) && world.houses[player].isPlayer && !world.houses[player].isEliminated
            && !world.openProphecies.contains { $0.by == player }
        remembering = world.riddle(of: player).map { riddle in
            Remembering(standing: riddle.standingSaid, line: riddle.line,
                        answers: riddle.choices.filter { world.riddleRefusal($0, as: player) == nil }.map {
                            Order(title: $0, command: .answerRiddle($0))
                        })
        }
        let studied = CompanionLedger.studies(of: allied, in: world, player: player)
        allianceLore = studied.lore
        pursuits = studied.pursuits
        allianceGifts = studied.gifts
    }

    /// The rallies the House may call: none while it is sworn to no
    /// alliance, has called one already or has no Muster Hall; otherwise
    /// the nearest targets the rules would take (those it has found), at
    /// most six.
    /// `at`, a hex: the rally called on what lies there alone.
    static func calls(in world: GameState, player: Int, holds: [NullmereCore.Hold], at hex: Hex? = nil) -> [Order] {
        let musters = holds.filter { $0.level(.musterHall) >= 1 }
        guard world.alliance(of: player) != nil, !musters.isEmpty,
              !world.ralliesStanding.contains(where: { $0.caller == player }) else { return [] }
        let rung = world.lairRung(of: player) + 1
        var targets: [(id: Int, position: Hex, name: String)] = world.lairsStanding
            .filter { $0.level <= rung }
            .map { ($0.id, $0.position, "the \($0.title)") }
        targets += world.holds.filter { $0.owner != player && world.isAtWar(player, $0.owner) }
            .map { ($0.id, $0.position, $0.name) }
        if let hex { targets = targets.filter { $0.position == hex } }
        var offered: [(distance: Int, order: Order)] = []
        for target in targets {
            let muster = musters.min { ($0.position.distance(to: target.position), $0.id) < ($1.position.distance(to: target.position), $1.id) }!
            offered.append((muster.position.distance(to: target.position),
                            Order(title: "Rally on \(target.name)",
                                  command: .callRally(from: muster.id, against: target.id, watches: CompanionLedger.rallyGathering))))
        }
        return offered.sorted { ($0.distance, $0.order.title) < ($1.distance, $1.order.title) }
            .lazy.map(\.order).filter { world.refusal(of: $0.command, as: player) == nil }.prefix(CompanionLedger.alliancesOffered).map { $0 }
    }

    /// The Houses standing nearest the keeper's seat, the nearest first, each
    /// with how it stands with the keeper's House and the envoys and war the
    /// rules would take now.
    static func dealings(in world: GameState, player: Int) -> [Dealing] {
        let houses = world.houses
        guard houses.indices.contains(player), let home = world.seat(of: player)?.position else { return [] }
        let others = houses.indices.filter { $0 != player && !houses[$0].isEliminated }.compactMap { house -> (Int, Int)? in
            world.seat(of: house).map { (house, $0.position.distance(to: home)) }
        }
        let nearest = others.sorted { ($0.1, $0.0) < ($1.1, $1.0) }.prefix(dealtWith).map(\.0)
        let stock = houses[player].stock
        return nearest.map { house in
            let name = houses[house].title
            let stance: String
            if world.areAllied(player, house) {
                stance = "Sworn to your alliance"
            } else {
                switch world.stance(player, house) {
                case .war: stance = "At war with your House"
                case .pact: stance = "In a pact with your House"
                case .peace: stance = "At peace with your House"
                }
            }
            let offered: [(String, Proposal)] = [("Offer peace to", .peace), ("Offer a pact to", .pact), ("Demand tribute of", .tribute)]
            let envoys = offered.map { Order(title: "\($0.0) \(name)", command: .propose($0.1, to: house)) }
                .filter { world.refusal(of: $0.command, as: player) == nil }
            let atWar = world.isAtWar(player, house)
            let gifts = atWar ? [] : Resource.allCases.compactMap { resource -> Order? in
                let amount = resource == .moonsalt ? GameState.giftsTakenPerWatch / 4 : GameState.giftsTakenPerWatch
                guard stock[resource] >= amount else { return nil }
                let order = Order(title: "Send \(amount) \(resource.title.lowercased()) to \(name)",
                                  command: .gift(to: house, resource: resource, amount: amount))
                return world.refusal(of: order.command, as: player) == nil ? order : nil
            }
            let war = Order(title: "Declare war on \(name)", command: .declareWar(on: house))
            return Dealing(id: house, name: name, stance: stance, envoys: envoys, gifts: gifts,
                           war: atWar || world.refusal(of: war.command, as: player) != nil ? nil : war, mayTrade: !atWar,
                           waiting: world.envoysWaiting(from: player, to: house).map(world.envoyWaitingSaid))
        }
    }

    /// The alliance's studies for the ledger: what it pursues and still needs
    /// or that it pursues none, what it has learned; the studies its leader
    /// may set it to pursue; and what the House may give toward the pursuit.
    static func studies(of alliance: Alliance?, in world: GameState, player: Int) -> (lore: [String], pursuits: [Order], gifts: [Order]) {
        guard let alliance else { return ([], [], []) }
        let lore = alliance.lore ?? AllianceLore()
        var lines: [String] = []
        var gifts: [Order] = []
        if let next = lore.next {
            let named = "\(next.study.title) \(BuildingKind.numeral(next.grade))"
            let still = lore.given.shortfall(for: next.study.cost(grade: next.grade))
            lines.append("Pursuing \(named): \(still) still to give")
            var offered = [Order(title: "Give all \(named) still needs: \(still)", command: .giveToAlliance(still))]
            let lacking = Resource.allCases.filter { still[$0] > 0 }
            let stock = world.houses.indices.contains(player) ? world.houses[player].stock : .zero
            if lacking.count > 1 {
                for resource in lacking {
                    var gift = Stock()
                    gift[resource] = min(still[resource], stock[resource])
                    offered.append(Order(title: "Give \(gift) toward \(named)", command: .giveToAlliance(gift)))
                }
            } else if let only = lacking.first, stock[only] < still[only], stock[only] > 0 {
                var gift = Stock()
                gift[only] = stock[only]
                offered.append(Order(title: "Give \(gift) toward \(named)", command: .giveToAlliance(gift)))
            }
            gifts = offered.filter { order in
                guard case .giveToAlliance(let stock) = order.command else { return false }
                return world.allianceGiftRefusal(stock, by: player) == nil
            }
        } else {
            lines.append("Your alliance pursues no study.")
        }
        let learned = AllianceStudy.allCases.filter { lore.grade(of: $0) > 0 }
            .map { "\($0.title) \(BuildingKind.numeral(lore.grade(of: $0)))" }
        if !learned.isEmpty { lines.append("Learned together: " + learned.joined(separator: ", ")) }
        let pursuits = AllianceStudy.allCases.filter { world.pursuitRefusal($0, by: player) == nil }.map { study in
            Order(title: "Pursue \(study.title) \(BuildingKind.numeral(lore.grade(of: study) + 1))", command: .pursueAllianceStudy(study))
        }
        return (lines, pursuits, gifts)
    }

    /// The most sites a company is offered to gather at: the nearest.
    public static let sitesOffered = 3

    /// What a company may strike now from where it stands, by the rules'
    /// own reach: the wilds, which any House may strike, and the companies
    /// and holds of Houses at war with this one.
    /// The House's standing orders as the keeper is told them, and every
    /// order the rules would take to change them: a kind of company of war
    /// to muster or a work to raise first other than those given, every
    /// company kept home unless it is, peace and tribute each way not
    /// given, and the orders cleared while any stand.
    static func standing(in world: GameState, player: Int) -> Standing {
        let given = world.standingOrders(of: player)
        func taken(_ title: String, _ command: Command) -> Order? {
            world.refusal(of: command, as: player) == nil ? Order(title: title, command: command) : nil
        }
        let musters = UnitKind.allCases.filter { $0.isMilitary && $0 != given.muster }.compactMap { kind in
            taken("Muster only \(kind.title)", .stand(.muster(kind)))
        }
        let raises = BuildingKind.allCases.filter { $0 != given.raise }.compactMap { kind in
            taken("Raise the \(kind.title) first", .stand(.raise(kind)))
        }
        var others: [Order?] = []
        if given.home != true { others.append(taken("Keep every company on your land", .stand(.home))) }
        if given.peace != true { others.append(taken("Make peace with any House that offers it", .stand(.peace(true)))) }
        if given.peace != false { others.append(taken("Make peace with no House", .stand(.peace(false)))) }
        if given.tribute != true { others.append(taken("Pay any tribute demanded", .stand(.tribute(true)))) }
        if given.tribute != false { others.append(taken("Pay no tribute", .stand(.tribute(false)))) }
        if !given.isEmpty { others.append(taken("Keep the House as it sees fit", .standDown)) }
        return Standing(said: given.said, musters: musters, raises: raises, others: others.compactMap { $0 })
    }

    /// The Spine as the Mac's commanders panel tells it: the House's next
    /// stage, what its host weighs and its spoils; a line of its strongest
    /// free commanders, up to three, and each alone, as the rules would send
    /// them, none once it has ventured this watch.
    static func spine(in world: GameState, player: Int) -> Spine {
        guard let stage = ExpeditionStage.stage(world.expeditionStage(of: player) + 1) else {
            return Spine(said: "Every stage of the Spine is yours.", ventures: [])
        }
        var said = "The Spine, \(stage.name) (\(stage.number) of \(ExpeditionStage.count)): its host weighs \(stage.strength); "
            + "its spoils \(stage.spoils)" + (stage.sculptures > 0 ? " and \(stage.sculptures) sculptures." : ".")
        if world.hasVentured(player) { said += " Your House has ventured this watch." }
        let free = world.commanders(of: player).filter { $0.captive == nil && ($0.woundedUntil ?? 0) <= world.watch }
            .sorted { (world.ringWeight(of: $0), -$0.id) > (world.ringWeight(of: $1), -$1.id) }
        var ventures: [Order] = []
        let line = Array(free.prefix(GameState.expeditionLine))
        if line.count > 1, world.expeditionRefusal(line.map(\.id), as: player) == nil {
            let names = line.map(\.name)
            let listed = names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
            ventures.append(Order(title: "Send a line of \(line.count) up the Spine: \(listed)", command: .ventureLine(commanders: line.map(\.id), stage: nil)))
        }
        for commander in free where world.expeditionRefusal(commander.id, as: player) == nil {
            ventures.append(Order(title: "Send \(commander.name) alone, weighing \(world.ringWeight(of: commander))",
                                  command: .venture(commander: commander.id)))
        }
        return Spine(said: said, ventures: ventures)
    }

    /// The pedlar lying off one of the House's holds, as the Mac's card tells
    /// him: where he lies, when he poles away, and each ware with its price,
    /// bought where the rules would sell it or why not; none, while none lies off.
    static func pedlar(in world: GameState, player: Int) -> Wares? {
        guard let pedlar = world.pedlar(for: player) else { return nil }
        let left = max(1, pedlar.came + NullmereCore.Pedlar.stays - world.watch)
        let said = "The Pedlar of the Still lies off \(world.hold(pedlar.hold)?.name ?? "your hold"); "
            + "he poles away in \(left) watch\(left == 1 ? "" : "es")."
        let wares = pedlar.wares.map { ware -> Ware in
            guard !ware.sold else { return Ware(id: ware.id, title: "\(ware.goods.title.lineBegun): sold", buy: nil, why: nil) }
            let refusal = world.buyRefusal(ware.id, as: player)
            return Ware(id: ware.id, title: "\(ware.goods.title.lineBegun), for \(ware.price)",
                        buy: refusal == nil ? Order(title: "Buy \(ware.goods.title)", command: .buyFromPedlar(ware: ware.id)) : nil,
                        why: refusal?.description)
        }
        return Wares(said: said, wares: wares)
    }

    /// The House's letters, the latest first, lined as the Mac lines them;
    /// and the keepers it may write to, those it has letters with first.
    static func letters(in world: GameState, player: Int) -> ([Letter], [Correspondent]) {
        let houses = world.houses
        func title(_ house: Int) -> String { houses.indices.contains(house) ? houses[house].title : "a fallen House" }
        let mail = world.letters(of: player).reversed()
        let letters = mail.map { letter in
            let other = letter.from == player ? letter.to : letter.from
            return Letter(id: letter.id, line: "\(letter.from == player ? "To" : "From") \(title(other)): \(letter.text)",
                          incoming: letter.to == player)
        }
        let keepers = Set(houses.indices.filter { $0 != player && houses[$0].isPlayer && !houses[$0].isEliminated })
        var ordered: [Int] = []
        for letter in mail {
            let other = letter.from == player ? letter.to : letter.from
            if keepers.contains(other), !ordered.contains(other) { ordered.append(other) }
        }
        if let home = world.seat(of: player)?.position {
            let nearest = keepers.subtracting(ordered).map { house in (house, world.seat(of: house)?.position.distance(to: home) ?? Int.max) }
                .sorted { ($0.1, $0.0) < ($1.1, $1.0) }.map(\.0)
            ordered += nearest
        }
        let correspondents = ordered.prefix(CompanionLedger.dealtWith).map { Correspondent(id: $0, name: title($0)) }
        return (Array(letters), correspondents)
    }

    /// What waits at the market, the Inn and in the satchel, a few words
    /// each: the pedlar while he lies off with wares unsold, and how many of
    /// them the House may buy; the House's keys at the Inn while it holds
    /// one, and a word where one more silver key would be lost; and the
    /// satchel's items the House may use now.
    static func errands(in world: GameState, player: Int, satchel: [Item]) -> [String] {
        func opened(_ line: String) -> String { line.prefix(1).uppercased() + line.dropFirst() }
        var errands: [String] = []
        if let pedlar = world.pedlar(for: player), pedlar.wares.contains(where: { !$0.sold }) {
            let buyable = pedlar.wares.filter { !$0.sold && world.buyRefusal($0.id, as: player) == nil }.count
            let off = "The pedlar lies off \(world.hold(pedlar.hold)?.name ?? "your hold")"
            errands.append(buyable == 0 ? off : "\(off): \(buyable == 1 ? "a ware" : "\(buyable) wares") you may buy")
        }
        let keys = world.innKeys(of: player)
        if world.innRefusal(.silver, as: player) == nil || keys.gold > 0 {
            func counted(_ count: Int, _ kind: String) -> String? {
                count == 0 ? nil : count == 1 ? "a \(kind) key" : "\(count) \(kind) keys"
            }
            var line = [counted(keys.silver, "silver"), counted(keys.gold, "gold")].compactMap { $0 }.joined(separator: " and ")
                + " to spend at the Inn"
            if keys.silver >= InnKeys.mostKeys { line += ", before the next silver key is lost" }
            errands.append(opened(line))
        }
        let ready = satchel.filter { !$0.uses.isEmpty }
        if ready.count > 2 {
            errands.append("\(ready.count) kinds of item in the satchel ready to use")
        } else if !ready.isEmpty {
            errands.append(opened(ready.map(\.count).joined(separator: " and ") + " ready to use"))
        }
        return errands
    }

    /// The Lyceum's next question the House hasn't answered while it sits,
    /// as the Mac's card sets it, each answer one the rules take.
    static func lyceum(in world: GameState, player: Int) -> Asked? {
        guard let questions = world.lyceumNow else { return nil }
        let given = world.lyceumAnswers(of: player)
        guard let index = given.indices.first(where: { given[$0] == nil }), questions.indices.contains(index) else { return nil }
        let question = questions[index]
        let answers = question.choices.enumerated().compactMap { choice, title -> Order? in
            world.lyceumRefusal(question: index, choice: choice, as: player) == nil
                ? Order(title: title, command: .answerLyceum(question: index, choice: choice)) : nil
        }
        return Asked(place: "\(index + 1) of \(Lyceum.questions)", text: question.text, answers: answers)
    }

    /// A hold's Infirmary while any lie in its beds, in the Mac's words, and
    /// the healing of those still waiting where the rules would pay for it.
    static func infirmary(at hold: NullmereCore.Hold, in world: GameState, player: Int) -> (String?, Order?) {
        guard let wounded = hold.wounded, !wounded.isEmpty else { return (nil, nil) }
        let said = "Infirmary, \(wounded.count) of \(hold.beds) beds: \(Wounded.lying(wounded))"
        let waiting = wounded.filter { !$0.healing }.count
        guard waiting > 0, world.refusal(of: .heal(hold: hold.id), as: player) == nil else { return (said, nil) }
        return (said, Order(title: "Heal \(waiting) for \(world.healingCost(at: hold))", command: .heal(hold: hold.id)))
    }

    /// The House's labours this watch and its part in the happening, in the
    /// Mac's words (`Labours.summary`, `RealmBoard.happeningSaid`).
    static func course(in world: GameState, player: Int) -> Course {
        let labours = world.labours(of: player)
        let board = world.realmBoard(for: player)
        return Course(labours: labours?.summary,
                      tasks: labours?.tasks.map { Course.Line(text: $0.line, done: $0.isDone) } ?? [],
                      happening: board.happeningSaid(at: world.watch), standing: board.standingSaid)
    }

    /// The House's keys at the Lantern Inn, five of each kind kept and more
    /// lost, and the chests the rules would open now.
    static func inn(in world: GameState, player: Int) -> Inn {
        let keys = world.innKeys(of: player)
        func counted(_ count: Int, _ kind: String) -> String { "\(count) \(kind) key\(count == 1 ? "" : "s")" }
        var said = "\(counted(keys.silver, "silver")) and \(counted(keys.gold, "gold")), of \(InnKeys.mostKeys) of each kept"
        if keys.silver >= InnKeys.mostKeys { said += ": open a silver chest, or the next silver key is lost" }
        let opens = InnChest.allCases.compactMap { chest -> Order? in
            guard world.innRefusal(chest, as: player) == nil else { return nil }
            let title = chest == .gold && keys.gold == 0
                ? "Open the gold chest for \(InnKeys.goldPrice.moonsalt) moonsalt" : "Open a \(chest.named) chest"
            return Order(title: title, command: .openInnChest(chest))
        }
        return Inn(keys: said, opens: opens)
    }

    static func strikes(for unit: Unit, in world: GameState, player: Int) -> [Order] {
        guard unit.kind.isMilitary, unit.movesLeft > 0 else { return [] }
        let reach = unit.kind.range
        func near(_ hex: Hex) -> Bool { hex != unit.position && hex.distance(to: unit.position) <= reach }
        let houses = world.houses
        func title(_ house: Int) -> String { houses.indices.contains(house) ? houses[house].title : "the wilds" }
        var strikes: [Order] = []
        for wild in world.wildsStanding where near(wild.position) {
            strikes.append(Order(title: "Strike \(wild.called)", command: .attack(unit: unit.id, target: wild.position)))
        }
        for other in world.units where other.owner != player && houses.indices.contains(other.owner)
            && world.isAtWar(player, other.owner) && near(other.position) {
            strikes.append(Order(title: "Strike \(title(other.owner))'s \(SpokenOrders.named(other, in: world))",
                                 command: .attack(unit: unit.id, target: other.position)))
        }
        for hold in world.holds where hold.owner != player && houses.indices.contains(hold.owner)
            && world.isAtWar(player, hold.owner) && near(hold.position) {
            strikes.append(Order(title: "Strike \(hold.name)", command: .attack(unit: unit.id, target: hold.position)))
        }
        return strikes
    }

    /// The nearest sites a company of war may be sent to gather at, as the
    /// rules would send it.
    static func gathers(for unit: Unit, in world: GameState, player: Int) -> [Order] {
        guard unit.kind.isMilitary, unit.errand == nil else { return [] }
        let nearest = world.sitesInLand.sorted { ($0.position.distance(to: unit.position), $0.id) < ($1.position.distance(to: unit.position), $1.id) }
        return nearest.lazy.filter { world.gatherRefusal(unit.id, at: $0.id, as: player) == nil }.prefix(sitesOffered).map { site in
            // The site by its name, which way and how far from the company,
            // never "at on the blackwood by" a hold.
            Order(title: "Gather \(site.store.title.lowercased()) at \(world.siteSaid(site)), \(GameState.waySaid(to: site.position, from: unit.position))",
                  command: .gather(unit: unit.id, site: site.id))
        }
    }

    /// The rallies of the House's side a company of war with no errand may
    /// be sent to now, as the rules would send it.
    static func rallies(for unit: Unit, in world: GameState, player: Int) -> [Order] {
        guard unit.kind.isMilitary, unit.errand == nil else { return [] }
        return world.ralliesStanding.filter { world.joinRallyRefusal($0.id, with: unit.id, as: player) == nil }.map { rally in
            Order(title: "Join the rally against \(world.targetName(rally.target) ?? "a hold")", command: .joinRally(rally: rally.id, unit: unit.id))
        }
    }

    /// The nearest of the House's allies' seats a company of war with no
    /// errand may be sent to keep the gates of, as the rules would send it.
    static func gates(for unit: Unit, in world: GameState, player: Int) -> [Order] {
        guard unit.kind.isMilitary, unit.errand == nil, let allied = world.alliance(of: player) else { return [] }
        let seats = Set([allied.leader] + allied.members).subtracting([player]).compactMap { world.seat(of: $0) }
        let nearest = seats.sorted { ($0.position.distance(to: unit.position), $0.id) < ($1.position.distance(to: unit.position), $1.id) }
        return nearest.lazy.filter { world.reinforceRefusal($0.id, with: unit.id, as: player) == nil }.prefix(sitesOffered).map { seat in
            Order(title: "Keep the gates of \(seat.name)", command: .reinforce(unit: unit.id, hold: seat.id))
        }
    }

    /// The companies a hold may muster now at the first tier: none while it
    /// musters one; those its works allow, the House able to pay.
    static func musters(at hold: NullmereCore.Hold, in world: GameState, player: Int) -> [Order] {
        guard hold.training == nil, world.houses.indices.contains(player) else { return [] }
        let stock = world.houses[player].stock
        return UnitKind.allCases.filter { kind in
            world.tierRefusal(of: kind, tier: 1, at: hold, for: player) == nil && stock.covers(world.trainingCost(of: kind, tier: 1, for: player))
        }.map { kind in
            Order(title: "Muster \(kind.title) I", command: .train(hold: hold.id, kind: kind, tier: 1))
        }
    }

    /// The studies a House may begin now, each at its next grade, as the
    /// rules would take it: none while one is under way, each its Archive
    /// high enough for, its studies before it learned and its stores able
    /// to pay.
    static func studies(in world: GameState, player: Int) -> [Order] {
        guard world.houses.indices.contains(player) else { return [] }
        let research = world.houses[player].research
        return Study.allCases.filter { world.studyRefusal(of: $0, for: player) == nil }.map { study in
            Order(title: "Study \(study.title) \(BuildingKind.numeral(research.grade(of: study) + 1))", command: .study(study))
        }
    }

    /// The works a hold may raise a level now: none while it raises one;
    /// each below its last level, the Moonspire at the seat alone and never
    /// by a vassal, the House able to pay.
    static func works(at hold: NullmereCore.Hold, in world: GameState, player: Int) -> [Order] {
        guard hold.project == nil, world.houses.indices.contains(player) else { return [] }
        let house = world.houses[player]
        return BuildingKind.allCases.compactMap { kind -> Order? in
            if kind.requiresSeat, !hold.isSeat { return nil }
            if kind == .moonspire, house.liege != nil { return nil }
            let level = hold.level(kind) + 1
            guard level <= kind.maxLevel, house.stock.covers(world.buildCost(of: kind, toLevel: level, for: player)) else { return nil }
            return Order(title: "Raise \(kind.title) \(BuildingKind.numeral(level))", command: .build(hold: hold.id, kind: kind))
        }
    }

    /// What a company is about, in a few words; out at the land's work as
    /// the Mac's gatherers tell it (`GameState.gatheringSaid`), and a march
    /// as the Mac's panel tells it, which way and how far, for the phone has
    /// no map beside the list (`GameState.marchSaid`).
    static func doing(_ unit: Unit, in world: GameState, for player: Int) -> String {
        // Out at the land's work as the Mac's gatherers tell it: which site,
        // when full or home, and what it carries.
        if let gathering = world.gatheringSaid(of: unit) { return gathering.prefix(1).uppercased() + gathering.dropFirst() }
        switch unit.errand {
        case .rally(let id)?: return world.rallySaid(id)
        case .reinforce(let hold)?: return "Keeping the gates of \(world.hold(hold)?.name ?? "an ally's hold")"
        case .gather?, .homeward?, nil: break
        }
        if let march = world.marchSaid(of: unit, for: player) { return march }
        if unit.fortified { return "Dug in" }
        return "At rest"
    }

    static func watches(_ count: Int) -> String {
        count == 1 ? "1 watch to go" : "\(count) watches to go"
    }
}
