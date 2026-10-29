import Foundation
@testable import NullmereCore
@testable import NullmereKit
import NullmereRealm

extension GameSession {
    /// One House's game in a realm hosted in the test, its keeper holding
    /// the world's first kept House: a rehearsal, never the game's own way
    /// in, which is always through the realm's front door.
    convenience init(state: GameState, store: LocalStore = LocalStore(), voice: (any Voice)? = nil) {
        let identity = "rehearsal"
        let realm = LocalRealm(state: RealmState(name: "Rehearsal", world: state, keeper: identity, now: Date().timeIntervalSince1970))
        self.init(link: realm.link(identity: identity), house: state.player, world: state.view(for: state.player), store: store,
                  voice: voice, host: realm)
    }
}
