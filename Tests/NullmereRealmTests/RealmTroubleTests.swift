import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import NullmereTestSupport
import XCTest
@testable import NullmereRealm

/// What a keeper is told when the realm can't be reached: plain words for
/// every kind of trouble, never an error's domain, code and user info.
@MainActor
final class RealmTroubleTests: XCTestCase {
    func testEachTroubleIsSaidPlainly() {
        let said: [(any Error, String)] = [
            (SpacetimeError("The realm isn't open yet."), "The realm isn't open yet."),
            (URLError(.notConnectedToInternet), "This Mac isn't connected to the internet."),
            (URLError(.timedOut), "The realm's server didn't answer in time."),
            (URLError(.cannotFindHost), "The realm's server can't be found."),
            (URLError(.dnsLookupFailed), "The realm's server can't be found."),
            (URLError(.serverCertificateUntrusted), "The realm's server couldn't be reached safely."),
            (URLError(.secureConnectionFailed), "The realm's server couldn't be reached safely."),
            (URLError(.cannotConnectToHost), "The realm's server can't be reached."),
            (URLError(.networkConnectionLost), "The realm's server can't be reached."),
            (NSError(domain: "NSOSStatusErrorDomain", code: -25308),
             "This Mac's keychain wouldn't keep the realm's key. Unlock the keychain, then try again."),
            (NSError(domain: "Elsewhere", code: 7), "The realm can't be reached."),
        ]
        for (error, words) in said {
            XCTAssertEqual(RealmTrouble.words(for: error), words, "\(error)")
        }
        let garbled = Result { try JSONDecoder().decode(SpacetimeCredentials.self, from: Data("{}".utf8)) }
        if case .failure(let error) = garbled {
            XCTAssertTrue(RealmTrouble.words(for: error).hasPrefix("The realm answered in words"))
        } else {
            XCTFail("Garbled credentials don't decode")
        }
    }

    /// The link, over SpacetimeDB's HTTP API, to a server that doesn't answer.
    func testAServerThatDoesntAnswerIsSaidPlainlyByTheLink() async throws {
        let server = StubHTTP.serve { _ in throw URLError(.cannotConnectToHost) }
        let transport = try XCTUnwrap(SpacetimeHTTP(address: server.address.appendingPathComponent("nullmere"), session: server.session))
        let told = try await firstTrouble(NetworkRealmLink(transport: transport, credentials: MemoryStore(), pollInterval: 0.05))
        XCTAssertEqual(told, "The realm's server can't be reached.")
    }

    /// A keychain that won't keep the key the realm's server gave.
    func testAKeychainThatWontKeepTheKeyIsSaidPlainly() async throws {
        let server = StubHTTP.serve { _ in StubHTTP.Answer(text: #"{"identity":"c200abc","token":"t0ken"}"#) }
        let transport = try XCTUnwrap(SpacetimeHTTP(address: server.address.appendingPathComponent("nullmere"), session: server.session))
        let told = try await firstTrouble(NetworkRealmLink(transport: transport, credentials: LockedStore(), pollInterval: 0.05))
        XCTAssertEqual(told, "This Mac's keychain wouldn't keep the realm's key. Unlock the keychain, then try again.")
    }

    private func firstTrouble(_ link: NetworkRealmLink) async throws -> String {
        let listener = Listener()
        listener.listen(to: link)
        link.connect()
        defer { link.leave() }
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            for event in listener.events { if case .unreachable(let words) = event { return words } }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        throw SpacetimeError("The link told of no trouble")
    }
}

/// A keychain that is locked: nothing kept, nothing keeps.
private final class LockedStore: IdentityStore, @unchecked Sendable {
    func load() -> String? { nil }
    func save(_ identity: String) throws { throw NSError(domain: "NSOSStatusErrorDomain", code: -25308) }
}
