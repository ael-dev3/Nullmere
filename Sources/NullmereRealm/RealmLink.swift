import NullmereCore

/// What the realm tells a keeper's client.
public enum RealmEvent: Sendable {
    /// How the realm stands: its age, its watch, who is there.
    case status(RealmStatus)
    /// The keeper is in: who they are, and the world as it stands.
    case arrived(Keeper, GameState)
    /// The realm would not take the keeper in, or not yet.
    case refused(RealmError)
    /// The keeper's own order, carried out: the world after it, and what it did.
    case settled(GameState, [GameEvent])
    /// The keeper's order was refused; the world as it truly stands.
    case orderRefused(RealmError, GameState)
    /// Someone else's order changed the world.
    case changed(GameState)
    /// What others did that this keeper hears of, as it happens: a gift, a
    /// war declared, an envoy sent.
    case heard([GameEvent])
    /// What came of the keeper's own order as the realm decided it, after
    /// each order it carried out: an offer a steward took or refused, a
    /// trade carried out or fallen through. The keeper's copy can't decide
    /// these, not seeing the others' stores and companies.
    case answered([GameEvent])
    /// The watch turned: the new world, and everything that happened.
    case watchTurned(GameState, [GameEvent])
    /// The realm can't be reached.
    case unreachable(String)
    /// The realm counts the keeper as ready, or not, otherwise than the
    /// keeper last asked: readiness lost while away, put right.
    case readiness(Bool)
}

/// A keeper's line to the realm. The realm holds the world; the client
/// sends orders and hears back. A realm in this process answers at once;
/// one across the network answers when it can.
@MainActor
public protocol RealmLink: AnyObject {
    /// Where the realm's news goes.
    var onEvent: ((RealmEvent) -> Void)? { get set }
    /// Asks for the realm's status.
    func connect()
    /// Arrives as the keeper this link speaks for: a returning keeper needs
    /// no name; a new one gives the name they'll go by.
    func arrive(name: String?)
    /// Seals the keeper this link speaks for with the words they wrote
    /// down, by the words' proof (see `KeeperWords`); `done` hears nothing
    /// when the realm keeps it, or why it didn't.
    func seal(proof: String, done: @escaping @MainActor (String?) -> Void)
    /// Takes up the keeper the words seal, by their proof, as the identity
    /// this link speaks for, and arrives as them: heard as an arrival is.
    func reclaim(proof: String)
    /// Offers to link a phone to the keeper this link speaks for, by the
    /// code this Mac shows (only its digest goes to the realm); `done`
    /// hears how many devices already speak for them, or why not.
    func offerLink(code: String, done: @escaping @MainActor (Result<Int, LinkRefusal>) -> Void)
    /// Lets go every device that speaks for the keeper; `done` hears
    /// nothing when the realm has, or why it didn't.
    func unlinkDevices(done: @escaping @MainActor (String?) -> Void)
    func send(_ command: Command)
    func setReady(_ ready: Bool)
    /// Leaves the realm, once what the keeper ordered has gone to it; after
    /// two watches a caretaker keeps the keeper's House.
    func leave()
    /// Stops listening and asking, without a word to the realm: for a link
    /// let go at the door, or for a keeper the realm no longer knows.
    func close()
}

extension RealmLink {
    public func close() {
        onEvent = nil
    }

    /// A link to a realm that keeps no words.
    public func seal(proof: String, done: @escaping @MainActor (String?) -> Void) {
        done("This realm keeps no words.")
    }

    public func reclaim(proof: String) {
        onEvent?(.refused(.unknownWords))
    }

    /// A link to a realm that links no phones.
    public func offerLink(code: String, done: @escaping @MainActor (Result<Int, LinkRefusal>) -> Void) {
        done(.failure(LinkRefusal(RealmLinkNote.linksNoPhones)))
    }

    public func unlinkDevices(done: @escaping @MainActor (String?) -> Void) {
        done(RealmLinkNote.linksNoPhones)
    }
}

/// What a link says of what its realm doesn't do.
public enum RealmLinkNote {
    public static let linksNoPhones = "This realm links no phones: only a realm across the network does."
}
