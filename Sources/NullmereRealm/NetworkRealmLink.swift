import Foundation
import NullmereCore

/// A keeper's line to the realm proper, across the network.
@MainActor
public final class NetworkRealmLink: RealmLink {
    public let url: URL
    public let identity: String
    public var onEvent: ((RealmEvent) -> Void)?

    public init(url: URL, identity: String) {
        self.url = url
        self.identity = identity
    }

    public func connect() {
        onEvent?(.unreachable("The realm's server isn't open yet."))
    }

    public func arrive(name: String?) {
        onEvent?(.unreachable("The realm's server isn't open yet."))
    }

    public func send(_ command: Command) {}

    public func setReady(_ ready: Bool) {}

    public func leave() {}
}
