import Foundation
import NullmereCore
import NullmereRealm
import Observation

/// Where a phone keeps the realm it was linked to, so it comes back in as
/// its keeper when it opens: the address alone, never a key. And what each
/// of the keeper's commanders remembers of counsel taken on this phone,
/// which stays on it: counsel is spoken on the device it is taken on.
public protocol CompanionMemory: AnyObject {
    var realm: URL? { get set }
    /// By commander.
    var counsel: [Int: CounselMemory] { get set }
    /// What the keeper last saw of their House on this phone, to tell them
    /// what happened while it was set aside.
    var lastSeen: LastSeen? { get set }
}

/// A memory kept for the life of the process: for tests.
public final class PassingMemory: CompanionMemory {
    public var realm: URL?
    public var counsel: [Int: CounselMemory] = [:]
    public var lastSeen: LastSeen?
    public init(realm: URL? = nil) { self.realm = realm }
}

/// A keeper's phone on their realm. Linked once by the code their Mac shows,
/// under an identity of its own (the Mac's key never leaves the Mac), it
/// comes in as the keeper whenever it opens, reading their view of the
/// world as their Mac does, and gives orders for their House. The realm
/// alone decides each order: one the rules would refuse from this view is
/// refused here, with their reason, and sent nowhere; one sent is carried
/// out here at once as the realm will, and the realm's word follows, the
/// world as it truly stands with it.
@MainActor
@Observable
public final class CompanionSession {
    public enum Phase: Equatable, Sendable {
        /// Linked to no keeper: the code their Mac shows is wanted.
        case pairing
        /// Bringing the code, or coming in as the keeper.
        case entering
        /// In as the keeper, their House shown.
        case keeping
        /// Set aside, still linked: in again as the keeper when it comes back.
        case away
    }

    /// The realm's word on an order, or why it went nowhere.
    public struct Word: Equatable, Sendable {
        public let text: String
        public let refused: Bool
        /// Sent, the realm's answer still to come.
        public let awaited: Bool
    }

    public private(set) var phase: Phase = .pairing
    /// Why linking or coming in failed, for the keeper to read.
    public private(set) var problem: String?
    /// The realm this phone goes to.
    public private(set) var realm: URL?
    public private(set) var status: RealmStatus?
    /// When the status was heard, to count its watch down from.
    public private(set) var statusHeard: Date?
    public private(set) var keeper: Keeper?
    public private(set) var world: GameState?
    public private(set) var ledger: CompanionLedger?
    /// The House's reports while the phone is linked, the latest first, as
    /// the Mac files them: each battle and hunt it had a part in, each field
    /// of battle as it ended, each hold its Lanterns scouted, each lair it
    /// assaulted.
    public private(set) var reports: [BattleReport] = []
    /// The most reports the phone keeps.
    public static let reportsKept = 20
    private var reportsFiled = 0
    /// The realm's word on the last order given here.
    public private(set) var word: Word?
    /// What happened to the House while the phone was set aside, told as it
    /// comes in again, until the keeper puts it away.
    public private(set) var away: AwayReport?
    /// The House the report tells of, as its caretaker names it.
    private var awayTitle = ""
    public private(set) var isReady = false
    /// The realm can't be reached just now, and why.
    public private(set) var outOfReach: String?
    /// When the realm was last heard from: a status it published, the
    /// House's view moved on, an order answered.
    public private(set) var lastHeard: Date?
    /// When the realm went out of reach, while it is, and how many of the
    /// phone's tries at it have failed since: the link tries again on its
    /// own, waiting twice as long after each.
    public private(set) var lostAt: Date?
    public private(set) var triesSinceLost = 0
    /// The realm in reach again: how long it was out of touch, and when it
    /// came back, told until the realm's first word once `mendedShown` has
    /// passed.
    public private(set) var mended: Mended?

    /// A link mended: how long the phone was out of touch, and when.
    public struct Mended: Equatable, Sendable {
        public let away: TimeInterval
        public let at: Date
    }

    /// How long the phone tells of a mending once the realm is back.
    public static let mendedShown: TimeInterval = 60

    /// What a phone the realm no longer links to anyone is told.
    public static let unlinked = "This phone no longer speaks for a keeper of this realm. Link it again from the keeper's Mac."
    /// What a realm too old to link phones is said to be.
    public static let tooOld = "This realm doesn't link phones yet: its steward keeps an older Nullmere Online."
    /// The tongue a realm must speak to link a phone.
    public static let linkingSpeech = 13

