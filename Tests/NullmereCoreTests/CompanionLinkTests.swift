import Foundation
import XCTest
@testable import NullmereCore

/// A keeper's phone linked to them by a code their Mac shows: the realm
/// keeps only its digest and links whoever brings it within ten minutes
/// and once; four devices at most speak for a keeper, each lets itself go
/// or the keeper lets them all go, and a keeper taken to another Mac by
/// their words leaves every device linked to the old one behind. A linked
/// device speaks for its keeper, and never for another.
final class CompanionLinkTests: XCTestCase {
    private func realm() throws -> RealmState {
        var realm = RealmState(name: "Linked", seed: "linked", seats: 4, now: 0)
        try realm.arrive("mac-of-ama", name: "Ama", now: 0)
        try realm.arrive("mac-of-bo", name: "Bo", now: 0)
        return realm
    }

    /// Codes are twelve of thirty-two letters and figures, none that could
    /// be taken for another, shown in three fours and read back however
    /// typed.
    func testCodesAreMadeShownAndReadBack() {
        var generator = SystemRandomNumberGenerator()
        let codes = (0..<200).map { _ in LinkCode.make(using: &generator) }
        XCTAssertTrue(codes.allSatisfy { $0.count == LinkCode.length && $0.allSatisfy(LinkCode.alphabet.contains) })
        XCTAssertEqual(Set(codes).count, codes.count, "Sixty bits: no two alike")
        XCTAssertEqual(LinkCode.alphabet.count, 32)
        XCTAssertFalse(LinkCode.alphabet.contains { "01OI".contains($0) })
        XCTAssertEqual(LinkCode.shown("ABCD2345EFGH"), "ABCD-2345-EFGH")
        XCTAssertEqual(LinkCode.shown("SHORT"), "SHORT", "Only a code is shown in fours")
        XCTAssertEqual(LinkCode.read("abcd-2345-efgh"), "ABCD2345EFGH")
        XCTAssertEqual(LinkCode.read(" AbC d23 45E fgh "), "ABCD2345EFGH")
        XCTAssertNil(LinkCode.read("ABCD2345EFG"), "Eleven")
        XCTAssertNil(LinkCode.read("ABCD2345EFG0"), "A figure of none of the code's")
        XCTAssertNil(LinkCode.read("ABCD2345EFGO"), "Nor a letter")
        XCTAssertEqual(LinkCode.digest(of: "ABCD2345EFGH").count, 64)
        XCTAssertNotEqual(LinkCode.digest(of: "ABCD2345EFGH"), LinkCode.digest(of: "ABCD2345EFGJ"))
    }

    /// The phone brings the code the Mac showed and speaks for its keeper
    /// from then on; the offer is spent, and the phone speaks for no other.
    func testAPhoneBringingTheCodeSpeaksForItsKeeper() throws {
        var realm = try realm()
        let code = "KQ7MX4RT2PZZ"
        try realm.offerLink("mac-of-ama", digest: LinkCode.digest(of: code), now: 10)
        XCTAssertEqual(realm.keeper("mac-of-ama")?.linkOffer?.until, 10 + RealmState.linkLasts)
        XCTAssertNil(realm.keeperID(speakingFor: "phone-of-ama"))
        let linked = try realm.takeLink("phone-of-ama", code: "kq7m-x4rt-2pzz", now: 20)
        XCTAssertEqual(linked.id, "mac-of-ama")
        XCTAssertEqual(realm.keeperID(speakingFor: "phone-of-ama"), "mac-of-ama")
        XCTAssertEqual(realm.keeperID(speakingFor: "mac-of-ama"), "mac-of-ama")
        XCTAssertEqual(realm.keeperID(speakingFor: "mac-of-bo"), "mac-of-bo")
        XCTAssertNil(realm.keeper("mac-of-ama")?.linkOffer, "Spent")
        XCTAssertEqual(realm.companionsByKeeper.map(\.companion), ["phone-of-ama"])
        XCTAssertEqual(realm.companionsByKeeper.map(\.keeper), ["mac-of-ama"])
        // Spent: the same code links no one else.
        XCTAssertThrowsError(try realm.takeLink("thief", code: code, now: 30))
        XCTAssertNil(realm.keeperID(speakingFor: "thief"))
        // A device that speaks for a keeper takes no other link, nor does a Mac.
        try realm.offerLink("mac-of-bo", digest: LinkCode.digest(of: "BBBBCCCCDDDD"), now: 40)
        XCTAssertThrowsError(try realm.takeLink("phone-of-ama", code: "BBBBCCCCDDDD", now: 41))
        XCTAssertThrowsError(try realm.takeLink("mac-of-ama", code: "BBBBCCCCDDDD", now: 41))
        XCTAssertEqual(try realm.takeLink("phone-of-bo", code: "BBBBCCCCDDDD", now: 42).id, "mac-of-bo")
        // Kept as the realm keeps itself.
        let data = try JSONEncoder().encode(realm)
        XCTAssertEqual(try JSONDecoder().decode(RealmState.self, from: data), realm)
    }

