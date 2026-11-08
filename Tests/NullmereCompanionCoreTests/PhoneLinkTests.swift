import Foundation
@testable import NullmereCore
import NullmereRealm
import XCTest
@testable import NullmereCompanionCore

/// The phone's link to the realm as its keeper reads it: in step, and when
/// the realm was last heard from; out of touch, for how long, and trying
/// again; back in step for a while after, with how long it was out.
@MainActor
final class PhoneLinkTests: XCTestCase {
    /// The phone's clock, set by the test.
    private final class Clock {
        var now = Date(timeIntervalSince1970: 1_000_000)
    }

    private func status() -> RealmStatus {
        RealmStatus(name: "The Nullmere", age: 1, watch: 2, seats: 4, freeSeats: 1, keepers: 3, online: 2, ready: 0,
                    secondsLeft: 170, isEnding: false)
    }

    func testTheLinkIsToldAsItGoesAndComesBack() async {
        let clock = Clock()
        let phone = CompanionSession(memory: PassingMemory(), clock: { clock.now }) { _ in nil }
        XCTAssertNil(phone.link(at: clock.now), "Nothing heard, nothing told")

        phone.hear(.status(status()))
        XCTAssertEqual(phone.lastHeard, clock.now)
        clock.now += 4
        // Coming in, the phone tells nothing of the link until it keeps a House.
        XCTAssertNil(phone.link(at: clock.now))

        // Out of reach: told at once, with each failed try counted.
        phone.hear(.unreachable("The realm can't be reached."))
        XCTAssertEqual(phone.outOfReach, "The realm can't be reached.")
        XCTAssertEqual(phone.lostAt, clock.now)
        let lost = clock.now
        clock.now += 1
        phone.hear(.unreachable("The realm can't be reached."))
        clock.now += 2
        phone.hear(.unreachable("The realm can't be reached."))
        XCTAssertEqual(phone.lostAt, lost, "Lost when first lost, not at each try")
        XCTAssertEqual(phone.triesSinceLost, 3)
        clock.now += 45
        XCTAssertEqual(phone.link(at: clock.now),
                       .outOfTouch("Out of touch for 48 s, and trying again (3 tries so far): orders given now go when the realm answers."))
        // The plain "can't be reached" gives way to the line that says it and
        // more; a reason of its own is told beside it.
        XCTAssertEqual(RealmTrouble.unreachable, "The realm can't be reached.")
        XCTAssertNil(phone.reachSaid(at: clock.now), "Said once, not twice")
        phone.hear(.unreachable("This phone isn't connected to the internet."))
        XCTAssertEqual(phone.reachSaid(at: clock.now), "This phone isn't connected to the internet.")
        // What the link says of itself is no word from the realm.
        phone.hear(.orderRefused(.refused("Too old to send."), GameState(settings: GameSettings(seedText: "link"))))
        XCTAssertNotNil(phone.lostAt, "Still out of touch")

        // The realm heard again: back in step, and for how long it was out.
        clock.now += 20
        phone.hear(.heard([]))
        XCTAssertNil(phone.outOfReach)
        XCTAssertNil(phone.lostAt)
        XCTAssertEqual(phone.triesSinceLost, 0)
        XCTAssertEqual(phone.mended, CompanionSession.Mended(away: 68, at: clock.now))
        XCTAssertEqual(phone.link(at: clock.now + 10), .backInStep("Back in step with the realm after 1:08 out of touch."))
        XCTAssertTrue(phone.linkTold)
        // Told until the realm's first word a minute on, then the link as
        // it stands: here, keeping no House, nothing more to tell.
        clock.now += 30
        phone.hear(.heard([]))
        XCTAssertNotNil(phone.mended, "Still told half a minute on")
        clock.now += CompanionSession.mendedShown
        phone.hear(.heard([]))
        XCTAssertNil(phone.mended)
        XCTAssertFalse(phone.linkTold)
        XCTAssertNil(phone.link(at: clock.now), "Not keeping a House, nothing more to tell")
    }

    func testTheWordsForTheLink() async {
        XCTAssertEqual(LinkSaid.span(0), "0 s")
        XCTAssertEqual(LinkSaid.span(59.9), "59 s")
        XCTAssertEqual(LinkSaid.span(65), "1:05")
        XCTAssertEqual(LinkSaid.span(599), "9:59")
        XCTAssertEqual(LinkSaid.span(840), "14 min")
        XCTAssertEqual(LinkSaid.inStep(heardAgo: 3), "In step with the realm, heard from 3 s ago.")
        // Under a second, never "0 s": as a keeper would say it.
        XCTAssertEqual(LinkSaid.inStep(heardAgo: 0.4), "In step with the realm, heard from just now.")
        XCTAssertEqual(LinkSaid.outOfTouch(for: 0.2, tries: 1),
                       "Out of touch for a moment, and trying again (1 try so far): orders given now go when the realm answers.")
        XCTAssertEqual(LinkSaid.backInStep(after: 0.9), "Back in step with the realm after a moment out of touch.")
        XCTAssertEqual(LinkSaid.outOfTouch(for: 12, tries: 1),
                       "Out of touch for 12 s, and trying again (1 try so far): orders given now go when the realm answers.")
        XCTAssertEqual(LinkSaid.backInStep(after: 125), "Back in step with the realm after 2:05 out of touch.")
    }
}
