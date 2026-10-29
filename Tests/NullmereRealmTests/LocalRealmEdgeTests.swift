import Foundation
@testable import NullmereCore
import XCTest
@testable import NullmereRealm

/// The realm in this process at its edges: a steward playing a keeper's
/// House, a link let go, a realm closed, and a new age seating everyone
/// afresh. Each test runs its body on the main actor, where the realm lives.
final class LocalRealmEdgeTests: XCTestCase {
    private func state() -> RealmState {
        RealmState(name: "The Nullmere", seed: "edges", seats: 4, radius: 18, watchLength: 60, now: 0)
    }

    func testAStewardPlaysAKeepersHouseForSomeWatches() {
        MainActor.assumeIsolated {
            let realm = LocalRealm(state: state(), clock: { 0 })
            let link = realm.link(identity: "a")
            var turned = 0
            link.onEvent = { if case .watchTurned = $0 { turned += 1 } }
            link.arrive(name: "Ama")
            let before = realm.state.world.watch
            realm.autoplay("a", watches: 3)
            XCTAssertEqual(realm.state.world.watch, before + 3)
            XCTAssertEqual(turned, 3, "The keeper hears each watch turn")
            XCTAssertNotNil(realm.state.keeper("a")?.house, "and keeps the seat")
        }
    }

    /// A link closed stops hearing without leaving: the keeper stays in the
    /// realm, and a link made since for them is the one told. Leaving by an
    /// old link doesn't silence the new one.
    func testALinkClosedStopsHearingAndLeavesNoOneOut() {
        MainActor.assumeIsolated {
            let realm = LocalRealm(state: state(), clock: { 0 })
            let old = realm.link(identity: "a")
            old.arrive(name: "Ama")
            var oldHeard = 0
            old.onEvent = { _ in oldHeard += 1 }
            old.close()
            XCTAssertNil(old.onEvent)
            XCTAssertEqual(realm.state.keeper("a")?.isOnline, true, "Closed, not gone")
            let new = realm.link(identity: "a")
            var heard: [RealmEvent] = []
            new.onEvent = { heard.append($0) }
            old.leave()
            new.connect()
            XCTAssertTrue(heard.contains { if case .status = $0 { return true } else { return false } }, "The new link is told")
            XCTAssertEqual(oldHeard, 0)
        }
    }

    /// A link of another kind closes by letting go of its listener.
    func testAnyLinkClosesByLettingGo() {
        final class Bare: RealmLink {
            var onEvent: ((RealmEvent) -> Void)?
            func connect() {}
            func arrive(name: String?) {}
            func send(_ command: Command) {}
            func setReady(_ ready: Bool) {}
            func leave() {}
        }
        MainActor.assumeIsolated {
            let link = Bare()
            link.onEvent = { _ in }
            link.close()
            XCTAssertNil(link.onEvent)
        }
    }

    /// A keeper whose link is gone is no longer told anything; the others
    /// still are.
    func testALinkLetGoIsForgotten() {
        MainActor.assumeIsolated {
            let realm = LocalRealm(state: state(), clock: { 0 })
            let kept = realm.link(identity: "a")
            var heard = 0
            kept.onEvent = { _ in heard += 1 }
            var gone: LocalLink? = realm.link(identity: "b")
            gone?.arrive(name: "Bel")
            weak let released = gone
            gone = nil
            XCTAssertNil(released, "Nothing in the realm holds a keeper's link")
            kept.arrive(name: "Ama")
            XCTAssertGreaterThan(heard, 0)
            heard = 0
            realm.setReady(true, from: "a")
            XCTAssertGreaterThan(heard, 0, "Ama still hears the realm")
        }
    }

    func testALinkToAClosedRealmSaysSo() {
        MainActor.assumeIsolated {
            var realm: LocalRealm? = LocalRealm(state: state(), clock: { 0 })
            let link = realm!.link(identity: "a")
            var heard: [RealmEvent] = []
            link.onEvent = { heard.append($0) }
            realm = nil
            link.connect()
            guard case .unreachable(let reason)? = heard.last else { return XCTFail("\(heard)") }
            XCTAssertEqual(reason, "The realm has closed.")
            // Nor does anything else reach a realm that's gone.
            link.arrive(name: "Ama")
            link.send(.fortify(unit: 1))
            link.setReady(true)
            link.leave()
            XCTAssertEqual(heard.count, 1)
        }
    }

    /// When a victory ends an age, the next watch begins a new one, and the
    /// realm seats each keeper there afresh.
    func testANewAgeSeatsEachKeeperAfresh() throws {
        try MainActor.assumeIsolated {
            var begun = state()
            let keeper = try begun.arrive("a", name: "Ama", now: 0)
            begun.world.outcome = Outcome(winner: try XCTUnwrap(keeper.house), kind: .dominion, watch: 1)
            let realm = LocalRealm(state: begun, clock: { 10 })
            let link = realm.link(identity: "a")
            var arrived: [(Keeper, GameState)] = []
            link.onEvent = { if case .arrived(let keeper, let world) = $0 { arrived.append((keeper, world)) } }
            link.setReady(true)
            XCTAssertEqual(realm.state.age, 2)
            XCTAssertEqual(arrived.count, 1, "Seated in the new age")
            XCTAssertNotNil(arrived.first?.0.house)
            XCTAssertNil(arrived.first?.1.outcome, "on a lake no one has won yet")
        }
    }
}
