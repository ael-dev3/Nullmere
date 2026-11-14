import Foundation
@testable import NullmereLive
import NullmereRealm
import XCTest

/// The client's lists of the realm's tables against the module's own
/// source (realm/src), so a column added, moved or renamed there can't go
/// unnoticed here: a transaction's rows come as bare values in the
/// module's order.
final class LiveSchemaTests: XCTestCase {
    /// The module's source, where the repository is at hand.
    private func source(_ name: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard let text = try? String(contentsOf: root.appendingPathComponent("realm/src/\(name)"), encoding: .utf8) else {
            throw XCTSkip("realm/src is not beside the tests here")
        }
        return text
    }

    /// Each table the module declares in a source file: its accessor, its
    /// struct, its columns in order and its key.
    private func declared(in text: String) -> [(table: String, type: String, columns: [String], key: String)] {
        var tables: [(String, String, [String], String)] = []
        let lines = text.components(separatedBy: "\n")
        var index = 0
        while index < lines.count {
            let line = lines[index]
            guard let at = line.range(of: "table(accessor = ") else {
                index += 1
                continue
            }
            let name = String(line[at.upperBound...].prefix { $0.isLetter || $0 == "_" })
            var type = "", columns: [String] = [], key = "", keyed = false
            index += 1
            while index < lines.count, !lines[index].hasPrefix("}") {
                let field = lines[index].trimmingCharacters(in: .whitespaces)
                if field.hasPrefix("pub struct ") {
                    type = String(field.dropFirst("pub struct ".count).prefix { $0.isLetter })
                } else if field == "#[primary_key]" {
                    keyed = true
                } else if field.hasPrefix("pub "), let colon = field.firstIndex(of: ":") {
                    let column = String(field[field.index(field.startIndex, offsetBy: 4)..<colon])
                    columns.append(column)
                    if keyed {
                        key = column
                        keyed = false
                    }
                }
                index += 1
            }
            tables.append((name, type, columns, key))
        }
        return tables
    }

    func testEveryTableIsListedAsTheModuleDeclaresIt() throws {
        let rows = declared(in: try source("rows.rs"))
        XCTAssertGreaterThanOrEqual(rows.count, 15, "The module's tables were read")
        let byType = Dictionary(rows.map { ($0.type, $0) }, uniquingKeysWith: { first, _ in first })
        let module = try source("module.rs")

        var checked = 0
        for (name, listed) in LiveSchema.tables {
            let declared: (table: String, type: String, columns: [String], key: String)
            if let table = LiveSchema.views[name] {
                // A view of the caller's own rows of a table: the module
                // declares it, public, returning that table's rows.
                XCTAssertTrue(module.contains("#[view(accessor = \(name), public)]"), "\(name) is a public view of the module's")
                declared = try XCTUnwrap(rows.first { $0.table == table }, "\(name) shows rows of \(table)")
                let returns = module.range(of: "fn \(name)(ctx: &ViewContext) -> ").map { module[$0.upperBound...].prefix { $0 != "{" } } ?? ""
                XCTAssertTrue(returns.contains("<\(declared.type)>"), "\(name) returns \(declared.type) rows: \(returns)")
            } else {
                declared = try XCTUnwrap(rows.first { $0.table == name }, "\(name) is a table of the module's")
                XCTAssertTrue(try source("rows.rs").contains("table(accessor = \(name), public)"), "\(name) is public: a client may read it")
            }
            XCTAssertEqual(listed.columns, declared.columns, "\(name)'s columns, in the module's order")
            XCTAssertEqual(listed.key, declared.key, "\(name)'s key")
            checked += 1
        }
        XCTAssertEqual(checked, 17)
        XCTAssertNotNil(byType["Player"])

        // What is a player's alone stays closed: read only through a view.
        for table in ["pace", "building", "job", "stock", "troop", "squad", "haul"] {
            XCTAssertNil(LiveSchema.tables[table], "\(table) is not a client's to read")
            XCTAssertTrue(try source("rows.rs").contains("table(accessor = \(table))"), "\(table) is private in the module")
        }
        XCTAssertEqual(LiveSchema.queries.count, 17)
        XCTAssertTrue(LiveSchema.queries.contains("SELECT * FROM my_stock"))
    }

    /// Every reducer the client calls is one the module has, with as many
    /// arguments.
    func testEveryReducerTheClientCallsIsTheModules() throws {
        let module = try source("module.rs")
        for (reducer, arguments) in [("join", 1), ("build", 1), ("upgrade", 1), ("train", 3), ("send", 4), ("recall", 1)] {
            let signature = try XCTUnwrap(module.range(of: "pub fn \(reducer)(ctx: &ReducerContext"), "\(reducer) is a reducer")
            let rest = module[signature.upperBound...].prefix { $0 != ")" }
            XCTAssertEqual(rest.filter { $0 == ":" }.count, arguments, "\(reducer) takes \(arguments): \(rest)")
        }
    }
}
