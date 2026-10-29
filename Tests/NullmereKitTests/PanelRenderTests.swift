import LauncherKit
@testable import NullmereCore
import NullmereRealm
import SwiftUI
import XCTest
@testable import NullmereKit

/// Every panel a keeper sees draws, over a game well under way, at the
/// sizes a Mac shows it and with larger text: a panel that can't lay out
/// its world is caught here, not by a player.
@MainActor
final class PanelRenderTests: XCTestCase {
    private var dir: URL!

    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        TextSize.shared.isLarger = false
    }

    private func busySession() -> GameSession {
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "panels")), store: LocalStore(directory: dir))
        session.autoplay(watches: 40)
        return session
    }

    @discardableResult
    private func draw(_ view: some View, width: CGFloat, height: CGFloat? = nil) throws -> CGImage {
        let renderer = ImageRenderer(content: view.frame(width: width, height: height).background(Color.black))
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage)
        XCTAssertEqual(CGFloat(image.width), width)
        return image
    }

    func testThePanelsDrawAGameUnderWay() throws {
        let session = busySession()
        for larger in [false, true] {
            TextSize.shared.isLarger = larger
            try draw(ChroniclePanel(session: session), width: 360, height: 700)
            try draw(GuidePanel(session: session), width: 360, height: 700)
            try draw(HousesPanel(session: session), width: 360, height: 700)
            try draw(RaceTable(session: session), width: 360)
            try draw(StoryChart(state: session.state, player: session.player), width: 360, height: 180)
            for width in [960.0, 1512.0] {
                try draw(TopBar(session: session), width: width)
            }
            try draw(TopBar(session: session, compact: true), width: 760)
        }
    }

    func testTheSelectionPanelDrawsWhateverIsChosen() throws {
        let session = busySession()
        let state = session.state
        var choices: [GameSession.Selection] = [.none]
        if let unit = state.units.first(where: { $0.owner == session.player }) { choices.append(.unit(unit.id)) }
        if let unit = state.units.first(where: { $0.owner != session.player }) { choices.append(.unit(unit.id)) }
        if let hold = state.holds.first(where: { $0.owner == session.player }) { choices.append(.hold(hold.id)) }
        if let hold = state.holds.first(where: { $0.owner != session.player }) { choices.append(.hold(hold.id)) }
        if let hold = state.holds.first { choices.append(.tile(hold.position)) }
        // A company of every kind there is, and ground of every kind.
        for kind in UnitKind.allCases {
            if let unit = state.units.first(where: { $0.kind == kind }) { choices.append(.unit(unit.id)) }
        }
        for terrain in Terrain.allCases {
            if let hex = state.map.hexes.first(where: { state.map[$0]?.terrain == terrain && session.isExplored($0) }) {
                choices.append(.tile(hex))
            }
        }
        // A hold of the keeper's with works and a company under way.
        if let hold = state.holds.first(where: { $0.owner == session.player }) {
            _ = BuildingKind.allCases.contains { session.perform(.build(hold: hold.id, kind: $0)) }
            _ = UnitKind.allCases.contains { session.perform(.train(hold: hold.id, kind: $0)) }
            choices.append(.hold(hold.id))
        }
        XCTAssertGreaterThanOrEqual(choices.count, 4, "A game under way has companies and holds of its own and others'")
        for choice in choices {
            session.selection = choice
            try draw(SelectionPanel(session: session), width: 320, height: 600)
        }
    }

    func testEachStoreHasAnAccountToShow() throws {
        let session = busySession()
        for resource in Resource.allCases {
            let breakdown = IncomeBreakdown(state: session.state, house: session.player, resource: resource, territory: session.territory)
            try draw(IncomeCard(breakdown: breakdown), width: 300)
        }
    }

    func testTheFrontDoorAndSettingsDraw() throws {
        let identity = FileIdentityStore(url: dir.appendingPathComponent("identity"))
        UserDefaults.standard.removeObject(forKey: GameApp.nameKey(for: .hosted(seed: "front door")))
        let app = GameApp(store: LocalStore(directory: dir), readiness: { .ready }, sound: false,
                          address: .hosted(seed: "front door"), identity: identity)
        app.checkModel()
        guard case .frontDoor = app.phase else { return XCTFail("A ready model opens the front door") }
        for width in [960.0, 1512.0] {
            try draw(FrontDoor(app: app), width: width, height: 700)
        }
        try draw(GameSettingsView(app: app), width: 480, height: 520)
        // Every way the realm can look from its door.
        let full = RealmStatus(name: "The Nullmere", age: 2, watch: 40, seats: 12, freeSeats: 0, keepers: 12, online: 9, ready: 3,
                               secondsLeft: 75, isEnding: false, present: ["Ama", "Bel", "Cor"], lake: "Twin")
        let ending = RealmStatus(name: "The Nullmere", age: 2, watch: 90, seats: 12, freeSeats: 4, keepers: 8, online: 1, ready: 0,
                                 secondsLeft: 5, isEnding: true)
        for door in [GameApp.Door.connecting, .unreachable("No answer from the server."), .open(full), .open(ending)] {
            try draw(RealmLine(door: door), width: 600)
        }
        try draw(LakeTitle(size: CGSize(width: 1200, height: 760)), width: 1200)
        app.enterWorld(name: "Ama")
        let session = try XCTUnwrap(app.session)
        try draw(TopBar(session: session), width: 1200)
        try draw(GameSettingsView(app: app), width: 480, height: 520)
    }

    func testEveryStanceAndEveryEnvoyDraws() throws {
        var state = GameState(settings: GameSettings(seedText: "every stance", houseCount: 6, radius: 22))
        let me = state.player
        let others = state.houses.indices.filter { $0 != me }
        state.setStance(.war, between: me, and: others[0], by: me)
        state.setStance(.pact, between: me, and: others[1], by: me)
        state.houses[others[2]].isPlayer = true
        state.houses[others[3]].liege = me
        for (index, proposal) in Proposal.allCases.enumerated() {
            let trade = proposal == .trade ? Trade(give: .timber, 20, for: .grain, 15) : nil
            state.envoys.append(Envoy(id: 900 + index, from: others[index % others.count], to: me, proposal: proposal,
                                      arrived: state.watch, words: index == 0 ? "Hear us." : nil, trade: trade))
        }
        let session = GameSession(state: state, store: LocalStore(directory: dir))
        for larger in [false, true] {
            TextSize.shared.isLarger = larger
            try draw(HousesPanel(session: session), width: 360, height: 900)
            for house in session.state.houses where house.id != me {
                try draw(HouseRow(session: session, house: house, draft: OfferDraft(for: house)), width: 340)
            }
            try draw(EnvoyCards(session: session), width: 360)
        }
        for envoy in session.envoys {
            let line = EnvoyCards.words(for: envoy, from: session.state.houses[envoy.from], in: session.state, player: me)
            XCTAssertFalse(line.isEmpty, "\(envoy.proposal)")
        }
        XCTAssertEqual(HouseRow.keeping(session.state.houses[others[2]], present: ["Someone"]), "Its keeper is away; it stands as they left it.")
        XCTAssertEqual(HouseRow.keeping(session.state.houses[others[0]], present: nil), "A steward gives its orders.")
    }

    /// Everything a House's row can tell: a fallen House, a sworn one, the
    /// pacts broken between two Houses, a Moonspire rising, the goodwill of
    /// gifts, and an envoy's words as the on-device voice spoke them.
    func testAHouseRowTellsAllThatLiesBetweenTwoHouses() throws {
        var state = GameState(settings: GameSettings(seedText: "all between", houseCount: 6, radius: 22))
        let me = state.player
        let others = state.houses.indices.filter { $0 != me }
        state.setStance(.war, between: me, and: others[0], by: others[0])
        let index = try XCTUnwrap(state.relations.firstIndex { [$0.first, $0.second].sorted() == [me, others[0]].sorted() })
        state.relations[index].betrayals = 2
        state.relations[index].since = max(state.watch - 3, 1)
        state.houses[others[1]].liege = others[0]
        state.houses[others[2]].isEliminated = true
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == others[0] && $0.isSeat })
        state.holds[seat].levels[.moonspire] = 2
        state.gifts = [Gift(from: me, to: others[0], worth: 45, watch: state.watch)]
        let envoy = Envoy(id: 77, from: others[0], to: me, proposal: .peace, arrived: state.watch)
        state.envoys.append(envoy)
        let store = LocalStore(directory: dir.appendingPathComponent("between"))
        store.saveVoices([GameSession.Spoken.envoy(77).key: "The water remembers the last war. Let it rest."])
        let session = GameSession(state: state, store: store)
        XCTAssertEqual(session.spoken[.envoy(77)], "The water remembers the last war. Let it rest.")
        for house in [others[0], others[1], others[2]] {
            try draw(HouseRow(session: session, house: session.state.houses[house], draft: OfferDraft(for: session.state.houses[house])), width: 340)
        }
        try draw(HousesPanel(session: session), width: 360, height: 900)
        try draw(EnvoyCards(session: session), width: 360)
    }

    /// A chronicle's entry with the words the chronicler spoke for it,
    /// kept from before.
    func testTheChronicleShowsWhatWasSpokenOfIt() throws {
        let state = GameState(settings: GameSettings(seedText: "spoken chronicle", houseCount: 4, radius: 18))
        XCTAssertFalse(state.chronicle.isEmpty, "The age's first entry")
        let store = LocalStore(directory: dir.appendingPathComponent("chronicle"))
        store.saveVoices([GameSession.Spoken.chronicle(0).key: "The lake took the first of them without a sound."])
        let session = GameSession(state: state, store: store)
        XCTAssertEqual(session.spoken[.chronicle(0)], "The lake took the first of them without a sound.")
        try draw(ChroniclePanel(session: session), width: 360, height: 700)
    }

    /// What the selection panel shows of a hold whose works are all built,
    /// a foreign hold out of sight with its Moonspire rising, and ground
    /// no lantern has seen.
    func testTheSelectionPanelAtItsEdges() throws {
        var state = GameState(settings: GameSettings(seedText: "selection edges", houseCount: 4, radius: 18))
        let me = state.player
        let mine = try XCTUnwrap(state.holds.firstIndex { $0.owner == me })
        for kind in BuildingKind.allCases where !kind.requiresSeat || state.holds[mine].isSeat {
            state.holds[mine].levels[kind] = kind.maxLevel
        }
        let theirs = try XCTUnwrap(state.holds.firstIndex { $0.owner != me && $0.isSeat })
        state.holds[theirs].levels[.moonspire] = 3
        state.houses[me].explored[state.map.index(of: state.holds[theirs].position)!] = true
        let session = GameSession(state: state, store: LocalStore(directory: dir.appendingPathComponent("edges")))
        session.selection = .hold(session.state.holds[mine].id)
        try draw(SelectionPanel(session: session), width: 340, height: 900)
        session.selection = .hold(session.state.holds[theirs].id)
        try draw(SelectionPanel(session: session), width: 340, height: 500)
        let unseen = try XCTUnwrap(session.state.map.hexes.first { !session.isExplored($0) })
        session.selection = .tile(unseen)
        try draw(SelectionPanel(session: session), width: 340, height: 300)
    }

    func testTheTopBarInEveryStateOfTheRealm() throws {
        let link = SilentLink()
        let state = GameState(settings: GameSettings(seedText: "top bar states", houseCount: 4, radius: 18))
        let session = GameSession(link: link, house: state.player, world: state.view(for: state.player), store: LocalStore(directory: dir))
        let status = RealmStatus(name: "The Nullmere", age: 1, watch: 3, seats: 4, freeSeats: 1, keepers: 3, online: 3, ready: 1,
                                 secondsLeft: 134, isEnding: false)
        link.onEvent?(.status(status))
        XCTAssertEqual(EndWatchButton.realmLine(status: status, secondsLeft: session.secondsLeft()), "Turns in 2:14 · 1 of 3 ready")
        XCTAssertNil(EndWatchButton.realmLine(status: nil, secondsLeft: 10))
        try draw(TopBar(session: session), width: 1200)
        try draw(WatchClock(session: session), width: 400)
        session.endWatch()
        XCTAssertTrue(session.isReady)
        try draw(EndWatchButton(session: session), width: 200)
        session.cancelReady()
        link.onEvent?(.unreachable("No answer."))
        XCTAssertTrue(session.isOutOfReach)
        try draw(WatchClock(session: session), width: 400)
        try draw(TopBar(session: session, compact: true), width: 800)
        try draw(NoticeFeed(session: session), width: 400)
        let empty = IncomeBreakdown(state: state, house: state.player, resource: .moonsalt)
        try draw(IncomeCard(breakdown: empty), width: 260)
    }
}

