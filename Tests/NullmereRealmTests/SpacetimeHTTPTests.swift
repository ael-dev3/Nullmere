import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import NullmereTestSupport
import XCTest
@testable import NullmereRealm

/// SpacetimeDB's HTTP API as the realm speaks it, against a server in
/// memory: the paths and bodies sent, the answers read, and each way a
/// server can refuse said in plain words.
final class SpacetimeHTTPTests: XCTestCase {
    private func transport(_ handler: @escaping StubHTTP.Handler) -> (SpacetimeHTTP, () -> [StubHTTP.Received]) {
        let server = StubHTTP.serve(handler)
        return (SpacetimeHTTP(address: server.address.appendingPathComponent("nullmere"), session: server.session)!, { server.requests })
    }

    func testAnAddressNamesTheServerAndTheDatabase() throws {
        let http = try XCTUnwrap(SpacetimeHTTP(address: URL(string: "http://127.0.0.1:3000/nullmere")!))
        XCTAssertEqual(http.server.absoluteString, "http://127.0.0.1:3000")
        XCTAssertEqual(http.database, "nullmere")
        XCTAssertNil(SpacetimeHTTP(address: URL(string: "https://realm.test")!), "No database named")
    }

    func testANewIdentity() async throws {
        let (http, requests) = transport { _ in
            StubHTTP.Answer(text: #"{"identity":"c200abc","token":"t0ken"}"#)
        }
        let credentials = try await http.createIdentity()
        XCTAssertEqual(credentials, SpacetimeCredentials(identity: "c200abc", token: "t0ken"))
        let sent = try XCTUnwrap(requests().first)
        XCTAssertEqual(sent.method, "POST")
        XCTAssertEqual(sent.url.path, "/v1/identity")
    }

    func testAReducerCallCarriesItsArgumentsAndTheKey() async throws {
        let (http, requests) = transport { _ in StubHTTP.Answer() }
        try await http.call("order", [.string("it's"), .bool(true), .integer(7), .strings(["a", "b"]), .integers([1, 2])], token: "t0ken")
        let sent = try XCTUnwrap(requests().first)
        XCTAssertEqual(sent.method, "POST")
        XCTAssertEqual(sent.url.path, "/v1/database/nullmere/call/order")
        XCTAssertEqual(sent.headers["Authorization"], "Bearer t0ken")
        XCTAssertEqual(sent.headers["Content-Type"], "application/json")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: sent.body) as? [Any])
        XCTAssertEqual(body.count, 5)
        XCTAssertEqual(body[0] as? String, "it's")
        XCTAssertEqual(body[1] as? Bool, true)
        XCTAssertEqual((body[2] as? NSNumber)?.intValue, 7)
        XCTAssertEqual(body[3] as? [String], ["a", "b"])
        XCTAssertEqual((body[4] as? [NSNumber])?.map(\.intValue), [1, 2])
    }

    func testAQueryReadsItsRowsAndTheServersClock() async throws {
        let (http, requests) = transport { _ in
            StubHTTP.Answer(headers: ["Date": "Mon, 26 Oct 2026 22:04:54 GMT"],
                            text: #"[{"schema":{},"rows":[[1,"Ama",true,null],[2,"Bel",false,[1,2]]]}]"#)
        }
        let (rows, date) = try await http.queryDated("SELECT * FROM keeper WHERE name = \(sqlString("O'Dell"))", token: "t0ken")
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0][0].number, 1)
        XCTAssertEqual(rows[0][1].string, "Ama")
        XCTAssertEqual(rows[0][2], .bool(true))
        XCTAssertEqual(rows[0][3], .null)
        XCTAssertEqual(rows[1][3], .array([.number(1), .number(2)]))
        XCTAssertNil(rows[0][1].number)
        XCTAssertNil(rows[0][0].string)
        XCTAssertEqual(date, Date(timeIntervalSince1970: 1_793_052_294))
        let sent = try XCTUnwrap(requests().first)
        XCTAssertEqual(sent.url.path, "/v1/database/nullmere/sql")
        XCTAssertEqual(sent.text, "SELECT * FROM keeper WHERE name = 'O''Dell'")
        XCTAssertEqual(sent.headers["Authorization"], "Bearer t0ken")

        let plain = try await http.query("SELECT 1", token: "t0ken")
        XCTAssertEqual(plain.count, 2)
    }

    func testAnEmptyAnswerHasNoRowsAndAnOddDateIsNone() async throws {
        let (http, _) = transport { _ in StubHTTP.Answer(headers: ["Date": "yesterday"], text: "[]") }
        let (rows, date) = try await http.queryDated("SELECT 1", token: "t0ken")
        XCTAssertEqual(rows, [])
        XCTAssertNil(date)
    }

    func testRefusalsAreSaidPlainly() async throws {
        func refusal(_ answer: StubHTTP.Answer) async -> SpacetimeError? {
            let (http, _) = transport { _ in answer }
            do {
                try await http.call("order", [], token: "t0ken")
                return nil
            } catch {
                return error as? SpacetimeError
            }
        }
        let missing = await refusal(StubHTTP.Answer(status: 404))
        XCTAssertEqual(missing?.description, "The realm isn't open yet.")
        let gone = await refusal(StubHTTP.Answer(status: 404, text: "`nullmere` not found"))
        XCTAssertEqual(gone?.description, "The realm isn't open yet.")
        // A request the realm's module doesn't have is no realm unopened.
        let unknown = await refusal(StubHTTP.Answer(status: 404, text: "No such procedure"))
        XCTAssertEqual(unknown?.description, SpacetimeError.unknownRequest)
        XCTAssertEqual(unknown.map { RealmTrouble.words(for: $0) }, SpacetimeError.unknownRequest)
        let forgotten = await refusal(StubHTTP.Answer(status: 401))
        XCTAssertEqual(forgotten, .unauthorized)
        XCTAssertTrue(forgotten?.isUnauthorized == true)
        // The server's own words are kept for whoever runs the realm; the
        // keeper is told plainly.
        let said = await refusal(StubHTTP.Answer(status: 530, text: "  The reducer panicked: no such keeper\n"))
        XCTAssertEqual(said?.description, "The reducer panicked: no such keeper")
        XCTAssertEqual(said?.status, 530)
        XCTAssertEqual(said.map { RealmTrouble.words(for: $0) }, "The realm couldn't answer just now.")
        XCTAssertFalse(said?.isUnauthorized ?? true)
        let silent = await refusal(StubHTTP.Answer(status: 503))
        XCTAssertEqual(silent?.description, "The realm answered 503.")
        XCTAssertEqual(silent.map { RealmTrouble.words(for: $0) }, "The realm couldn't answer just now.")
    }

    func testAServerOutOfReachIsAnError() async {
        let (http, _) = transport { _ in throw URLError(.cannotConnectToHost) }
        do {
            _ = try await http.createIdentity()
            XCTFail("No identity from a server out of reach")
        } catch {
            XCTAssertNotNil(error as? URLError)
        }
    }
}
