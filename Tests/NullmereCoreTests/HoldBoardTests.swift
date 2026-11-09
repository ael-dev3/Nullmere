import Foundation
@testable import NullmereCore
import XCTest

/// The realm's holds keep where each lies and whose each is through every
/// change, so the hold on a hex, a House's holds and its seat are found at
/// once: what they keep must always say what a walk down the list would.
final class HoldBoardTests: XCTestCase {
    private func hold(_ id: Int, _ q: Int, _ r: Int, owner: Int, seat: Bool = false) -> Hold {
        Hold(id: id, name: "Hold \(id)", owner: owner, position: Hex(q, r), isSeat: seat, foundedWatch: 1)
    }

    private func assertKept(_ holds: Holdings, _ note: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(holds.boardHolds(), "Every hold kept where it lies and whose it is: \(note)", file: file, line: line)
        for hex in Set(holds.map(\.position)).union([Hex(7, 7)]) {
            XCTAssertEqual(holds.first(at: hex), holds.firstIndex { $0.position == hex }, "\(note): the hold on \(hex)", file: file, line: line)
        }
        for house in Set(holds.map(\.owner)).union([42]) {
            XCTAssertEqual(holds.places(of: house), holds.indices.filter { holds[$0].owner == house }, "\(note): House \(house)'s", file: file, line: line)
            XCTAssertEqual(holds.count(of: house), holds.filter { $0.owner == house }.count, file: file, line: line)
        }
        assertNear(holds, note, file: file, line: line)
    }

    /// The holds near a hex, as the land's squares find them, are those a
    /// walk down the list finds that near, in the list's order: about each
    /// hold and hexes on either side of a square's edge, at every reach
    /// asked.
    private func assertNear(_ holds: Holdings, _ note: String, file: StaticString = #filePath, line: UInt = #line) {
        let hexes = Set(holds.map(\.position) + [Hex(7, 7), Hex(8, 8), Hex(-1, -1), Hex(-8, 9), Hex(15, -16), Hex(0, 0)])
        for hex in hexes {
            for range in [0, 1, 2, 3, 8, 12] {
                XCTAssertEqual(holds.places(within: range, of: hex), holds.indices.filter { holds[$0].position.distance(to: hex) <= range },
                               "\(note): the holds within \(range) of \(hex)", file: file, line: line)
            }
        }
    }

    func testTheHoldsNearAHexAreFoundAmongTheLandsSquares() {
        var holds: Holdings = [hold(1, 0, 0, owner: 0), hold(2, 7, 0, owner: 1), hold(3, 8, 0, owner: 1), hold(4, -1, -1, owner: 2),
                               hold(5, -8, 9, owner: 0), hold(6, 15, -16, owner: 2)]
        assertKept(holds, "laid across squares' edges")
        holds[1].position = Hex(8, 1)
        assertKept(holds, "moved over a square's edge")
        holds[2].position = Hex(9, 1)
        assertKept(holds, "moved within its square")
        holds.remove(at: 0)
        assertKept(holds, "one lost, those after it moved up the list")
        XCTAssertEqual(holds.places(within: -3, of: Hex(8, 1)), holds.places(within: 0, of: Hex(8, 1)), "No reach below none")
        XCTAssertEqual(holds.places(within: 2, of: Hex(Int.max - 1, 0)), [], "Nothing beyond the world")
        XCTAssertEqual(holds.places(within: 2, of: Hex(0, Int.min + 1)), [])
    }

    func testWhatIsKeptFollowsEveryChange() {
        var holds: Holdings = [hold(1, 0, 0, owner: 0, seat: true), hold(2, 2, 0, owner: 1, seat: true), hold(3, 0, 3, owner: 0)]
        assertKept(holds, "laid out")
        holds.append(hold(6, 4, -2, owner: 1))
        assertKept(holds, "one founded")
        holds[2].owner = 1
        assertKept(holds, "one taken")
        holds[1].position = Hex(5, 5)
        assertKept(holds, "a seat raised anew")
        holds[0].levels[.granary] = 3
        assertKept(holds, "one built up, neither moved nor taken")
        holds[3] = hold(9, 0, 0, owner: 2)
        assertKept(holds, "one written anew onto another's hex")
        holds.removeAll { $0.owner == 1 }
        assertKept(holds, "a House's all lost")
        holds.insert(hold(4, 1, 1, owner: 3), at: 0)
        assertKept(holds, "one set in before the rest")
        holds.swapAt(0, 1)
        assertKept(holds, "two swapped")
        holds.append(contentsOf: [hold(10, 8, 8, owner: 3), hold(11, 9, 9, owner: 0)])
        assertKept(holds, "two founded at once")
        holds.removeAll()
        assertKept(holds, "none left")
    }

