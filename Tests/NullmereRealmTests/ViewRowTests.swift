import Foundation
import XCTest
@testable import NullmereRealm

/// A keeper's view as its row names it: their own parts with the version
/// each was written at, the list of pages told alike they take, and the
/// pages of that list they haven't.
final class ViewRowTests: XCTestCase {
    private let list = ViewRow.list(of: ["~head#aaaa", "~houses.0#bbbb", "~map#cccc", "~sites.0#dddd", "~units.0#eeee"])

    func testARowReadsAndWritesAsItIsKept() throws {
        let row = ViewRow(own: ["head": 12, "units.0": 11], told: list.name, without: ["sites.0"])
        XCTAssertEqual(row.text, "-sites.0:0,head:12,units.0:11,\(list.name):0")
        XCTAssertEqual(ViewRow(row.text), row)
        XCTAssertTrue(ViewRow.isList(list.name))
        XCTAssertTrue(AlikePages.isAlike(list.name), "The list a page told alike as any")
        XCTAssertEqual(AlikePages.page(of: list.name), "", "and no page of the view")
        XCTAssertEqual(list.text, "~head#aaaa,~houses.0#bbbb,~map#cccc,~sites.0#dddd,~units.0#eeee")
        XCTAssertEqual(ViewRow.list(of: list.text.split(separator: ",").map(String.init).reversed()).name, list.name, "In any order the same list")

        // A row naming every part itself, as rows did before there was a list.
        let whole = try XCTUnwrap(ViewRow("head:12,map:3,~houses.0#bbbb:0"))
        XCTAssertNil(whole.told)
        XCTAssertEqual(whole.parts(told: nil), ["head": 12, "map": 3, "~houses.0#bbbb": 0])
        XCTAssertEqual(whole.text, "head:12,map:3,~houses.0#bbbb:0")

        // What isn't a row is none.
        for text in ["", "map:x", "head", "head:12,~#one:0,~#two:0", "-sites.0:0"] {
            XCTAssertNil(ViewRow(text), text)
        }
    }

    /// The view has every page of the list but those it has its own of and
    /// those it hasn't, each as every keeper is told it, and the list.
    func testAViewHasTheListButItsOwnAndThoseItHasnt() throws {
        let row = ViewRow(own: ["head": 12, "units.0": 11, "units.1": 11], told: list.name, without: ["sites.0"])
        XCTAssertEqual(row.parts(told: list.text), [
            "head": 12, "units.0": 11, "units.1": 11,
            "~houses.0#bbbb": 0, "~map#cccc": 0,
            list.name: 0,
        ])
        XCTAssertNil(row.parts(told: nil), "Not without its list")
        // A list with what isn't a page told alike in it takes none of that.
        XCTAssertEqual(row.parts(told: "~map#cccc,map,"), ["head": 12, "units.0": 11, "units.1": 11, "~map#cccc": 0, list.name: 0])
        XCTAssertEqual(ViewRow(own: [:], told: list.name).parts(told: "")?.keys.sorted(), [list.name])
    }
}