    private var link: NetworkRealmLink?
    private let memory: CompanionMemory
    private let makeLink: @MainActor (URL) -> NetworkRealmLink?
    private let clock: () -> Date
    /// The orders given here the realm hasn't answered yet, as each was
    /// told, the first given first: the link sends them one at a time and
    /// in order, and the realm answers each, so its word is on the first.
    private var pending: [String] = []

    /// `makeLink` reaches a realm at an address under this phone's own
    /// identity for it; nil for an address it can't reach.
    public init(memory: CompanionMemory, clock: @escaping () -> Date = Date.init,
                makeLink: @escaping @MainActor (URL) -> NetworkRealmLink?) {
        self.memory = memory
        self.makeLink = makeLink
        self.clock = clock
        realm = memory.realm
    }

    /// Comes in as the keeper of the realm this phone was linked to last,
    /// if it was: when it opens, and when it comes back to the front.
    public func resume() {
        guard let realm = memory.realm else { return }
        guard phase != .entering else { return }
        if phase == .keeping, let link {
            link.wake()
            return
        }
        guard let link = open(realm) else { return }
        phase = .entering
        problem = nil
        link.accompany()
    }

    /// The phone's network back after it was gone: a phone in as the keeper
    /// asks the realm at once, rather than at its next read, which a realm
    /// long out of reach puts as much as half a minute off.
    public func networkReturned() {
        guard phase == .keeping, let link else { return }
        link.wake()
    }

    /// Brings the code the keeper's Mac shows, to speak for them from now on.
    public func take(_ invite: CompanionInvite) {
        guard let link = open(invite.realm) else { return }
        phase = .entering
        problem = nil
        link.takeLink(code: invite.code)
    }

    /// Lets this phone go: it speaks for the keeper no more, and forgets
    /// the realm.
    public func unlink() {
        link?.unlinkDevices { _ in }
        forget(nil)
    }

    /// The phone set aside: the realm hears no more of it until it comes
    /// back. Its keeper stays while their Mac is there.
    public func pause() {
        guard let link, phase == .keeping else { return }
        if let world, let house = keeper?.house, world.houses.indices.contains(house) {
            memory.lastSeen = LastSeen(of: house, in: world)
        }
        link.leave()
        self.link = nil
        letGoOfPending()
        phase = .away
    }

    /// Counsel of one of the keeper's commanders as this phone takes it:
    /// what they are told of the realm, from the keeper's view as this phone
    /// holds it, and what they remember of counsel taken here this age.
    /// Nil unless the phone speaks for the keeper and the commander is the
    /// House's own and free to speak.
    public func counsel(of commander: Int) -> (counsel: CommanderCounsel, memory: CounselMemory)? {
        guard phase == .keeping, let world, let house = keeper?.house,
              let grounded = CommanderCounsel(state: world, player: house, commander: commander, reports: reports),
              grounded.commander.captive == nil else { return nil }
        let age = status?.age ?? 0
        let kept = memory.counsel[commander].flatMap { $0.age == age ? $0 : nil }
        return (grounded, kept ?? CounselMemory(commander: commander, age: age))
    }

    /// The House's commander who led in a battle of one of its reports and
    /// may be asked of it in counsel here, as on the Mac; nil for none.
    public func askable(of report: BattleReport) -> Commander? {
        guard phase == .keeping, let world, let house = keeper?.house else { return nil }
        return world.askable(of: report, by: house)
    }

    /// The report of what happened while away, put away.
    /// The key the caretaker's word to a keeper come back is kept under,
    /// as the Mac keeps it: the watch they came back to.
    public static func caretakerKey(_ away: AwayReport) -> String { "caretaker-\(away.watch)" }

    /// The realm's characters this phone's own model gives words to, as the
    /// ledger keys them, with the caretaker's word to the keeper come back
    /// first while its card stands.
    public var voicedMoments: [Voicing.Keyed] {
        let caretaker = away.map { [Voicing.Keyed(key: CompanionSession.caretakerKey($0), moment: $0.voiced(house: awayTitle))] } ?? []
        return caretaker + (ledger?.voices ?? [])
    }

    public func dismissAway() {
        away = nil
    }

    /// Keeps what a commander remembers of counsel taken here, forgetting
    /// what any remembers of an age gone by.
    public func remember(_ counsel: CounselMemory) {
        guard memory.realm != nil else { return }
        var kept = memory.counsel.filter { $0.value.age == counsel.age }
        kept[counsel.commander] = counsel
        memory.counsel = kept
    }

