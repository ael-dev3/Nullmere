import Foundation
import NullmereCore
import XCTest
@testable import NullmereCompanionCore

/// The link a keeper's Mac shows, its QR code's or typed: read back whole,
/// and taken only to a realm over HTTPS, or one on this very machine.
final class CompanionInviteTests: XCTestCase {
    func testALinkIsMadeAndReadBack() throws {
        let realm = try XCTUnwrap(URL(string: "https://maincloud.spacetimedb.com/nullmere"))
        let invite = try XCTUnwrap(CompanionInvite(realm: realm, code: "abcd-2345-efgh"))
        XCTAssertEqual(invite.code, "ABCD2345EFGH", "Read as the realm reads it")
        XCTAssertEqual(invite.url.scheme, "nullmere")
        XCTAssertEqual(CompanionInvite(url: invite.url), invite, "Read back whole")
        let typed = try XCTUnwrap(CompanionInvite(realm: "  maincloud.spacetimedb.com/nullmere ", code: "ABCD 2345 EFGH"))
        XCTAssertEqual(typed.realm.absoluteString, "https://maincloud.spacetimedb.com/nullmere", "An address typed bare is HTTPS")
        XCTAssertEqual(typed, invite)
        // Its realm written out in full, as a script that sends the phone by
        // another way to the same realm writes it: read the same.
        let written = try XCTUnwrap(URL(string: "nullmere://link?realm=http%3A%2F%2F127.0.0.1%3A46249%2Fnullmere&code=ABCD2345EFGH"))
        XCTAssertEqual(CompanionInvite(url: written)?.realm.absoluteString, "http://127.0.0.1:46249/nullmere")
        XCTAssertEqual(CompanionInvite(url: written)?.code, "ABCD2345EFGH")
    }

    func testOnlyARealmOverHTTPSOrOnThisMachineIsTaken() throws {
        func url(_ text: String) throws -> URL { try XCTUnwrap(URL(string: text)) }
        XCTAssertTrue(CompanionInvite.isAcceptable(try url("https://realm.example/nullmere")))
        XCTAssertTrue(CompanionInvite.isAcceptable(try url("http://127.0.0.1:3000/nullmere")), "A realm raised to test, here")
        XCTAssertTrue(CompanionInvite.isAcceptable(try url("http://localhost:3000/nullmere")))
        XCTAssertFalse(CompanionInvite.isAcceptable(try url("http://realm.example/nullmere")), "Not in the clear across the network")
        XCTAssertFalse(CompanionInvite.isAcceptable(try url("https://realm.example")), "A database is named")
        XCTAssertFalse(CompanionInvite.isAcceptable(try url("https://realm.example/")))
        XCTAssertFalse(CompanionInvite.isAcceptable(try url("ftp://realm.example/nullmere")))
        XCTAssertNil(CompanionInvite(realm: try url("http://realm.example/nullmere"), code: "ABCD2345EFGH"))
        XCTAssertNil(CompanionInvite(realm: try url("https://realm.example/nullmere"), code: "ABCD2345EFG"), "Not a code")
        XCTAssertNil(CompanionInvite(realm: "", code: "ABCD2345EFGH"))
    }

    func testOnlyTheMacsLinkIsRead() throws {
        func url(_ text: String) throws -> URL { try XCTUnwrap(URL(string: text)) }
        XCTAssertNil(CompanionInvite(url: try url("https://link?realm=https://r.example/n&code=ABCD2345EFGH")), "Another scheme")
        XCTAssertNil(CompanionInvite(url: try url("nullmere://other?realm=https://r.example/n&code=ABCD2345EFGH")), "Another link")
        XCTAssertNil(CompanionInvite(url: try url("nullmere://link?code=ABCD2345EFGH")), "No realm")
        XCTAssertNil(CompanionInvite(url: try url("nullmere://link?realm=https://r.example/n")), "No code")
        XCTAssertNil(CompanionInvite(url: try url("nullmere://link?realm=http://r.example/n&code=ABCD2345EFGH")), "A realm in the clear")
        XCTAssertNotNil(CompanionInvite(url: try url("nullmere://link?realm=https://r.example/n&code=abcd-2345-efgh")))
    }
}
