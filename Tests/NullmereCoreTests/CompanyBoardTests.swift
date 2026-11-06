import Foundation
@testable import NullmereCore
import XCTest

/// The realm's companies keep a board of where each stands through every
/// change, so who stands on a hex is found at once: the board must always
/// say what a walk down the list would.
final class CompanyBoardTests: XCTestCase {
    private func company(_ id: Int, _ q: Int, _ r: Int, owner: Int = 0) -> NullmereCore.Unit {
        NullmereCore.Unit(id: id, kind: .spear, owner: owner, position: Hex(q, r))
    }

    /// What a walk down the list finds on a hex: the first company there,
    /// and every one there by id.
    private func walk(_ units: Companies, _ hex: Hex) -> (first: Int?, ids: [Int]) {
        (units.firstIndex { $0.position == hex }, units.filter { $0.position == hex }.map(\.id).sorted())
    }

    private func assertBoard(_ units: Companies, _ note: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(units.boardHolds(), "The board holds every company where it stands: \(note)", file: file, line: line)
        let hexes = Set(units.map(\.position)).union([Hex(9, 9), Hex(-3, 2)])
        for hex in hexes {
            let walked = walk(units, hex)
            XCTAssertEqual(units.first(at: hex), walked.first, "\(note): the first on \(hex)", file: file, line: line)
            XCTAssertEqual(units.ids(at: hex), walked.ids, "\(note): every one on \(hex)", file: file, line: line)
            XCTAssertEqual(units.isHeld(hex), walked.first != nil, file: file, line: line)
        }
    }

    func testTheBoardFollowsEveryChange() {
        var units: Companies = [company(1, 0, 0), company(2, 1, 0), company(4, 2, -1)]
        assertBoard(units, "laid out")
        units.append(company(7, 1, 0))
        assertBoard(units, "one raised where another stands")
        units[0].position = Hex(1, 0)
        assertBoard(units, "one moved onto a held hex")
        units[1].health -= 10
        assertBoard(units, "one changed but not moved")
        units[2] = company(5, 3, 3)
        assertBoard(units, "one written anew")
        units.remove(at: 1)
        assertBoard(units, "one lost")
        units.insert(company(3, 0, 0), at: 1)
        assertBoard(units, "one set in among them, out of the order of its id")
        units.swapAt(0, 2)
        assertBoard(units, "two swapped")
        units.sort { $0.position < $1.position }
        assertBoard(units, "sorted by where they stand")
        units.append(contentsOf: [company(8, 4, 4), company(9, 4, 4)])
        assertBoard(units, "many raised at once")
        units.removeAll { $0.position == Hex(1, 0) }
        assertBoard(units, "all on one hex lost")
        units.replaceSubrange(0..<1, with: [company(10, 5, 5), company(11, 5, 5)])
        assertBoard(units, "one replaced by two")
        let kept = Companies(units.filter { $0.id > 9 })
        assertBoard(kept, "sifted and laid out again")
        XCTAssertEqual(kept.map(\.id), [10, 11])
        units.removeAll()
        assertBoard(units, "none left")
        XCTAssertNil(units.first(at: Hex(5, 5)))
    }

    /// The first on a hex is the first in the list, whatever its id: as a
    /// company set in out of order would be found by a walk.
    func testTheFirstOnAHexIsTheFirstInTheList() {
        let units: Companies = [company(5, 0, 0), company(2, 0, 0), company(9, 1, 1)]
        XCTAssertEqual(units.first(at: Hex(0, 0)), 0, "The one lying first, though its id is the higher")
        XCTAssertEqual(units.ids(at: Hex(0, 0)), [2, 5])
        XCTAssertEqual(units.index(ofID: 2), 1, "Found though out of order")
        XCTAssertEqual(units.index(ofID: 9), 2)
        XCTAssertNil(units.index(ofID: 3))
    }

    /// Written and read as the plain list it holds, so a realm's words
    /// and saves are as they were.
    func testItIsWrittenAsAPlainList() throws {
        let list = [company(1, 0, 0), company(2, 1, -1, owner: 3)]
        let units = Companies(list)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        XCTAssertEqual(try encoder.encode(units), try encoder.encode(list))
        let read = try JSONDecoder().decode(Companies.self, from: try encoder.encode(list))
        XCTAssertEqual(read, units)
        assertBoard(read, "read back")
        XCTAssertEqual(Companies(list), Companies(list.reversed().reversed()))
        XCTAssertNotEqual(Companies(list), Companies(list.reversed()), "The same companies in another order are not the same list")
    }

    /// Through ages of play, every company raised, marched, fought, lost
    /// and carried by the rules, the board never strays.
    func testTheBoardHoldsThroughAnAge() {
        var world = RealmState.world(seed: "the board through an age", age: 1, seats: 12, radius: RealmState.radius(forSeats: 12))
        let absent = Set(world.houses.indices)
        for index in world.houses.indices { world.houses[index].isPlayer = true }
        for watch in 1...60 where world.outcome == nil {
            for pace in 1..<GameState.pacesPerWatch { _ = world.walk(to: pace, keptFor: absent) }
            _ = world.endWatch(keptFor: absent)
            XCTAssertTrue(world.units.boardHolds(), "The board holds at watch \(watch)")
        }
        XCTAssertGreaterThan(world.units.count, 12, "Companies raised")
        for unit in world.units {
            XCTAssertNotNil(world.unit(at: unit.position))
        }
    }
}
