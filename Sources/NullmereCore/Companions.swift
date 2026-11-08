/// A code a keeper's Mac shows to link a phone's companion to the keeper:
/// twelve letters and figures of thirty-two that can't be taken for another
/// (no 0 or O, no 1 or I), sixty bits, read in three fours. The Mac sends
/// the realm only its digest; the phone brings the code itself, and the
/// realm links whoever brings it first, within ten minutes, once.
///
/// Sixty bits need no count of wrong guesses kept: a stranger guessing as
/// fast as the realm's steward could hear them, a thousand a second for the
/// whole ten minutes, has about one chance in two million million of
/// finding a code before it lapses. A count kept for the whole realm would
/// be worse than none: anyone could spend it, and stop every keeper's
/// linking for as long as they kept guessing.
public enum LinkCode {
    public static let alphabet = Array("23456789ABCDEFGHJKLMNPQRSTUVWXYZ")
    public static let length = 12

    /// A new code, from `generator`.
    public static func make<G: RandomNumberGenerator>(using generator: inout G) -> String {
        String((0..<length).map { _ in alphabet[Int(generator.next() % UInt64(alphabet.count))] })
    }

    /// A new code, from the system's own randomness.
    public static func make() -> String {
        var generator = SystemRandomNumberGenerator()
        return make(using: &generator)
    }

    /// A code as the keeper reads it out: three fours, a dash between each.
    public static func shown(_ code: String) -> String {
        guard code.count == length else { return code }
        let letters = Array(code)
        return stride(from: 0, to: length, by: 4).map { String(letters[$0..<$0 + 4]) }.joined(separator: "-")
    }

    /// A code as it was typed, read back: any case, spaces or dashes between;
    /// nil unless twelve of the code's own letters and figures.
    public static func read(_ text: String) -> String? {
        var code = ""
        for character in text.uppercased() where !character.isWhitespace && character != "-" {
            guard alphabet.contains(character) else { return nil }
            code.append(character)
        }
        return code.count == length ? code : nil
    }

    /// What the Mac sends the realm: the code's digest, never the code.
    public static func digest(of code: String) -> String {
        SHA256.hex("nullmere link: " + code)
    }
}

/// A link a keeper's Mac offered: the digest of the code it showed, and the
/// moment it lapses.
public struct LinkOffer: Codable, Equatable, Sendable {
    public let digest: String
    public let until: Double

    public init(digest: String, until: Double) {
        self.digest = digest
        self.until = until
    }
}

extension RealmState {
    /// How long a link offered may be taken, in seconds.
    public static let linkLasts = 600.0
    /// The most devices that may speak for one keeper besides their Mac.
    public static let mostCompanions = 4

    /// The keeper an identity speaks for: the keeper it is, or the keeper
    /// whose companion it is.
    public func keeperID(speakingFor identity: String) -> String? {
        if keepers.contains(where: { $0.id == identity }) { return identity }
        return keepers.first { $0.companions?.contains(identity) == true }?.id
    }

    /// Every companion with the keeper it speaks for, as the realm's
    /// database resolves a companion's view to its keeper's.
    public var companionsByKeeper: [(companion: String, keeper: String)] {
        keepers.flatMap { keeper in (keeper.companions ?? []).map { ($0, keeper.id) } }
    }

    /// A keeper's Mac offers a link by the digest of the code it shows, good
    /// for ten minutes and once; a new offer lets the last go.
    public mutating func offerLink(_ id: String, digest: String, now: Double) throws(RealmError) {
        guard let index = keepers.firstIndex(where: { $0.id == id }) else { throw .unknownKeeper }
        guard KeeperWords.isProof(digest) else { throw .refused("The link's digest couldn't be read.") }
        keepers[index].linkOffer = LinkOffer(digest: digest, until: now + RealmState.linkLasts)
    }

    /// A device brings the code its keeper's Mac showed: from now on it
    /// speaks for that keeper, as their companion, and the offer is spent.
    @discardableResult
    public mutating func takeLink(_ identity: String, code text: String, now: Double) throws(RealmError) -> Keeper {
        guard keeperID(speakingFor: identity) == nil else {
            throw .refused("This device already speaks for a keeper of this realm.")
        }
        guard let code = LinkCode.read(text) else {
            throw .refused("A link code is twelve letters and figures, as the keeper's Mac shows it.")
        }
        let digest = LinkCode.digest(of: code)
        guard let index = keepers.firstIndex(where: { $0.linkOffer?.digest == digest && ($0.linkOffer?.until ?? 0) >= now }) else {
            throw .refused("No keeper's Mac shows that code, or it has lapsed. Show a new one and try again.")
        }
        guard (keepers[index].companions ?? []).count < RealmState.mostCompanions else {
            throw .refused("Four devices already speak for this keeper. Unlink them from the Mac first.")
        }
        keepers[index].companions = (keepers[index].companions ?? []) + [identity]
        keepers[index].linkOffer = nil
        return keepers[index]
    }