/// A link that tells only what a test makes it.
@MainActor
private final class SilentLink: RealmLink {
    var onEvent: ((RealmEvent) -> Void)?
    func connect() {}
    func arrive(name: String?) {}
    func send(_ command: Command) {}
    func setReady(_ ready: Bool) {}
    func leave() {}
}

final class FlowLayoutTests: XCTestCase {
    func testViewsWrapIntoRows() {
        let sizes = [CGSize(width: 80, height: 20), CGSize(width: 70, height: 24), CGSize(width: 90, height: 20), CGSize(width: 400, height: 22)]
        let rows = FlowLayout.rows(of: sizes, width: 200, spacing: 4)
        XCTAssertEqual(rows.map(\.indices), [[0, 1], [2], [3]], "Two fit, the third wraps, an over-wide one stands alone")
        XCTAssertEqual(rows[0].width, 154)
        XCTAssertEqual(rows[0].height, 24)
        XCTAssertEqual(FlowLayout.rows(of: sizes, width: .infinity, spacing: 4).count, 1, "Unbounded, all in one row")
        XCTAssertTrue(FlowLayout.rows(of: [], width: 100, spacing: 4).isEmpty)
    }
}

@MainActor
final class ScrollEdgeFadeTests: XCTestCase {
    /// The brightest pixel in a band of rows.
    private func brightest(_ image: CGImage, rows: Range<Int>) throws -> Int {
        let width = image.width
        var pixels = [UInt8](repeating: 0, count: width * image.height * 4)
        let drawn = pixels.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(data: raw.baseAddress, width: width, height: image.height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: image.height))
            return true
        }
        XCTAssertTrue(drawn)
        var most = 0
        for y in rows {
            for x in 0..<width {
                let i = (y * width + x) * 4
                most = max(most, Int(pixels[i]) + Int(pixels[i + 1]) + Int(pixels[i + 2]))
            }
        }
        return most
    }

    func testAPanelFadesAtItsEdgeRatherThanCutting() throws {
        // Rows running past the panel's foot, as a long panel's do.
        let lines = VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<60, id: \.self) { _ in
                Rectangle().fill(Color.white).frame(height: 6)
                Color.clear.frame(height: 2)
            }
        }
        .frame(width: 120, height: 200, alignment: .top)
        .clipped()
        let renderer = ImageRenderer(content: lines.scrollEdgeFade().background(Color.black))
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage)
        // The buffer's first row is the image's top; its foot is the last.
        let middle = try brightest(image, rows: 90..<110)
        let edge = try brightest(image, rows: (image.height - 3)..<image.height)
        let top = try brightest(image, rows: 0..<6)
        XCTAssertGreaterThan(top, 600, "The top isn't faded")
        XCTAssertGreaterThan(middle, 600, "Bright above the edge")
        XCTAssertLessThan(edge, middle / 3, "and faded at it: \(edge) against \(middle)")
    }
}