    /// A hold told alike where it lies is the hold `toldAlike` gives; to
    /// its House's allies, all but who lies in its beds. Neither moves it,
    /// gives it to another House nor changes what the holds claim.
    func testAHoldIsToldAlikeWhereItLies() {
        var full = hold(2, 2, 0, owner: 1, seat: true)
        full.project = Hold.Project(kind: .granary, targetLevel: 2, watchesLeft: 3)
        full.training = Hold.Training(kind: .spear, watchesLeft: 2)
        full.wounded = [Wounded(kind: .spear, tier: 1, experience: 0, since: 4)]
        var holds: Holdings = [hold(1, 0, 0, owner: 0, seat: true), full, hold(3, 0, 3, owner: 1)]
        let claims = holds.claims
        XCTAssertTrue(holds[0].isToldAlike)
        XCTAssertFalse(holds[1].isToldAlike)
        var allies = holds
        allies.tellAlike(at: 1, toAllies: true)
        XCTAssertNil(allies[1].wounded)
        XCTAssertEqual(allies[1].project, full.project, "Its allies know what it raises")
        XCTAssertEqual(allies[1].training, full.training)
        XCTAssertFalse(allies[1].isToldAlike)
        holds.tellAlike(at: 1)
        XCTAssertEqual(holds[1], full.toldAlike())
        XCTAssertTrue(holds[1].isToldAlike)
        XCTAssertEqual(holds.claims, claims, "What the holds claim as it was")
        assertKept(holds, "one told alike")
        for one in [full, full.toldAlike(), hold(4, 1, 1, owner: 2)] {
            XCTAssertEqual(one.isToldAlike, one == one.toldAlike())
        }
        // A page of holds compared where they lie, as a list of them is.
        let other: Holdings = [hold(1, 0, 0, owner: 0, seat: true), full.toldAlike(), hold(3, 0, 3, owner: 1)]
        XCTAssertTrue(GameState.sameItems(holds.page(0..<3), other.page(0..<3)))
        XCTAssertFalse(GameState.sameItems(allies.page(0..<3), other.page(0..<3)))
        XCTAssertTrue(GameState.sameItems(allies.page(0..<1), other.page(0..<1)))
        XCTAssertFalse(GameState.sameItems(holds.page(0..<2), other.page(0..<3)), "Of another length")
        XCTAssertFalse(GameState.sameStorage(holds.page(0..<3), other.page(0..<3)))
        let copy = holds
        XCTAssertTrue(GameState.sameStorage(copy.page(0..<3), holds.page(0..<3)), "A copy keeps the list it was made from")
        XCTAssertTrue(GameState.sameItems(copy.page(1..<3), holds.page(1..<3)))
    }

    func testAHoldIsFoundByItsId() {
        let holds: Holdings = [hold(3, 0, 0, owner: 0), hold(5, 1, 0, owner: 0), hold(4, 2, 0, owner: 1)]
        XCTAssertEqual(holds.index(ofID: 5), 1)
        XCTAssertEqual(holds.index(ofID: 4), 2, "Found though out of order")
        XCTAssertNil(holds.index(ofID: 9))
    }

    /// Written and read as the plain list it holds.
    func testItIsWrittenAsAPlainList() throws {
        let list = [hold(1, 0, 0, owner: 0, seat: true), hold(2, 3, -1, owner: 2)]
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        XCTAssertEqual(try encoder.encode(Holdings(list)), try encoder.encode(list))
        let read = try JSONDecoder().decode(Holdings.self, from: try encoder.encode(list))
        XCTAssertEqual(read, Holdings(list))
        assertKept(read, "read back")
        XCTAssertEqual(Holdings(list).filter { $0.isSeat }, [list[0]], "Sifted as a plain list")
    }

    /// Through an age of play, holds founded, built, taken and raised anew
    /// by the rules, what is kept never strays, and the rules' own asks
    /// say what a walk down the list would.
    func testWhatIsKeptHoldsThroughAnAge() {
        var world = RealmState.world(seed: "the holds through an age", age: 1, seats: 12, radius: RealmState.radius(forSeats: 12))
        let absent = Set(world.houses.indices)
        for index in world.houses.indices { world.houses[index].isPlayer = true }
        for watch in 1...60 where world.outcome == nil {
            for pace in 1..<GameState.pacesPerWatch { _ = world.walk(to: pace, keptFor: absent) }
            _ = world.endWatch(keptFor: absent)
            XCTAssertTrue(world.holds.boardHolds(), "Kept true at watch \(watch)")
            if watch % 15 == 0 { assertNear(world.holds, "watch \(watch)") }
        }
        XCTAssertGreaterThan(world.holds.count, 12, "Holds founded")
        for house in world.houses.indices {
            XCTAssertEqual(world.holds(of: house).map(\.id), world.holds.filter { $0.owner == house }.map(\.id))
            XCTAssertEqual(world.seat(of: house)?.id, world.holds.first { $0.owner == house && $0.isSeat }?.id)
        }
        for hold in world.holds {
            XCTAssertEqual(world.hold(at: hold.position)?.id, world.holds.first { $0.position == hold.position }?.id)
        }
    }
}
