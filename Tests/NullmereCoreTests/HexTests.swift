import XCTest
@testable import NullmereCore

final class HexTests: XCTestCase {
    func testDistanceRingsAndSpirals() {
        XCTAssertEqual(Hex(0, 0).distance(to: Hex(3, -1)), 3)
        XCTAssertEqual(Hex(2, -2).distance(to: Hex(-1, 2)), 4)
        for radius in 1...6 {
            let ring = Hex(2, -1).ring(radius)
            XCTAssertEqual(ring.count, 6 * radius)
            XCTAssertEqual(Set(ring).count, ring.count)
            XCTAssertTrue(ring.allSatisfy { $0.distance(to: Hex(2, -1)) == radius })
        }
        XCTAssertEqual(Hex.origin.spiral(4).count, WorldMap.count(radius: 4))
    }

    func testLinesRunEndToEndOneStepAtATime() {
        let line = Hex(-4, 1).line(to: Hex(5, -3))
        XCTAssertEqual(line.first, Hex(-4, 1))
        XCTAssertEqual(line.last, Hex(5, -3))
        XCTAssertEqual(line.count, Hex(-4, 1).distance(to: Hex(5, -3)) + 1)
        for (a, b) in zip(line, line.dropFirst()) {
            XCTAssertEqual(a.distance(to: b), 1)
        }
    }

    func testLayoutFindsTheHexUnderAPoint() {
        let layout = HexLayout(size: 18)
        for hex in Hex(1, 1).spiral(5) {
            let c = layout.center(of: hex)
            XCTAssertEqual(layout.hex(atX: c.x, y: c.y), hex)
            XCTAssertEqual(layout.hex(atX: c.x + 7, y: c.y - 6), hex, "A point inside the hex picks it")
        }
    }

    func testMapIndicesRoundTrip() {
        let map = WorldMap(radius: 7, fill: Tile(terrain: .greyfield))
        XCTAssertEqual(map.count, 169)
        for (index, hex) in map.hexes.enumerated() {
            XCTAssertEqual(map.index(of: hex), index)
            XCTAssertEqual(map.hex(at: index), hex)
        }
        XCTAssertNil(map.index(of: Hex(8, 0)))
        XCTAssertEqual(map.hexes, map.hexes.sorted(), "Index order is row order")
    }

    func testRandomnessIsDeterministicAndUnbiasedInRange() {
        var a = SeededRandom(seed: 42)
        var b = SeededRandom(seed: 42)
        XCTAssertEqual((0..<20).map { _ in a.next() }, (0..<20).map { _ in b.next() })
        var c = SeededRandom(seed: 7)
        var counts = [Int](repeating: 0, count: 6)
        for _ in 0..<6000 { counts[c.int(below: 6)] += 1 }
        XCTAssertTrue(counts.allSatisfy { (850...1150).contains($0) }, "\(counts)")
        XCTAssertEqual(Seed.from("the still water"), Seed.from("the still water"))
        XCTAssertNotEqual(Seed.from("the still water"), Seed.from("the still waters"))
    }

    func testNoiseStaysInRangeAndIsSmooth() {
        let noise = ValueNoise(seed: 9)
        var previous = noise.fractal(0, 0.5)
        for step in 1...200 {
            let value = noise.fractal(Double(step) * 0.01, 0.5)
            XCTAssertTrue((0...1).contains(value))
            XCTAssertLessThan(abs(value - previous), 0.08)
            previous = value
        }
    }
}
