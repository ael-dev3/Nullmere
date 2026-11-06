import Foundation
import XCTest
@testable import NullmereRealm

/// The rows a subscription watches, kept from SpacetimeDB's own messages:
/// these are their shapes as a SpacetimeDB 2 server sends them.
final class SubscriptionMirrorTests: XCTestCase {
    /// A message's table, its rows each the text of its JSON.
    private func table(_ name: String, deletes: [String] = [], inserts: [String]) -> [String: Any] {
        ["table_id": 4101, "table_name": name, "num_rows": deletes.count + inserts.count,
         "updates": [["deletes": deletes, "inserts": inserts]]]
    }

    private func text(_ object: [String: Any]) -> String {
        String(decoding: try! JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    }

    private func initial(_ tables: [[String: Any]]) -> String {
        text(["InitialSubscription": ["database_update": ["tables": tables], "request_id": 1,
                                      "total_host_execution_duration": ["__time_duration_micros__": 520]]])
    }

    private func light(_ tables: [[String: Any]]) -> String {
        text(["TransactionUpdateLight": ["request_id": 0, "update": ["tables": tables]]])
    }

    func testTheFirstRowsComeByNameAndATransactionsInOrder() {
        let mirror = SubscriptionMirror()
        XCTAssertFalse(mirror.isLive)
        // The first rows, as objects by column: the status, and the keeper's view.
        XCTAssertTrue(mirror.apply(initial([
            table("status", inserts: [#"{"id":0,"version":80,"status":"{\"watch\":2}"}"#]),
            table("my_view", inserts: [#"{"keeper":"c200","version":80,"view":"head:80","events":"[]"}"#]),
        ])))
        XCTAssertTrue(mirror.isLive)
        XCTAssertEqual(mirror.connection, 1)
        XCTAssertEqual(mirror.row(of: "status", key: "0"), [.number(0), .number(80), .string(#"{"watch":2}"#)])
        XCTAssertEqual(mirror.row(of: "my_view", key: "c200")?[1], .number(80))

        // A transaction's rows, as arrays in the columns' order: the old
        // status let go and the new one written; a part of the view come.
        XCTAssertTrue(mirror.apply(light([
            table("status", deletes: [#"[0,80,"{\"watch\":2}"]"#], inserts: [#"[0,81,"{\"watch\":3}"]"#]),
            table("my_view_parts", inserts: [#"["c200/head","c200","head",81,"{}"]"#]),
        ])))
        XCTAssertEqual(mirror.rows(of: "status"), [[.number(0), .number(81), .string(#"{"watch":3}"#)]])
        XCTAssertEqual(mirror.row(of: "my_view_parts", key: "c200/head")?[2], .string("head"))
        XCTAssertEqual(mirror.updates, 2)

        // A row let go is gone; a row of a table not watched is no row.
        mirror.apply(light([table("my_view_parts", deletes: [#"["c200/head","c200","head",81,"{}"]"#], inserts: []),
                            table("request", inserts: [#"[1,"c200","order","n","{}"]"#])]))
        XCTAssertTrue(mirror.rows(of: "my_view_parts").isEmpty)
        XCTAssertTrue(mirror.rows(of: "request").isEmpty)
        XCTAssertEqual(Set(mirror.snapshot().keys), ["status", "my_view", "my_view_parts"])
    }

    /// The caller's own transaction comes whole, committed or not; and
    /// what isn't a subscription's word changes nothing.
    func testACommittedTransactionIsTakenAndAFailedOneIsNot() {
        let mirror = SubscriptionMirror()
        mirror.apply(initial([table("my_replies", inserts: [])]))
        let committed = text(["TransactionUpdate": ["status": ["Committed": ["tables": [
            table("my_replies", inserts: [#"["n1","c200","{\"ok\":true}"]"#]),
        ]]], "timestamp": ["__timestamp_micros_since_unix_epoch__": 1]]])
        XCTAssertTrue(mirror.apply(committed))
        XCTAssertEqual(mirror.row(of: "my_replies", key: "n1")?[2], .string(#"{"ok":true}"#))

        let failed = text(["TransactionUpdate": ["status": ["Failed": "No such reducer."]]])
        XCTAssertFalse(mirror.apply(failed))
        XCTAssertEqual(mirror.rows(of: "my_replies").count, 1)
        XCTAssertFalse(mirror.apply(text(["TransactionUpdate": ["timestamp": 1]])))
        XCTAssertFalse(mirror.apply(#"{"IdentityToken":{"token":"t"}}"#))
        XCTAssertFalse(mirror.apply("not JSON"))
        XCTAssertFalse(mirror.apply("[]"))
        XCTAssertEqual(mirror.updates, 2)
    }

    /// The line dropped, the rows stand for nothing; the subscription taken
    /// again brings them afresh, and those gone meanwhile are gone.
    func testALostLineThenTheRowsAfresh() {
        let mirror = SubscriptionMirror()
        mirror.apply(initial([table("my_replies", inserts: [#"{"nonce":"n1","keeper":"c200","payload":"{}"}"#])]))
        mirror.lost()
        XCTAssertFalse(mirror.isLive)
        XCTAssertEqual(mirror.rows(of: "my_replies").count, 1, "Kept, though no longer the server's")
        mirror.apply(initial([table("my_replies", inserts: [#"{"nonce":"n2","keeper":"c200","payload":"{}"}"#])]))
        XCTAssertTrue(mirror.isLive)
        XCTAssertEqual(mirror.connection, 2)
        XCTAssertNil(mirror.row(of: "my_replies", key: "n1"))
        XCTAssertNotNil(mirror.row(of: "my_replies", key: "n2"))
    }

    /// Rows as JSON itself rather than its text, a column a row lacks, and
    /// values of every kind, are read as they are.
    func testRowsOfEveryShape() {
        let table = SubscriptionMirror.Table(columns: ["a", "b", "c"], key: "a")
        XCTAssertEqual(SubscriptionMirror.row(["x", 2, true] as [Any], of: table), [.string("x"), .number(2), .bool(true)])
        XCTAssertEqual(SubscriptionMirror.row(["a": "x", "c": NSNull()] as [String: Any], of: table), [.string("x"), .null, .null])
        XCTAssertEqual(SubscriptionMirror.row(#"[[1,{"k":"v"}],2.5]"#, of: table),
                       [.array([.number(1), .object(["k": .string("v")])]), .number(2.5)])
        XCTAssertNil(SubscriptionMirror.row(#""just text""#, of: table))
        XCTAssertNil(SubscriptionMirror.row("not JSON", of: table))
        XCTAssertNil(SubscriptionMirror.row(7, of: table))
        XCTAssertEqual(SubscriptionMirror.key(.number(81)), "81")
        XCTAssertEqual(SubscriptionMirror.key(.number(2.5)), "2.5")
        XCTAssertEqual(SubscriptionMirror.key(.bool(true)), "true")
        XCTAssertEqual(SubscriptionMirror.key(.null), "")
    }
}
