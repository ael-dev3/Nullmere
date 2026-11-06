import Foundation
import XCTest
@testable import NullmereCore

/// A House's explored ground, a bit to a tile: read and written as a list
/// of yes and no, the same list however it was made, and travelling as the
/// list of booleans it replaced did, eight to a byte.
final class ExploredTests: XCTestCase {
    /// The booleans as they travelled before a House kept them as bits:
    /// "count:base64", eight to a byte, the first in each byte's lowest bit.
    private func travelled(_ values: [Bool]) -> String {
        guard values.contains(true) else { return "\(values.count):\(Bits.noneSet)" }
        var bytes = [UInt8](repeating: 0, count: (values.count + 7) / 8)
        for (index, value) in values.enumerated() where value { bytes[index / 8] |= 1 << UInt8(index % 8) }
        return "\(values.count):" + Data(bytes).base64EncodedString()
    }

    func testItReadsAndWritesAsTheListItReplaced() {
        var random = SeededRandom(seed: 7)
        for count in [0, 1, 7, 8, 9, 63, 64, 65, 127, 128, 129, 1_000] {
            var list = (0..<count).map { _ in random.chance(30) }
            var bits = Explored(list)
            XCTAssertEqual(bits.count, count)
            XCTAssertEqual(Array(bits), list, "\(count) tiles")
            XCTAssertEqual(bits.setCount, list.filter { $0 }.count)
            XCTAssertEqual(bits.contains(true), list.contains(true))
            XCTAssertEqual(bits.contains(false), list.contains(false))
            for _ in 0..<min(count, 40) {
                let index = random.int(below: count), value = random.chance(50)
                list[index] = value
                bits[index] = value
            }
            XCTAssertEqual(Array(bits), list, "\(count) tiles, written")
            XCTAssertEqual(bits, Explored(list), "The same, made either way")
            XCTAssertEqual(Bits.encode(bits), travelled(list), "Travelling as the booleans did")
            XCTAssertEqual(Bits.decode(travelled(list)), bits, "And read back")
        }
    }

    /// Nothing known of a map of a size is one, kept for every House told
    /// as a stranger: alike to nothing made anew, and a House that comes to
    /// know a tile knows it alone.
    func testNothingKnownIsOneForEveryMapOfASize() {
        let nothing = Explored.unknown(count: 300)
        XCTAssertEqual(nothing, Explored(repeating: false, count: 300))
        XCTAssertEqual(nothing.count, 300)
        XCTAssertFalse(nothing.contains(true))
        nothing.words.withUnsafeBufferPointer { kept in
            Explored.unknown(count: 300).words.withUnsafeBufferPointer { again in
                XCTAssertEqual(kept.baseAddress, again.baseAddress, "the very same storage")
            }
        }
        var learnt = Explored.unknown(count: 300)
        learnt[7] = true
        XCTAssertTrue(learnt[7])
        XCTAssertFalse(Explored.unknown(count: 300)[7], "what one House learns, the nothing doesn't")
        XCTAssertEqual(Explored.unknown(count: 5).count, 5)
    }

    func testAllOrNoneAndTheTileBeyondTheLast() {
        for count in [0, 5, 64, 70] {
            let all = Explored(repeating: true, count: count), none = Explored(repeating: false, count: count)
            XCTAssertEqual(all.setCount, count, "Every tile and none beyond")
            XCTAssertEqual(none.setCount, 0)
            XCTAssertEqual(all, Explored(Array(repeating: true, count: count)))
            XCTAssertEqual(Bits.encode(none), "\(count):\(Bits.noneSet)")
            XCTAssertEqual(Bits.decode(Bits.encode(all)), all)
        }
        XCTAssertEqual(Explored(repeating: true, count: -3).count, 0, "No fewer than none")
        XCTAssertTrue(Explored().isEmpty)
        let literal: Explored = [true, false, true]
        XCTAssertEqual(Array(literal), [true, false, true])
        // Bits set past the last tile in what travels are let go of.
        XCTAssertEqual(Explored(count: 3, bytes: [0xFF]), [true, true, true])
        XCTAssertEqual(Explored(count: 3, bytes: [0xFF]).setCount, 3)
        // What doesn't read is refused.
        XCTAssertNil(Bits.decode("3"))
        XCTAssertNil(Bits.decode("x:-"))
        XCTAssertNil(Bits.decode("16:AA=="), "Too few bytes for sixteen tiles")
    }

    /// A House's whole explored ground, kept as bits, travels as the same
    /// text and reads back the same.
    func testAHouseTravelsAsItDid() throws {
        var state = GameState(settings: GameSettings(seedText: "explored as bits", houseCount: 3, radius: 16))
        for _ in 0..<3 { _ = state.endWatch() }
        let house = state.houses[0]
        let text = String(decoding: try JSONEncoder().encode(house), as: UTF8.self)
        XCTAssertTrue(text.contains(travelled(Array(house.explored)).replacingOccurrences(of: "/", with: "\\/")))
        XCTAssertEqual(try JSONDecoder().decode(House.self, from: Data(text.utf8)).explored, house.explored)
    }
}
