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
    /// The watch turned: the new world, and everything that happened.
    case watchTurned(GameState, [GameEvent])
    /// The realm can't be reached.
    case unreachable(String)
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
    func send(_ command: Command)
    func setReady(_ ready: Bool)
    /// Leaves the realm; the keeper's House stands as they left it.
    func leave()
}
