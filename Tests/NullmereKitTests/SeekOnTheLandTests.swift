import AppKit
import LauncherKit
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The keeper's search on the land on the Mac (Rise of Kingdoms' search on
/// its map): from the Realm panel, a kind of place sought among what the
/// House has seen, the nearest to where the view looks first; the view
/// brought there and what stands there chosen, or a company of the House
/// kept chosen to be sent; Next for the one after, round again; none seen
/// said so. The search itself is held in NullmereCoreTests (`SeekingTests`).
@MainActor
final class SeekOnTheLandTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        PressableButtons.isListening = true
    }

    override func tearDown() async throws {
        PressableButtons.isListening = false
        try? FileManager.default.removeItem(at: dir)
    }

    private func draw(_ view: some View, width: CGFloat = 340, height: CGFloat = 400) {
        PressableButtons.isListening = true
        let renderer = ImageRenderer(content: view.frame(width: width, height: height).background(Color.black))
        renderer.scale = 1
        XCTAssertNotNil(renderer.cgImage)
    }

    private var shown: [String] { PressableButtons.actions.keys.sorted() }

    func testTheNearestSeenIsSoughtThenTheNext() throws {
        var state = GameState(settings: GameSettings(seedText: "seeking on the mac", houseCount: 4, radius: 16, keepers: 1))
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me)).position
        state.reveal(around: seat, range: 6, for: me)
        // Both in sight, for a keeper's view holds only the wilds in sight.
        let sight = state.visibility(for: me)
        func ground(_ distance: Int) -> Hex? {
            state.map.hexes.first { hex in
                hex.distance(to: seat) == distance && state.hold(at: hex) == nil && state.map.index(of: hex).map { sight[$0] } == true
            }
        }
        let near = try XCTUnwrap(ground(1))
        let far = try XCTUnwrap((2...4).reversed().lazy.compactMap { ground($0) }.first)
        state.wilds = [Wild(id: 1, kind: .reavers, level: 4, position: far, raised: 1),
                       Wild(id: 2, kind: .saltwights, level: 2, position: near, raised: 1)]
        state.sites = []
        let session = GameSession(state: state, store: LocalStore(directory: dir))
        session.dismissSeatBriefing()
        session.glide(to: seat, reducesMotion: true)
        XCTAssertEqual(session.camera.centreHex, seat)
        session.panel = .realm

        // Sought from the Realm panel: the nearest to where the view looks.
        draw(SeekSection(session: session))
        XCTAssertTrue(PressableButtons.press("Wilds"), "Among \(shown)")
        XCTAssertEqual(session.sought?.at, near)
        XCTAssertEqual(session.selection, .tile(near), "what stands there chosen")
        XCTAssertEqual(session.panel, .realm, "the panel stays, for the next")
        XCTAssertEqual(SeekSection.line(session.sought, in: session.state),
                       "Saltwights, level II, \(GameState.waySaid(to: near, from: seat)) of where you looked; 1 of 2 seen")

        // Next: the one after, from where the search began, then round again.
        draw(SeekSection(session: session))
        XCTAssertTrue(PressableButtons.press("Next"), "Among \(shown)")
        XCTAssertEqual(session.sought?.at, far)
        XCTAssertEqual(session.selection, .tile(far))
        XCTAssertEqual(session.seekNext(), near, "round to the nearest again")

        // A company of the House chosen stays chosen, to be sent there.
        let company = try XCTUnwrap(session.state.units(of: me).first { $0.kind.isMilitary })
        session.selection = .unit(company.id)
        XCTAssertEqual(session.seek(.wilds), near)
        XCTAssertEqual(session.selection, .unit(company.id))

        // None seen: said so, and nothing chosen or moved.
        XCTAssertNil(session.seek(.timber))
        XCTAssertEqual(SeekSection.line(session.sought, in: session.state), Seeking.timber.noneSeen)
        draw(SeekSection(session: session))
        XCTAssertFalse(PressableButtons.press("Next"), "no next where none was seen: \(shown)")
        XCTAssertEqual(session.selection, .unit(company.id))

        // Drawn in the Realm panel, every kind offered.
        draw(RealmPanel(session: session), width: 360, height: 2400)
        for seeking in Seeking.allCases {
            XCTAssertNotNil(PressableButtons.actions[seeking.title], "\(seeking.title) among \(shown)")
        }
    }

    func testWhatIsFoundIsNamedAsTheMapNamesIt() throws {
        var state = GameState(settings: GameSettings(seedText: "named as found", houseCount: 4, radius: 16, keepers: 1))
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me)).position
        let ground = try XCTUnwrap(state.map.hexes.first { $0.distance(to: seat) == 3 && state.hold(at: $0) == nil })
        state.sites = [Site(id: 1, store: .stone, level: 3, position: ground, found: 1)]
        XCTAssertEqual(SeekSection.named(ground, in: state), "\(Site.title(of: .stone)) III, 900 stone left")
        state.sites = []
        state.finds = [Find(id: 1, kind: .hamlet, position: ground, name: "Ashby")]
        XCTAssertEqual(SeekSection.named(ground, in: state), "The hamlet of Ashby")
        state.finds = []
        state.shrines = [Shrine(id: 1, kind: .moonwell, position: ground)]
        XCTAssertTrue(SeekSection.named(ground, in: state).hasSuffix(", held by none"), SeekSection.named(ground, in: state))
        state.shrines = []
        XCTAssertEqual(SeekSection.named(ground, in: state), state.keptName(of: ground), "else as the ground goes by")
        XCTAssertNil(SeekSection.line(nil, in: state), "nothing said before a search")
        _ = me
    }
}
