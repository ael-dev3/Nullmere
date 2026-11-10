import AppKit
import LauncherKit
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The places a keeper keeps in their book on the Mac (RoK's bookmarks):
/// kept from the ground's panel or a hold's, by the name it goes by or one
/// of their own; listed in the Realm panel, Go bringing the view there;
/// forgotten; refused once the book is full; and kept by this Mac for the
/// age, so a session begun again has them. The book itself is held in
/// NullmereCoreTests (`PlaceBookTests`).
@MainActor
final class PlacesKeptTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        PressableButtons.isListening = true
    }

    override func tearDown() async throws {
        PressableButtons.isListening = false
        try? FileManager.default.removeItem(at: dir)
    }

    private func draw(_ view: some View, width: CGFloat = 400, height: CGFloat = 500) {
        PressableButtons.isListening = true
        let renderer = ImageRenderer(content: view.frame(width: width, height: height).background(Color.black))
        renderer.scale = 1
        XCTAssertNotNil(renderer.cgImage)
    }

    private var shown: [String] { PressableButtons.actions.keys.sorted() }

    func testAPlaceIsKeptListedGoneToAndForgotten() throws {
        let state = GameState(settings: GameSettings(seedText: "places kept on the mac", houseCount: 4, radius: 16, keepers: 1))
        let seat = try XCTUnwrap(state.seat(of: state.player))
        let ground = try XCTUnwrap(seat.position.spiral(3).first { hex in
            hex.distance(to: seat.position) >= 2 && state.map[hex] != nil && state.hold(at: hex) == nil
        })
        let session = GameSession(state: state, store: LocalStore(directory: dir))
        session.dismissSeatBriefing()
        XCTAssertTrue(session.placeBook.places.isEmpty)
        XCTAssertEqual(PlacesSection.summary(session.placeBook), "No places kept. Keep one from a hold or the ground to come back to it.")

        // Kept from the ground's row, by the name it goes by.
        draw(KeepPlaceRow(session: session, hex: ground))
        XCTAssertTrue(PressableButtons.press("Keep this place…"), "Among \(shown)")
        draw(KeepPlaceRow(session: session, hex: ground, open: true))
        XCTAssertTrue(PressableButtons.press("Keep"), "Among \(shown)")
        XCTAssertEqual(session.placeBook.place(at: ground)?.name, state.keptName(of: ground))
        XCTAssertEqual(session.placeBook.place(at: ground)?.kept, state.watch)
        draw(KeepPlaceRow(session: session, hex: ground))
        XCTAssertFalse(PressableButtons.press("Keep this place…"), "kept once: \(shown)")

        // Listed in the Realm panel; Go brings the view there, the panel put
        // away and the ground chosen.
        session.panel = .realm
        draw(PlacesSection(session: session, open: true))
        XCTAssertTrue(PressableButtons.press("Go"), "Among \(shown)")
        XCTAssertNil(session.panel)
        XCTAssertEqual(session.selection, .tile(ground))

        // By a name of the keeper's own, at the seat: the hold chosen there.
        XCTAssertTrue(session.keepPlace(seat.position, named: "  Home\n"))
        XCTAssertEqual(session.placeBook.place(at: seat.position)?.name, "Home")
        XCTAssertFalse(session.keepPlace(seat.position), "one to a place")
        XCTAssertEqual(PlacesSection.summary(session.placeBook), "2 places kept, the newest Home.")
        XCTAssertEqual(PlacesSection.line(try XCTUnwrap(session.placeBook.place(at: seat.position)), in: state),
                       "\(seat.name), kept at watch \(state.watch)", "what stands there now, where it goes by another name")
        XCTAssertEqual(PlacesSection.line(try XCTUnwrap(session.placeBook.place(at: ground)), in: state), "Kept at watch \(state.watch)")
        session.goToPlace(seat.position)
        XCTAssertEqual(session.selection, .hold(seat.id))
        // Marked on the small map, and said with it.
        XCTAssertTrue(MiniMap.spoken(session).hasSuffix(", 2 places kept"), MiniMap.spoken(session))
        let mark = MiniMap.diamond(at: CGPoint(x: 10, y: 20), size: 3).boundingRect
        XCTAssertEqual(mark, CGRect(x: 7, y: 17, width: 6, height: 6))
        draw(MiniMap(session: session), width: MiniMap.side + 12, height: MiniMap.side + 12)
        try CardShot.keep(PlacesSection(session: session, open: true).padding(16).frame(width: 360).background(Palette.panel),
                          as: "game-places.png")

        // Forgotten from its row; and kept by this Mac, so a session begun
        // again has what was left.
        draw(KeepPlaceRow(session: session, hex: ground))
        XCTAssertTrue(PressableButtons.press("Forget"), "Among \(shown)")
        XCTAssertNil(session.placeBook.place(at: ground))
        XCTAssertTrue(MiniMap.spoken(session).hasSuffix(", 1 place kept"), MiniMap.spoken(session))
        let again = GameSession(state: state, store: LocalStore(directory: dir))
        XCTAssertEqual(again.placeBook.places.map(\.name), ["Home"])
        XCTAssertEqual(again.placeBook, session.placeBook)
    }

    /// A full book keeps no more: its row says why, and keeps nothing.
    func testAFullBookKeepsNoMore() throws {
        let state = GameState(settings: GameSettings(seedText: "a full book of places", houseCount: 4, radius: 16, keepers: 1))
        let session = GameSession(state: state, store: LocalStore(directory: dir))
        session.dismissSeatBriefing()
        let hexes = state.map.hexes.filter { state.hold(at: $0) == nil }
        for hex in hexes.prefix(PlaceBook.limit) {
            XCTAssertTrue(session.keepPlace(hex))
        }
        XCTAssertTrue(session.placeBook.isFull)
        let more = try XCTUnwrap(hexes.dropFirst(PlaceBook.limit).first)
        XCTAssertEqual(KeepPlaceRow.refusal(session.placeBook), "Your book keeps \(PlaceBook.limit) places: forget one to keep another.")
        XCTAssertNil(KeepPlaceRow.refusal(PlaceBook()))
        draw(KeepPlaceRow(session: session, hex: more, open: true))
        XCTAssertFalse(PressableButtons.press("Keep"), "full: \(shown)")
        XCTAssertFalse(session.keepPlace(more))
        XCTAssertNil(session.placeBook.place(at: more))
    }
}
