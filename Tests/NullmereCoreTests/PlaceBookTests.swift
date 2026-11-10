import XCTest
@testable import NullmereCore

/// The places a keeper keeps in their book to come back to (RoK's
/// bookmarks): one to a hex, the newest first, at most a score of them,
/// named as the keeper would say it unless they name it otherwise. The
/// Mac's keeping of it and its rows are held in NullmereKitTests
/// (`PlacesKeptTests`).
final class PlaceBookTests: XCTestCase {
    func testABookKeepsEachPlaceOnceTheNewestFirstAndLetsItGo() {
        var book = PlaceBook()
        XCTAssertTrue(book.places.isEmpty)
        XCTAssertTrue(book.keep(Hex(1, 2), named: "The ford", at: 3))
        XCTAssertTrue(book.keep(Hex(-4, 0), named: "Wenholme", at: 5))
        XCTAssertEqual(book.places.map(\.name), ["Wenholme", "The ford"], "the newest first")
        XCTAssertEqual(book.place(at: Hex(1, 2)), KeptPlace(at: Hex(1, 2), name: "The ford", kept: 3))
        XCTAssertEqual(book.place(at: Hex(1, 2))?.id, Hex(1, 2))
        XCTAssertFalse(book.keep(Hex(1, 2), named: "The ford again", at: 6), "one to a hex")
        XCTAssertEqual(book.places.count, 2)
        XCTAssertFalse(book.keep(Hex(9, 9), named: "  \n ", at: 6), "never by no name")
        book.forget(Hex(1, 2))
        XCTAssertNil(book.place(at: Hex(1, 2)))
        XCTAssertEqual(book.places.map(\.at), [Hex(-4, 0)])
        book.forget(Hex(7, 7))
        XCTAssertEqual(book.places.count, 1, "letting go of what it doesn't keep changes nothing")
    }

    func testANameIsKeptOnOneLineAndNoLongerThanABookAllows() throws {
        XCTAssertEqual(PlaceBook.kept("  The ford\nby Wenholme  "), "The ford by Wenholme")
        XCTAssertNil(PlaceBook.kept(" \n\t "))
        let long = try XCTUnwrap(PlaceBook.kept(String(repeating: "Blackwood ", count: 10)))
        XCTAssertLessThanOrEqual(long.count, PlaceBook.longestName)
        XCTAssertFalse(long.hasSuffix(" "))
        var book = PlaceBook()
        book.keep(Hex(0, 1), named: "Here", at: 1)
        XCTAssertTrue(book.rename(Hex(0, 1), to: " Where the Spears wait "))
        XCTAssertEqual(book.place(at: Hex(0, 1))?.name, "Where the Spears wait")
        XCTAssertEqual(book.place(at: Hex(0, 1))?.kept, 1, "named anew, kept since it was kept")
        XCTAssertFalse(book.rename(Hex(0, 1), to: "   "), "never named nothing")
        XCTAssertEqual(book.place(at: Hex(0, 1))?.name, "Where the Spears wait")
        XCTAssertFalse(book.rename(Hex(5, 5), to: "Nowhere"), "a place it doesn't keep")
    }

    func testABookIsFullAtAScoreAndKeepsWhatItKeptAcrossItsKeeping() throws {
        var book = PlaceBook()
        for index in 0..<PlaceBook.limit {
            XCTAssertTrue(book.keep(Hex(index, 0), named: "Place \(index)", at: index))
        }
        XCTAssertTrue(book.isFull)
        XCTAssertFalse(book.keep(Hex(0, 9), named: "One more", at: 30), "full")
        XCTAssertEqual(book.places.count, PlaceBook.limit)
        book.forget(Hex(3, 0))
        XCTAssertFalse(book.isFull)
        XCTAssertTrue(book.keep(Hex(0, 9), named: "One more", at: 30))
        // Kept by the Mac as written, and read back the same.
        let read = try JSONDecoder().decode(PlaceBook.self, from: JSONEncoder().encode(book))
        XCTAssertEqual(read, book)
    }

    /// Unless the keeper names it, a place is called by the hold standing
    /// there, or by its ground and the nearest hold within a few tiles, or
    /// by its ground alone far from any.
    func testAPlaceIsNamedAsTheKeeperWouldSayIt() throws {
        let state = GameState(settings: GameSettings(seedText: "places kept", houseCount: 4, radius: 14, keepers: 1))
        let seat = try XCTUnwrap(state.seat(of: state.player))
        XCTAssertEqual(state.keptName(of: seat.position), seat.name)
        let beside = try XCTUnwrap(seat.position.neighbors.first { hex in
            state.map[hex] != nil && state.hold(at: hex) == nil
                && state.holds.allSatisfy { $0.id == seat.id || $0.position.distance(to: hex) > hex.distance(to: seat.position) }
        })
        let ground = try XCTUnwrap(state.map[beside]).terrain.ground
        XCTAssertEqual(state.keptName(of: beside), (ground.prefix(1).uppercased() + ground.dropFirst()) + " by \(seat.name)")
        let far = try XCTUnwrap(state.map.hexes.first { hex in state.holds.allSatisfy { $0.position.distance(to: hex) > 4 } })
        let alone = try XCTUnwrap(state.map[far]).terrain.ground
        XCTAssertEqual(state.keptName(of: far), alone.prefix(1).uppercased() + alone.dropFirst())
        XCTAssertNotNil(PlaceBook.kept(state.keptName(of: far)), "a name a book keeps")
    }
}