    /// Gives an order for the keeper's House: refused here with the rules'
    /// reason if they wouldn't take it from this view, else carried out
    /// here as the realm will and sent, its word to follow; while the realm
    /// is out of reach, said to wait until it is, as it does.
    public func give(_ command: Command, told: String) {
        guard phase == .keeping, let link, let house = keeper?.house, var copy = world else { return }
        do {
            _ = try copy.perform(command, as: house)
        } catch {
            word = Word(text: "\(told): \(error)", refused: true, awaited: false)
            return
        }
        pending.append(told)
        show(copy)
        word = Word(text: outOfReach == nil ? "\(told): sent to the realm." : "\(told): \(Self.waitsForReach)",
                    refused: false, awaited: true)
        link.send(command)
    }

    /// The word on an order given while the realm is out of reach: it is
    /// sent once the realm can be reached again.
    public static let waitsForReach = "it waits until the realm can be reached."

    /// The word on an order still unanswered when the phone's link went:
    /// whether the realm carried it out is the House's to show.
    public static let letGo = "the phone was set aside before the realm answered."

    /// What was given here and not yet answered goes with the link that
    /// would have sent it: the keeper told so, where they were waiting on it.
    private func letGoOfPending() {
        if let told = pending.last, word?.awaited == true {
            word = Word(text: "\(told): \(Self.letGo)", refused: false, awaited: false)
        }
        pending = []
    }

    /// Ready for the watch to turn, or not.
    public func setReady(_ ready: Bool) {
        guard phase == .keeping, let link else { return }
        isReady = ready
        link.setReady(ready)
    }

    /// Words to the keeper's alliance, or to the whole realm.
    public func say(_ words: String, toAlliance: Bool) {
        let said = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !said.isEmpty else { return }
        give(.say(words: said, toAlliance: toAlliance), told: toAlliance ? "Said to your alliance" : "Said to the realm")
    }

    /// Seconds until the watch turns of its own accord, by the status heard.
    public func secondsLeft(at now: Date) -> Int? {
        guard let status, let heard = statusHeard else { return nil }
        return max(0, status.secondsLeft - Int(now.timeIntervalSince(heard)))
    }

    // MARK: The realm's word

    private func open(_ address: URL) -> NetworkRealmLink? {
        link?.close()
        letGoOfPending()
        guard let made = makeLink(address) else {
            problem = "This phone can't reach a realm at \(address.absoluteString)."
            phase = .pairing
            return nil
        }
        realm = address
        link = made
        made.device = .phone
        made.onEvent = { [weak self, weak made] event in
            guard let self, let made, made === self.link else { return }
            self.hear(event)
        }
        made.connect()
        return made
    }

    func hear(_ event: RealmEvent) {
        // What only the realm says is word from it; what the link says of
        // itself (out of reach, an order too old to send, a refusal it made
        // up from a failure) is not.
        switch event {
        case .unreachable, .orderRefused, .refused, .settled: break
        default: heardFromTheRealm()
        }
        switch event {
        case .status(let status):
            self.status = status
            statusHeard = clock()
            outOfReach = nil
            if phase == .entering, (status.speech ?? 0) < Self.linkingSpeech {
                forget(Self.tooOld)
            }
        case .arrived(let keeper, let world):
            self.keeper = keeper
            phase = .keeping
            problem = nil
            outOfReach = nil
            memory.realm = realm
            if let house = keeper.house, let seen = memory.lastSeen, seen.house == house {
                away = AwayReport(since: seen, now: world, player: house)
                awayTitle = world.houses.indices.contains(house) ? world.houses[house].title : ""
            }
            show(world)
        case .refused(let error):
            if error == .unknownKeeper {
                forget(Self.unlinked)
            } else if phase == .entering {
                link?.close()
                link = nil
                problem = error.description
                phase = .pairing
            } else {
                word = Word(text: error.description, refused: true, awaited: false)
            }
        case .settled(let world, let events):
            // A realm in this process answers the order too, just after.
            show(world)
            file(events, in: world)
        case .answered(let events):
            // Across the network, an order carried out is answered so, the
            // world it made told as it changed.
            carriedOut(events)
        case .orderRefused(let error, let world):
            show(world)
            let told = pending.isEmpty ? "Your order" : pending.removeFirst()
            word = Word(text: "\(told): the realm refused it. \(error.description)", refused: true, awaited: false)
        case .changed(let world):
            show(world)
        case .watchTurned(let world, let events):
            isReady = false
            show(world)
            file(events, in: world)
        case .readiness(let ready):
            isReady = ready
        case .unreachable(let why):
            outOfReach = why
            if lostAt == nil {
                lostAt = clock()
                mended = nil
            }
            triesSinceLost += 1
        case .heard(let events):
            if let world { file(events, in: world) }
        case .keeperChanged(let keeper):
            // Their favour and the watches kept, as the watch left them.
            self.keeper = keeper
        }
    }

