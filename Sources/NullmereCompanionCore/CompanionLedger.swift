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
    }

    /// A line said in the alliance or to the realm.
    public struct Said: Equatable, Identifiable, Sendable {
        public let id: Int
        public let from: String
        public let text: String
        public let watch: Int
        /// Said by this keeper's own House.
        public let isOwn: Bool
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
    public let companies: [Company]
    public let commanders: [Commander]
    /// Help for each ally with works, musters or study under way the
    /// House hasn't helped yet.
    public let helps: [Order]
    public let holds: [Hold]
    /// The study under way at the House's Archive, and how long it has to go.
    public let studying: String?
    /// The studies the House may begin now, its stores able to pay: none
    /// while one is under way.
    public let studies: [Order]
    public let stores: [(resource: Resource, amount: Int)]
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
    /// The Houses nearest the keeper's seat, the nearest first, and the
    /// dealings the rules would take with each.
    public let dealings: [Dealing]
    /// The most Houses the phone deals with at once: the nearest.
    public static let dealtWith = 12
    /// The caretaker's standing orders, and the orders that would change them.
    public let standing: Standing
    /// The Lantern Inn's keys and the chests the House may open.
    public let inn: Inn
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
            && a.companies == b.companies && a.commanders == b.commanders && a.helps == b.helps
            && a.holds == b.holds && a.studying == b.studying && a.studies == b.studies
            && a.stores.map(\.amount) == b.stores.map(\.amount) && a.storage == b.storage && a.satchel == b.satchel && a.alliance == b.alliance && a.allies == b.allies
            && a.allianceWords == b.allianceWords && a.realmWords == b.realmWords && a.chronicle == b.chronicle
            && a.invitations == b.invitations && a.requests == b.requests && a.asks == b.asks && a.invites == b.invites
            && a.leave == b.leave && a.calls == b.calls
            && a.allianceLore == b.allianceLore && a.pursuits == b.pursuits && a.allianceGifts == b.allianceGifts
            && a.dealings == b.dealings && a.standing == b.standing && a.inn == b.inn
            && a.letters == b.letters && a.correspondents == b.correspondents
    }

    /// The House's stores as one stock.
    public var stock: Stock {
        var stock = Stock()
        for store in stores { stock[store.resource] = store.amount }
        return stock
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
            let orders = offered.filter(\.2).map { Order(title: $0.0, command: $0.1) }
            let marches = holds.filter { $0.position != unit.position && unit.destination != $0.position }.map { hold in
                Order(title: "March to \(hold.name)", command: .move(unit: unit.id, to: hold.position))
            }
            return Company(id: unit.id, name: named(unit), troops: GameState.counted(world.troops(of: unit)),
                           leader: unit.leader.flatMap { world.commander($0)?.name }, doing: CompanionLedger.doing(unit, in: world),
                           orders: orders, marches: marches, strikes: CompanionLedger.strikes(for: unit, in: world, player: player),
                           gathers: CompanionLedger.gathers(for: unit, in: world, player: player),
                           rallies: CompanionLedger.rallies(for: unit, in: world, player: player),
                           gates: CompanionLedger.gates(for: unit, in: world, player: player))
        }
        let war = world.units(of: player).filter { $0.kind.isMilitary }.sorted { $0.id < $1.id }
        let armoury = world.gear(of: player)
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
            let gear: [Order] = line.heldBy != nil ? [] : armoury.filter { $0.wornBy != id }.map { piece in
                let from = piece.wornBy.flatMap { world.commander($0)?.name }.map { ", from \($0)" } ?? ""
                return Order(title: "Wear the \(piece.title)\(from)", command: .wear(gear: piece.id, commander: id))
            }
            return Commander(id: id, name: line.commander.name, title: "\(line.commander.archetype.title) · level \(line.level)",
                             standing: standing, canCounsel: line.heldBy == nil, leads: leads, seconds: seconds,
                             home: riding ? Order(title: "Ride home", command: .unassign(commander: id)) : nil,
                             talents: talents, gear: gear)
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
            return Hold(id: hold.id, name: hold.name, isSeat: hold.isSeat, work: work,
                        musters: CompanionLedger.musters(at: hold, in: world, player: player),
                        works: CompanionLedger.works(at: hold, in: world, player: player))
        }
        let pursuit = houses.indices.contains(player) ? houses[player].research.pursuit : nil
        studying = pursuit.map { "Studying \($0.study.title) \(BuildingKind.numeral($0.grade)), " + CompanionLedger.watches($0.watchesLeft) }
        studies = CompanionLedger.studies(in: world, player: player)
        let stock = houses.indices.contains(player) ? houses[player].stock : .zero
        stores = Resource.allCases.map { ($0, stock[$0]) }
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
            return Item(kind: stack.kind, count: stack.kind.counted(stack.count), effect: effect.prefix(1).uppercased() + effect.dropFirst(),
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
            words.suffix(CompanionLedger.linesShown).map { Said(id: $0.id, from: title($0.from), text: $0.text, watch: $0.watch, isOwn: $0.from == player) }
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
            Answer(id: "invited by \(invited.id)", question: "\(invited.name) invites your House to join it.",
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
        calls = CompanionLedger.calls(in: world, player: player, holds: holds)
        // The alliance's studies, as the Mac's Alliance panel reads them.
        dealings = CompanionLedger.dealings(in: world, player: player)
        standing = CompanionLedger.standing(in: world, player: player)
        inn = CompanionLedger.inn(in: world, player: player)
        (letters, correspondents) = CompanionLedger.letters(in: world, player: player)
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
                           war: atWar || world.refusal(of: war.command, as: player) != nil ? nil : war)
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
            strikes.append(Order(title: "Strike the \(wild.kind.title)", command: .attack(unit: unit.id, target: wild.position)))
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
            Order(title: "Gather \(site.store.title.lowercased()) at \(world.placeName(of: site.position))",
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

    /// What a company is about, in a few words.
    static func doing(_ unit: Unit, in world: GameState) -> String {
        switch unit.errand {
        case .gather?: return "Gathering"
        case .homeward?: return "Bringing its load home"
        case .rally?: return "With a rally"
        case .reinforce(let hold)?: return "Keeping the gates of \(world.hold(hold)?.name ?? "an ally's hold")"
        case nil: break
        }
        if let destination = unit.destination { return "Marching to " + whither(world.placeName(of: destination)) }
        if unit.fortified { return "Dug in" }
        return "At rest"
    }

    /// A place as a march's end, its own word for where let go: "at
    /// Tirford" is "Tirford", "on the barrows by Tirford" is "the barrows by
    /// Tirford", "in the field" is "the field".
    static func whither(_ place: String) -> String {
        for preposition in ["at ", "on ", "in "] where place.hasPrefix(preposition) { return String(place.dropFirst(preposition.count)) }
        return place
    }

    static func watches(_ count: Int) -> String {
        count == 1 ? "1 watch to go" : "\(count) watches to go"
    }
}
