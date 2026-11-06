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

    /// Ground that lies together travels as its runs, ground scattered as
    /// its bits, whichever is shorter; either comes back exactly, and the
    /// bits as they travelled before read as they did.
    func testGroundTravelsAsItsRunsWhereThatIsShorter() throws {
        var together = Explored(repeating: false, count: 10_000)
        for tile in 2_000..<3_500 { together[tile] = true }
        for tile in 7_000..<7_040 { together[tile] = true }
        XCTAssertEqual(together.runs, [2_000, 1_500, 3_500, 40, 2_960])
        let runs = Bits.encode(together)
        XCTAssertTrue(runs.hasPrefix("10000;"), runs)
        XCTAssertLessThan(runs.count, 30)
        XCTAssertEqual(Bits.decode(runs), together)

        var scattered = Explored(repeating: false, count: 1_000)
        for tile in stride(from: 0, to: 1_000, by: 2) { scattered[tile] = true }
        let bits = Bits.encode(scattered)
        XCTAssertTrue(bits.hasPrefix("1000:"), "Bits, where runs would be longer")
        XCTAssertEqual(Bits.decode(bits), scattered)
        XCTAssertEqual(Bits.decode("1000:" + Data(scattered.bytes).base64EncodedString()), scattered)

        // The first tile seen, the last, every one, a run longer than a
        // byte's seven bits can count, and ground drawn at random.
        var edges = Explored(repeating: false, count: 300)
        edges[0] = true
        edges[299] = true
        for values in [edges, Explored(repeating: true, count: 200), Explored(repeating: false, count: 64)] {
            XCTAssertEqual(Bits.decode(Bits.encode(values)), values)
        }
        XCTAssertEqual(edges.runs.first, 0)
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<20 {
            var random = Explored(repeating: false, count: Int.random(in: 1...5_000, using: &generator))
            var tile = 0
            while tile < random.count {
                let run = Int.random(in: 1...400, using: &generator)
                if Bool.random(using: &generator) { for seen in tile..<min(tile + run, random.count) { random[seen] = true } }
                tile += run
            }
            XCTAssertEqual(Bits.decode(Bits.encode(random)), random)
            XCTAssertEqual(Explored(count: random.count, runs: random.runs), random)
        }

        // Runs that don't come to the tiles told of, a run of none past the
        // first, and a number cut short are refused.
        XCTAssertNil(Explored(count: 10, runs: [3, 4]))
        XCTAssertNil(Explored(count: 10, runs: [3, 0, 7]))
        XCTAssertNil(Explored(count: 10, runs: [-1, 11]))
        XCTAssertNil(Bits.decode("10;" + Data([0x83]).base64EncodedString()))
        XCTAssertNil(Bits.decode("10;" + Data([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01]).base64EncodedString()))
        XCTAssertNil(Bits.decode("10;not base64!"))
        XCTAssertNil(Bits.decode("x;AA=="))
        XCTAssertNil(Bits.decode("10"))
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

    /// A House's whole explored ground travels as its runs, lying together
    /// as it does, and reads back the same; a House written while it went as
    /// bits reads as it did.
    func testAHouseTravelsAsItDid() throws {
        var state = GameState(settings: GameSettings(seedText: "explored as bits", houseCount: 3, radius: 16))
        for _ in 0..<3 { _ = state.endWatch() }
        let house = state.houses[0]
        let text = String(decoding: try JSONEncoder().encode(house), as: UTF8.self)
        let runs = Bits.encode(house.explored)
        XCTAssertTrue(runs.contains(";"), "As runs: \(runs)")
        XCTAssertTrue(text.contains(runs.replacingOccurrences(of: "/", with: "\\/")))
        XCTAssertEqual(try JSONDecoder().decode(House.self, from: Data(text.utf8)).explored, house.explored)
        let bits = travelled(Array(house.explored)).replacingOccurrences(of: "/", with: "\\/")
        let before = text.replacingOccurrences(of: runs.replacingOccurrences(of: "/", with: "\\/"), with: bits)
        XCTAssertNotEqual(before, text)
        XCTAssertEqual(try JSONDecoder().decode(House.self, from: Data(before.utf8)), house)
    }
}
