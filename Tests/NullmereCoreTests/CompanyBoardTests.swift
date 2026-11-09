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
        for house in Set(units.map(\.owner)).union([42]) {
            XCTAssertEqual(units.places(of: house), units.indices.filter { units[$0].owner == house }, "\(note): House \(house)'s", file: file, line: line)
            XCTAssertEqual(units.ids(of: house), units.filter { $0.owner == house }.map(\.id).sorted(), file: file, line: line)
        }
    }

    /// Where the companies stand is told by a token drawn anew whenever one
    /// moves, is raised or falls, and the latest moves are kept: from a
    /// token they stood at, which companies moved since, in order; from one
    /// they never stood at, or across a company raised or fallen or more
    /// moves than are kept, nothing claimed.
    func testTheyTellWhichMovedSinceTheyStoodWhereTheyStood() {
        var units = Companies([company(1, 0, 0), company(2, 1, 0), company(3, 2, 0)])
        let first = units.stand
        XCTAssertEqual(units.moved(since: first), [], "None moved yet")
        units[1].health -= 10
        units[2].owner = 1
        XCTAssertEqual(units.stand, first, "Hurt or given over, none moved")
        units[0].position = Hex(0, 1)
        units[2].position = Hex(2, 1)
        units[0].position = Hex(0, 2)
        XCTAssertEqual(units.moved(since: first), [1, 3, 1], "Each move, in order")
        // Two copies part ways: each tells its own moves, and neither knows
        // where the other stands.
        let parted = units.stand
        var other = units
        units[1].position = Hex(5, 5)
        other[2].position = Hex(7, 7)
        XCTAssertEqual(units.moved(since: parted), [2])
        XCTAssertEqual(other.moved(since: parted), [3])
        XCTAssertNil(units.moved(since: other.stand), "A stand these never stood at")
        XCTAssertNil(units.moved(since: 0))
        // A company raised, or fallen, begins it afresh.
        let beforeRaised = units.stand
        units.append(company(4, 3, 0))
        XCTAssertNil(units.moved(since: beforeRaised), "Raised: not all kept")
        let beforeFallen = units.stand
        units.remove(at: 0)
        XCTAssertNil(units.moved(since: beforeFallen), "Fallen: not all kept")
        // More moves than are kept: the oldest let go.
        let longAgo = units.stand
        for step in 0...Companies.shiftsKept { units[0].position = Hex(10 + step, 0) }
        XCTAssertNil(units.moved(since: longAgo), "Too many moves ago")
        let lately = units.stand
        units[1].position = Hex(-1, -1)
        XCTAssertEqual(units.moved(since: lately), [units[1].id])
        // Written and read back, a list like any other, its token its own.
        let read = try? JSONDecoder().decode(Companies.self, from: JSONEncoder().encode(units))
        XCTAssertEqual(read, units)
        XCTAssertNotEqual(read?.stand, units.stand)
        assertBoard(units, "after all of it")
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
        units[1].owner = 5
        assertBoard(units, "one given over to another House")
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
        for house in world.houses.indices {
            XCTAssertEqual(world.units(of: house).map(\.id), world.units.filter { $0.owner == house }.map(\.id))
        }
    }
}