    /// A code lapses after ten minutes; a new offer lets the last go; a
    /// keeper unknown to the realm offers none, nor one whose digest can't
    /// be read; and what isn't a code is said to be none.
    func testOffersLapseAndGiveWayToTheNext() throws {
        var realm = try realm()
        try realm.offerLink("mac-of-ama", digest: LinkCode.digest(of: "AAAA22222222"), now: 0)
        XCTAssertThrowsError(try realm.takeLink("late", code: "AAAA22222222", now: RealmState.linkLasts + 1))
        try realm.offerLink("mac-of-ama", digest: LinkCode.digest(of: "AAAA22222222"), now: 1_000)
        try realm.offerLink("mac-of-ama", digest: LinkCode.digest(of: "AAAA33333333"), now: 1_001)
        XCTAssertThrowsError(try realm.takeLink("first", code: "AAAA22222222", now: 1_002), "Given way to the next")
        XCTAssertEqual(try realm.takeLink("second", code: "AAAA33333333", now: 1_003).id, "mac-of-ama")
        XCTAssertThrowsError(try realm.offerLink("stranger", digest: LinkCode.digest(of: "AAAA44444444"), now: 0)) { error in
            XCTAssertEqual(error as? RealmError, .unknownKeeper)
        }
        XCTAssertThrowsError(try realm.offerLink("mac-of-ama", digest: "not a digest", now: 0))
        XCTAssertThrowsError(try realm.takeLink("x", code: "not even a code", now: 0)) { error in
            XCTAssertTrue((error as? RealmError)?.description.contains("twelve letters and figures") == true, "\(error)")
        }
    }

    /// Four devices may speak for a keeper; one lets itself go, the others
    /// still speaking; and the keeper lets them all go when they ask.
    func testFourDevicesAtMostEachLetGoOrAll() throws {
        var realm = try realm()
        for phone in 0..<RealmState.mostCompanions {
            let code = "PHXNE234567\(phone + 2)"
            try realm.offerLink("mac-of-ama", digest: LinkCode.digest(of: code), now: Double(phone))
            try realm.takeLink("device-\(phone)", code: code, now: Double(phone))
        }
        try realm.offerLink("mac-of-ama", digest: LinkCode.digest(of: "PHXNE2345679"), now: 10)
        XCTAssertThrowsError(try realm.takeLink("device-9", code: "PHXNE2345679", now: 10)) { error in
            XCTAssertTrue((error as? RealmError)?.description.contains("Four devices") == true)
        }
        XCTAssertEqual(realm.keeper("mac-of-ama")?.companions?.count, RealmState.mostCompanions)
        XCTAssertTrue(realm.unlink(companion: "device-1"))
        XCTAssertFalse(realm.unlink(companion: "device-1"), "Gone already")
        XCTAssertFalse(realm.unlink(companion: "mac-of-bo"), "A keeper is no one's companion")
        XCTAssertNil(realm.keeperID(speakingFor: "device-1"))
        XCTAssertEqual(realm.keeperID(speakingFor: "device-2"), "mac-of-ama", "The others still speak")
        try realm.unlinkCompanions("mac-of-ama")
        XCTAssertNil(realm.keeper("mac-of-ama")?.companions)
        XCTAssertNil(realm.keeper("mac-of-ama")?.linkOffer, "Nor any offer still waiting")
        XCTAssertNil(realm.keeperID(speakingFor: "device-0"))
        XCTAssertTrue(realm.companionsByKeeper.isEmpty)
        XCTAssertThrowsError(try realm.unlinkCompanions("stranger"))
        // The last companion gone, none are kept at all.
        try realm.offerLink("mac-of-ama", digest: LinkCode.digest(of: "LASTQNE22222"), now: 20)
        try realm.takeLink("device-0", code: "LASTQNE22222", now: 20)
        XCTAssertTrue(realm.unlink(companion: "device-0"))
        XCTAssertNil(realm.keeper("mac-of-ama")?.companions)
    }

    /// A keeper taken to another Mac by their words leaves every device
    /// linked to the old one behind, and any link it offered; a companion
    /// can't take a keeper up by words, as it already speaks for one.
    func testWordsTakenToAnotherMacLeaveTheOldDevicesBehind() throws {
        var realm = try realm()
        let proof = String(repeating: "ab", count: 32)
        try realm.seal("mac-of-ama", proof: proof)
        try realm.offerLink("mac-of-ama", digest: LinkCode.digest(of: "PHONE2222222".replacingOccurrences(of: "O", with: "Q")), now: 0)
        try realm.takeLink("phone-of-ama", code: "PHQNE2222222", now: 1)
        try realm.offerLink("mac-of-ama", digest: LinkCode.digest(of: "WAXTXNG22222"), now: 2)
        XCTAssertThrowsError(try realm.reclaim("phone-of-ama", proof: proof, now: 3)) { error in
            XCTAssertEqual(error as? RealmError, .keepsAnother)
        }
        let moved = try realm.reclaim("new-mac-of-ama", proof: proof, now: 4)
        XCTAssertEqual(moved.name, "Ama")
        XCTAssertNil(realm.keeper("new-mac-of-ama")?.companions)
        XCTAssertNil(realm.keeper("new-mac-of-ama")?.linkOffer)
        XCTAssertNil(realm.keeperID(speakingFor: "phone-of-ama"), "The phone of the old Mac speaks for no one")
        XCTAssertThrowsError(try realm.takeLink("someone", code: "WAXTXNG22222", now: 5), "The old Mac's offer lapsed with it")
    }
}