    /// The realm heard from: back in step, if it was out of reach.
    private func heardFromTheRealm() {
        let now = clock()
        if let lost = lostAt {
            mended = Mended(away: now.timeIntervalSince(lost), at: now)
            lostAt = nil
            triesSinceLost = 0
            outOfReach = nil
        } else if let told = mended, now.timeIntervalSince(told.at) >= Self.mendedShown {
            mended = nil
        }
        lastHeard = now
    }

    /// The phone's link to the realm as its keeper reads it at a moment:
    /// out of touch and trying again, back in step for a while after, or in
    /// step and when the realm was last heard from.
    /// Why the realm can't be reached, where that says more than the
    /// link's own line: the plain "can't be reached" gives way to "Out of
    /// touch for …, and trying again", which says it and more; a reason of
    /// its own (no internet, no answer in time) is told beside it.
    public func reachSaid(at now: Date) -> String? {
        guard let reach = outOfReach else { return nil }
        if reach == RealmTrouble.unreachable, case .outOfTouch? = link(at: now) { return nil }
        return reach
    }

    public func link(at now: Date) -> Link? {
        if let lost = lostAt {
            return .outOfTouch(LinkSaid.outOfTouch(for: now.timeIntervalSince(lost), tries: triesSinceLost))
        }
        // Told until the realm's first word a while after (`mendedShown`).
        if let mended {
            return .backInStep(LinkSaid.backInStep(after: mended.away))
        }
        guard phase == .keeping, let lastHeard else { return nil }
        return .inStep(LinkSaid.inStep(heardAgo: now.timeIntervalSince(lastHeard)))
    }

    /// Whether there is anything of the link to tell at the head of a tab:
    /// out of reach, or mended lately.
    public var linkTold: Bool { outOfReach != nil || lostAt != nil || mended != nil }

    /// The link as told: each with its words.
    public enum Link: Equatable, Sendable {
        case inStep(String)
        case outOfTouch(String)
        case backInStep(String)

        public var text: String {
            switch self {
            case .inStep(let text), .outOfTouch(let text), .backInStep(let text): return text
            }
        }
    }

    /// The realm's word on the first order given here still unanswered, and
    /// what came of it where it is told at once, as the Mac tells it: what a
    /// chest of the Lantern Inn opened by it held, how a venture up the Spine
    /// went.
    private func carriedOut(_ events: [GameEvent] = []) {
        guard !pending.isEmpty else { return }
        var text = "\(pending.removeFirst()): carried out by the realm."
        if let house = keeper?.house, let world,
           let held = events.lazy.compactMap({ event -> String? in
               switch event {
               case .innChestOpened(house, _, _): return world.tidings(of: event, for: house)?.text
               case .expedition(let result) where result.house == house: return world.tidings(of: event, for: house)?.text
               default: return nil
               }
           }).first {
            text += " " + held
        }
        word = Word(text: text, refused: false, awaited: false)
    }

    private func show(_ world: GameState) {
        self.world = world
        ledger = keeper?.house.map { CompanionLedger(world: world, player: $0) }
    }

    /// Files the House's reports of what the realm told, as the Mac does.
    private func file(_ events: [GameEvent], in world: GameState) {
        guard let house = keeper?.house else { return }
        let filed = world.reports(of: events, for: house, after: reportsFiled)
        guard !filed.isEmpty else { return }
        reportsFiled += filed.count
        reports = Array((filed.reversed() + reports).prefix(Self.reportsKept))
    }

    /// Linked to no one, or to a realm that can't link: back to pairing,
    /// the realm forgotten, and why.
    private func forget(_ why: String?) {
        link?.close()
        link = nil
        pending = []
        memory.realm = nil
        memory.counsel = [:]
        memory.lastSeen = nil
        away = nil
        keeper = nil
        world = nil
        ledger = nil
        reports = []
        word = nil
        isReady = false
        phase = .pairing
        problem = why
    }
}
