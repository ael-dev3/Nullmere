@testable import NullmereCore
@testable import NullmereKit
import NullmereWorld
import SwiftUI
import XCTest

/// The Houses named over their land from afar, as Rise of Kingdoms' kingdom
/// map names its cities: shown only as the holds' own names go; set down
/// the keeper's own first, never one over another, beneath a seat or above
/// it to leave a name of the land clear, and no more than a few at once.
@MainActor
final class HouseNamesAfarTests: XCTestCase {
    func testTheNamesShowOnlyAsTheHoldsOwnGo() {
        XCTAssertEqual(HouseNamesAfar.shown(at: 30), 0)
        XCTAssertEqual(HouseNamesAfar.shown(at: 18), 0, "the holds name themselves from 18 points a hex")
        XCTAssertEqual(HouseNamesAfar.shown(at: 16.5), 0.5)
        XCTAssertEqual(HouseNamesAfar.shown(at: 15), 1)
        XCTAssertEqual(HouseNamesAfar.shown(at: 6), 1)
    }

    func testNamesAreSetDownInTurnNeverOneOverAnother() {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 300)
        let first = CGRect(x: 10, y: 10, width: 100, height: 20)
        let overFirst = CGRect(x: 60, y: 15, width: 100, height: 20)
        let aboveIt = CGRect(x: 60, y: 40, width: 100, height: 20)
        let offTheMap = CGRect(x: 500, y: 10, width: 50, height: 20)
        let land = CGRect(x: 200, y: 100, width: 80, height: 14)
        let onTheLand = CGRect(x: 210, y: 95, width: 60, height: 20)
        let clearOfIt = CGRect(x: 210, y: 140, width: 60, height: 20)
        let set = HouseNamesAfar.place([[first], [overFirst, aboveIt], [offTheMap], [onTheLand, clearOfIt], [bounds]],
                                       within: bounds, around: [land], limit: 8)
        XCTAssertEqual(set.map { $0.index }, [0, 1, 3], "off the map, and over every name set down, none")
        XCTAssertEqual(set[1].frame, aboveIt, "its other place, the first falling on a name set down")
        XCTAssertEqual(set[2].frame, clearOfIt, "clear of the land's name where it can be")
        // Over a name of the land rather than not at all.
        XCTAssertEqual(HouseNamesAfar.place([[onTheLand]], within: bounds, around: [land], limit: 8).map { $0.frame }, [onTheLand])
        // And no more than the limit.
        let many = (0..<10).map { [CGRect(x: CGFloat($0) * 30, y: 0, width: 20, height: 10)] }
        XCTAssertEqual(HouseNamesAfar.place(many, within: bounds, limit: 4).map { $0.index }, [0, 1, 2, 3])
    }

    func testTheKeepersOwnHouseIsNamedFirstAtItsSeatAndNoNameCoversAnother() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        var world = GameState(settings: GameSettings(seedText: "houses named from afar", keepers: 1))
        let me = world.player
        let home = try XCTUnwrap(world.seat(of: me)).position
        world.reveal(around: home, range: 60, for: me)
        let session = GameSession(state: world, store: LocalStore(directory: dir))
        let size = CGSize(width: 1400, height: 900)
        var camera = session.camera
        camera.focus(on: home)
        camera.scale = 7
        session.camera = camera

        let plates = HouseNamesAfar.plates(for: session, in: size)
        XCTAssertEqual(plates.first?.house, me, "the keeper's own first")
        XCTAssertEqual(plates.first?.standing, .own)
        XCTAssertEqual(plates.first?.title, session.state.houses[me].name.uppercased())
        XCTAssertGreaterThanOrEqual(plates.count, 3, "the Houses about the lake named: \(plates.map(\.title))")
        XCTAssertLessThanOrEqual(plates.count, HouseNamesAfar.limit)
        for (index, plate) in plates.enumerated() {
            XCTAssertTrue(CGRect(origin: .zero, size: size).intersects(plate.frame), "\(plate.title) on the map")
            for other in plates[(index + 1)...] {
                XCTAssertFalse(plate.frame.intersects(other.frame), "\(plate.title) over \(other.title)")
            }
            // Beneath its seat, or above it.
            let seat = session.viewPoint(of: try XCTUnwrap(session.state.seat(of: plate.house)).position, in: size)
            XCTAssertEqual(plate.frame.midX, seat.x, accuracy: 0.5, plate.title)
            XCTAssertTrue(plate.frame.minY > seat.y || plate.frame.maxY < seat.y, plate.title)
        }

        // Drawn over the painted land and its marks, as a Mac that cannot
        // draw the world shows the lake from afar.
        let view = ZStack {
            WorldFallback(session: session)
            WorldMarks(session: session)
            HouseNamesAfar(session: session)
        }
        try CardShot.keep(view.frame(width: size.width, height: size.height), as: "game-houses-afar.png", size: size)

        // Close in, none: the holds name themselves.
        camera.scale = 24
        session.camera = camera
        XCTAssertEqual(HouseNamesAfar.shown(at: session.camera.scale), 0)
    }
}
