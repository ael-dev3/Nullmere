import Foundation
import XCTest
@testable import NullmereCore

/// The realm's compact, read and accepted before a keeper first enters and
/// again when its words change; the tongue a realm speaks, so that a Mac
/// too old for it is told so; and a keeper forgotten when they ask.
final class CompactTests: XCTestCase {
    private func realm(seats: Int = 4) -> RealmState {
        RealmState(name: "The Nullmere", seed: "compact test", seats: seats, radius: 18, watchLength: 60, now: 0)
    }

    func testTheCompactIsReadBeforeTheFirstEntryAndAgainWhenItChanges() {
        XCTAssertTrue(Compact.mustRead(accepted: nil), "Never accepted")
        XCTAssertTrue(Compact.mustRead(accepted: 0))
        XCTAssertFalse(Compact.mustRead(accepted: Compact.edition), "Accepted as it stands")
        XCTAssertTrue(Compact.mustRead(accepted: Compact.edition, held: Compact.edition + 1), "Its words changed since")
        XCTAssertFalse(Compact.mustRead(accepted: Compact.edition + 1), "A later edition accepted covers this one")
        XCTAssertEqual(Compact.preface(accepted: nil), "Before you first enter: what you agree to, and what the realm keeps of you.")
        XCTAssertEqual(Compact.preface(accepted: Compact.edition), Compact.preface(accepted: nil),
                       "No change to tell of the edition accepted")
    }

    /// Every part of the compact says something, in plain words, and
    /// together they cover what the gap list promised: terms and privacy.
    func testTheCompactSaysWhatTheRealmKeepsAndWhatIsAsked() {
        XCTAssertGreaterThanOrEqual(Compact.articles.count, 5)
        XCTAssertEqual(Set(Compact.articles.map(\.heading)).count, Compact.articles.count, "Each part its own heading")
        for article in Compact.articles {
            XCTAssertFalse(article.heading.isEmpty)
            XCTAssertTrue(article.text.hasSuffix("."), article.heading)
            XCTAssertLessThan(article.text.count, 600, "\(article.heading) is a few sentences")
        }
        let whole = Compact.spoken
        for promise in ["keychain", "on-device model", "Words", "report", "forget", "read them again", "public domain"] {
            XCTAssertTrue(whole.contains(promise), "The compact speaks of \(promise)")
        }
        // Each edition after the first says what changed.
        for edition in 2...max(2, Compact.edition) where edition <= Compact.edition {
            XCTAssertNotNil(Compact.changes[edition], "Edition \(edition) says what changed")
        }
    }

    /// A realm tells the tongue it speaks, the oldest it hears and the
    /// compact it holds its keepers to; a Mac too old for any of them
    /// knows it must get a newer build, and an older realm, which tells
    /// none of them, takes this one in.
    func testARealmTellsItsTongueAndAMacTooOldKnowsIt() throws {
        let status = realm().status(now: 0)
        XCTAssertEqual(status.speech, Speech.current)
        XCTAssertEqual(status.oldestSpeech, Speech.oldestHeard)
        XCTAssertEqual(status.compact, Compact.edition)
        XCTAssertFalse(status.wantsNewerBuild, "A realm of this build takes this build")
        XCTAssertLessThanOrEqual(Speech.oldestHeard, Speech.current)
        XCTAssertEqual(status.aged(by: 5).compact, status.compact, "Kept as the status ages")

        func told(oldest: Int?, compact: Int?) -> RealmStatus {
            RealmStatus(name: "R", age: 1, watch: 1, seats: 4, freeSeats: 1, keepers: 0, online: 0, ready: 0, secondsLeft: 30,
                        isEnding: false, speech: oldest, oldestSpeech: oldest, compact: compact)
        }
        XCTAssertTrue(told(oldest: Speech.current + 1, compact: Compact.edition).wantsNewerBuild, "The realm no longer hears this Mac")
        XCTAssertTrue(told(oldest: Speech.current, compact: Compact.edition + 1).wantsNewerBuild, "A compact this build can't show")
        XCTAssertFalse(told(oldest: nil, compact: nil).wantsNewerBuild, "An older realm says nothing of either")

        // A realm of an earlier build sends none of the three: read as nil.
        var json = try XCTUnwrap(String(data: JSONEncoder().encode(told(oldest: nil, compact: nil)), encoding: .utf8))
        XCTAssertFalse(json.contains("speech"))
        json = json.replacingOccurrences(of: "}", with: ",\"speech\":9,\"oldestSpeech\":9,\"compact\":1}")
        let later = try JSONDecoder().decode(RealmStatus.self, from: Data(json.utf8))
        XCTAssertEqual(later.oldestSpeech, 9)
        XCTAssertTrue(later.wantsNewerBuild)
        XCTAssertTrue(RealmStatus.newerBuildNote.contains("github.com/ael-dev3/Nullmere/releases"))
        XCTAssertTrue(Speech.newestBuild.hasPrefix("https://github.com/ael-dev3/Nullmere/releases"))
    }

    /// A keeper who asks to be forgotten is: their name and identity leave
    /// the roll, a steward keeps their House under another name, and the
    /// name is free for anyone again. Their Mac, coming back, is a stranger.
    func testAKeeperWhoAsksToBeForgottenIs() throws {
        var realm = realm()
        let ama = try realm.arrive("ama-key", name: "Ama", now: 1)
        _ = try realm.arrive("bel-key", name: "Bel", now: 2)
        let house = try XCTUnwrap(ama.house)
        XCTAssertEqual(realm.world.houses[house].name, "Ama")

        XCTAssertNil(realm.forget(keeperNamed: "Nobody"))
        XCTAssertNil(realm.forget(keeperNamed: "  "))
        let gone = try XCTUnwrap(realm.forget(keeperNamed: " ama "), "Found by name, however written")
        XCTAssertEqual(gone.id, "ama-key")
        XCTAssertNil(realm.keeper("ama-key"))
        XCTAssertEqual(realm.keepers.map(\.name), ["Bel"])
        XCTAssertFalse(realm.world.houses[house].isPlayer, "A steward keeps the House")
        XCTAssertNotEqual(realm.world.houses[house].name, "Ama", "Under another name")
        XCTAssertEqual(Set(realm.world.houses.map { $0.name.lowercased() }).count, realm.world.houses.count, "Every House its own name")
        XCTAssertTrue(realm.world.chronicle.contains {
            $0.text == "\(realm.world.houses[house].title) passes to the stewards, its keeper gone from the realm for good."
        })
        XCTAssertEqual(realm.status(now: 3).freeSeats, 3, "The seat is open again")

        // The Mac that was Ama's comes back by its identity: a stranger.
        XCTAssertThrowsError(try realm.arrive("ama-key", name: nil, now: 4)) { error in
            XCTAssertEqual(error as? RealmError, .nameInvalid)
        }
        // And the name is anyone's.
        let again = try realm.arrive("another-key", name: "Ama", now: 5)
        XCTAssertEqual(again.name, "Ama")
        XCTAssertNotNil(again.house)
    }
}