    /// A keeper lets every companion go, and any link offered: none speaks
    /// for them from now on.
    public mutating func unlinkCompanions(_ id: String) throws(RealmError) {
        guard let index = keepers.firstIndex(where: { $0.id == id }) else { throw .unknownKeeper }
        keepers[index].companions = nil
        keepers[index].linkOffer = nil
        keepers[index].companionsHere = nil
        keepers[index].companionLastHeard = nil
    }

    /// A companion lets itself go: it speaks for its keeper no more.
    /// Whether it spoke for one.
    @discardableResult
    public mutating func unlink(companion identity: String) -> Bool {
        guard let index = keepers.firstIndex(where: { $0.companions?.contains(identity) == true }) else { return false }
        let left = keepers[index].companions?.filter { $0 != identity } ?? []
        keepers[index].companions = left.isEmpty ? nil : left
        if left.isEmpty {
            keepers[index].companionsHere = nil
            keepers[index].companionLastHeard = nil
        }
        return true
    }

    /// Which keepers' devices the realm has heard from lately, as many as
    /// it has of each keeper's (`heard`), and when each keeper's were last
    /// heard from (`lastHeard`): set in their records, for their Mac to
    /// show their phone in the realm with them, or when it last was. A
    /// keeper with no device linked keeps neither. Whether any record
    /// changed.
    @discardableResult
    public mutating func hearCompanions(_ heard: [String: Int], lastHeard: [String: Double]) -> Bool {
        var changed = false
        for index in keepers.indices where keepers[index].companions != nil || keepers[index].companionsHere != nil
            || keepers[index].companionLastHeard != nil {
            let id = keepers[index].id
            let linked = keepers[index].companions != nil
            let count = linked ? min(heard[id] ?? 0, keepers[index].companions?.count ?? 0) : 0
            let here: Int? = count > 0 ? count : nil
            let last: Double? = !linked || here != nil ? nil : lastHeard[id] ?? keepers[index].companionLastHeard
            if keepers[index].companionsHere != here || keepers[index].companionLastHeard != last {
                keepers[index].companionsHere = here
                keepers[index].companionLastHeard = last
                changed = true
            }
        }
        return changed
    }
}

extension Keeper {
    /// Whether the keeper's phone is in the realm with them, as their Mac
    /// tells it at `now` (the realm's clock, in seconds): with them now, or
    /// when it last was; nil while no device is linked to them.
    public func companionsSaid(now: Double) -> String? {
        guard let linked = companions?.count, linked > 0 else { return nil }
        if let here = companionsHere, here > 0 {
            if linked == 1 { return "Your phone is in the realm with you." }
            if here >= linked { return linked == 2 ? "Both your phones are in the realm with you." : "All \(linked) of your phones are in the realm with you." }
            return "\(here) of your \(linked) phones \(here == 1 ? "is" : "are") in the realm with you."
        }
        let phones = linked == 1 ? "Your phone" : "Your phones"
        guard let last = companionLastHeard else {
            return "\(phones) \(linked == 1 ? "hasn't" : "haven't") been in the realm lately."
        }
        return "\(phones) \(linked == 1 ? "was" : "were") last in the realm \(Keeper.ago(now - last))."
    }

    /// How long ago, as a keeper says it: "a moment ago", "4 min ago",
    /// "3 hours ago", "2 days ago".
    static func ago(_ seconds: Double) -> String {
        let seconds = max(seconds, 0)
        if seconds < 60 { return "a moment ago" }
        if seconds < 3_600 { return "\(Int(seconds / 60)) min ago" }
        if seconds < 86_400 {
            let hours = Int(seconds / 3_600)
            return hours == 1 ? "an hour ago" : "\(hours) hours ago"
        }
        let days = Int(seconds / 86_400)
        return days == 1 ? "a day ago" : "\(days) days ago"
    }
}
