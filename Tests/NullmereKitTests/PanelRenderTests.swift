import FoundationModels
import LauncherKit
@testable import NullmereCore
import NullmereRealm
import SwiftUI
import XCTest
@testable import NullmereKit
import NullmereTestSupport

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
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "panels", keepers: 1)), store: LocalStore(directory: dir))
        session.autoplay(watches: 40)
        return session
    }

    /// `lit`: whether something must show (true), nothing may (false), or
    /// either (nil), for what ImageRenderer can't draw: a scroll view's
    /// contents, which are drawn on their own instead.
    @discardableResult
    private func draw(_ view: some View, width: CGFloat, height: CGFloat? = nil, lit: Bool? = true) throws -> CGImage {
        let renderer = ImageRenderer(content: view.frame(width: width, height: height).background(Color.black))
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage)
        XCTAssertEqual(CGFloat(image.width), width)
        switch lit {
        case true?: XCTAssertGreaterThanOrEqual(litPixels(image), 20, "Drawn, not blank")
        case false?: XCTAssertLessThan(litPixels(image), 20, "Nothing to draw")
        case nil: break
        }
        return image
    }

    /// A hold at work: the work it raises and the company it musters, each
    /// with the watches it has to go, the next watch, or, trained with no
    /// ground to stand on, waiting for room; and on its alliance's land, the
    /// share of all it yields the land gives it.
    func testAHoldAtWorkTellsWhatItRaisesAndMusters() throws {
        var state = GameState(settings: GameSettings(seedText: "hold at work", keepers: 1))
        let me = state.player
        state.houses[me].stock = Stock(grain: 9_000, timber: 9_000, stone: 9_000, moonsalt: 900)
        let seat = try XCTUnwrap(state.seat(of: me))
        let index = try XCTUnwrap(state.holdIndex(seat.id))
        _ = try state.perform(.build(hold: seat.id, kind: .granary), as: me)
        // A Muster Hall at the seat: every company of war, spears the first,
        // is mustered at one, and a seat has none as the age begins.
        XCTAssertNotNil(state.tierRefusal(of: .spear, tier: 1, at: state.holds[index], for: me), "No Muster Hall, no spears")
        state.holds[index].levels[.musterHall] = 1
        let kind = try XCTUnwrap(UnitKind.allCases.first { $0.hasTiers && state.tierRefusal(of: $0, tier: 1, at: state.holds[index], for: me) == nil })
        XCTAssertEqual(kind, .spear, "Spears, at a Muster Hall of I")
        _ = try state.perform(.train(hold: seat.id, kind: kind, tier: 1), as: me)
        _ = try state.perform(.foundAlliance(name: "Hostward"), as: me)
        let alliance = try XCTUnwrap(state.alliance(of: me))
        var standard = Standard(id: state.takeID(), alliance: alliance.id, raisedBy: me, position: seat.position, raised: state.watch)
        standard.built = Standard.raising
        XCTAssertTrue(standard.isWhole, "Raised whole")
        state.standards = [standard]
        XCTAssertTrue(state.isOnAllianceLand(try XCTUnwrap(state.hold(seat.id))), "Its seat on the alliance's land")
        XCTAssertNotNil(state.holds[index].project)
        XCTAssertNotNil(state.holds[index].training)
        for left in [3, 1, 0] {
            state.holds[index].training?.watchesLeft = left
            let session = GameSession(state: state, store: LocalStore(directory: dir.appendingPathComponent("at-work-\(left)")))
            try draw(OwnHoldDetails(session: session, hold: try XCTUnwrap(session.state.hold(seat.id))), width: 340, height: 1000)
        }
    }

    /// The selection panel for what is chosen: nothing chosen draws nothing;
    /// the keeper's own hold scrolls, so its details are drawn on their own.
    private func drawSelection(_ session: GameSession, width: CGFloat, height: CGFloat) throws {
        if case .none = session.selection {
            try draw(SelectionPanel(session: session), width: width, height: height, lit: false)
        } else if let hold = session.selectedHold, hold.owner == session.player {
            try draw(SelectionPanel(session: session), width: width, height: height, lit: nil)
            try draw(OwnHoldDetails(session: session, hold: hold), width: width, height: 1000)
        } else {
            try draw(SelectionPanel(session: session), width: width, height: height)
        }
    }

    /// A realm wider than ninety-six seats draws its Houses and their race:
    /// the race shows its dozen leaders and the keeper's own place, and says
    /// how many more there are.
    func testAWideRealmsHousesAndRaceDraw() throws {
        let state = GameState(settings: GameSettings(seedText: "a wide realm's Houses", houseCount: 128,
                                                     radius: RealmState.radius(forSeats: 128), keepers: 1))
        let session = GameSession(state: state, store: LocalStore(directory: dir))
        let shown = Standing.shown(session.standings, to: session.player)
        let leading = session.standings.prefix(Standing.leaders).contains { $0.house == session.player }
        XCTAssertEqual(shown.count, Standing.leaders + (leading ? 0 : 1), "Its leaders and the keeper's own place")
        XCTAssertEqual(RaceTable.more(session.standings.count - shown.count), "\(128 - shown.count) more Houses, further from winning")
        try draw(HousesPanel(session: session), width: 360, height: 900)
        // A House found by its name among them, or none.
        let far = try XCTUnwrap(state.houses.last)
        try draw(HousesPanel(session: session, looking: "house \(far.name.lowercased())"), width: 360, height: 900)
        try draw(HousesPanel(session: session, looking: "Qqx"), width: 360, height: 900)
        XCTAssertEqual(state.houses.filter { $0.id != session.player && HouseChoice.isNamed($0.name, by: "Qqx") }.count, 0)
        try draw(RaceTable(session: session), width: 360)
        // The story of the age: the dozen holding most and the keeper's own, not a line for each House.
        let told = StoryChart.told(in: state, player: session.player)
        XCTAssertEqual(told.count, Standing.leaders + (told.prefix(Standing.leaders).contains(session.player) ? 0 : 1))
        XCTAssertTrue(told.contains(session.player))
        XCTAssertEqual(Set(StoryChart.points(for: state, houses: told).map(\.house)), Set(told))
        XCTAssertEqual(StoryChart(state: state, player: session.player).makeChartDescriptor().series.count, told.count)
        try draw(StoryChart(state: state, player: session.player), width: 360, height: 180)
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

    /// The Guide's sections each headed by a picture of what they tell of,
    /// painted from the world's own models, the House's own in its colours,
    /// the keys alone with none; kept as a window draws the panel.
    func testTheGuideIsPictured() throws {
        let session = busySession()
        let pictured = Guide.sections.filter { $0.picture != nil }
        XCTAssertEqual(pictured.map(\.title), Guide.sections.dropLast().map(\.title), "Every section but the keys")
        XCTAssertNil(Guide.sections.last?.picture, "The keys need none")
        XCTAssertEqual(Set(pictured.compactMap(\.picture)).count, pictured.count, "Each its own")
        XCTAssertEqual(pictured.filter(\.housed).map(\.title),
                       ["The watch", "Holds", "Companies", "Tiers and studies", "Commanders", "Houses", "Alliances and rallies",
                        "Happenings and charges", "Winning"], "What is the House's own in its colours; the land, the wilds and the omens in none")
        guard Portraits.shared.prepareNow() else { throw XCTSkip("No Metal device to paint with") }
        let colour = Portrait.colour(of: session.player, in: session.state)
        for section in pictured {
            XCTAssertNotNil(Portraits.shared.image(of: try XCTUnwrap(section.picture), colour: section.housed ? colour : nil),
                            "\(section.title)'s picture painted")
        }
        try CardShot.keep(GuidePanel(session: session).padding(20), as: "game-guide.png", size: CGSize(width: 420, height: 760))
    }

    /// The alliance's marks on the keeper's panels: on the ground card the
    /// mark made there, in its hue with its words, who made it and how long
    /// it stands, with its leader's Lift; unfolded, what a mark may bid;
    /// and the alliance panel listing every mark with Look. Kept as a
    /// window draws it for CI's screenshots (game-mark.png).
    @MainActor
    func testTheAlliancesMarksAreOnTheGroundCardAndTheAlliancePanel() throws {
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "marks on the card", keepers: 1)),
                                  store: LocalStore(directory: dir.appendingPathComponent("marks")))
        let me = session.player
        XCTAssertTrue(session.perform(.foundAlliance(name: "Lantern Oath")))
        let seat = try XCTUnwrap(session.state.seat(of: me))
        let ground = try XCTUnwrap(seat.position.neighbors.first { session.isExplored($0) && session.state.hold(at: $0) == nil })
        XCTAssertTrue(MarkRow.offered(at: ground, in: session.state, player: me), "Its leader may mark it")
        XCTAssertTrue(session.perform(.markGround(ground, .gather, words: "Bring the spears")))
        let mark = try XCTUnwrap(session.state.marksSeen(by: me).first)
        XCTAssertEqual(mark.at, ground)
        XCTAssertEqual(mark.words, "Bring the spears")
        XCTAssertEqual(GameSession.place(of: .groundMarked(mark), in: session.state), ground, "Heard from where it lies")
        XCTAssertEqual(GameSession.cue(forDepth: .groundMarked(mark), in: session.state, player: me), nil, "Its own leader hears no horn for it")
        session.selection = .tile(ground)
        try draw(SelectionPanel(session: session), width: PanelWidth.record)
        try CardShot.keep(MarkRow(session: session, hex: ground, open: true, words: "Hold till dawn")
            .padding(16).frame(width: PanelWidth.record).panelBackground().padding(20),
                          as: "game-mark.png")
        _ = try CardShot.draw(AlliancePanel(session: session), size: CGSize(width: PanelWidth.rail + 40, height: 700))
        // Lifted, the card offers marking it again, and the alliance lists none.
        XCTAssertTrue(session.perform(.unmarkGround(mark.id)))
        XCTAssertTrue(session.state.marksSeen(by: me).isEmpty)
        try draw(SelectionPanel(session: session), width: PanelWidth.record)
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
            try drawSelection(session, width: 320, height: 600)
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

    /// How the voices stand, in the game's settings, by Apple's own word on
    /// its model: who speaks through it, or who falls silent and why.
    func testTheSettingsSayHowTheVoicesStand() {
        XCTAssertEqual(GameSettingsView.voices(.available), CounselTrouble.voicesReady)
        XCTAssertEqual(GameSettingsView.voices(.unavailable(.deviceNotEligible)), CounselTrouble.Unavailability.deviceNotEligible.voicesSaid)
        XCTAssertEqual(GameSettingsView.voices(.unavailable(.appleIntelligenceNotEnabled)),
                       CounselTrouble.Unavailability.appleIntelligenceOff.voicesSaid)
        XCTAssertEqual(GameSettingsView.voices(.unavailable(.modelNotReady)), CounselTrouble.Unavailability.modelNotReady.voicesSaid)
    }

    func testEveryStanceAndEveryEnvoyDraws() throws {
        var state = GameState(settings: GameSettings(seedText: "every stance", houseCount: 6, radius: 22, keepers: 1))
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
        XCTAssertEqual(HouseRow.keeping(session.state.houses[others[2]], present: ["Someone"]), "Its keeper is away; after two watches a caretaker keeps it, beginning no war, demand or pact.")
        XCTAssertEqual(HouseRow.keeping(session.state.houses[others[0]], present: nil), "A steward gives its orders.")
    }

    /// Everything a House's row can tell: a fallen House, a sworn one, the
    /// pacts broken between two Houses, a Moonspire rising, the goodwill of
    /// gifts, and an envoy's words as the on-device voice spoke them.
    func testAHouseRowTellsAllThatLiesBetweenTwoHouses() throws {
        var state = GameState(settings: GameSettings(seedText: "all between", houseCount: 6, radius: 22, keepers: 1))
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
        // As a window draws it, the sending House's seat painted, kept with CI's screenshots.
        Portraits.shared.prepareNow()
        try CardShot.keep(EnvoyCards(session: session).padding(30), as: "game-envoy.png")
    }

    /// A chronicle's entry with the words the chronicler spoke for it,
    /// kept from before.
    func testTheChronicleShowsWhatWasSpokenOfIt() throws {
        let state = GameState(settings: GameSettings(seedText: "spoken chronicle", houseCount: 4, radius: 18, keepers: 1))
        XCTAssertFalse(state.chronicle.isEmpty, "The age's first entry")
        let store = LocalStore(directory: dir.appendingPathComponent("chronicle"))
        store.saveVoices([GameSession.Spoken.chronicle(0).key: "The lake took the first of them without a sound."])
        let session = GameSession(state: state, store: store)
        XCTAssertEqual(session.spoken[.chronicle(0)], "The lake took the first of them without a sound.")
        try draw(ChroniclePanel(session: session), width: 360, height: 700)
    }

    /// The Reports show the dreams the Still showed the House, in its own
    /// voice where this Mac's model gave it one, and plainly beneath.
    func testTheReportsShowTheHousesDreams() throws {
        var state = GameState(settings: GameSettings(seedText: "dreams told", houseCount: 4, radius: 18, keepers: 1))
        state.watch = GameState.dreamingMoon
        _ = state.dream()
        let dream = try XCTUnwrap(state.dreams(of: state.player).first)
        let store = LocalStore(directory: dir.appendingPathComponent("dreams"))
        store.saveVoices([GameSession.Spoken.dream(dream.watch).key: "The water showed you a host upon the far shore."])
        let session = GameSession(state: state, store: store)
        XCTAssertEqual(session.spoken[.dream(dream.watch)], "The water showed you a host upon the far shore.")
        XCTAssertEqual(GameSession.Spoken(key: "dream-15"), .dream(15))
        try draw(ChroniclePanel(session: session, shown: .reports), width: 360, height: 700)
        XCTAssertEqual(ChroniclePanel.subtitle(.reports), "Your House's dreams, battles and scouting, the latest first")
        let moment = VoiceFacts.dream(dream, in: state)
        XCTAssertEqual(moment.kind, .dream)
        XCTAssertEqual(moment.facts, [state.told(dream), "It is the dark of the moon."])
        XCTAssertTrue(moment.prompt.contains("dark of the moon"), moment.prompt)
    }

    /// The Remembering's riddle in the Still's voice where this Mac's model
    /// gave it one, its blank kept, and plainly beneath; the model is
    /// never given the name taken out.
    func testTheRiddleIsSetInTheStillsVoice() throws {
        var state = GameState(settings: GameSettings(seedText: "a riddle voiced", houseCount: 4, radius: 18, keepers: 1))
        state.chronicle = []
        state.drowned = ["House Aske", "House Brine", "House Corrow", "House Dovet"].enumerated().map { index, house in
            DrownedHold(position: Hex(index, 0), name: "Hold \(index)", house: house, age: 1, works: 3, spire: 0)
        }
        state.watch = GameState.lunarMonth + 7
        _ = state.setRiddles()
        let riddle = try XCTUnwrap(state.riddle(of: state.player))
        let answer = try XCTUnwrap(riddle.answer)
        let spoken = "Whose House was it, ———, that held a hold the water took in the first age?"
        let store = LocalStore(directory: dir.appendingPathComponent("riddle"))
        store.saveVoices([GameSession.Spoken.riddle(riddle.set).key: spoken])
        let session = GameSession(state: state, store: store)
        XCTAssertEqual(session.spoken[.riddle(riddle.set)], spoken)
        XCTAssertEqual(GameSession.Spoken(key: "riddle-37"), .riddle(37))
        XCTAssertEqual(GameSession.Spoken.riddle(37).key, "riddle-37")
        try draw(RiddleSection(session: session, riddle: riddle, open: true), width: 360, height: 400)
        let moment = VoiceFacts.riddle(riddle)
        XCTAssertEqual(moment.kind, .riddle)
        XCTAssertEqual(moment.facts, [riddle.line, "It is the half moon."])
        XCTAssertFalse(moment.prompt.contains(answer), "The name taken out is never given")
        XCTAssertTrue(moment.prompt.contains("half moon"), moment.prompt)
        XCTAssertEqual(VoiceCheck.problems(of: "Whose House held the drowned hold in the first age?", for: moment), ["loses the riddle's blank"])
        XCTAssertEqual(VoiceCheck.problems(of: spoken, for: moment), [])
    }

    /// What the selection panel shows of a hold whose works are all built,
    /// a foreign hold out of sight with its Moonspire rising, and ground
    /// no lantern has seen.
    func testTheSelectionPanelAtItsEdges() throws {
        // The works open, each standing complete.
        UserDefaults.standard.set(true, forKey: OwnHoldDetails.worksKey)
        defer { UserDefaults.standard.removeObject(forKey: OwnHoldDetails.worksKey) }
        var state = GameState(settings: GameSettings(seedText: "selection edges", houseCount: 4, radius: 18, keepers: 1))
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
        try drawSelection(session, width: 340, height: 900)
        session.selection = .hold(session.state.holds[theirs].id)
        try drawSelection(session, width: 340, height: 500)
        let unseen = try XCTUnwrap(session.state.map.hexes.first { !session.isExplored($0) })
        session.selection = .tile(unseen)
        try drawSelection(session, width: 340, height: 300)
    }

    func testTheTopBarInEveryStateOfTheRealm() throws {
        let link = SilentLink()
        let state = GameState(settings: GameSettings(seedText: "top bar states", houseCount: 4, radius: 18, keepers: 1))
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
