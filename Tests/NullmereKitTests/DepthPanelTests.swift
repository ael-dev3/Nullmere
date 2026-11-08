import AppKit
@testable import LauncherKit
import NullmereModels
import NullmereRealm
import NullmereWorld
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The screens of the realm's depth, their buttons pressed: the Archive
/// begins a study, the Commanders set one at a company's head and call it
/// back, the Alliance joins, asks, invites, helps and leaves, an enemy hold
/// calls a rally, the charge shows the way, and the rail opens each panel.
/// And the map: a site right-clicked is gathered, the wilds and the sites
/// are read to VoiceOver, and a company says what it was sent to do.
@MainActor
final class DepthPanelTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        PressableButtons.isListening = true
    }

    override func tearDown() async throws {
        PressableButtons.isListening = false
        try? FileManager.default.removeItem(at: dir)
    }

    /// Draws the view afresh, so its buttons are those it shows now.
    private func draw(_ view: some View, width: CGFloat = 360, height: CGFloat = 900) {
        PressableButtons.isListening = true
        let renderer = ImageRenderer(content: view.frame(width: width, height: height).background(Color.black))
        renderer.scale = 1
        XCTAssertNotNil(renderer.cgImage)
    }

    private var shown: [String] { PressableButtons.actions.keys.sorted() }

    private func world(_ seed: String) -> GameState {
        GameState(settings: GameSettings(seedText: seed, houseCount: 6, radius: 20, keepers: 1))
    }

    private func session(_ state: GameState) -> (GameSession, DepthLink) {
        let link = DepthLink()
        let session = GameSession(link: link, house: state.player, world: state.view(for: state.player),
                                  store: LocalStore(directory: dir.appendingPathComponent(UUID().uuidString)))
        session.dismissSeatBriefing()
        return (session, link)
    }

    /// A free, passable hex near another, with nothing on it.
    private func free(near hex: Hex, in state: GameState) throws -> Hex {
        try XCTUnwrap(hex.spiral(3).first { candidate in
            candidate != hex && state.map[candidate]?.terrain.isPassable == true && state.unit(at: candidate) == nil
                && state.hold(at: candidate) == nil && state.wild(at: candidate) == nil && state.site(at: candidate) == nil
        })
    }

    // MARK: The Archive

    func testTheArchiveBeginsAStudy() throws {
        var state = world("pressed archive")
        let me = state.player
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == me && $0.isSeat })
        state.holds[seat].levels[.archive] = 2
        state.houses[me].stock = Stock(grain: 900, timber: 900, stone: 900, moonsalt: 90)
        let (session, link) = session(state)
        draw(ArchivePanel(session: session))
        XCTAssertTrue(PressableButtons.press("Study I"), "Among \(shown)")
        guard case .study(let study)? = link.sent.last else { return XCTFail("A study begun: \(String(describing: link.sent.last))") }
        XCTAssertEqual(session.state.houses[me].research.pursuit?.study, study)
        // One at a time: the rest wait, and say why.
        PressableButtons.isListening = true
        draw(ArchivePanel(session: session))
        XCTAssertFalse(PressableButtons.press("Study I"), "Another is under way")
        XCTAssertEqual(ArchivePanel.why(.waiting), "Another study is under way; one at a time.")
        XCTAssertEqual(ArchivePanel.why(.short(Stock(timber: 20))), "You are short of \(Stock(timber: 20).description).")
        XCTAssertNil(ArchivePanel.why(.open))
        XCTAssertEqual(ArchivePanel.left(1), "Done next watch")
        XCTAssertEqual(ArchivePanel.subtitle(session.state.archiveBoard(for: me)), "Archive II · 0 of \(ArchiveBoard.gradesInAll) grades learned")
        XCTAssertEqual(ArchivePanel.subtitle(world("no archive").archiveBoard(for: 0)), "No Archive yet")
    }

    // MARK: Commanders

    func testACommanderIsSetAtACompanysHeadAndCalledBack() throws {
        let state = world("pressed commanders")
        let (session, link) = session(state)
        let company = try XCTUnwrap(session.state.units(of: session.player).first { $0.kind.isMilitary })
        let commander = try XCTUnwrap(session.state.commanders(of: session.player).first)
        draw(CommandersPanel(session: session))
        XCTAssertFalse(PressableButtons.press("Lead them"), "No company chosen, none to lead")
        XCTAssertTrue(PressableButtons.press("Talents"), "Its talents hidden while no point waits, among \(shown)")
        XCTAssertFalse(PressableButtons.press("Learn"))
        session.selection = .unit(company.id)
        draw(CommandersPanel(session: session))
        XCTAssertTrue(PressableButtons.press("Lead them"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .assign(commander: commander.id, unit: company.id))
        XCTAssertEqual(session.state.company(ledBy: commander.id)?.id, company.id)
        XCTAssertEqual(UnitPanel.leader(of: try XCTUnwrap(session.state.unit(company.id)), in: session.state),
                       "Led by \(commander.name), \(commander.archetype.named) of level 1")
        draw(CommandersPanel(session: session))
        XCTAssertTrue(PressableButtons.press("Call back"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .unassign(commander: commander.id))
        XCTAssertNil(session.state.company(ledBy: commander.id))

        let board = session.state.commandersBoard(for: session.player)
        XCTAssertEqual(CommandersPanel.standing(of: try XCTUnwrap(board.lines.first)), "Free to lead a company of war")
        XCTAssertEqual(CommandersPanel.named(company), "\(company.kind.title) I")
    }

    /// A listening stone sunk in the lake before a hold, and what it heard,
    /// folded under By the water in the hold's record.
    func testAListeningStoneIsSunkAndWhatItHeardIsToldFolded() throws {
        var state = world("pressed stone")
        let me = state.player
        let seatIndex = try XCTUnwrap(state.holds.firstIndex { $0.owner == me && $0.isSeat })
        let shore = try XCTUnwrap(state.map.hexes.first { state.isShore($0) && state.hold(at: $0) == nil })
        state.holds[seatIndex].position = shore
        state.houses[me].stock.moonsalt = 30
        // The water before it known to the keeper, as a seat's own shore is.
        state.reveal(around: shore, range: GameState.stoneFromHold, for: me)
        let seat = state.holds[seatIndex]
        XCTAssertTrue(StoneRow.line(state, hold: seat, house: me).contains("hears marches out of sight"))
        XCTAssertTrue(OwnHoldDetails.waterSummary(of: seat, in: state, for: me).contains("a listening stone"))
        let (session, link) = session(state)
        draw(StoneRow(session: session, hold: seat))
        XCTAssertTrue(PressableButtons.press("Sink a stone"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .sinkStone(hold: seat.id))
        XCTAssertEqual(session.state.stones(of: me).count, 1)
        XCTAssertTrue(StoneRow.line(session.state, hold: seat, house: me).contains("begins to listen"))
        XCTAssertEqual(GameSession.cues(for: .sinkStone(hold: seat.id), events: [], in: session.state, player: me), [.lore])
        XCTAssertTrue(OwnHoldDetails.waterSummary(of: seat, in: session.state, for: me).contains("its listening stone"))
    }

    /// A ripple-stone cast from a hold on the shore against the Still Hour.
    func testARippleStoneIsCastFromAHoldOnTheShore() throws {
        var state = world("pressed ripple")
        let me = state.player
        let seatIndex = try XCTUnwrap(state.holds.firstIndex { $0.owner == me && $0.isSeat })
        let shore = try XCTUnwrap(state.map.hexes.first { state.isShore($0) && state.hold(at: $0) == nil })
        state.holds[seatIndex].position = shore
        state.houses[me].stock.moonsalt = 30
        let seat = state.holds[seatIndex]
        XCTAssertTrue(RippleRow.line(state, house: me).contains("hides yours"))
        let (session, link) = session(state)
        draw(RippleRow(session: session, hold: seat))
        XCTAssertTrue(PressableButtons.press("Cast a stone"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .castRipple(hold: seat.id))
        XCTAssertTrue(session.state.hasRippled(me))
        XCTAssertTrue(RippleRow.line(session.state, house: me).contains("mirrors none of yours"))
        XCTAssertEqual(GameSession.cues(for: .castRipple(hold: seat.id), events: [], in: session.state, player: me), [.lore])
    }

    /// A second commander sent to ride with a company that has a leader.
    func testASecondCommanderRidesWithALedCompany() throws {
        var state = world("pressed pairing")
        let me = state.player
        var random = SeededRandom(seed: 11)
        let lead = try XCTUnwrap(state.commanders(of: me).first).id
        let second = try XCTUnwrap(state.raiseCommander(for: me, using: &random)).id
        let seat = try XCTUnwrap(state.seat(of: me))
        let company = try XCTUnwrap(state.units(of: me).first { $0.kind.isMilitary && $0.position.distance(to: seat.position) <= 1 })
        try state.perform(.assign(commander: lead, unit: company.id), as: me)
        let (session, link) = session(state)
        session.selection = .unit(company.id)
        draw(CommandersPanel(session: session))
        XCTAssertTrue(PressableButtons.press("Ride second"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .assignSecond(commander: second, unit: company.id))
        XCTAssertEqual(session.state.unit(company.id)?.second, second)
    }

    func testACommanderLearnsATalentAndForgetsThemAll() throws {
        var state = world("pressed talents")
        let me = state.player
        let id = try XCTUnwrap(state.commanders(of: me).first).id
        state.commanders![id - 1].experience = Commander.experience(forLevel: 3)
        state.houses[me].stock.moonsalt = 50
        let (session, link) = session(state)
        XCTAssertEqual(TalentsView.summary(of: try XCTUnwrap(session.state.commander(id))), "2 talent points to spend")
        draw(CommandersPanel(session: session))
        XCTAssertTrue(PressableButtons.press("Hide talents"), "Shown of itself while points wait, among \(shown)")
        XCTAssertNil(PressableButtons.actions[TalentsView.forgetting], "Nothing learned, nothing to forget")
        XCTAssertTrue(PressableButtons.press("Learn"), "Among \(shown)")
        guard case .learnTalent(id, let talent)? = link.sent.last else { return XCTFail("A talent learned: \(String(describing: link.sent.last))") }
        XCTAssertEqual(talent.place, 0, "Only a tree's first is open")
        XCTAssertEqual(session.state.commander(id)?.rank(of: talent), 1)
        XCTAssertEqual(TalentsView.summary(of: try XCTUnwrap(session.state.commander(id))), "1 talent point to spend")

        draw(CommandersPanel(session: session))
        XCTAssertTrue(PressableButtons.press(TalentsView.forgetting), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .forgetTalents(commander: id))
        XCTAssertEqual(session.state.commander(id)?.talents, [])
        XCTAssertEqual(session.state.houses[me].stock.moonsalt, 30)
        XCTAssertEqual(TalentsView.forgetting, "Forget all · 20 moonsalt")

        var spent = Commander(id: 9, name: "Ysra", archetype: .warden, owner: me)
        XCTAssertEqual(TalentsView.summary(of: spent), "A talent point comes with each level")
        spent.experience = Commander.experience(forLevel: 2)
        spent.talents = [.thickHide]
        XCTAssertEqual(TalentsView.summary(of: spent), "1 talent point spent")
        spent.experience = Commander.experience(forLevel: 4)
        spent.talents = [.thickHide, .thickHide, .thickHide]
        XCTAssertEqual(TalentsView.summary(of: spent), "3 talent points spent")
        draw(TalentsView(session: session, commander: spent))
        XCTAssertTrue(PressableButtons.press("Talents"), "Every point spent: hidden of itself")
    }

    func testACommanderIsArmedFromTheArmouryAndItsGearTakenOffAndBrokenUp() throws {
        var state = world("pressed gear")
        let me = state.player
        let commander = try XCTUnwrap(state.commanders(of: me).first).id
        state.armoury = [Gear(id: state.takeID(), kind: .saltGlaive, quality: .fine, owner: me),
                         Gear(id: state.takeID(), kind: .huntersEye, quality: .plain, owner: me)]
        let (session, link) = session(state)
        draw(CommandersPanel(session: session))
        XCTAssertNil(PressableButtons.actions["Take off"], "Nothing worn yet")
        XCTAssertTrue(PressableButtons.press("Arm"), "Among \(shown)")
        guard case .wear(let piece, commander)? = link.sent.last else { return XCTFail("Armed: \(String(describing: link.sent.last))") }
        XCTAssertEqual(session.state.gear(piece)?.wornBy, commander)

        draw(CommandersPanel(session: session))
        XCTAssertTrue(PressableButtons.press("Take off"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .takeOff(gear: piece))
        XCTAssertNil(session.state.gear(piece)?.wornBy)

        draw(CommandersPanel(session: session))
        let moonsalt = session.state.houses[me].stock.moonsalt
        XCTAssertTrue(PressableButtons.press("Break up"), "Among \(shown)")
        guard case .breakUp(let broken)? = link.sent.last else { return XCTFail("Broken up: \(String(describing: link.sent.last))") }
        XCTAssertNil(session.state.gear(broken))
        XCTAssertGreaterThan(session.state.houses[me].stock.moonsalt, moonsalt)

        // With more commanders, the one to arm is chosen; with none, none is armed.
        let other = Commander(id: 99, name: "Ysra Stillwater", archetype: .warden, owner: me)
        draw(ArmouryView(session: session, commanders: session.state.commanders(of: me) + [other]))
        XCTAssertNotNil(PressableButtons.actions["Arm"])
        draw(ArmouryView(session: session, commanders: []))
        XCTAssertNil(PressableButtons.actions["Arm"], "No commander to arm")
        let (bare, _) = self.session(world("bare armoury"))
        draw(ArmouryView(session: bare, commanders: bare.state.commanders(of: bare.player)))
        XCTAssertNil(PressableButtons.actions["Break up"], "An empty armoury says where gear comes from")
        XCTAssertTrue(ArmouryView.empty.hasPrefix("Gear falls with the wilds struck down"))
    }

    // MARK: Alliances

    func testAnInvitationIsTakenAndAnotherAllianceAsked() throws {
        var state = world("pressed invitations")
        let me = state.player
        let (other, third) = ((me + 1) % 6, (me + 2) % 6)
        state.houses[other].isPlayer = true
        _ = try state.perform(.foundAlliance(name: "The Salt Oath"), as: other)
        _ = try state.perform(.inviteToAlliance(house: me), as: other)
        _ = try state.perform(.foundAlliance(name: "The Grey Hand"), as: third)
        let oath = try XCTUnwrap(state.alliance(of: other)).id
        let (session, link) = session(state)
        draw(AlliancePanel(session: session))
        XCTAssertTrue(PressableButtons.press("Join"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .answerInvitation(alliance: oath, accept: true))
        // Another keeper, the same invitation waiting, asks another alliance instead.
        let (asking, asked) = self.session(state)
        draw(AlliancePanel(session: asking))
        XCTAssertTrue(PressableButtons.press("Refuse"), "Among \(shown)")
        XCTAssertEqual(asked.sent.last, .answerInvitation(alliance: oath, accept: false))
        XCTAssertTrue(PressableButtons.press("Ask to join"), "Among \(shown)")
        guard case .askToJoin? = asked.sent.last else { return XCTFail("Asked: \(String(describing: asked.sent.last))") }
    }

    func testASwornHouseInvitesHelpsAndLeaves() throws {
        let state = world("pressed alliance")
        let (session, link) = session(state)
        XCTAssertFalse(AlliancePanel.raise("x", in: session), "a name that won't do raises nothing")
        XCTAssertTrue(AlliancePanel.raise("The Ashen Ring", in: session))
        XCTAssertEqual(link.sent.last, .foundAlliance(name: "The Ashen Ring"))
        draw(AlliancePanel(session: session))
        XCTAssertTrue(PressableButtons.press("Invite"), "Among \(shown)")
        guard case .inviteToAlliance(let invited)? = link.sent.last else { return XCTFail("Invited: \(String(describing: link.sent.last))") }
        XCTAssertNotEqual(invited, session.player)
        draw(AlliancePanel(session: session))
        XCTAssertTrue(PressableButtons.press("Leave the alliance"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .leaveAlliance)
        XCTAssertEqual(AlliancePanel.when(RallyLine(rally: Rally(id: 1, caller: 0, muster: 1, target: 2, called: 0, setsOut: 3),
                                                    watchesLeft: 2, companies: 1, capacity: 4, isCaller: true)), "Sets out in 2 watches")
        XCTAssertEqual(AlliancePanel.when(RallyLine(rally: Rally(id: 1, caller: 0, muster: 1, target: 2, called: 0, setsOut: 3),
                                                    watchesLeft: 1, companies: 1, capacity: 4, isCaller: true)), "Sets out next watch")
    }

    /// A realm of a hundred and twenty-eight Houses: an alliance's leader is
    /// offered the Houses they have reason to invite, nearest first, and
    /// finds any other by name, not a row for every House unsworn.
    func testAWideRealmsLeaderInvitesAmongTheHousesOffered() throws {
        var state = GameState(settings: GameSettings(seedText: "a wide realm's alliance", houseCount: 128,
                                                     radius: RealmState.radius(forSeats: 128), keepers: 1))
        let me = state.player
        _ = try state.perform(.foundAlliance(name: "The Wide Accord"), as: me)
        let (session, link) = session(state)
        let invitable = session.state.allianceBoard(for: me).invitable
        XCTAssertGreaterThan(invitable.count, HouseChoice.shownWhole)
        let choice = session.state.houseChoice(by: me, excluding: [me], among: Set(invitable))
        let near = try XCTUnwrap(choice.offered.first)
        draw(AlliancePanel(session: session), width: 360, height: 2400)
        XCTAssertEqual(shown.filter { $0.hasPrefix("Invite House") }.count, choice.offered.count, "Among \(shown)")
        XCTAssertLessThan(choice.offered.count, 40, "Not a row for every House unsworn")
        XCTAssertTrue(PressableButtons.press("Invite \(near.title)"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .inviteToAlliance(house: near.id))
    }

    func testAnEnemyHoldCallsARally() throws {
        var state = world("pressed rally")
        let me = state.player
        let foe = (me + 2) % 6
        _ = try state.perform(.foundAlliance(name: "The Ashen Ring"), as: me)
        _ = try state.declareWar(by: me, on: foe)
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == me && $0.isSeat })
        state.holds[seat].levels[.musterHall] = 1
        let target = try XCTUnwrap(state.holds.first { $0.owner == foe })
        state.reveal(around: target.position, range: 1, for: me)
        let (session, link) = session(state)
        session.selection = .hold(target.id)
        draw(SelectionPanel(session: session), width: 330, height: 700)
        XCTAssertTrue(PressableButtons.press("Call a rally"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .callRally(from: state.holds[seat].id, against: target.id, watches: 2))
    }

    // MARK: The realm, the charges and the rail

    func testTheRealmsPanelAndTheChargeShowTheWay() throws {
        var state = world("pressed realm")
        state.happening = Happening(number: 0, kind: .longHunt, begins: state.watch, houses: state.houses.count)
        let (session, _) = session(state)
        draw(RealmPanel(session: session))
        let board = session.state.realmBoard(for: session.player)
        XCTAssertTrue(RealmPanel.mightLine(board, standing: 6).hasPrefix("Might \(board.might)"))
        UserDefaults.standard.removeObject(forKey: "charges.hidden")
        UserDefaults.standard.removeObject(forKey: "charges.open")
        draw(ChargeCard(session: session), width: 330, height: 200)
        // A line until asked for more: how to keep it, and its reward.
        XCTAssertTrue(PressableButtons.press("More"), "Among \(shown)")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "charges.open"))
        draw(ChargeCard(session: session), width: 330, height: 200)
        XCTAssertTrue(PressableButtons.press("Less"), "Among \(shown)")
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "charges.open"))
        draw(ChargeCard(session: session), width: 330, height: 200)
        XCTAssertTrue(PressableButtons.press("Show me"), "Among \(shown)")
        XCTAssertEqual(session.selection, .hold(try XCTUnwrap(session.state.seat(of: session.player)).id), "A Granary is built at the seat")
        for charge in Charge.allCases {
            XCTAssertFalse(ChargeGuide.how(charge).isEmpty)
            ChargeGuide.show(charge, in: session)
        }
        ChargeGuide.show(.swearBanner, in: session)
        XCTAssertEqual(session.panel, .alliance)
        ChargeGuide.show(.leadCompany, in: session)
        XCTAssertEqual(session.panel, .commanders)
        if case .unit = session.selection {} else { XCTFail("A company of war chosen to lead: \(session.selection)") }
        ChargeGuide.show(.learnStudy, in: session)
        XCTAssertEqual(session.panel, .archive)
        ChargeGuide.show(.raiseMusterHall, in: session)
        XCTAssertNil(session.panel, "The seat's works, with nothing over them")
        XCTAssertEqual(session.beckon, .work(.musterHall), "its Build button ringed")
        UserDefaults.standard.removeObject(forKey: OwnHoldDetails.worksKey)
        draw(SelectionPanel(session: session), width: 330, height: 900)
        // The works, folded until asked for, are open on the work it points at.
        XCTAssertTrue(shown.contains { $0.hasPrefix("Build ") }, "Among \(shown)")
        XCTAssertFalse(shown.contains { $0.hasPrefix("All ") && $0.hasSuffix(" works") }, "Held open")
        // Each charge rings what keeps it, where a control does.
        let player = session.player
        XCTAssertEqual(ChargeGuide.beckon(for: .raiseGranary, in: session.state, player: player), .work(.granary))
        XCTAssertEqual(ChargeGuide.beckon(for: .musterCompany, in: session.state, player: player), .train(nil))
        XCTAssertEqual(ChargeGuide.beckon(for: .learnStudy, in: session.state, player: player), .study)
        XCTAssertEqual(ChargeGuide.beckon(for: .leadCompany, in: session.state, player: player), .lead)
        XCTAssertEqual(ChargeGuide.beckon(for: .swearBanner, in: session.state, player: player), .banner)
        XCTAssertNil(ChargeGuide.beckon(for: .huntWild, in: session.state, player: player), "the map shows the way")
        let founders = session.state.units(of: player).contains { $0.kind == .founder }
        XCTAssertEqual(ChargeGuide.beckon(for: .foundHold, in: session.state, player: player), founders ? .found : .train(.founder))
        // An order given, the ring is put away.
        let company = try XCTUnwrap(session.state.units(of: player).first { $0.kind.isMilitary })
        XCTAssertTrue(session.perform(.fortify(unit: company.id)))
        XCTAssertNil(session.beckon)
    }

    func testTheRailOpensAndClosesEachPanel() throws {
        let (session, _) = session(world("pressed rail"))
        // Folded to one button until asked for, so the world has the screen.
        draw(PanelRail(session: session), width: 720, height: 40)
        XCTAssertFalse(PressableButtons.actions.keys.contains("Houses"), "Folded: \(shown)")
        XCTAssertTrue(PressableButtons.press("Panels"), "Among \(shown)")
        XCTAssertTrue(session.railShown)
        draw(PanelRail(session: session), width: 720, height: 40)
        XCTAssertEqual(PanelRail.panels.map { $0.panel }, [.houses, .chronicle, .archive, .commanders, .alliance, .realm, .words, .guide],
                       "Every panel on the rail, and nowhere else")
        for (title, panel, _) in PanelRail.panels {
            XCTAssertTrue(PressableButtons.press(title), "Among \(shown)")
            XCTAssertEqual(session.panel, panel)
            XCTAssertTrue(PressableButtons.press(title))
            XCTAssertNil(session.panel, "\(title) again closes it")
        }
        // The small map of the lake is shown only when asked for.
        UserDefaults.standard.removeObject(forKey: MiniMap.shownKey)
        draw(PanelRail(session: session), width: 720, height: 40)
        XCTAssertTrue(PressableButtons.press("Map"), "Among \(shown)")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: MiniMap.shownKey))
        draw(PanelRail(session: session), width: 720, height: 40)
        XCTAssertTrue(PressableButtons.press("Map"))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: MiniMap.shownKey), "and hidden again")
        UserDefaults.standard.removeObject(forKey: MiniMap.shownKey)
        draw(PanelRail(session: session), width: 720, height: 40)
        XCTAssertTrue(PressableButtons.press("×"), "Among \(shown)")
        XCTAssertFalse(session.railShown, "and folded again")
    }

    /// A hold of the age before, drowned where it stood: named on its
    /// ground, under the pointer and chosen, and when searched.
    func testADrownedHoldIsToldOnItsGround() throws {
        var state = world("drowned ground")
        var before = world("the age before")
        for index in before.holds.indices { before.holds[index].levels[.granary] = 3 }
        state.drown(before, age: 2)
        let hold = try XCTUnwrap(state.drownedHolds.first)
        let me = state.player
        state.reveal(around: hold.position, range: 1, for: me)
        let line = try XCTUnwrap(HoverInfo.line(for: hold.position, in: state, explored: true, territory: state.territory()))
        XCTAssertTrue(line.contains("Drowned Ruin · the drowned hold of \(hold.title)"), line)
        XCTAssertEqual(Narration.line(for: .ruinSearched(at: hold.position, by: me, reward: Stock(grain: 40)), in: state, viewer: me)?.text,
                       "The drowned hold of \(hold.title) gives up 40 grain.")
        XCTAssertEqual(Narration.line(for: .ruinSearched(at: Hex(99, 99), by: me, reward: Stock(grain: 40)), in: state, viewer: me)?.text,
                       "A drowned ruin gives up 40 grain.")
        let (session, _) = session(state)
        session.selection = .tile(hold.position)
        draw(SelectionPanel(session: session), width: 330, height: 600)

        // Searched, the ground remembers where it stood.
        var searched = state
        let ground = try XCTUnwrap(searched.map[hold.position])
        searched.map.set(hold.position, Tile(terrain: ground.terrain, relief: ground.relief))
        let after = try XCTUnwrap(HoverInfo.line(for: hold.position, in: searched, explored: true, territory: searched.territory()))
        XCTAssertTrue(after.contains("where \(hold.title) stood"), after)
        let (later, _) = self.session(searched)
        later.selection = .tile(hold.position)
        draw(SelectionPanel(session: later), width: 330, height: 600)
    }

    /// A bottle set on the water from a shore hold's record, folded until
    /// asked for; named under the pointer and marked on the map.
    func testABottleIsSetOnTheWaterFromAShoreHold() throws {
        var state = world("a bottle cast")
        let me = state.player
        state.houses[me].stock = Stock(grain: 300, timber: 100, stone: 100, moonsalt: 10)
        let shore = try XCTUnwrap(state.map.hexes.first { hex in
            state.map[hex]?.terrain.isSettleable == true && state.hold(at: hex) == nil && state.unit(at: hex) == nil
                && state.map.neighbors(of: hex).contains { [.still, .shallows].contains(state.map[$0]?.terrain) }
        })
        let hold = Hold(id: state.takeID(), name: "Saltwatch", owner: me, position: shore, isSeat: false, foundedWatch: 1)
        state.holds.append(hold)
        state.reveal(around: shore, range: 2, for: me)
        let (session, link) = session(state)
        draw(BottleComposer(session: session, hold: hold), width: 330, height: 200)
        XCTAssertTrue(PressableButtons.press("A bottle…"), "Among \(PressableButtons.actions.keys.sorted())")
        // Open: nothing written, nothing cast; words written, cast, signed.
        PressableButtons.forget("Cast")
        draw(BottleComposer(session: session, hold: hold, open: true), width: 330, height: 260)
        XCTAssertFalse(PressableButtons.press("Cast"), "Nothing written, nothing to cast")
        draw(BottleComposer(session: session, hold: hold, open: true, draft: "The ford is false"), width: 330, height: 260)
        XCTAssertTrue(PressableButtons.press("Cast"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .castBottle(words: "The ford is false", from: hold.id, signed: true))
        XCTAssertEqual(session.state.castRefusal("Again", from: hold.id, as: me), .castThisWatch, "One a watch")
        let bottle = try XCTUnwrap(session.state.bottlesOnTheLake.last)
        XCTAssertEqual(HoverInfo.line(for: bottle.position, in: session.state, explored: true, territory: session.state.territory())?
            .contains("a bottle afloat"), true)
        session.selection = .hold(hold.id)
        draw(SelectionPanel(session: session), width: 330, height: 900)
        draw(WorldMarks(session: session), width: 900, height: 700)
        XCTAssertEqual(GameSession.cues(for: .castBottle(words: "x", from: hold.id, signed: true), events: [], in: session.state, player: me), [.order])
    }

    /// Prisoners in Commanders: one the keeper's House holds, questioned and
    /// let go from its row; one of its own another House holds, ransomed.
    func testPrisonersAreQuestionedLetGoAndRansomedInCommanders() throws {
        var state = world("prisoners in the panel")
        let me = state.player
        state.houses[me].stock = Stock(grain: 300, timber: 100, stone: 100, moonsalt: 200)
        let steward = try XCTUnwrap(state.houses.first { !$0.isPlayer }?.id)
        let theirs = try XCTUnwrap(state.commanders(of: steward).first)
        let mine = try XCTUnwrap(state.commanders(of: me).first)
        let held = try XCTUnwrap(state.commanderIndex(theirs.id)), taken = try XCTUnwrap(state.commanderIndex(mine.id))
        state.commanders![held].captive = Captivity(by: me, since: state.watch, questioned: 0, lastQuestioned: nil, told: nil)
        state.commanders![taken].captive = Captivity(by: steward, since: state.watch, questioned: 0, lastQuestioned: nil, told: nil)
        XCTAssertEqual(CommandersPanel.standing(of: try XCTUnwrap(state.commandersBoard(for: me).line(mine.id)), in: state),
                       "Held prisoner by \(state.houses[steward].title)")
        let (session, link) = session(state)
        draw(CommandersPanel(session: session))
        XCTAssertTrue(PressableButtons.press("Question"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .question(commander: theirs.id))
        XCTAssertTrue(session.awaitsRealm(.question(commander: theirs.id)), "Their words are the realm's to tell")
        XCTAssertEqual(session.state.commander(theirs.id)?.captive?.questioned, 0, "Not guessed at from this copy's view")
        XCTAssertNil(session.state.commander(theirs.id)?.captive?.told)
        let price = GameState.ransom(for: mine)
        XCTAssertTrue(PressableButtons.press("Ransom, \(price)"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .ransom(commander: mine.id))
        draw(CommandersPanel(session: session))
        XCTAssertFalse(PressableButtons.press("Question"), "Once a watch")
        XCTAssertTrue(PressableButtons.press("Let go"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .release(commander: theirs.id))
        let captivity = Captivity(by: me, since: 10, questioned: 0, lastQuestioned: nil, told: nil)
        // What a prisoner told is voiced once a captivity: taken again, they speak anew.
        var once = theirs, again = theirs
        once.captive = Captivity(by: me, since: 10, questioned: 1, lastQuestioned: 10, told: ["A true thing."])
        again.captive = Captivity(by: me, since: 40, questioned: 1, lastQuestioned: 40, told: ["Another."])
        XCTAssertNotEqual(GameSession.Spoken.prisonerKey(of: once), GameSession.Spoken.prisonerKey(of: again))
        XCTAssertNil(GameSession.Spoken.prisonerKey(of: mine), "None for one held by no one")
        XCTAssertEqual(PrisonersSection.held(captivity, at: 10 + GameState.captivityLasts - 1), "Slips away as the watch turns")
        XCTAssertEqual(PrisonersSection.held(captivity, at: 12), "Slips away in \(GameState.captivityLasts - 2) watches")
        XCTAssertEqual(GameSession.cues(for: .question(commander: theirs.id), events: [], in: session.state, player: me), [.lore])
        XCTAssertTrue(GameSession.isRealmsToTell(.prisonerQuestioned(commander: theirs.id, by: me, word: "A true thing.")))
    }

    /// What a prisoner the keeper's House holds has told shows on their row:
    /// the true thing plainly, and above it the prisoner's own voice where
    /// this Mac's model gave them one, kept from before.
    func testWhatAPrisonerToldShowsInTheirVoice() throws {
        var state = world("a prisoner who talked")
        let me = state.player
        let steward = try XCTUnwrap(state.houses.first { !$0.isPlayer }?.id)
        let theirs = try XCTUnwrap(state.commanders(of: steward).first)
        let held = try XCTUnwrap(state.commanderIndex(theirs.id))
        state.commanders![held].captive = Captivity(by: me, since: state.watch, questioned: 1, lastQuestioned: state.watch,
                                                    told: ["The north hold's walls are only timber."])
        let key = try XCTUnwrap(GameSession.Spoken.prisonerKey(of: state.commanders![held]))
        let store = LocalStore(directory: dir.appendingPathComponent(UUID().uuidString))
        store.saveVoices([key.key: "Timber, keeper. Only timber, and old."])
        let session = GameSession(link: DepthLink(), house: me, world: state.view(for: me), store: store)
        session.dismissSeatBriefing()
        XCTAssertEqual(session.spoken[key], "Timber, keeper. Only timber, and old.", "the voice kept from before")
        XCTAssertEqual(session.state.commander(theirs.id)?.captive?.told?.last, "The north hold's walls are only timber.")
        draw(CommandersPanel(session: session))
        // Without a voice kept, what they told is asked of the model anew.
        struct Speaks: Voice {
            func speak(_ moment: VoiceMoment) async -> String? { "Only timber." }
        }
        let fresh = GameSession(link: DepthLink(), house: me, world: state.view(for: me),
                                store: LocalStore(directory: dir.appendingPathComponent(UUID().uuidString)), voice: Speaks())
        let deadline = Date().addingTimeInterval(5)
        while fresh.spoken[key] == nil, Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
        XCTAssertEqual(fresh.spoken[key], "Only timber.", "Their words voiced by the model")
    }

    /// A letter to the age to come sealed from a hold's record, folded until
    /// asked for; the hold that keeps it says so and no other offers one;
    /// in the age after, the pointer and its drowned ruin's record tell of it.
    func testALetterIsSealedForTheAgeToComeFromAHold() throws {
        var state = world("a letter sealed")
        let me = state.player
        state.houses[me].stock = Stock(grain: 300, timber: 100, stone: 100, moonsalt: 40)
        let seat = try XCTUnwrap(state.seat(of: me))
        let (session, link) = session(state)
        draw(LetterComposer(session: session, hold: seat), width: 330, height: 200)
        XCTAssertTrue(PressableButtons.press("A letter to the age to come…"), "Among \(shown)")
        // Open: nothing written, nothing sealed; words written, sealed.
        PressableButtons.forget("Seal")
        draw(LetterComposer(session: session, hold: seat, open: true), width: 330, height: 260)
        XCTAssertFalse(PressableButtons.press("Seal"), "Nothing written, nothing to seal")
        draw(LetterComposer(session: session, hold: seat, open: true, draft: "Remember the ford"), width: 330, height: 260)
        XCTAssertTrue(PressableButtons.press("Seal"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .sealLetter(words: "Remember the ford", hold: seat.id))
        let letter = try XCTUnwrap(session.state.letter(sealedBy: me))
        XCTAssertEqual(LetterComposer.kept(letter), "Your letter to the age to come lies under these stones: “Remember the ford”")
        // Sealed: one an age, so no hold offers another.
        PressableButtons.forget("A letter to the age to come…")
        draw(LetterComposer(session: session, hold: seat), width: 330, height: 200)
        XCTAssertFalse(PressableButtons.press("A letter to the age to come…"), "One an age")
        session.selection = .hold(seat.id)
        draw(SelectionPanel(session: session), width: 330, height: 900)
        XCTAssertEqual(GameSession.cues(for: .sealLetter(words: "x", hold: seat.id), events: [], in: session.state, player: me), [.lore])
        XCTAssertFalse(GameSession.isRealmsToTell(.letterSealed(hold: seat.id, by: me)), "Its own letter it knows")
        XCTAssertTrue(GameSession.isRealmsToTell(.letterFound(letter: letter, by: me)), "A drowned letter's words are the realm's to tell")

        // In the age after: the letter lies with its drowned hold.
        var before = state
        _ = try before.perform(.sealLetter(words: "Remember the ford", hold: seat.id), as: me)
        var next = RealmState.world(seed: "a letter sealed", age: 2, seats: 6, radius: 20)
        next.drown(before, age: 2)
        let lies = try XCTUnwrap(next.lettersOfOld.first?.at)
        let viewer = next.player
        next.reveal(around: lies, range: 1, for: viewer)
        let view = next.view(for: viewer)
        XCTAssertEqual(HoverInfo.line(for: lies, in: view, explored: true, territory: view.territory())?.contains("a letter sealed within"), true)
        let (later, _) = self.session(next)
        later.selection = .tile(lies)
        draw(SelectionPanel(session: later), width: 330, height: 900)
    }

    /// The realm's law at the head of the Houses: an edict put, voted on,
    /// and those holding the realm; the rail marks a vote awaiting.
    func testTheRealmsLawIsPutAndVotedOnFromTheHouses() throws {
        UserDefaults.standard.removeObject(forKey: EdictsSection.proposingKey)
        defer { UserDefaults.standard.removeObject(forKey: EdictsSection.proposingKey) }
        var state = world("the realm's law")
        let me = state.player
        let other = try XCTUnwrap(state.houses.indices.first { $0 != me })
        state.houses[me].stock = Stock(grain: 400, timber: 100, stone: 100, moonsalt: 40)
        let seat = try XCTUnwrap(state.holds.first { $0.owner == me && $0.isSeat })
        let ground = try XCTUnwrap(seat.position.spiral(5).first { hex in
            hex.distance(to: seat.position) >= 3 && state.map[hex]?.terrain.isSettleable == true && state.hold(at: hex) == nil && state.unit(at: hex) == nil
        })
        state.holds.append(Hold(id: state.takeID(), name: "Second", owner: me, position: ground, isSeat: false, foundedWatch: 1))
        // Safe Conduct holds, broken once; the Moon's Peace is before the realm, put by another.
        state.edicts = [Edict(id: 51, kind: .safeConduct, proposer: other, proposed: 1, ayes: [other], closed: state.watch, ayeMight: 5, nayMight: 1,
                              breaches: [Edict.Breach(house: other, against: me, watch: state.watch)]),
                        Edict(id: 52, kind: .moonPeace, proposer: other, proposed: state.watch, ayes: [other])]
        let (session, link) = session(state)
        XCTAssertTrue(session.voteAwaits)
        let held = try XCTUnwrap(session.state.edictsInForce.first)
        XCTAssertEqual(EdictsSection.inForce(held, in: session.state),
                       "Safe Conduct holds 20 more watches: no House strikes Founders or Lanterns. Broken once.")
        let before = try XCTUnwrap(session.state.edictInVote)
        XCTAssertTrue(EdictsSection.tally(before, in: session.state).hasPrefix("Aye 1, might "), EdictsSection.tally(before, in: session.state))
        XCTAssertTrue(EdictsSection.tally(before, in: session.state).hasSuffix(" · 3 watches to vote"))
        draw(PanelRail(session: session), width: 120, height: 400)
        session.panel = .houses
        draw(HousesPanel(session: session), width: 360, height: 900)

        // The keeper votes aye; the mark is gone.
        XCTAssertTrue(PressableButtons.press("Aye"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .voteEdict(edict: 52, aye: true))
        XCTAssertEqual(session.state.edictInVote?.ayes, [other, me])
        XCTAssertFalse(session.voteAwaits)
        draw(EdictsSection(session: session), width: 330, height: 500)
        XCTAssertFalse(PressableButtons.actions.keys.contains("Aye"), "Voted")

        // Edicts to put, folded until asked for; none while one is before the realm.
        XCTAssertTrue(PressableButtons.press("Put an edict…"), "Among \(shown)")
        draw(EdictsSection(session: session), width: 330, height: 700)
        XCTAssertFalse(PressableButtons.press("Propose"), "One before the realm at a time")
        XCTAssertTrue(PressableButtons.press("Fold the edicts"))

        // Its vote closed, the keeper puts one of their own.
        var after = session.state
        after.edicts = after.edictsOfTheRealm.filter { $0.id == 51 }
        let (proposer, sent) = self.session(after)
        draw(EdictsSection(session: proposer), width: 330, height: 400)
        XCTAssertTrue(PressableButtons.press("Put an edict…"), "Folded again: \(shown)")
        draw(EdictsSection(session: proposer), width: 330, height: 700)
        XCTAssertTrue(PressableButtons.press("Propose"), "Among \(shown)")
        guard case .proposeEdict(let kind)? = sent.sent.last else { return XCTFail("An edict put: \(String(describing: sent.sent.last))") }
        XCTAssertEqual(proposer.state.edictInVote?.kind, kind)
        XCTAssertEqual(Narration.line(for: .edictProposed(try XCTUnwrap(proposer.state.edictInVote)), in: proposer.state, viewer: me)?.text
                       .hasPrefix("Your House puts \(kind.title) to the realm"), true)
        XCTAssertEqual(GameSession.cues(for: .proposeEdict(kind: kind), events: [], in: proposer.state, player: me), [.horn])
    }

    /// The view opens close enough over the seat that the land the House
    /// knows fills most of it; a House that knows more opens further out.
    func testTheViewOpensOnMoreLandThanMist() throws {
        var state = world("the opening view")
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        let known = GameSession.knownRadius(about: seat.position, in: state, for: me)
        XCTAssertTrue((GameState.knownAtStart...8).contains(known), "As the age opens: \(known)")
        let (opening, _) = session(state)
        XCTAssertEqual(opening.camera.scale, GameSession.openingScale(knownRadius: known), accuracy: 1e-9)
        XCTAssertGreaterThan(opening.camera.scale, GameSession.lakeScale, "Closer than the lake's view")
        XCTAssertLessThan(opening.camera.scale, GameSession.fineScale, "Short of the fine work")
        state.houses[me].explored = Explored(repeating: true, count: state.map.count)
        let (knowing, _) = session(state)
        XCTAssertEqual(knowing.camera.scale, GameSession.lakeScale, accuracy: 1e-9, "Knowing the whole lake, the lake's view")
        XCTAssertEqual(GameSession.openingScale(knownRadius: 0), GameSession.fineScale * 0.85, accuracy: 1e-9)
    }

    /// The interface heard: a leaf turned as a panel opens and laid down
    /// as it closes, a muted knock as the rules refuse an order, and the
    /// trackpad's taps for an order given and one refused.
    func testTheInterfaceIsHeardAndFelt() throws {
        let (session, _) = session(world("the interface heard"))
        var heard: [Ambience.Cue] = []
        session.onCue = { heard.append($0) }
        session.panel = .houses
        session.panel = .houses
        session.panel = .chronicle
        session.panel = nil
        XCTAssertEqual(heard, [.leaf, .leaf, .fold], "Once for each change")
        XCTAssertFalse(session.perform(.disband(unit: 987_654)))
        XCTAssertEqual(heard.last, .deny)
        XCTAssertEqual(Haptics.pattern(for: .order), .alignment)
        XCTAssertEqual(Haptics.pattern(for: .deny), .levelChange)
        XCTAssertNil(Haptics.pattern(for: .watch))
        Haptics.tap(for: .deny)
        Haptics.tap(for: .watch)
    }

    func testAHoldsRecordSaysWhenItWasRaised() {
        let seat = Hold(id: 1, name: "Ilsen", owner: 0, position: .origin, isSeat: true, foundedWatch: 1)
        let later = Hold(id: 2, name: "Vael", owner: 0, position: Hex(3, 0), isSeat: false, foundedWatch: 23)
        XCTAssertEqual(OwnHoldDetails.raised(seat), "raised as the age opened")
        XCTAssertEqual(OwnHoldDetails.raised(later), "raised in the 23rd watch")
    }

    func testTheMoonBandSpeaksOnlyAboutTheFull() throws {
        let first = Sundering.first
        XCTAssertNil(MoonBand.line(watch: first - 10, open: false), "Nothing while the moon is far from full")
        XCTAssertEqual(MoonBand.line(watch: first - 3, open: false), "The moon waxes: the Moonford lies bare across the lake in 3 watches.")
        XCTAssertEqual(MoonBand.line(watch: first - 1, open: false), "The moon waxes: the Moonford lies bare across the lake as the watch turns.")
        XCTAssertEqual(MoonBand.line(watch: first, open: true),
                       "The Moonford lies open across the lake: the water comes back over it in \(GameState.fordLasts) watches.")
        XCTAssertEqual(MoonBand.line(watch: first + GameState.fordLasts - 1, open: true),
                       "The Moonford lies open across the lake: the water comes back over it as the watch turns.")
        XCTAssertNil(MoonBand.line(watch: first + GameState.fordLasts + 2, open: false))
        draw(MoonBand(line: try XCTUnwrap(MoonBand.line(watch: first, open: true))), width: 700, height: 40)

        // The ford itself, under the pointer and chosen: what it is, and
        // when the water comes back.
        var state = world("the moon's road")
        state.watch = first
        _ = state.turnTide()
        let course = try XCTUnwrap(state.ford)
        let hex = course[course.count / 2]
        XCTAssertEqual(HoverInfo.line(for: hex, in: state, explored: true, territory: state.territory()),
                       "The Moonford · the moon's road, 1 move, under water again in \(GameState.fordLasts) watches")
        state.watch = first + GameState.fordLasts - 1
        XCTAssertEqual(HoverInfo.line(for: hex, in: state, explored: true, territory: state.territory()),
                       "The Moonford · the moon's road, 1 move, under water again as the watch turns")
        let (session, _) = session(state)
        session.selection = .tile(hex)
        draw(SelectionPanel(session: session), width: 330, height: 600)
    }

    func testNoticesFadeAndEnvoysWaitTheirTurn() throws {
        let now = Date()
        let notices = (1...5).map { index in
            GameSession.Notice(id: index, text: "Notice \(index)", tone: .neutral, posted: now.addingTimeInterval(Double(index - 5) * 3))
        }
        // Posted 12, 9, 6, 3 and 0 seconds ago: those within the while a
        // notice lingers, the latest three of them.
        XCTAssertEqual(NoticeFeed.fresh(notices, at: now).map(\.id), [3, 4, 5])
        XCTAssertEqual(NoticeFeed.fresh(notices, at: now.addingTimeInterval(7)).map(\.id), [5])
        XCTAssertTrue(NoticeFeed.fresh(notices, at: now.addingTimeInterval(NoticeFeed.lingers)).isEmpty, "The map clear again")

        let envoys = (0..<3).map { Envoy(id: 70 + $0, from: $0 + 1, to: 0, proposal: .peace, arrived: 1) }
        XCTAssertEqual(EnvoyCards.heard(of: envoys, forward: nil)?.id, 70, "The first to come heard first")
        XCTAssertEqual(EnvoyCards.heard(of: envoys, forward: 72)?.id, 72, "One brought forward")
        XCTAssertEqual(EnvoyCards.heard(of: envoys, forward: 99)?.id, 70, "One gone, the first again")
        XCTAssertNil(EnvoyCards.heard(of: [], forward: nil))
    }

    // MARK: Crests

    /// Every charge drawn, each its own; the keeper's House takes its own
    /// crest from the Realm panel once, and every House's row bears its.
    func testCrestsAreDrawnAndTaken() throws {
        UserDefaults.standard.removeObject(forKey: CrestSection.choosingKey)
        defer { UserDefaults.standard.removeObject(forKey: CrestSection.choosingKey) }
        var drawn: [Data] = []
        for charge in Crest.Charge.allCases {
            let renderer = ImageRenderer(content: CrestView(crest: Crest(field: .blue, charge: charge, tincture: .silver), size: 48))
            renderer.scale = 1
            let image = try XCTUnwrap(renderer.cgImage)
            drawn.append(try XCTUnwrap(image.dataProvider?.data) as Data)
        }
        XCTAssertEqual(Set(drawn).count, Crest.Charge.allCases.count, "Each charge its own")
        XCTAssertEqual(Set(Crest.Tincture.allCases.map { "\(CrestView.colour($0))" }).count, Crest.Tincture.allCases.count, "Each tincture its own")

        let (session, link) = session(world("crests taken"))
        let me = session.player
        let given = session.state.crest(of: me)
        XCTAssertEqual(CrestSection.line(given, chosen: false), "Your House bears \(given.blazon), as the lake gave it. Take your own once this age.")
        draw(RealmPanel(session: session), width: 360, height: 2400)
        XCTAssertFalse(shown.contains("Take this crest"), "Folded until asked for")
        XCTAssertTrue(PressableButtons.press("Take your own…"), "Among \(shown)")
        draw(RealmPanel(session: session), width: 360, height: 2400)
        XCTAssertTrue(PressableButtons.press("Take this crest"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .takeCrest(given))
        XCTAssertEqual(session.state.houses[me].crest, given, "Taken as the lake gave it, the keeper's own now")
        draw(RealmPanel(session: session), width: 360, height: 2400)
        XCTAssertFalse(shown.contains("Take your own…"), "Once an age")
        XCTAssertEqual(CrestSection.line(given, chosen: true), "Your House bears \(given.blazon), its own until the age ends.")
        draw(HousesPanel(session: session), width: 360, height: 900)
    }

    // MARK: The land

    /// A realm's streams and regions: told under the pointer and in a
    /// tile's record, a stream followed from spring to mouth, named over the
    /// land when the view is drawn back, and set out in the Realm panel's
    /// legend, folded until asked for.
    func testTheLandIsNamedFollowedAndSetOut() throws {
        UserDefaults.standard.removeObject(forKey: LandSection.openKey)
        defer { UserDefaults.standard.removeObject(forKey: LandSection.openKey) }
        var state = GameState(settings: GameSettings(seedText: "land named", houseCount: 6, radius: 20, keepers: 1, rivers: true))
        // The whole land found, so its streams show in the keeper's view.
        state.houses[state.player].explored = Explored(repeating: true, count: state.map.count)
        let atlas = try XCTUnwrap(state.atlas)
        let (session, _) = session(state)
        let regions = session.regions()
        XCTAssertEqual(regions, atlas.regionIndices(over: session.state.map))
        XCTAssertEqual(session.regions(), regions, "Kept")

        // Under the pointer, and in the tile's record.
        let river = atlas.rivers[0]
        let stream = try XCTUnwrap(river.course.first { state.map[$0]?.terrain == .stream })
        let shoal = try XCTUnwrap(river.course.first { state.map[$0]?.terrain == .shoal })
        let streamLine = try XCTUnwrap(HoverInfo.line(for: stream, in: session.state, explored: true, territory: session.territory, regions: regions))
        XCTAssertEqual(streamLine, "Stream · \(river.name) · yields nothing, crossed only at its shoals")
        let shoalLine = try XCTUnwrap(HoverInfo.line(for: shoal, in: session.state, explored: true, territory: session.territory, regions: regions))
        XCTAssertTrue(shoalLine.hasPrefix("Shoal · \(river.name)"), shoalLine)
        XCTAssertTrue(shoalLine.contains("2 moves") && shoalLine.contains("-25% defence"), shoalLine)
        let heart = atlas.regions[0].heart
        XCTAssertTrue(HoverInfo.line(for: heart, in: session.state, explored: true, territory: session.territory, regions: regions)?
            .contains(atlas.regions[0].name) == true)
        XCTAssertTrue(TilePanel.stream(river, cold: true).contains("crossed at its shoals"))
        XCTAssertTrue(TilePanel.stream(river, cold: true).hasPrefix(river.name.prefix(1).uppercased()))
        XCTAssertTrue(TilePanel.stream(nil, cold: false).hasPrefix("The stream runs wide and shallow"))
        XCTAssertTrue(Terrain.allCases.allSatisfy { !TilePanel.bare($0, river: river).isEmpty })
        XCTAssertEqual(TilePanel.bare(.greyfield, river: nil), "Bare ground.")
        session.selection = .tile(stream)
        draw(SelectionPanel(session: session), width: 360, height: 400)
        session.selection = .tile(shoal)
        draw(SelectionPanel(session: session), width: 360, height: 400)

        // Over the land: named far out, not close in; a stream followed.
        XCTAssertEqual(WorldMarks.landNames(at: 30), 0)
        XCTAssertEqual(WorldMarks.landNames(at: 12), 1)
        XCTAssertEqual(WorldMarks.landNames(at: 15), 0.5)
        session.camera.scale = 10
        session.hovered = stream
        draw(WorldMarks(session: session, moment: Date()), width: 900, height: 700)
        session.camera.scale = 30
        draw(WorldMarks(session: session, moment: Date()), width: 900, height: 700)

        // The legend in the Realm panel, folded until asked for.
        XCTAssertTrue(LandSection.summary(atlas).hasPrefix("Three streams run from the Spine down to the lake"), LandSection.summary(atlas))
        XCTAssertTrue(LandSection.summary(atlas).hasSuffix("Between them lie three regions of the shores."))
        XCTAssertEqual(LandSection.spelled(0), "no")
        XCTAssertEqual(LandSection.spelled(13), "13")
        let rows = LandSection.rows(session.state, regions: regions, player: session.player)
        XCTAssertEqual(rows.count, atlas.regions.count)
        XCTAssertTrue(rows.allSatisfy { $0.line.hasPrefix("by ") }, "\(rows)")
        XCTAssertTrue(rows.contains { $0.line.contains("of yours") }, "The keeper's seat stands in one")
        XCTAssertEqual(LandSection.rows(GameState(settings: GameSettings(seedText: "no streams", houseCount: 3, radius: 14)), regions: [], player: 0), [])
        draw(RealmPanel(session: session), width: 360, height: 2400)
        XCTAssertFalse(shown.contains("Fold the regions"))
        XCTAssertTrue(PressableButtons.press("Show the regions"), "Among \(shown)")
        draw(RealmPanel(session: session), width: 360, height: 2400)
        XCTAssertTrue(PressableButtons.press("Fold the regions"))
    }

    /// A hold's companies opened: each kind with tiers trained at the
    /// highest its Muster Hall and studies allow, unless a lower is chosen.
    func testAHoldTrainsTheHighestTierItMayMuster() throws {
        UserDefaults.standard.set(true, forKey: OwnHoldDetails.companiesKey)
        defer { UserDefaults.standard.removeObject(forKey: OwnHoldDetails.companiesKey) }
        var state = world("tiers mustered")
        let me = state.player
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == me && $0.isSeat })
        state.holds[seat].levels[.musterHall] = 3
        state.holds[seat].training = nil
        state.holds[seat].project = nil
        state.houses[me].research = Research(known: [Learned(study: .drill, grade: 1), Learned(study: .ironRanks, grade: 1)])
        state.houses[me].stock = Stock(grain: 9000, timber: 9000, stone: 9000, moonsalt: 900)
        let hold = state.holds[seat]
        XCTAssertGreaterThan(UnitKind.allCases.map { state.highestTier(of: $0, at: hold, for: me) }.max() ?? 1, 1, "Tiers above the first")
        let (session, link) = session(state)
        session.selection = .hold(hold.id)
        draw(SelectionPanel(session: session), width: 360, height: 2000)
        XCTAssertTrue(PressableButtons.press("Train"), "Among \(shown)")
        guard case .train(_, let kind, let tier)? = link.sent.last else { return XCTFail("Trained: \(link.sent)") }
        let highest = session.state.highestTier(of: kind, at: hold, for: me)
        XCTAssertEqual(tier, highest > 1 ? highest : nil, "The highest first chosen, for \(kind)")
    }

    /// A realm of a hundred and twenty-eight Houses: a whisper, a prophecy
    /// and a title each offer the Houses the keeper has reason to name,
    /// nearest first, not a button for every House, and find any other by
    /// its name.
    func testAWideRealmsComposersOfferTheHousesAKeeperHasReasonToName() throws {
        var state = GameState(settings: GameSettings(seedText: "a wide realm's choosers", houseCount: 128,
                                                     radius: RealmState.radius(forSeats: 128), keepers: 1))
        let me = state.player
        state.houses[me].stock.moonsalt = 80
        let ground = try XCTUnwrap(state.map.hexes.first { hex in
            state.map[hex]?.terrain.isPassable == true && state.map[hex]?.terrain.isWater == false && state.hold(at: hex) == nil
        })
        state.shrines = (state.shrines ?? []) + [Shrine(id: 99, kind: .brokenSpire, position: ground, holder: me, since: state.watch)]
        state.reveal(around: ground, range: 1, for: me)
        let (session, link) = session(state)
        let choice = session.state.houseChoice(by: me, excluding: [me])
        XCTAssertTrue(choice.searchable)
        let near = try XCTUnwrap(choice.offered.first)
        let far = try XCTUnwrap(session.state.livingHouses.last { house in house.id != me && !choice.offered.contains { $0.id == house.id } })
        func buttons(_ prefix: String) -> [String] { shown.filter { $0.hasPrefix(prefix) } }

        // A whisper: the Houses offered, not every House; one far off found by its name.
        draw(WhispersSection(session: session, composing: true, kind: .walls), width: 360, height: 1200)
        XCTAssertEqual(buttons("Of House").count, choice.offered.count, "Among \(shown)")
        XCTAssertTrue(shown.contains("Of \(near.title)"), "Its nearest first among them")
        XCTAssertFalse(shown.contains("Of \(far.title)"), "Found by its name, not offered")
        XCTAssertLessThan(choice.offered.count, 40, "Not a hundred and twenty-seven")
        draw(HouseChooser(session: session, excluding: [me], query: far.name) { house in
            QuietButton(title: "Of \(house.title)", size: 8.5) {}
        }, width: 360, height: 400)
        XCTAssertTrue(shown.contains("Of \(far.title)"), "Among \(shown)")
        draw(WhispersSection(session: session, composing: true, kind: .walls, house: far.id), width: 360, height: 1200)
        let claim = Whisper.Claim.seatBreached(house: far.id)
        XCTAssertTrue(PressableButtons.press("Whisper that \(session.state.told(claim))"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .whisper(claim))

        // Many go by a letter, two dozen shown; none by another.
        draw(HouseChooser(session: session, excluding: [me], query: "a") { house in
            QuietButton(title: "Of \(house.title)", size: 8.5) {}
        }, width: 360, height: 900)
        XCTAssertEqual(shown.count, HouseChoice.found, "Among \(shown)")
        draw(HouseChooser(session: session, excluding: [me], query: "Qqx") { house in
            QuietButton(title: "Of \(house.title)", size: 8.5) {}
        }, width: 360, height: 300)
        XCTAssertTrue(shown.isEmpty, "Among \(shown)")

        // A prophecy may be of the keeper's own House; a war's second House is never its first.
        draw(AugurySection(session: session, composing: true, kind: .falls), width: 360, height: 1200)
        XCTAssertTrue(shown.contains("Of Your House"), "Among \(shown)")
        XCTAssertEqual(buttons("Of House").count, choice.offered.count)
        draw(AugurySection(session: session, composing: true, kind: .war, first: near.id), width: 360, height: 1200)
        XCTAssertTrue(shown.contains("With Your House"), "Among \(shown)")
        XCTAssertFalse(shown.contains("With \(near.title)"))

        // A title named to one of the Houses offered, none far off.
        XCTAssertEqual(session.state.titleGiver, me)
        draw(TitlesSection(session: session, open: true, naming: .swordOfTheLake), width: 360, height: 1200)
        XCTAssertFalse(buttons("Name House").isEmpty, "Among \(shown)")
        XCTAssertTrue(Set(buttons("Name House")).isSubset(of: Set(choice.offered.map { "Name \($0.title)" })), "Among \(shown)")
        XCTAssertFalse(shown.contains("Name \(far.title)"))
    }

    /// The titles of the Spire on the Realm screen: the keeper whose House
    /// holds the broken Spire chooses a title, then the House to name to
    /// it; the House named reads it in the Houses' list, and hears it.
    func testTheSpiresKeeperNamesATitleFromTheRealm() throws {
        var state = world("titles named")
        let me = state.player
        let other = try XCTUnwrap(state.livingHouses.map(\.id).first { $0 != me })
        let ground = try XCTUnwrap(state.map.hexes.first { hex in
            state.map[hex]?.terrain.isPassable == true && state.map[hex]?.terrain.isWater == false && state.hold(at: hex) == nil
        })
        state.shrines = (state.shrines ?? []) + [Shrine(id: 99, kind: .brokenSpire, position: ground, holder: me, since: state.watch)]
        // Held by a company standing on it, its ground is known.
        state.reveal(around: ground, range: 1, for: me)
        let (session, link) = session(state)
        XCTAssertEqual(session.state.titleGiver, me)
        XCTAssertEqual(TitlesSection.giverLine(session.state, player: me), "Your House holds the broken Spire: you name the realm's titles.")
        draw(RealmPanel(session: session), width: 360, height: 2600)
        XCTAssertFalse(shown.contains("Sword of the Lake"), "Folded until asked for")
        XCTAssertTrue(PressableButtons.press("Name a title…"), "Among \(shown)")
        draw(TitlesSection(session: session, open: true), width: 360, height: 400)
        XCTAssertTrue(PressableButtons.press("Sword of the Lake"), "Among \(shown)")
        draw(TitlesSection(session: session, open: true, naming: .swordOfTheLake), width: 360, height: 500)
        let name = "Name \(session.state.houses[other].title)"
        XCTAssertTrue(PressableButtons.press(name), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .bestow(.swordOfTheLake, on: other))
        XCTAssertEqual(session.state.title(of: other)?.title, .swordOfTheLake)

        // Borne, it is shown with whose it is, and named no more to the same House.
        PressableButtons.forget(name)
        draw(TitlesSection(session: session, open: true, naming: .swordOfTheLake), width: 360, height: 500)
        XCTAssertFalse(PressableButtons.press(name), "Borne already")
        draw(HouseRow(session: session, house: session.state.houses[other], draft: OfferDraft(for: session.state.houses[other])))
        XCTAssertEqual(GameSession.cues(for: .bestow(.craven, on: other), events: [], in: session.state, player: me), [.banner])
        let named = GameEvent.titleBestowed(title: .swordOfTheLake, house: other, by: me)
        XCTAssertEqual(GameSession.cue(forDepth: named, in: session.state, player: other), .honour)
        XCTAssertEqual(GameSession.cue(forDepth: GameEvent.titleBestowed(title: .craven, house: other, by: me), in: session.state, player: other), .dread)
        XCTAssertNil(GameSession.cue(forDepth: named, in: session.state, player: me))
        // A commander raised a star is heard by its House alone.
        XCTAssertEqual(GameSession.cue(forDepth: .commanderStarred(commander: 1, house: me, stars: 2), in: session.state, player: me), .honour)
        XCTAssertNil(GameSession.cue(forDepth: .commanderStarred(commander: 1, house: me, stars: 2), in: session.state, player: other))

        // As others see who names them: a keeper, a steward, none, or no Spire this age.
        XCTAssertEqual(TitlesSection.giverLine(session.state, player: other),
                       "\(session.state.houses[me].title) holds the broken Spire, and names the realm's titles.")
        var stewards = session.state
        let spire = try XCTUnwrap(stewards.shrines?.firstIndex { $0.kind == .brokenSpire })
        stewards.shrines![spire].holder = other
        XCTAssertTrue(TitlesSection.giverLine(stewards, player: me).hasSuffix("its steward names no titles."))
        stewards.shrines![spire].holder = nil
        XCTAssertTrue(TitlesSection.giverLine(stewards, player: me).hasPrefix("The broken Spire is held by none."))
        stewards.shrines!.remove(at: spire)
        XCTAssertEqual(TitlesSection.giverLine(stewards, player: me), "No broken Spire stands this age, and no titles are named.")
        // One standing where the keeper's House has not been is not denied.
        stewards.brokenSpire = BrokenSpire(position: ground, house: "House Old", age: 1, stages: 3)
        XCTAssertTrue(stewards.brokenSpireStands)
        XCTAssertTrue(TitlesSection.giverLine(stewards, player: me).hasPrefix("The broken Spire stands where your House has not yet been."))
    }

    /// The Augury on the Realm screen: another keeper's prophecy stood
    /// against; one of the keeper's own chosen, its kind, then its House,
    /// and spoken with its stake; and prophecies judged shown as judged.
    func testAProphecyIsSpokenAndStakedFromTheRealm() throws {
        var state = world("an augury")
        let me = state.player
        let other = try XCTUnwrap(state.livingHouses.map(\.id).first { $0 != me })
        state.houses[other].isPlayer = true
        state.houses[other].stock.moonsalt = 50
        state.houses[me].stock.moonsalt = 80
        _ = try state.perform(.prophesy(.takesAHold(house: me), until: state.watch + 10, moonsalt: 10), as: other)
        let (session, link) = session(state)
        draw(RealmPanel(session: session), width: 360, height: 2600)
        XCTAssertTrue(PressableButtons.press("Stand against it"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .stake(prophecy: 1, backs: false, moonsalt: AugurySection.stake))
        XCTAssertFalse(shown.contains("A House falls"), "Folded until asked for")
        XCTAssertTrue(PressableButtons.press("Foretell…"), "Among \(shown)")

        // The keeper's own: its kind, its House, and spoken.
        draw(AugurySection(session: session, composing: true), width: 360, height: 500)
        XCTAssertTrue(PressableButtons.press("A House falls"), "Among \(shown)")
        draw(AugurySection(session: session, composing: true, kind: .falls), width: 360, height: 500)
        XCTAssertTrue(PressableButtons.press("Of \(session.state.houses[other].title)"), "Among \(shown)")
        draw(AugurySection(session: session, composing: true, kind: .falls, first: other), width: 360, height: 600)
        XCTAssertTrue(PressableButtons.press("Foretell"), "Among \(shown)")
        let until = session.state.watch + AugurySection.span
        XCTAssertEqual(link.sent.last, .prophesy(.falls(house: other), until: until, moonsalt: AugurySection.stake))
        XCTAssertEqual(session.state.openProphecies.count, 2)
        let mine = try XCTUnwrap(session.state.openProphecies.last)
        XCTAssertEqual(AugurySection.standing(mine, at: session.state.watch),
                       "\(AugurySection.stake) moonsalt backing it, 0 against; stakes close at watch \(mine.stakesClose).")
        XCTAssertEqual(AugurySection.standing(mine, at: mine.stakesClose + 1), "\(AugurySection.stake) moonsalt backing it, 0 against; stakes are closed.")
        draw(AugurySection(session: session), width: 360, height: 500)

        // A war's second House after its first; each kind's prophecy.
        XCTAssertNil(AugurySection.claim(.war, first: other, second: nil, in: session.state))
        XCTAssertNil(AugurySection.claim(.falls, first: nil, second: nil, in: session.state))
        XCTAssertEqual(AugurySection.claim(.war, first: other, second: me, in: session.state), .war(other, me))
        XCTAssertEqual(AugurySection.claim(.takesAHold, first: me, second: nil, in: session.state), .takesAHold(house: me))
        XCTAssertEqual(AugurySection.claim(.spireRises, first: me, second: nil, in: session.state), .spireRises(house: me, stage: 1))
        draw(AugurySection(session: session, composing: true, kind: .war, first: other), width: 360, height: 600)
        XCTAssertTrue(PressableButtons.press("With Your House"), "Among \(shown)")
        XCTAssertEqual(AugurySection.Kind.allCases.map(\.title), ["A House falls", "A House takes a hold", "Two Houses at war", "A Moonspire rises"])

        // Judged, as the realm judged them; heard as they are.
        var judged = session.state
        judged.auguries![0].cameToPass = true
        judged.auguries![1].cameToPass = false
        XCTAssertTrue(AugurySection.standing(judged.prophecies[0], at: judged.watch).hasPrefix("Came to pass."))
        XCTAssertTrue(AugurySection.standing(judged.prophecies[1], at: judged.watch).hasPrefix("Failed."))
        link.onEvent?(.changed(judged))
        draw(AugurySection(session: session), width: 360, height: 500)
        XCTAssertEqual(GameSession.cues(for: .prophesy(.falls(house: other), until: until, moonsalt: 10), events: [], in: session.state, player: me), [.lore])
        XCTAssertEqual(GameSession.cues(for: .stake(prophecy: 1, backs: true, moonsalt: 10), events: [], in: session.state, player: me), [.coin])
        let paid = GameEvent.prophecyJudged(prophecy: 2, cameToPass: false, paid: [Prophecy.Stake(house: me, backs: false, moonsalt: 20)])
        XCTAssertEqual(GameSession.cue(forDepth: paid, in: session.state, player: me), .triumph)
        XCTAssertNil(GameSession.cue(forDepth: paid, in: session.state, player: other))
    }

    /// Whispers on the Realm screen: another keeper's about the keeper's
    /// House shown unsigned; one of the keeper's own chosen, its kind, then
    /// its House, and let loose; and each as it stands once tried or found
    /// false.
    func testAWhisperIsLetLooseFromTheRealm() throws {
        var state = world("whispers on the water")
        let me = state.player
        let other = try XCTUnwrap(state.livingHouses.map(\.id).first { $0 != me })
        state.houses[other].isPlayer = true
        state.houses[me].stock.moonsalt = 60
        state.houses[other].stock.moonsalt = 60
        let theirs = try XCTUnwrap(state.seat(of: other))
        state.reveal(around: theirs.position, range: 1, for: me)
        _ = try state.perform(.whisper(.granariesLow(house: me)), as: other)
        let (session, link) = session(state)
        let heard = try XCTUnwrap(session.state.whispersHeard.first)
        XCTAssertNil(heard.by, "Unsigned")
        XCTAssertEqual(WhispersSection.standing(heard, in: session.state, player: me), "Unproven.", "Of the keeper's own House")
        draw(RealmPanel(session: session), width: 360, height: 3000)
        XCTAssertFalse(shown.contains("Walls broken"), "Folded until asked for")
        XCTAssertTrue(PressableButtons.press("Whisper…"), "Among \(shown)")

        // The keeper's own: its kind, its House, and let loose.
        draw(WhispersSection(session: session, composing: true), width: 360, height: 500)
        XCTAssertTrue(PressableButtons.press("Walls broken"), "Among \(shown)")
        draw(WhispersSection(session: session, composing: true, kind: .walls), width: 360, height: 500)
        XCTAssertTrue(PressableButtons.press("Of \(session.state.houses[other].title)"), "Among \(shown)")
        draw(WhispersSection(session: session, composing: true, kind: .walls, house: other), width: 360, height: 600)
        let claim = Whisper.Claim.seatBreached(house: other)
        XCTAssertTrue(PressableButtons.press("Whisper that \(session.state.told(claim))"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .whisper(claim))
        let mine = try XCTUnwrap(session.state.whispersHeard.last)
        XCTAssertEqual(mine.by, me)
        XCTAssertTrue(WhispersSection.standing(mine, in: session.state, player: me).hasPrefix("Yours. Unproven: your Lanterns may try it"))
        draw(WhispersSection(session: session, composing: true, kind: .host, house: other), width: 360, height: 600)
        draw(WhispersSection(session: session, composing: true, kind: .granaries, house: other), width: 360, height: 600)
        XCTAssertEqual(WhispersSection.claim(.host, house: other, hold: theirs.id), .hostGathered(house: other, hold: theirs.id))
        XCTAssertNil(WhispersSection.claim(.host, house: other))
        XCTAssertNil(WhispersSection.claim(.granaries, house: nil))
        XCTAssertEqual(WhispersSection.claim(.granaries, house: other), .granariesLow(house: other))
        XCTAssertEqual(WhispersSection.Kind.allCases.map(\.title), ["A host gathered", "Granaries low", "Walls broken"])

        // As each stands: tried, found false, or out of the Lanterns' reach.
        var judged = session.state
        XCTAssertEqual(WhispersSection.standing(judged.whispersHeard[1], in: judged, player: me).prefix(16), "Yours. Unproven:",
                       "This copy's guess of its truth is not told as found")
        judged.whispers![1].triedBy = [me]
        judged.whispers![1].truth = true
        XCTAssertEqual(WhispersSection.standing(judged.whispersHeard[1], in: judged, player: me), "Yours. True, as your Lanterns found.")
        judged.whispers![1].truth = false
        XCTAssertEqual(WhispersSection.standing(judged.whispersHeard[1], in: judged, player: me), "Yours. False, as your Lanterns found.")
        judged.whispers![1].unmasked = true
        XCTAssertEqual(WhispersSection.standing(judged.whispersHeard[1], in: judged, player: me), "Found false: it was yours.")
        judged.whispers![0].unmasked = true
        judged.whispers![0].by = other
        XCTAssertEqual(WhispersSection.standing(judged.whispersHeard[0], in: judged, player: me),
                       "Found false: it was \(judged.houses[other].title)'s.")
        var late = session.state
        late.watch += GameState.whisperReach + 1
        XCTAssertEqual(WhispersSection.standing(late.whispersHeard[1], in: late, player: me), "Yours. Unproven.")
        link.onEvent?(.changed(judged))
        draw(WhispersSection(session: session), width: 360, height: 500)
        let (quiet, _) = self.session(world("no whispers abroad"))
        draw(WhispersSection(session: quiet), width: 360, height: 300)

        // Heard: the whisper's reed call, a teller named in dread, the belied paid.
        XCTAssertEqual(GameSession.cues(for: .whisper(claim), events: [], in: session.state, player: me), [.parley])
        XCTAssertEqual(GameSession.cue(forDepth: .whisperUnmasked(id: 2, teller: me, belied: other, paid: 30), in: session.state, player: me), .dread)
        XCTAssertEqual(GameSession.cue(forDepth: .whisperUnmasked(id: 1, teller: other, belied: me, paid: 30), in: session.state, player: me), .coin)
        XCTAssertNil(GameSession.cue(forDepth: .whispered(id: 2, claim: claim), in: session.state, player: me))
        XCTAssertNotNil(Narration.line(for: .whispered(id: 2, claim: claim), in: session.state, viewer: me))
    }

    /// The Remembering on the Realm screen: the riddle folded to a line,
    /// opened to the line of the past and its four names, answered, and
    /// weighed until the realm, which alone knows the name, tells it.
    func testARiddleIsAnsweredFromTheRealm() throws {
        var state = world("a riddle on the realm")
        let me = state.player
        state.chronicle = []
        state.drowned = ["House Aske", "House Brine", "House Corrow", "House Dovet"].enumerated().map { index, house in
            DrownedHold(position: Hex(index, 0), name: "Hold \(index)", house: house, age: 1, works: 3, spire: 0)
        }
        state.watch = GameState.lunarMonth + 7
        XCTAssertEqual(state.setRiddles(), [.riddleSet(house: me)])
        let answer = try XCTUnwrap(state.riddle(of: me)?.answer)
        let (session, link) = session(state)
        let riddle = try XCTUnwrap(session.state.riddle(of: me))
        XCTAssertNil(riddle.answer, "Kept from the keeper's view")
        XCTAssertTrue(RiddleSection.standing(riddle).hasPrefix("Set at watch \(riddle.set): answer it rightly"))
        draw(RealmPanel(session: session), width: 360, height: 3200)
        XCTAssertFalse(shown.contains(answer), "Folded until asked for")
        XCTAssertTrue(PressableButtons.press("Answer…"), "Among \(shown)")
        draw(RiddleSection(session: session, riddle: riddle, open: true), width: 360, height: 400)
        XCTAssertTrue(PressableButtons.press(answer), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .answerRiddle(answer))
        let weighed = try XCTUnwrap(session.state.riddle(of: me))
        XCTAssertEqual(RiddleSection.standing(weighed), "You said \(answer); the lake weighs your answer.")
        draw(RiddleSection(session: session, riddle: weighed), width: 360, height: 400)

        // The realm's word: rightly remembered, or not.
        var told = state
        _ = try told.perform(.answerRiddle(answer), as: me)
        let right = try XCTUnwrap(told.view(for: me).riddle(of: me))
        XCTAssertEqual(RiddleSection.standing(right), "Rightly remembered: it was \(answer).")
        var missed = state
        let miss = try XCTUnwrap(riddle.choices.first { $0 != answer })
        _ = try missed.perform(.answerRiddle(miss), as: me)
        XCTAssertEqual(RiddleSection.standing(try XCTUnwrap(missed.view(for: me).riddle(of: me))), "You said \(miss); it was \(answer).")
        link.onEvent?(.changed(told.view(for: me)))
        draw(RealmPanel(session: session), width: 360, height: 3200)

        // Heard as the realm tells it, and the guesses kept back till then.
        XCTAssertEqual(GameSession.cues(for: .answerRiddle(answer), events: [], in: session.state, player: me), [.lore])
        XCTAssertEqual(GameSession.cue(forDepth: .riddleAnswered(house: me, right: true, answer: answer), in: session.state, player: me), .triumph)
        XCTAssertEqual(GameSession.cue(forDepth: .riddleAnswered(house: me, right: false, answer: answer), in: session.state, player: me), .refusal)
        XCTAssertEqual(GameSession.cue(forDepth: .riddleSet(house: me), in: session.state, player: me), .lore)
        XCTAssertTrue([GameEvent.riddleAnswered(house: me, right: true, answer: answer), .bout(Ring.Bout(watch: 1, challenger: me, defender: 1,
            challengerWeight: 50, defenderWeight: 40, won: true, change: 16)), .whisperTried(id: 1, house: me, truth: true),
            .whisperUnmasked(id: 1, teller: 1, belied: me, paid: 30)].allSatisfy(GameSession.isRealmsToTell))
        XCTAssertNotNil(Narration.line(for: .riddleSet(house: me), in: session.state, viewer: me))
    }

    /// The veil of the Still from the seat's record: drawn for moonsalt,
    /// shown while it lies on the keeper's holds and on another's, named
    /// under the pointer, and resting once lifted.
    func testTheVeilIsDrawnFromTheSeat() throws {
        var state = world("a veil drawn")
        let me = state.player
        // Short of moonsalt: why, beside the button, which can't be pressed.
        state.houses[me].stock.moonsalt = 26
        XCTAssertEqual(VeilLine.short(state, house: me), "Short of 4 moonsalt.")
        let (short, _) = session(state)
        short.selection = .hold(try XCTUnwrap(state.seat(of: me)).id)
        draw(SelectionPanel(session: short), width: 330, height: 1200)
        XCTAssertFalse(PressableButtons.press("Draw the veil"), "Among \(shown)")
        state.houses[me].stock.moonsalt = 60
        XCTAssertNil(VeilLine.short(state, house: me))
        let other = try XCTUnwrap(state.livingHouses.map(\.id).first { $0 != me })
        state.houses[other].isPlayer = true
        state.houses[other].stock.moonsalt = 60
        _ = try state.perform(.drawVeil, as: other)
        let theirs = try XCTUnwrap(state.seat(of: other))
        state.reveal(around: theirs.position, range: 1, for: me)
        let seat = try XCTUnwrap(state.seat(of: me))
        let (session, link) = session(state)
        XCTAssertTrue(VeilLine.words(session.state, house: me).hasPrefix("The veil of the Still, for 30 moonsalt"))
        session.selection = .hold(seat.id)
        draw(SelectionPanel(session: session), width: 330, height: 1200)
        XCTAssertTrue(PressableButtons.press("Draw the veil"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .drawVeil)
        XCTAssertTrue(session.state.isVeiled(me))
        XCTAssertTrue(VeilLine.words(session.state, house: me).hasPrefix("Veiled until watch \(session.state.watch + GameState.veilLasts)"))
        draw(SelectionPanel(session: session), width: 330, height: 1200)

        // Another's, on its hold's record and under the pointer.
        session.selection = .hold(theirs.id)
        draw(SelectionPanel(session: session), width: 330, height: 900)
        let line = try XCTUnwrap(HoverInfo.line(for: theirs.position, in: session.state, explored: true, territory: session.state.territory()))
        XCTAssertTrue(line.contains("veiled until watch"), line)

        // Lifted, it rests.
        var lifted = session.state
        _ = lifted.liftVeil(of: me)
        XCTAssertTrue(VeilLine.words(lifted, house: me).hasPrefix("The mist gathers again"))
        XCTAssertNil(VeilLine.short(lifted, house: me))
        XCTAssertEqual(GameSession.cues(for: .drawVeil, events: [], in: session.state, player: me), [.stand])
        XCTAssertEqual(GameSession.cue(forDepth: .veilLifted(house: me, struck: true), in: session.state, player: me), .horn)
        XCTAssertNil(GameSession.cue(forDepth: .veilLifted(house: other, struck: false), in: session.state, player: me))
    }

    /// A seat raised anew from a tile of the House's own land: offered
    /// there and nowhere a hold stands, and raised with its cost.
    func testTheSeatIsRaisedAnewFromItsLand() throws {
        var state = world("a seat moved")
        let me = state.player
        state.houses[me].stock.moonsalt = 80
        let seat = try XCTUnwrap(state.seat(of: me))
        let ground = try XCTUnwrap(state.map.hexes.first { state.seatMoveRefusal(to: $0, as: me) == nil })
        let (session, link) = session(state)
        XCTAssertTrue(SeatMoveRow.offered(at: ground, in: session.state, player: me))
        XCTAssertFalse(SeatMoveRow.offered(at: seat.position, in: session.state, player: me), "Not where a hold stands")
        XCTAssertFalse(SeatMoveRow.offered(at: ground, in: session.state, player: (me + 1) % 6), "Nor on another's land")
        session.selection = .tile(ground)
        draw(SelectionPanel(session: session), width: 330, height: 900)
        XCTAssertTrue(PressableButtons.press("Raise the seat here"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .raiseSeat(at: ground))
        XCTAssertEqual(session.state.hold(seat.id)?.position, ground)
        XCTAssertEqual(GameSession.cues(for: .raiseSeat(at: ground), events: [], in: session.state, player: me), [.rise])
    }

    /// The Ring at the foot of the Commanders: folded until asked for; a
    /// line chosen and stood; another keeper's line challenged, the bout
    /// shown and heard; and the full moon's honours heard by those honoured.
    func testTheRingIsEnteredFromTheCommanders() throws {
        var state = world("the ring entered")
        let me = state.player
        let other = try XCTUnwrap(state.livingHouses.map(\.id).first { $0 != me })
        state.houses[other].isPlayer = true
        let (session, link) = session(state)
        let mine = try XCTUnwrap(session.state.commanders(of: me).first)
        XCTAssertTrue(RingSection.standingLine(session.state, player: me).hasPrefix("Your House stands no line in the Ring."))
        draw(CommandersPanel(session: session), width: 360, height: 2600)
        XCTAssertFalse(shown.contains("Stand this line"), "Folded until asked for")
        XCTAssertTrue(PressableButtons.press("Enter the Ring…"), "Among \(shown)")

        // A commander chosen, then the line stood; no rival stands one yet.
        draw(RingSection(session: session, open: true), width: 360, height: 600)
        XCTAssertTrue(PressableButtons.press("\(mine.name) · \(session.state.ringWeight(of: mine))"), "Among \(shown)")
        draw(RingSection(session: session, open: true, picked: [mine.id]), width: 360, height: 600)
        XCTAssertTrue(PressableButtons.press("Stand this line"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .standInTheRing([mine.id]))
        XCTAssertEqual(session.state.ringLine(of: me), [mine.id])
        draw(RingSection(session: session, open: true), width: 360, height: 600)
        XCTAssertFalse(PressableButtons.press("This line stands"), "Stood already")
        XCTAssertTrue(PressableButtons.press("\(mine.name) · \(session.state.ringWeight(of: mine))"), "Taken from the line")

        // Another keeper's line, seen in the Ring and challenged.
        _ = try state.perform(.standInTheRing([mine.id]), as: me)
        let theirs = try XCTUnwrap(state.commanders(of: other).first)
        _ = try state.perform(.standInTheRing([theirs.id]), as: other)
        link.onEvent?(.changed(state.view(for: me)))
        XCTAssertNotNil(session.state.commander(theirs.id), "Every line in the Ring is seen")
        let challenge = "Challenge \(session.state.houses[other].title)"
        draw(RingSection(session: session, open: true), width: 360, height: 600)
        XCTAssertTrue(PressableButtons.press(challenge), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .challenge(house: other))
        let bout = try XCTUnwrap(session.state.ring?.bouts.last)
        XCTAssertTrue(RingSection.standingLine(session.state, player: me).hasSuffix("2 challenges left this watch."))
        XCTAssertTrue(RingSection.standingLine(session.state, player: me).contains(" of 2."))
        XCTAssertTrue(RingSection.boutLine(bout, in: session.state, player: me).hasPrefix("Watch \(bout.watch): You challenged \(session.state.houses[other].title), and"))
        XCTAssertTrue(RingSection.boutLine(bout, in: session.state, player: other).hasPrefix("Watch \(bout.watch): \(session.state.houses[me].title) challenged you"))
        draw(RingSection(session: session), width: 360, height: 400)

        // The last of the watch's challenges spent, the rest say why.
        var spent = session.state
        _ = try spent.perform(.challenge(house: other), as: me)
        _ = try spent.perform(.challenge(house: other), as: me)
        link.onEvent?(.changed(spent))
        XCTAssertTrue(RingSection.standingLine(session.state, player: me).hasSuffix("0 challenges left this watch."))
        PressableButtons.forget(challenge)
        draw(RingSection(session: session, open: true), width: 360, height: 600)
        XCTAssertFalse(PressableButtons.press(challenge), "Spent")
        var once = spent
        once.ring?.bouts.removeLast()
        XCTAssertTrue(RingSection.standingLine(once, player: me).hasSuffix("1 challenge left this watch."))

        // Heard: the orders, the bout by both Houses, the honours by those honoured.
        XCTAssertEqual(GameSession.cues(for: .standInTheRing([mine.id]), events: [], in: session.state, player: me), [.muster])
        XCTAssertEqual(GameSession.cues(for: .challenge(house: other), events: [], in: session.state, player: me), [.clash])
        XCTAssertEqual(GameSession.cue(forDepth: .bout(bout), in: session.state, player: bout.winner), .triumph)
        XCTAssertEqual(GameSession.cue(forDepth: .bout(bout), in: session.state, player: bout.loser), .refusal)
        let steward = try XCTUnwrap(session.state.livingHouses.map(\.id).first { $0 != me && $0 != other })
        XCTAssertNil(GameSession.cue(forDepth: .bout(bout), in: session.state, player: steward))
        XCTAssertEqual(GameSession.cue(forDepth: .ringHonoured(houses: [other, me]), in: session.state, player: me), .honour)
        XCTAssertNil(GameSession.cue(forDepth: .ringHonoured(houses: [other]), in: session.state, player: me))
        XCTAssertNotNil(Narration.line(for: .bout(bout), in: session.state, viewer: me))
        XCTAssertNotNil(Narration.line(for: .ringHonoured(houses: [other]), in: session.state, viewer: me))
        XCTAssertNil(Narration.line(for: .ringLineStood(house: other, line: [theirs.id]), in: session.state, viewer: me))
    }

    /// A Mangonel of the keeper's: its panel teaches how it strikes while
    /// the first steps are taught, the map without Metal draws it in a
    /// glyph of its own, and its blows sound as a ram's.
    func testAMangonelIsTaughtDrawnAndHeard() throws {
        var state = world("a mangonel")
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        let hex = try free(near: seat.position, in: state)
        let engine = Unit(id: state.takeID(), kind: .mangonel, owner: me, position: hex, tier: 3)
        state.units.append(engine)
        let (session, _) = session(state)
        XCTAssertNotNil(session.firstSteps, "taught in the first steps")
        session.selection = .unit(engine.id)
        draw(UnitPanel(session: session, unit: engine), width: 330, height: 700)
        draw(SelectionPanel(session: session), width: 330, height: 900)
        draw(WorldFallback(session: session), width: 900, height: 700)
        XCTAssertEqual(GameSession.strikeCue(.mangonel), .batter)
        XCTAssertEqual(GameSession.strikeCue(.bow), .loose)
        XCTAssertEqual(GameSession.strikeCue(.rider), .clash)
        let hunt = GameEvent.hunted(Hunt(attacker: engine.id, attackerOwner: me, attackerKind: .mangonel, wild: 1, wildKind: .saltwights, level: 1,
                                         at: hex, damageDealt: 10, damageTaken: 0, attackerFell: false, wildFell: false, spoils: Stock()))
        XCTAssertEqual(GameSession.cue(forDepth: hunt, in: session.state, player: me), .batter)
    }

    /// The Frontier on the Realm screen: how its kingdoms stand, the way
    /// across with the House's levy, and, there, the way home.
    func testTheFrontierIsCrossedAndLeftFromTheRealm() throws {
        let (session, link) = session(world("the frontier's way"))
        let news = FrontierNews(address: "https://realm.test/frontier", season: 2, watch: 3, lasts: 24, open: true,
                                standings: [KingdomStanding(realm: "The Farmere", points: 40, keepers: 3),
                                            KingdomStanding(realm: "The Nullmere", points: 12, keepers: 1)], last: nil)
        link.onEvent?(.status(RealmStatus(name: "The Nullmere", age: 1, watch: 3, seats: 6, freeSeats: 0, keepers: 1, online: 1, ready: 0,
                                          secondsLeft: 60, isEnding: false, frontier: news)))
        XCTAssertTrue(session.canCross)
        draw(RealmPanel(session: session), width: 360, height: 2400)
        XCTAssertTrue(PressableButtons.press("Cross to the Frontier"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .crossToFrontier)

        // There, the way home and no way across.
        var returned = 0
        session.onReturnHome = { returned += 1 }
        XCTAssertFalse(session.canCross)
        draw(RealmPanel(session: session), width: 360, height: 2400)
        XCTAssertTrue(PressableButtons.press("Return Home"), "Among \(shown)")
        XCTAssertEqual(returned, 1)
    }

    // MARK: Words

    /// A line of commanders sent up the Spine from Commanders.
    func testALineIsSentUpTheSpine() throws {
        var state = world("pressed line")
        let me = state.player
        while state.commanders(of: me).count < 3 { _ = state.commanderJoins(me, why: "joins") }
        let lead = try XCTUnwrap(state.commanders(of: me).first)
        let line = ExpeditionLine.line(with: lead, in: state, for: me)
        XCTAssertEqual(line.count, 3)
        XCTAssertEqual(line.first, lead.id)
        let (session, link) = session(state)
        draw(ExpeditionLine(session: session, commander: try XCTUnwrap(session.state.commander(lead.id))))
        XCTAssertTrue(PressableButtons.press("Send a line"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .ventureLine(commanders: line, stage: nil))
        XCTAssertTrue(session.state.hasVentured(me))
        // Its fight drawn on the Spine nearest the seat: a blow and a flare
        // of skill for each commander of the line.
        let field = try XCTUnwrap(GameSession.expeditionField(in: session.state, for: me))
        XCTAssertEqual(session.state.map[field.at]?.terrain, .spine)
        XCTAssertEqual(field.from.distance(to: field.at), 1)
        var result = ExpeditionResult(house: me, commander: lead.id, stage: 1, weight: 90, against: 60, won: true)
        result.line = line
        result.stars = 2
        let before = session.blows.count
        session.showBlows([.expedition(result)])
        XCTAssertEqual(session.blows.count - before, line.count)
        XCTAssertTrue(session.blows.suffix(line.count).allSatisfy { $0.at == field.at && $0.from == field.from })
        XCTAssertEqual(GameSession.place(of: .expedition(result), in: session.state), field.at)
        // Its figures on the ridge: the line below it, each commander at the
        // head of a company striking in turn, and the stage's host on it,
        // falling once the last blow has landed.
        let fight = try XCTUnwrap(session.expeditionFights.last)
        XCTAssertEqual(fight.line, line)
        let start = fight.start
        let figures = { (age: Double) in
            session.companyPoses(at: start.addingTimeInterval(age), animated: true, time: age)
                .filter { $0.unit <= GameSession.expeditionPoseBase }
        }
        let early = figures(0.1)
        let mine = early.filter(\.isOwn), host = early.filter { !$0.isOwn }
        XCTAssertEqual(mine.count, line.count)
        XCTAssertEqual(mine.compactMap(\.commander).count, line.count, "each led by its commander")
        XCTAssertTrue(mine.allSatisfy { $0.hex == field.from })
        XCTAssertEqual(mine.first?.clip, .attack, "the first strikes at once")
        XCTAssertEqual(mine.last?.clip, .idle, "the last in its turn")
        XCTAssertEqual(host.count, fight.hostSize)
        XCTAssertTrue(host.allSatisfy { $0.hex == field.at })
        XCTAssertTrue(figures(1.6).filter { !$0.isOwn }.allSatisfy { $0.clip == .death }, "won: the host falls")
        XCTAssertTrue(figures(3.9).filter { !$0.isOwn }.isEmpty, "and is gone")
        let lost = ExpeditionResult(house: me, commander: lead.id, stage: 7, weight: 40, against: 90, won: false)
        session.showBlows([.expedition(lost)])
        let held = try XCTUnwrap(session.expeditionFights.last)
        XCTAssertEqual(held.hostSize, 4, "a higher stage, a greater host")
        let standing = session.companyPoses(at: held.start.addingTimeInterval(1.6), animated: true, time: 1.6)
            .filter { $0.unit <= GameSession.expeditionPoseBase - held.id * 8 - 4 && $0.unit > GameSession.expeditionPoseBase - held.id * 8 - 8 }
        XCTAssertEqual(standing.count, 4)
        XCTAssertTrue(standing.allSatisfy { $0.clip == .attack }, "lost: the host stands and strikes back")
    }

    /// A false reflection cast from a hold by the water.
    func testAFalseReflectionIsCastFromTheWater() throws {
        var state = world("pressed reflection")
        let me = state.player
        let seatIndex = try XCTUnwrap(state.holds.firstIndex { $0.owner == me && $0.isSeat })
        let shore = try XCTUnwrap(state.map.hexes.first { state.isShore($0) && state.hold(at: $0) == nil })
        state.holds[seatIndex].position = shore
        state.reveal(around: shore, range: GameState.falseReflectionReach, for: me)
        state.houses[me].stock.moonsalt = 30
        let seat = state.holds[seatIndex]
        let (session, link) = session(state)
        let at = try XCTUnwrap(ReflectionRow.shore(near: seat, in: session.state, for: me))
        XCTAssertTrue(ReflectionRow.line(session.state, house: me).contains("though none is there"))
        draw(ReflectionRow(session: session, hold: seat))
        XCTAssertTrue(PressableButtons.press("Cast a reflection"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .castReflection(hold: seat.id, at: at, kind: .spear))
        XCTAssertTrue(ReflectionRow.line(session.state, house: me).hasPrefix("1 false reflection wait"))
    }

    /// A company of war on the Still's shore is offered the mirror; inland, not.
    func testACompanyOnTheShoreWalksTheMirrorFromItsPanel() throws {
        var state = world("pressed mirror")
        let me = state.player
        let shore = try XCTUnwrap(state.map.hexes.first { hex in
            state.isOnTheStill(hex) && state.map[hex]!.terrain.isPassable && state.unit(at: hex) == nil
                && state.hold(at: hex) == nil && state.mirrorLanding(from: hex) != nil
        })
        let company = NullmereCore.Unit(id: state.takeID(), kind: .spear, owner: me, position: shore)
        state.units.append(company)
        state.houses[me].stock.credit(MirrorWalk.price)
        let (session, link) = session(state)
        session.selection = .unit(company.id)
        PressableButtons.isListening = true
        draw(SelectionPanel(session: session), width: 330, height: 900)
        XCTAssertTrue(PressableButtons.press("Walk the mirror"))
        XCTAssertEqual(link.sent.last, .walkTheMirror(unit: company.id))
        XCTAssertEqual(UnitPanel.mirrorHelp(nil), "The Still shows no open ground on the far shore.")
        XCTAssertTrue(UnitPanel.mirrorHelp(shore).hasPrefix("Step into the Still for \(MirrorWalk.price)"))
    }

    /// A Beacon's warning, said as much as its grade tells.
    func testABeaconsWarningSaysWhatItsGradeTells() throws {
        let state = world("pressed beacon")
        let foe = (state.player + 1) % state.houses.count
        let at = Hex(1, 1)
        XCTAssertEqual(WorldMarks.warningLine(MarchWarning(hold: 1, from: at, house: nil, kind: nil, troops: nil, watches: nil), in: state), "A march")
        XCTAssertEqual(WorldMarks.warningLine(MarchWarning(hold: 1, from: at, house: foe, kind: .rider, troops: nil, watches: nil), in: state),
                       "\(state.houses[foe].title)'s Riders")
        XCTAssertEqual(WorldMarks.warningLine(MarchWarning(hold: 1, from: at, house: foe, kind: .spear, troops: 4_000, watches: 2), in: state),
                       "\(state.houses[foe].title)'s Spears · \(GameState.counted(4_000)) · in 2 watches")
        XCTAssertTrue(WorldMarks.warningLine(MarchWarning(hold: 1, from: at, house: foe, kind: .spear, troops: 10, watches: 1), in: state).hasSuffix("this watch"))
    }

    /// The Lantern Inn in the Realm panel: keys, chests opened by button.
    func testTheInnsChestsAreOpenedFromTheRealmPanel() throws {
        var state = world("pressed inn")
        let me = state.player
        state.turnInn()
        state.houses[me].stock.moonsalt = 0 // the gold chest's button drawn disabled
        state.innBook![me]!.gold = 0
        let keys = state.innKeys(of: me)
        XCTAssertEqual(InnSection.summary(keys), "1 silver key · \(keys.gold) gold")
        XCTAssertEqual(InnSection.means(.silver, keys), "With a silver key")
        XCTAssertEqual(InnSection.means(.gold, InnKeys(silver: 0, gold: 0, sinceCommander: 0, opened: 0)), "For \(InnKeys.goldPrice)")
        let (session, link) = session(state)
        draw(InnSection(session: session))
        PressableButtons.isListening = true
        draw(InnSection(session: session, open: true))
        XCTAssertTrue(PressableButtons.press("Open"), "The silver chest's, the gold one's being disabled")
        XCTAssertEqual(link.sent.last, .openInnChest(.silver))
        draw(RealmPanel(session: session))
    }

    /// The watch's labours in the Realm panel, folded and opened.
    func testTheWatchsLaboursAreShown() throws {
        var state = world("pressed labours")
        let me = state.player
        _ = state.turnLabours()
        let labours = try XCTUnwrap(state.labours(of: me))
        XCTAssertTrue(LaboursSection.summary(labours).hasPrefix("0 of 3 done this watch"))
        XCTAssertEqual(LaboursSection.line(Labour(kind: .raise, done: 3)), "Raise works: 1 of 1")
        let (session, _) = session(state)
        draw(LaboursSection(session: session))
        draw(LaboursSection(session: session, open: true))
    }

    /// The realm's calendar in the Realm panel, folded and opened.
    func testTheCalendarShowsWhatIsComing() throws {
        let state = world("pressed calendar")
        let (session, _) = session(state)
        let entries = session.state.calendar(for: session.player)
        XCTAssertFalse(entries.isEmpty)
        let first = try XCTUnwrap(entries.first)
        XCTAssertTrue(CalendarSection.line(first, now: session.state.watch).hasSuffix(first.title))
        XCTAssertEqual(CalendarSection.line(CalendarEntry(watch: session.state.watch + 1, kind: .stillHour), now: session.state.watch),
                       "Next watch: The Still Hour")
        draw(CalendarSection(session: session))
        draw(CalendarSection(session: session, open: true))
        draw(RealmPanel(session: session))
    }

    /// Letters between two keepers, under Letters in the Words.
    func testALetterIsWrittenToOneKeeperAndShownToBoth() throws {
        var state = world("pressed letters")
        let me = state.player
        let other = (me + 1) % 6
        state.houses[other].isPlayer = true
        XCTAssertEqual(LettersSection.keepers(in: state, besides: me), [other])
        _ = try state.perform(.writeLetter(to: me, words: "Meet at the ford"), as: other)
        let (session, link) = session(state)
        let letter = try XCTUnwrap(session.state.letters(of: me).first)
        XCTAssertEqual(LettersSection.line(letter, in: session.state, player: me), "From \(session.state.houses[other].title): Meet at the ford")
        draw(WordsPanel(session: session))
        draw(LettersSection(session: session))
        draw(LettersSection(session: session, open: true, draft: "I will be there"))
        XCTAssertTrue(PressableButtons.press("Send"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .writeLetter(to: other, words: "I will be there"))
        let sent = try XCTUnwrap(session.state.letters(of: me).last)
        XCTAssertEqual(LettersSection.line(sent, in: session.state, player: me), "To \(session.state.houses[other].title): I will be there")
        XCTAssertEqual(GameSession.cues(for: .writeLetter(to: other, words: "x"), events: [], in: session.state, player: me), [.parley])
    }

    /// A realm of more keepers than a menu shows well: a letter's reader
    /// chosen among those the keeper has reason to write to, nearest first,
    /// or found by name, not picked from a menu of every keeper.
    func testAWideRealmsLetterGoesToAKeeperChosenAmongThoseOffered() throws {
        var state = GameState(settings: GameSettings(seedText: "a wide realm's letters", houseCount: 128,
                                                     radius: RealmState.radius(forSeats: 128), keepers: 1))
        let me = state.player
        for house in state.houses.indices { state.houses[house].isPlayer = true }
        let (session, link) = session(state)
        let keepers = LettersSection.keepers(in: session.state, besides: me)
        XCTAssertEqual(keepers.count, 127)
        let choice = session.state.houseChoice(by: me, excluding: [me], among: Set(keepers))
        XCTAssertTrue(choice.searchable)
        let near = try XCTUnwrap(choice.offered.first)
        draw(LettersSection(session: session, open: true), width: 360, height: 1200)
        XCTAssertEqual(shown.filter { $0.hasPrefix("To House") }.count, choice.offered.count, "Among \(shown)")
        XCTAssertLessThan(choice.offered.count, 40, "Not a hundred and twenty-seven")
        XCTAssertFalse(shown.contains("Send"), "No one to write to until one is chosen")
        XCTAssertTrue(PressableButtons.press("To \(near.title)"), "Among \(shown)")
        draw(LettersSection(session: session, open: true, to: near.id, draft: "Well met, neighbour"), width: 360, height: 1200)
        XCTAssertTrue(PressableButtons.press("Send"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .writeLetter(to: near.id, words: "Well met, neighbour"))
    }

    /// The Pedlar of the Still lying off the keeper's hold, a ware bought.
    func testThePedlarsCardSellsAWare() throws {
        var state = world("pressed pedlar")
        let me = state.player
        let seatIndex = try XCTUnwrap(state.holds.firstIndex { $0.owner == me && $0.isSeat })
        let shore = try XCTUnwrap(state.map.hexes.first { state.isShore($0) && state.hold(at: $0) == nil })
        state.holds[seatIndex].position = shore
        state.reveal(around: shore, range: GameState.stoneFromHold, for: me)
        state.watch = GameState.pedlarComes(to: me, from: state.watch + 1)
        _ = state.turnThePedlars()
        let pedlar = try XCTUnwrap(state.pedlar(for: me))
        let ware = try XCTUnwrap(pedlar.wares.first { if case .sculptures = $0.goods { return true } else { return false } })
        state.houses[me].stock.credit(ware.price)
        let (session, link) = session(state)
        UserDefaults.standard.set(true, forKey: OwnHoldDetails.waterKey)
        defer { UserDefaults.standard.removeObject(forKey: OwnHoldDetails.waterKey) }
        draw(OwnHoldDetails(session: session, hold: try XCTUnwrap(session.state.hold(pedlar.hold))), height: 2400)
        draw(PedlarCard(session: session, pedlar: try XCTUnwrap(session.state.pedlar(for: me))))
        XCTAssertTrue(PressableButtons.press("Buy"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .buyFromPedlar(ware: ware.id))
        XCTAssertEqual(session.state.pedlar(for: me)?.wares.first { $0.id == ware.id }?.sold, true)
        draw(PedlarCard(session: session, pedlar: try XCTUnwrap(session.state.pedlar(for: me))))
        XCTAssertEqual(GameSession.cues(for: .buyFromPedlar(ware: ware.id), events: [], in: session.state, player: me), [.coin])
    }

    /// A commander's star raised, and sent up the Spine, from Commanders.
    func testAStarIsRaisedAndACommanderVentures() throws {
        var state = world("pressed stars")
        let me = state.player
        let commander = try XCTUnwrap(state.commanders(of: me).first)
        _ = state.giveSculptures(10, to: me)
        XCTAssertEqual(StarsLine.line(commander, kept: 10), "Next star: 10 sculptures, 10 kept")
        let (session, link) = session(state)
        draw(StarsLine(session: session, commander: commander))
        XCTAssertTrue(PressableButtons.press("Raise a star"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .raiseStar(commander: commander.id))
        XCTAssertEqual(session.state.commander(commander.id)?.starCount, 2)
        XCTAssertTrue(ExpeditionLine.line(session.state, commander: try XCTUnwrap(session.state.commander(commander.id)), house: me).contains("the Scree Gate"))
        draw(ExpeditionLine(session: session, commander: try XCTUnwrap(session.state.commander(commander.id))))
        XCTAssertTrue(PressableButtons.press("Venture"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .venture(commander: commander.id))
        XCTAssertTrue(session.state.hasVentured(me))
        XCTAssertEqual(GameSession.cues(for: .raiseStar(commander: commander.id), events: [], in: session.state, player: me), [.honour])
    }

    func testWordsAreHeardSaidAndShown() throws {
        var state = world("pressed words")
        let me = state.player
        let other = (me + 1) % 6
        state.houses[other].isPlayer = true
        // Nothing said yet: the Words say where words said go.
        let (quiet, _) = session(state)
        draw(WordsPanel(session: quiet))
        _ = try state.perform(.say(words: "Well met", toAlliance: false), as: other)
        let (session, link) = session(state)
        XCTAssertEqual(session.state.words(heardBy: me).map(\.text), ["Well met"])
        draw(WordsPanel(session: session))
        XCTAssertFalse(PressableButtons.press("Say"), "Nothing written, nothing to say")
        draw(WordsPanel(session: session, draft: "And you"))
        XCTAssertTrue(PressableButtons.press("Say"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .say(words: "And you", toAlliance: false))
        let said = session.state.wordsSaid
        XCTAssertEqual(said.map(\.text), ["Well met", "And you"])
        XCTAssertEqual(WordLine.speaker(try XCTUnwrap(said.last), in: session.state, player: me), "You")
        XCTAssertEqual(WordLine.speaker(try XCTUnwrap(said.first), in: session.state, player: me), session.state.houses[other].title)
        XCTAssertFalse(session.perform(.say(words: "   ", toAlliance: false)), "Nothing to say is refused")
        XCTAssertFalse(WordsPanel.say("", toAlliance: false, in: session))
        XCTAssertTrue(WordsPanel.say("Hold fast", toAlliance: true, in: session), "sworn to none, said to the realm")
        XCTAssertEqual(link.sent.last, .say(words: "Hold fast", toAlliance: false))
        XCTAssertFalse(session.perform(.say(words: "Hail", toAlliance: true)), "Sworn to none, no alliance to say it to")
        draw(WordsPanel(session: session))
        XCTAssertEqual(GameSession.cues(for: .say(words: "Hail", toAlliance: false), events: [], in: session.state, player: me), [.parley])

        // Another's line reported to the realm's steward from its menu; once.
        let met = try XCTUnwrap(said.first)
        XCTAssertFalse(PressableButtons.actions.keys.contains("Report line \(try XCTUnwrap(said.last).id)"), "One's own line isn't reported")
        XCTAssertTrue(PressableButtons.press("Report line \(met.id)"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .reportWord(word: met.id))
        XCTAssertEqual(session.state.wordReports.map(\.word), [met.id])
        draw(WordsPanel(session: session))
        XCTAssertFalse(PressableButtons.actions.keys.contains("Report line \(met.id)"), "Reported once")

        // Taken away by the realm's steward, a line stands as taken away;
        // barred, the keeper is told why nothing is said.
        var judged = session.state
        _ = judged.removeWord(met.id)
        _ = judged.bar(me, watches: 3)
        link.onEvent?(.changed(judged))
        let gone = try XCTUnwrap(session.state.wordsSaid.first { $0.id == met.id })
        XCTAssertEqual(WordLine.shown(gone), GameState.removedWords)
        XCTAssertEqual(WordLine.shown(try XCTUnwrap(session.state.wordsSaid.last)), session.state.wordsSaid.last?.text)
        XCTAssertEqual(session.state.sayRefusal("Again", toAlliance: false, as: me), .barredFromWords(until: judged.watch + 3))
        draw(WordsPanel(session: session))
        XCTAssertFalse(PressableButtons.actions.keys.contains("Report line \(met.id)"), "A line taken away is no more to report")
    }

    /// A House's keeper hidden is hidden everywhere: their words in the
    /// Words, as notices and in the songbook. Words said by others since
    /// the keeper last read them are counted on the rail until they do.
    func testHiddenWordsAreHiddenEverywhereAndUnreadOnesCounted() throws {
        UserDefaults.standard.removeObject(forKey: GameSession.mutedKey)
        defer { UserDefaults.standard.removeObject(forKey: GameSession.mutedKey) }
        var state = world("hidden words")
        let me = state.player
        let (other, third) = ((me + 1) % 6, (me + 2) % 6)
        state.houses[other].isPlayer = true
        state.houses[third].isPlayer = true
        _ = try state.perform(.say(words: "Before you came", toAlliance: false), as: other)
        let (session, link) = session(state)
        XCTAssertEqual(session.unreadWords, 0, "What was said before the keeper came counts as read")

        // Others speak while the keeper is away from the Words.
        _ = try state.perform(.say(words: "Well met", toAlliance: false), as: other)
        _ = try state.perform(.say(words: "Hold the ford", toAlliance: false), as: third)
        link.onEvent?(.changed(state.view(for: me)))
        XCTAssertEqual(session.unreadWords, 2)
        draw(PanelRail(session: session), width: 720, height: 40)
        XCTAssertTrue(PressableButtons.press("Words"), "Among \(PressableButtons.actions.keys.sorted())")
        draw(WordsPanel(session: session))
        session.markWordsRead()
        XCTAssertEqual(session.unreadWords, 0, "Read")

        // One keeper's House hidden: gone from the Words, and from what is told.
        session.setMuted(true, house: session.state.houses[other])
        XCTAssertTrue(session.isMuted(other))
        XCTAssertEqual(session.wordsHeard.map(\.text), ["Hold the ford"])
        _ = try state.perform(.say(words: "Do you hear me", toAlliance: false), as: other)
        link.onEvent?(.changed(state.view(for: me)))
        XCTAssertEqual(session.unreadWords, 0, "Nothing counted of a hidden House")
        let notices = session.notices.count
        link.onEvent?(.heard([.said(try XCTUnwrap(state.wordsSaid.last))]))
        XCTAssertEqual(session.notices.count, notices, "Nor told")
        session.setMuted(false, house: session.state.houses[other])
        XCTAssertEqual(session.unreadWords, 1)
    }

    // MARK: Every state drawn

    /// Each new screen drawn in each of its states: an Archive not yet
    /// raised and a study mastered; a roster empty, wounded, ready to fire;
    /// an alliance asked to, rallying, its gates to keep; the realm between
    /// happenings and in one, with a keeper's renown; words none and many;
    /// a company carrying and led; tiers to choose; a rally with no hall.
    func testEveryNewScreenDrawsInEachOfItsStates() throws {
        var state = world("every state")
        let me = state.player
        let (other, foe) = ((me + 1) % 6, (me + 2) % 6)
        state.houses[other].isPlayer = true
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == me && $0.isSeat })

        // The Archive: none raised; then a study mastered, another under way.
        do {
            let (session, _) = self.session(state)
            draw(ArchivePanel(session: session))
            XCTAssertEqual(ArchivePanel.subtitle(session.state.archiveBoard(for: me)), "No Archive yet")
        }
        state.holds[seat].levels[.archive] = 4
        state.holds[seat].levels[.musterHall] = 3
        state.houses[me].stock = Stock(grain: 900, timber: 900, stone: 900, moonsalt: 90)
        state.houses[me].research = Research(known: [Learned(study: .drill, grade: 1), Learned(study: .spearwork, grade: 1),
                                                     Learned(study: .ironRanks, grade: 1)])
        _ = try state.perform(.study(.furrowLore), as: me)

        // Commanders: one wounded, one ready to fire at a company's head.
        var random = SeededRandom(seed: 5)
        state.raiseCommander(for: me, archetype: .vanguard, using: &random)
        let roster = state.commanders(of: me).map(\.id)
        let company = try XCTUnwrap(state.units(of: me).first { $0.kind.isMilitary })
        _ = try state.perform(.assign(commander: roster[0], unit: company.id), as: me)
        let led = try XCTUnwrap(state.commanderIndex(roster[0]))
        state.commanders![led].experience = Commander.experience(forLevel: 12)
        state.commanders![led].fury = 5
        state.commanders![try XCTUnwrap(state.commanderIndex(roster[1]))].woundedUntil = state.watch + 2

        // An alliance of the keeper's, asked to by another keeper, rallying against a foe.
        _ = try state.perform(.foundAlliance(name: "The Ashen Ring"), as: me)
        let banner = try XCTUnwrap(state.alliance(of: me)).id
        _ = try state.perform(.askToJoin(alliance: banner), as: other)
        let ally = (me + 3) % 6
        let index = try XCTUnwrap(state.alliances?.firstIndex { $0.id == banner })
        state.alliances![index].members.append(ally)
        // The ally with a work rising to help, and its seat known.
        let allySeat = try XCTUnwrap(state.holds.firstIndex { $0.owner == ally && $0.isSeat })
        state.holds[allySeat].project = Hold.Project(kind: .granary, targetLevel: 1, watchesLeft: 3)
        state.reveal(around: state.holds[allySeat].position, range: 1, for: me)
        // Founders, for the charge that founds a hold.
        _ = try XCTUnwrap(state.placeUnit(.founder, for: me, near: state.holds[seat].position))
        _ = try state.declareWar(by: me, on: foe)
        let target = try XCTUnwrap(state.holds.first { $0.owner == foe })
        state.reveal(around: target.position, range: 1, for: me)
        _ = try state.perform(.callRally(from: state.holds[seat].id, against: target.id, watches: 3), as: me)

        // The realm in a happening, with the keeper and others scoring.
        var happening = Happening(number: 0, kind: .harvestFair, begins: state.watch, houses: state.houses.count)
        happening.points[me] = 12
        happening.points[foe] = 30
        state.happening = happening
        _ = try state.perform(.say(words: "Well met", toAlliance: false), as: other)
        _ = try state.perform(.say(words: "The ford is ours", toAlliance: true), as: me)

        // A second company, carrying stores home.
        let placed = try XCTUnwrap(state.placeUnit(.bow, for: me, near: state.holds[seat].position))
        let carrier = try XCTUnwrap(state.units.firstIndex { $0.id == placed.id })
        state.units[carrier].load = Stock(timber: 30)
        state.units[carrier].errand = .homeward

        let (session, _) = self.session(state)
        session.keeper = try JSONDecoder().decode(Keeper.self, from: Data("""
            {"id":"k","name":"Ama","house":\(me),"isReady":false,"isOnline":true,"arrival":0,"renown":25,"titles":["Lord of the Lake, Age 1"]}
            """.utf8))
        draw(ArchivePanel(session: session))
        draw(CommandersPanel(session: session))
        session.selection = .unit(company.id)
        draw(CommandersPanel(session: session))
        draw(AlliancePanel(session: session))
        let helpable = session.state.helpable(by: me, for: ally)
        XCTAssertGreaterThan(helpable, 0)
        for title in ["Help \(helpable)", "Keep their gates", "Send the chosen", "Refuse", "Admit", "Cast out"] {
            XCTAssertTrue(PressableButtons.press(title), "\(title) among \(shown)")
        }
        draw(RealmPanel(session: session))
        draw(WordsPanel(session: session))
        draw(SelectionPanel(session: session), width: 330, height: 700)
        session.selection = .unit(state.units[carrier].id)
        draw(SelectionPanel(session: session), width: 330, height: 700)
        session.selection = .unit(company.id)
        draw(SelectionPanel(session: session), width: 330, height: 700)
        XCTAssertTrue(PressableButtons.press("Commanders"), "Among \(shown)")
        XCTAssertEqual(session.panel, .commanders)
        ChargeGuide.show(.foundHold, in: session)
        if case .unit(let chosen) = session.selection {
            XCTAssertEqual(session.state.unit(chosen)?.kind, .founder, "Founders chosen to found a hold")
        } else {
            XCTFail("Founders chosen: \(session.selection)")
        }
        session.focusOnSeat()
        draw(SelectionPanel(session: session), width: 330, height: 900)
        draw(ChargeCard(session: session), width: 330, height: 200)

        // Between happenings, with no commanders, and with no Muster Hall to rally from.
        state.happening = nil
        state.commanders = state.commanders?.filter { $0.owner != me }
        state.holds[seat].levels[.musterHall] = nil
        state.rallies = []
        state.chargesDone = Array(repeating: Charge.allCases.count, count: state.houses.count)
        state.units.removeAll { $0.owner == me && $0.kind.isMilitary }
        let (bare, _) = self.session(state)
        draw(RealmPanel(session: bare))
        XCTAssertNil(bare.state.realmBoard(for: me).charge, "every charge kept")
        ChargeGuide.show(.gatherSite, in: bare)
        XCTAssertEqual(bare.selection, .hold(try XCTUnwrap(bare.state.seat(of: me)).id), "with no company of war, the seat to muster one")
        draw(CommandersPanel(session: bare))
        bare.selection = .hold(target.id)
        draw(SelectionPanel(session: bare), width: 330, height: 700)
        XCTAssertEqual(AlliancePanel.when(RallyLine(rally: Rally(id: 1, caller: 0, muster: 1, target: 2, called: 0, setsOut: 3),
                                                    watchesLeft: 0, companies: 1, capacity: 4, isCaller: true)), "Sets out as the watch turns")
        let board = bare.state.realmBoard(for: me)
        XCTAssertNotNil(board.nextBegins)
        XCTAssertEqual(CommandersPanel.standing(of: CommanderLine(commander: Commander(id: 9, name: "Ysra", archetype: .warden, owner: me),
                                                                  level: 1, progress: 0, span: 50, skills: [], leads: nil,
                                                                  woundedFor: 1, heldBy: nil, furyReady: false)),
                       "Wounded: whole again next watch")
    }

    // MARK: Battle reports

    func testTheHousesBattlesAreReportedInTheChronicle() throws {
        let (session, _) = session(world("reported"))
        let me = session.player
        let foe = (me + 1) % session.state.houses.count
        let others = (me + 2) % session.state.houses.count
        let company = try XCTUnwrap(session.state.units(of: me).first { $0.kind.isMilitary })
        draw(ChroniclePanel(session: session, showingReports: true), width: 400)
        func battle(_ attacker: Int, _ defender: Int, fell: Bool) -> GameEvent {
            .battle(Battle(attacker: 90, attackerOwner: attacker, attackerKind: .rider, defender: company.id, defenderOwner: defender,
                           defenderKind: .spear, hold: nil, at: company.position, damageDealt: 30, damageTaken: 8,
                           attackerFell: false, defenderFell: fell))
        }
        session.showBlows([battle(foe, me, fell: false), battle(foe, others, fell: true),
                           .hunted(Hunt(attacker: company.id, attackerOwner: me, attackerKind: .spear, wild: 900, wildKind: .reavers,
                                        level: 2, at: company.position, damageDealt: 20, damageTaken: 4, attackerFell: false,
                                        wildFell: true, spoils: Stock(timber: 30)))])
        XCTAssertEqual(session.reports.count, 2, "the House's battle and its hunt; not others'")
        XCTAssertEqual(session.reports.first?.outcome, .won, "the latest first: the hunt")
        XCTAssertEqual(session.reports.last?.outcome, .held)
        XCTAssertNotEqual(session.reports.first?.id, session.reports.last?.id)
        draw(ChroniclePanel(session: session, showingReports: true), width: 400)
        draw(ChroniclePanel(session: session), width: 400)
        XCTAssertEqual(["Won", "Lost", "Both stood"], [BattleReport.Outcome.won, .lost, .held].map { ReportList.outcome($0) })
        for _ in 0..<(GameSession.reportsKept + 5) { session.showBlows([battle(foe, me, fell: false)]) }
        XCTAssertEqual(session.reports.count, GameSession.reportsKept, "the latest kept")
    }

    // MARK: Fields of battle

    func testAFieldOfBattleIsShownToldAndReported() throws {
        var state = world("field shown")
        let me = state.player
        let foe = (me + 1) % state.houses.count
        let company = try XCTUnwrap(state.units(of: me).first { $0.kind.isMilitary })
        let theirs = try XCTUnwrap(state.units.first { $0.owner == foe && $0.kind.isMilitary })
        var field = Field(id: 950, at: company.position, joined: state.watch, first: me, second: foe)
        field.fighters = [Fighter(unit: company.id, owner: me, side: 0, kind: company.kind, tier: company.tier, leader: nil, troops: 1_200),
                          Fighter(unit: theirs.id, owner: foe, side: 1, kind: theirs.kind, tier: theirs.tier, leader: nil, troops: 1_000)]
        field.fighters[0].slain = 700
        field.fighters[0].lost = 200
        field.fighters[0].foe = theirs.id
        field.fighters[1].slain = 200
        field.fighters[1].lost = 700
        state.fields = [field]
        let (session, _) = session(state)
        let titles = (state.houses[me].title, state.houses[foe].title)

        // On the map: its blades and each side's troops, the troops of each
        // company in it; on hover, and to VoiceOver.
        draw(WorldMarks(session: session), width: 900, height: 700)
        draw(WorldMarks(session: session, modelsDrawn: true), width: 900, height: 700)
        let hover = try XCTUnwrap(HoverInfo.line(for: company.position, in: session.state, explored: true, territory: session.state.territory()))
        XCTAssertTrue(hover.contains("a battle, \(titles.0)'s side 1,000 troops against \(titles.1)'s 300"), hover)
        // In the world, its dust, as thick as the companies standing in it.
        let stage = WorldStage(map: session.state.map, relief: Relief(map: session.state.map))
        let dust = session.happenings(poses: [], sights: [], stage: stage, at: Date(), time: 1).battles
        XCTAssertEqual(dust.map(\.strength), [2])
        XCTAssertEqual(dust.first.map { abs($0.at.x - Relief.centre(of: company.position).x) < 1e-3 }, true)
        let items = MapAccessibility.items(for: session)
        XCTAssertTrue(items.contains { $0.id == "field-950" && $0.label.hasPrefix("a battle, \(titles.0)'s side") })
        XCTAssertTrue(try XCTUnwrap(items.first { $0.selection == .unit(company.id) }).label.contains("in battle"))

        // A blow in it is neither reported alone nor told; its joining is told, and its end is both.
        var blow = Battle(attacker: company.id, attackerOwner: me, attackerKind: company.kind, defender: theirs.id, defenderOwner: foe,
                          defenderKind: theirs.kind, hold: nil, at: theirs.position, damageDealt: 20, damageTaken: 6,
                          attackerFell: false, defenderFell: false, slain: 240, lost: 60)
        blow.field = 950
        let joined = GameEvent.fieldJoined(field: 950, at: company.position, first: me, second: foe)
        session.showBlows([joined, .battle(blow)])
        XCTAssertTrue(session.reports.isEmpty, "Told in the field's report, as it ends")
        XCTAssertNil(Narration.line(for: .battle(blow), in: session.state, viewer: me))
        XCTAssertEqual(Narration.line(for: joined, in: session.state, viewer: me)?.text,
                       "Battle is joined \(session.state.placeName(of: company.position)): your companies fall upon \(titles.1)'s.")
        var over = field
        over.held = 0
        over.fighters[1].standing = false
        over.fighters[1].fell = true
        session.showBlows([.fieldEnded(over)])
        let report = try XCTUnwrap(session.reports.first)
        XCTAssertEqual(report.outcome, .won)
        XCTAssertEqual(report.sides.map(\.companies), [1, 1])
        XCTAssertEqual(ReportList.side(report.sides[0]), "Your side: 1 company, 1,200 troops; 200 lost")
        XCTAssertEqual(ReportList.side(report.sides[1]), "The foe: 1 company, 1,000 troops; 700 lost, 1 company fallen")
        XCTAssertEqual(ReportList.side(BattleReport.Side(title: "The foe", houses: 2, companies: 3, troops: 3_000, lost: 900, fallen: 2)),
                       "The foe: 3 companies of 2 Houses, 3,000 troops; 900 lost, 2 companies fallen")
        XCTAssertEqual(Narration.line(for: .fieldEnded(over), in: session.state, viewer: me)?.tone, .good)
        draw(ChroniclePanel(session: session, showingReports: true), width: 400)

        // Counted once in the watch's summary, and heard where it was fought.
        let summary = WatchSummary(before: state, after: state, events: [joined, .battle(blow), .battle(blow)], player: me)
        XCTAssertEqual(summary.events.first, "A battle")
        XCTAssertEqual(GameSession.place(of: joined, in: state), company.position)
        XCTAssertEqual(GameSession.place(of: .fieldEnded(over), in: state), company.position)
        XCTAssertTrue(GameSession.isRealmsToTell(joined) && GameSession.isRealmsToTell(.fieldEnded(over)))
    }

    // MARK: City life

    func testTownsfolkGoAboutTheHoldsWorksInFullMotion() throws {
        var state = world("townsfolk shown")
        let me = state.player
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == me && $0.isSeat })
        state.holds[seat].levels = [.walls: 1, .granary: 1, .sawpit: 1]
        // A second hold a few hexes off, unbroken land between: a way for carts.
        let home = state.holds[seat].position
        let other = try XCTUnwrap(home.spiral(5).first { hex in
            (3...5).contains(hex.distance(to: home)) && state.unit(at: hex) == nil && state.hold(at: hex) == nil
                && home.line(to: hex).allSatisfy { state.map[$0].map { $0.terrain.isPassable && !$0.terrain.isWater } ?? false }
                && home.line(to: hex).dropFirst().allSatisfy { state.hold(at: $0) == nil }
        })
        state.holds.append(Hold(id: state.takeID(), name: "Farstead", owner: me, position: other, isSeat: false, foundedWatch: 0))
        state.reveal(around: other, range: 2, for: me)
        let (session, _) = session(state)
        XCTAssertEqual(session.ways.map { [$0.hexes.first!, $0.hexes.last!] }.filter { Set($0) == [home, other] }.count, 1, "One way, once")
        func folk(_ frame: SceneFrame) -> Int {
            frame.batches.reduce(0) { total, batch in
                if case .folk = batch.key { return total + batch.instances.count }
                return total
            }
        }
        session.motion = .full
        XCTAssertGreaterThanOrEqual(folk(session.sceneFrame(at: 4)), 3, "A farmhand and a carter about the seat, and a cart on the way")
        session.motion = .still
        XCTAssertEqual(folk(session.sceneFrame(at: 4)), 0, "Still, the holds are quiet")
    }

    // MARK: The city view

    func testTheCityViewComesCloseOverTheSeatAndNamesItsWorks() throws {
        var state = world("city view")
        let me = state.player
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == me && $0.isSeat })
        state.holds[seat].levels = [.walls: 2, .granary: 2, .sawpit: 1]
        state.holds[seat].project = Hold.Project(kind: .quarry, targetLevel: 1, watchesLeft: 2)
        let hold = state.holds[seat]
        let (session, link) = session(state)
        session.motion = .still
        XCTAssertNil(session.cityInView, "Over the lake")
        XCTAssertFalse(session.sceneFrame(at: 1).fine, "From the lake's view, the models' fine work is too small to draw")
        XCTAssertTrue(session.handle(.city))
        XCTAssertEqual(session.camera.scale, GameSession.cityScale, accuracy: 1e-9)
        XCTAssertEqual(session.camera.tilt, GameSession.cityTilt, accuracy: 1e-9)
        XCTAssertTrue(session.sceneFrame(at: 1).fine, "Close over the city, it is drawn")
        XCTAssertEqual(session.cityInView?.id, hold.id)
        XCTAssertEqual(session.selection, .hold(hold.id))
        // Each work named where it stands, in the view.
        let size = CGSize(width: 1200, height: 800)
        let works = session.cityWorks(in: size)
        XCTAssertEqual(Set(works.map(\.kind)), [.walls, .granary, .sawpit, .quarry])
        XCTAssertEqual(works.first { $0.kind == .granary }?.title, "\(BuildingKind.granary.title) II")
        XCTAssertEqual(works.first { $0.kind == .quarry }?.title, "\(BuildingKind.quarry.title) I, rising")
        XCTAssertTrue(works.allSatisfy { (0...size.width).contains($0.at.x) && (0...size.height).contains($0.at.y) }, "\(works)")
        // A name chosen: the hold's panel opens on its row.
        session.focus(work: .granary, at: hold)
        XCTAssertEqual(session.workInFocus, .granary)
        draw(CityLabels(session: session), width: size.width, height: size.height)
        draw(SelectionPanel(session: session), width: 330, height: 700)
        // Chosen, it may be set in any other place round the keep, trading
        // with a work that stands there.
        let places = session.cityPlaces(in: size)
        XCTAssertFalse(places.isEmpty)
        XCTAssertFalse(places.contains { $0.work == .granary }, "Every place but its own")
        let taken = try XCTUnwrap(places.first { $0.work == .sawpit }, "\(places)")
        XCTAssertEqual(taken.label(setting: .granary),
                       "Set the Granary here, where the \(BuildingKind.sawpit.title) stands; the \(BuildingKind.sawpit.title) takes its place")
        XCTAssertEqual(CityPlace(place: 1, work: nil, at: .zero).label(setting: .granary), "Set the Granary here")
        session.set(.granary, at: taken.place)
        XCTAssertEqual(link.sent.last, .placeWork(hold: hold.id, kind: .granary, place: taken.place))
        XCTAssertEqual(session.state.holds[seat].place(of: .granary), taken.place)
        XCTAssertEqual(session.cityPlaces(in: size).first { $0.place == taken.place }?.work, nil, "Its own now, so not shown")
        draw(CityLabels(session: session), width: size.width, height: size.height)
        session.focus(work: .walls, at: hold)
        XCTAssertEqual(session.cityPlaces(in: size), [], "The walls ring the keep")
        XCTAssertEqual(GameSession.kind(of: .study), .archive)
        session.focus(work: .granary, at: hold)
        // C again: back out over the lake.
        XCTAssertTrue(session.handle(.city))
        XCTAssertEqual(session.camera.scale, GameSession.lakeScale, accuracy: 1e-9)
        XCTAssertEqual(session.camera.tilt, Camera.defaultTilt, accuracy: 1e-9)
        XCTAssertNil(session.cityInView)
        XCTAssertNil(session.workInFocus)
        XCTAssertEqual(session.cityWorks(in: size), [])
        draw(CityLabels(session: session), width: size.width, height: size.height)
        // Never over another House's hold.
        let theirs = try XCTUnwrap(state.holds.first { $0.owner != me })
        session.viewCity(theirs.id)
        XCTAssertNil(session.cityInView)
        XCTAssertEqual(GameMenu.viewCity.title, "View the Seat Close")
    }

    // MARK: The small map

    func testTheSmallMapShowsTheLakeAndCarriesTheViewThere() throws {
        let (session, _) = session(world("small map"))
        session.motion = .still
        let radius = session.state.map.radius
        // Every hex lies where the map puts it, and is found there again.
        for hex in session.state.map.hexes {
            let point = MiniMap.point(of: hex, radius: radius)
            XCTAssertEqual(MiniMap.hex(at: point, radius: radius), hex)
            XCTAssertTrue((0...MiniMap.side).contains(point.x) && (0...MiniMap.side).contains(point.y), "\(hex) within the square")
        }
        // Its ground is drawn once for each change of the world.
        let ground = try XCTUnwrap(session.miniMapGround(side: MiniMap.side))
        XCTAssertEqual(ground.width, Int(MiniMap.side * 2))
        XCTAssertTrue(session.miniMapGround(side: MiniMap.side) === ground, "kept while the world stands")
        draw(MiniMap(session: session), width: 170, height: 170)
        // A click carries the view there; off the lake, nowhere.
        let seat = try XCTUnwrap(session.state.seat(of: session.player))
        let far = try XCTUnwrap(session.state.map.hexes.max { $0.distance(to: seat.position) < $1.distance(to: seat.position) })
        MiniMap.look(at: MiniMap.point(of: far, radius: radius), in: session)
        XCTAssertEqual(session.camera.centreHex, far)
        MiniMap.look(at: CGPoint(x: -500, y: -500), in: session)
        XCTAssertEqual(session.camera.centreHex, far, "off the lake, the view stays")
        XCTAssertTrue(MiniMap.spoken(session).hasPrefix("1 hold of yours"))
        // Its camera buttons: nearer, further, turned, and set back to the whole House.
        PressableButtons.isListening = true
        draw(CameraButtons(session: session), width: 200, height: 30)
        let scale = session.camera.scale
        XCTAssertTrue(PressableButtons.press("+"), "Among \(PressableButtons.actions.keys.sorted())")
        XCTAssertGreaterThan(session.camera.scale, scale)
        XCTAssertTrue(PressableButtons.press("−"))
        XCTAssertEqual(session.camera.scale, scale, accuracy: 1e-6)
        XCTAssertTrue(PressableButtons.press("⟳"))
        XCTAssertEqual(session.camera.heading, .pi / 6, accuracy: 1e-9)
        XCTAssertTrue(PressableButtons.press("⟲"))
        XCTAssertEqual(session.camera.heading, 0, accuracy: 1e-9)
        XCTAssertTrue(PressableButtons.press("Reset"))
    }

    // MARK: The map

    func testASiteRightClickedIsGatheredAndTheLandIsReadAloud() throws {
        var state = world("gathered sites")
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        let company = try XCTUnwrap(state.units(of: me).first { $0.kind.isMilitary })
        let spot = try free(near: company.position, in: state)
        state.sites = (state.sites ?? []) + [Site(id: state.takeID(), store: .timber, level: 2, position: spot, found: state.watch)]
        let lair = try free(near: seat.position, in: state)
        state.wilds = (state.wilds ?? []) + [Wild(id: state.takeID(), kind: .barrowkin, level: 3, position: lair, raised: state.watch)]
        state.reveal(around: spot, range: 1, for: me)
        state.reveal(around: lair, range: 1, for: me)
        let (session, link) = session(state)
        let site = try XCTUnwrap(session.state.site(at: spot))

        // Read aloud: the wild in sight and the site found, and the way to gather.
        session.selection = .unit(company.id)
        let items = MapAccessibility.items(for: session)
        if session.isVisible(lair) {
            XCTAssertTrue(items.contains { $0.id.hasPrefix("wild-") && $0.label.hasPrefix("Barrowkin, level III, of the wilds") })
        }
        XCTAssertTrue(items.contains { $0.id == "site-\(site.id)" && $0.label.hasPrefix("Deadfall II, 600 timber left") })
        let orders = try XCTUnwrap(items.first { $0.selection == .unit(company.id) }).orders
        XCTAssertTrue(orders.contains { $0.name.hasPrefix("Gather at the Deadfall II") && $0.hex == spot }, "\(orders.map(\.name))")
        XCTAssertEqual(HoverInfo.line(for: spot, in: session.state, explored: true, territory: session.territory)?.contains("Deadfall II, 600 timber left"),
                       true)
        XCTAssertEqual(HoverInfo.named(Wild(id: 1, kind: .drowned, level: 2, position: lair, raised: 0)), "The Drowned, level II")

        // Right-clicked, the site is worked, and the company says so.
        UserDefaults.standard.removeObject(forKey: GameSession.gatherLengthKey)
        defer { UserDefaults.standard.removeObject(forKey: GameSession.gatherLengthKey) }
        session.gatherLength = nil
        session.order(spot)
        XCTAssertEqual(link.sent.last, .gather(unit: company.id, site: site.id))
        let sent = try XCTUnwrap(session.state.unit(company.id))
        XCTAssertEqual(sent.position, spot, "There at once")
        let left = try XCTUnwrap(session.state.watchesToFill(sent))
        XCTAssertEqual(UnitPanel.errand(of: sent, in: session.state),
                       "Gathering at the Deadfall II, 600 timber left: full " + (left <= 1 ? "as the watch turns." : "in \(left) watches."))

        // How long it works there, chosen again on its record, and kept for the next sent.
        session.selection = .unit(company.id)
        draw(SelectionPanel(session: session), width: 330, height: 700)
        XCTAssertTrue(PressableButtons.press("A watch"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .gather(unit: company.id, site: site.id, watches: 1))
        XCTAssertEqual(session.gatherLength, 1)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: GameSession.gatherLengthKey), 1)
        XCTAssertEqual(GameSession.storedGatherLength(), 1)
        XCTAssertEqual(UnitPanel.errand(of: try XCTUnwrap(session.state.unit(company.id)), in: session.state),
                       "Gathering at the Deadfall II, 600 timber left: home as the watch turns.")
        XCTAssertTrue(GathererList.line(for: try XCTUnwrap(session.state.unit(company.id)), in: session.state).hasSuffix(", home as the watch turns"))
        draw(SelectionPanel(session: session), width: 330, height: 700)
        XCTAssertTrue(PressableButtons.press("Until full"))
        XCTAssertNil(session.gatherLength)
        XCTAssertEqual(link.sent.last, .gather(unit: company.id, site: site.id))
        session.selection = .tile(spot)
        draw(SelectionPanel(session: session), width: 330, height: 600)
        session.selection = .tile(lair)
        draw(SelectionPanel(session: session), width: 330, height: 600)
    }

    func testTheHolySitesAreShownNamedAndDrawn() throws {
        var state = world("holy sites shown")
        let me = state.player
        let shrine = try XCTUnwrap(state.holySites.first)
        state.reveal(around: shrine.position, range: 1, for: me)
        state.units.append(Unit(id: state.takeID(), kind: .spear, owner: me, position: shrine.position))
        _ = state.holdShrines()
        let (session, _) = session(state)
        draw(RealmPanel(session: session))
        let held = try XCTUnwrap(session.state.holySites.first { $0.id == shrine.id })
        XCTAssertEqual(RealmPanel.held(held, in: session.state, player: me), "Yours")
        let other = (me + 1) % session.state.houses.count
        XCTAssertEqual(RealmPanel.held(Shrine(id: 9, kind: .saltAltar, position: .origin, holder: other), in: session.state, player: me),
                       "Held by \(session.state.houses[other].title)")
        XCTAssertEqual(RealmPanel.held(Shrine(id: 9, kind: .saltAltar, position: .origin), in: session.state, player: me), "Held by none")
        XCTAssertTrue(HoverInfo.named(held, in: session.state).hasPrefix("the \(held.title), a holy site, held by \(session.state.houses[me].title)"))
        let line = try XCTUnwrap(HoverInfo.line(for: shrine.position, in: session.state, explored: true, territory: session.state.territory()))
        XCTAssertTrue(line.contains("a holy site"), line)
        // Drawn in the world, its pennant in its holder's colour.
        let frame = session.sceneFrame(at: 1)
        let drawn = frame.batches.first { $0.key == .shrine(held.kind) }
        XCTAssertNotNil(drawn, "The shrine stands in the world")
        XCTAssertEqual(drawn?.instances.first?.colour.w, 1, "Its holder's colour")
        XCTAssertEqual(GameSession.place(of: .shrineTaken(shrine: shrine.id, house: me, from: nil), in: session.state), shrine.position)
    }

    func testTheInfirmaryShowsItsBedsAndHealsItsWounded() throws {
        var state = world("infirmary shown")
        let me = state.player
        let index = try XCTUnwrap(state.holds.firstIndex { $0.owner == me && $0.isSeat })
        let seat = state.holds[index]
        state.holds[index].levels[.infirmary] = 2
        state.holds[index].wounded = [Wounded(kind: .spear, tier: 2, experience: 3, since: 0),
                                      Wounded(kind: .bow, tier: 1, experience: 0, since: 0, healing: true)]
        state.houses[me].stock = Stock(grain: 900, timber: 900, stone: 900, moonsalt: 90)
        let (session, link) = session(state)
        session.selection = .hold(seat.id)
        draw(SelectionPanel(session: session), width: 330, height: 1100)
        XCTAssertEqual(session.state.lying(at: try XCTUnwrap(session.state.hold(seat.id))), "Spears II · Bows I, healing")
        XCTAssertTrue(PressableButtons.press("Heal 1"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .heal(hold: seat.id))
        XCTAssertEqual(session.state.hold(seat.id)?.wounded?.map(\.healing), [true, true], "Paid for at once on the keeper's copy")
        // All being healed: nothing more to pay for.
        PressableButtons.isListening = true
        draw(SelectionPanel(session: session), width: 330, height: 1100)
        XCTAssertFalse(PressableButtons.press("Healing"))
        XCTAssertEqual(session.state.refusal(of: .heal(hold: seat.id), as: me), .noneWounded)
        XCTAssertEqual(GameSession.place(of: .healingBegun(hold: seat.id, house: me, count: 1), in: session.state), seat.position)
        // The Infirmary stands in the world beside the hold.
        let frame = session.sceneFrame(at: 1)
        XCTAssertTrue(frame.batches.contains { $0.key == .work(.infirmary, level: 2) } || frame.fixed.contains { $0.key == .work(.infirmary, level: 2) },
                      "Drawn by the hold")
    }

    func testAHoldIsScoutedFromItsPanelAndWhatWasSeenIsKept() throws {
        var state = world("scouted shown")
        let me = state.player
        let foe = (me + 1) % 6
        let target = try XCTUnwrap(state.holds.first { $0.owner == foe && $0.isSeat })
        let spot = try XCTUnwrap(target.position.ring(2).first { hex in
            state.map[hex]?.terrain.isPassable == true && state.unit(at: hex) == nil && state.hold(at: hex) == nil && state.wild(at: hex) == nil
        })
        let lantern = Unit(id: state.takeID(), kind: .lantern, owner: me, position: spot)
        state.units.append(lantern)
        state.reveal(around: target.position, range: 2, for: me)
        let (session, link) = session(state)
        session.selection = .hold(target.id)
        draw(SelectionPanel(session: session), width: 330, height: 900)
        XCTAssertTrue(PressableButtons.press("Scout"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .scout(unit: lantern.id, hold: target.id))

        // The realm's word: the report filed, kept for the hold, and the Lanterns' light drawn.
        var world = state
        let events = try world.perform(.scout(unit: lantern.id, hold: target.id), as: me)
        guard case .holdScouted(let report)? = events.first else { return XCTFail("A report") }
        session.showBlows(world.events(events, heardBy: me))
        XCTAssertEqual(session.reports.first?.outcome, .scouted)
        XCTAssertEqual(session.reports.first?.title, "Your Lanterns scouted \(target.name), \(state.houses[foe].title)'s seat")
        XCTAssertEqual(session.scoutings[target.id], report)
        XCTAssertEqual(session.sightings.map(\.at), [target.position])
        XCTAssertEqual(ReportList.outcome(.scouted), "Scouted")
        // The keeper's fogged copy can only guess what Lanterns see, or who
        // is carried from a battle: those are the realm's to tell.
        XCTAssertTrue([GameEvent.holdScouted(report), .scoutSeen(hold: target.id, by: me),
                       .carriedToInfirmary(kind: .spear, owner: me, hold: 1), .woundedLost(hold: 1, house: me, count: 1)]
            .allSatisfy(GameSession.isRealmsToTell))
        XCTAssertFalse(GameSession.isRealmsToTell(.healingBegun(hold: 1, house: me, count: 1)), "Its own stores and beds it knows")
        XCTAssertEqual(GameSession.place(of: .holdScouted(report), in: session.state), target.position)
        XCTAssertEqual(GameSession.place(of: .scoutSeen(hold: target.id, by: me), in: session.state), target.position)
        PressableButtons.isListening = true
        draw(SelectionPanel(session: session), width: 330, height: 900)
        draw(ChroniclePanel(session: session, showingReports: true))
        let stage = WorldStage(map: session.state.map, relief: session.relief)
        let staged = session.happenings(poses: [], sights: [], stage: stage, at: Date(), time: 40)
        XCTAssertEqual(staged.sightings.count, 1, "Its Lanterns' light circles the hold")
        // With no Lanterns near, the button says why it can't.
        XCTAssertNil(ForeignHoldPanel.scout(for: target, in: state, player: (me + 2) % 6))
        // The Lanterns' own panel scouts the nearest hold within reach too,
        // while they have moves left.
        XCTAssertEqual(UnitPanel.scoutable(by: lantern, in: state, player: me)?.id, target.id)
        session.selection = .unit(lantern.id)
        PressableButtons.isListening = true
        draw(SelectionPanel(session: session), width: 330, height: 700)
        XCTAssertFalse(PressableButtons.press("Scout"), "Spent on the scouting already")
        let (fresh, freshLink) = self.session(state)
        fresh.selection = .unit(lantern.id)
        PressableButtons.isListening = true
        draw(SelectionPanel(session: fresh), width: 330, height: 700)
        XCTAssertTrue(PressableButtons.press("Scout"), "Among \(shown)")
        XCTAssertEqual(freshLink.sent.last, .scout(unit: lantern.id, hold: target.id))
        XCTAssertNil(UnitPanel.scoutable(by: Unit(id: 1, kind: .lantern, owner: me, position: try XCTUnwrap(state.seat(of: me)).position),
                                         in: state, player: me), "None of another's within reach of its own seat")
    }

    func testALairIsDrawnNamedAndRalliedOnAndItsBreakingShown() throws {
        var state = world("lair shown")
        let me = state.player
        _ = try state.perform(.foundAlliance(name: "The Broken Gate"), as: me)
        let index = try XCTUnwrap(state.holds.firstIndex { $0.owner == me && $0.isSeat })
        state.holds[index].levels[.musterHall] = 1
        let seat = state.holds[index]
        let spot = try XCTUnwrap(seat.position.ring(4).first { hex in
            state.map[hex]?.terrain.isPassable == true && state.map[hex]?.terrain.isWater == false && state.unit(at: hex) == nil
                && state.hold(at: hex) == nil && state.wild(at: hex) == nil && state.site(at: hex) == nil
        })
        state.lairLadder = [me: 1] // a level-2 lair waits on the first rung's climb
        let lair = Lair(id: state.takeID(), kind: .reavers, level: 2, position: spot, raised: 0)
        state.lairs = [lair]
        state.reveal(around: spot, range: 1, for: me)
        let (session, link) = session(state)
        // Named on hover, and in its tile's panel with a rally to call on it.
        let line = try XCTUnwrap(HoverInfo.line(for: spot, in: session.state, explored: true, territory: session.state.territory()))
        XCTAssertTrue(line.contains("the Reavers' Stockade, a lair of the wilds of level II, 450 of 450 standing"), line)
        XCTAssertEqual(LairRally.muster(for: lair, in: session.state, player: me)?.id, seat.id)
        session.selection = .tile(spot)
        draw(SelectionPanel(session: session), width: 330, height: 900)
        XCTAssertTrue(PressableButtons.press("Call a rally"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .callRally(from: seat.id, against: lair.id, watches: 2))
        // Drawn in the world, its fire smoking.
        let frame = session.sceneFrame(at: 1)
        XCTAssertTrue(frame.batches.contains { $0.key == .lair(.reavers) }, "The lair stands in the world")
        // Its breaking: each blow drawn from where it was struck, filed as a report, heard.
        let striker = try XCTUnwrap(spot.neighbors.first { session.state.map[$0]?.terrain.isPassable == true })
        let assault = LairAssault(rally: 9, caller: me, lair: lair.id, kind: .reavers, level: 2, at: spot,
                                  strikes: [.init(unit: 77, owner: me, kind: .spear, from: striker, dealt: 450, taken: 20, fell: false)],
                                  before: 450, strength: 0, might: 450, shares: [.init(house: me, spoils: Stock(grain: 90))])
        session.showBlows([.lairAssaulted(assault)])
        XCTAssertEqual(session.blows.last?.from, striker)
        XCTAssertEqual(session.blows.last?.at, spot)
        XCTAssertEqual(session.reports.first?.outcome, .won)
        XCTAssertEqual(session.reports.first?.title, "Your host broke the Reavers' Stockade of the second level")
        XCTAssertEqual(GameSession.place(of: .lairAssaulted(assault), in: session.state), spot)
        XCTAssertEqual(GameSession.place(of: .rallySetOut(rally: 9, caller: me, target: lair.id, defender: Rally.noHouse, companies: 3),
                                         in: session.state), spot)
        XCTAssertTrue(GameSession.isRealmsToTell(.lairAssaulted(assault)))
        // A keeper with no Muster Hall is told where a rally gathers.
        XCTAssertNil(LairRally.muster(for: lair, in: session.state, player: (me + 1) % 6))
        var unmustered = state
        unmustered.holds[index].levels[.musterHall] = nil
        let (none, _) = self.session(unmustered)
        XCTAssertNil(LairRally.muster(for: lair, in: none.state, player: me))
        none.selection = .tile(spot)
        PressableButtons.forget("Call a rally")
        draw(SelectionPanel(session: none), width: 330, height: 900)
        XCTAssertFalse(PressableButtons.press("Call a rally"), "No Muster Hall, no rally")
        // The Realm lists the lairs found.
        draw(RealmPanel(session: session))
        XCTAssertEqual(RealmPanel.standing(lair), "Whole, 450")
        var struck = lair
        struck.strength = 120
        XCTAssertEqual(RealmPanel.standing(struck), "120 of 450 standing")
    }

    func testAStandardIsRaisedFromItsGroundAndItsLandNamed() throws {
        var state = world("standard shown")
        let me = state.player
        _ = try state.perform(.foundAlliance(name: "The Tall Pole"), as: me)
        let seat = try XCTUnwrap(state.holds.first { $0.owner == me && $0.isSeat })
        state.reveal(around: seat.position, range: 5, for: me)
        state.houses[me].stock = Stock(grain: 300, timber: 300, stone: 300, moonsalt: 30)
        let spot = try XCTUnwrap(seat.position.ring(2).first { hex in
            state.map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true && !state.isOccupied(hex)
                && state.site(at: hex) == nil && state.shrine(at: hex) == nil
        })
        let (session, link) = session(state)
        session.selection = .tile(spot)
        draw(SelectionPanel(session: session), width: 330, height: 900)
        XCTAssertTrue(PressableButtons.press("Raise a standard"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .raiseStandard(at: spot))
        let standard = try XCTUnwrap(session.state.standard(at: spot), "Raised at once on the keeper's copy")
        // Named on hover, its land too, and shown in its tile's panel.
        let named = try XCTUnwrap(HoverInfo.line(for: spot, in: session.state, explored: true, territory: session.state.territory()))
        XCTAssertTrue(named.contains("a standard of The Tall Pole rising, whole in \(Standard.raising) watches"), named)
        // Once it stands whole, its land is named the alliance's.
        var whole = session.state
        whole.standStandardsWhole()
        let stood = try XCTUnwrap(HoverInfo.line(for: spot, in: whole, explored: true, territory: whole.territory()))
        XCTAssertTrue(stood.contains("a standard of The Tall Pole, ward 60 of 60"), stood)
        let about = try XCTUnwrap(spot.ring(1).first { whole.standard(at: $0) == nil && whole.hold(at: $0) == nil })
        let land = try XCTUnwrap(HoverInfo.line(for: about, in: whole, explored: true, territory: whole.territory()))
        XCTAssertTrue(land.contains("land of The Tall Pole"), land)
        PressableButtons.isListening = true
        draw(SelectionPanel(session: session), width: 330, height: 900)
        XCTAssertFalse(PressableButtons.press("Raise a standard"), "Not on a standard")
        // Drawn in the world, counted on the Alliance screen, placed for its sound.
        XCTAssertTrue(session.sceneFrame(at: 1).batches.contains { $0.key == .standard })
        let alliance = try XCTUnwrap(session.state.alliance(of: me))
        XCTAssertTrue(AlliancePanel.standardsLine(alliance, in: session.state).hasPrefix("Standards: 1 of 2."))
        draw(AlliancePanel(session: session))
        XCTAssertEqual(GameSession.place(of: .standardRaised(standard: standard.id, alliance: alliance.id, house: me, at: spot),
                                         in: session.state), spot)
        XCTAssertTrue(GameSession.isRealmsToTell(.standardTorn(standard: standard.id, alliance: alliance.id, by: 2, at: spot)))
    }

    func testAHallIsBegunOnItsAlliancesLandAndDrawnRising() throws {
        var state = world("hall shown")
        let me = state.player
        _ = try state.perform(.foundAlliance(name: "The Tall Hall"), as: me)
        let seat = try XCTUnwrap(state.holds.first { $0.owner == me && $0.isSeat })
        state.reveal(around: seat.position, range: 6, for: me)
        state.houses[me].stock = Stock(grain: 900, timber: 900, stone: 900, moonsalt: 90)
        let flag = try XCTUnwrap(seat.position.spiral(3).first { hex in
            (2...3).contains(hex.distance(to: seat.position)) && state.refusal(of: .raiseStandard(at: hex), as: me) == nil
        })
        _ = try state.perform(.raiseStandard(at: flag), as: me)
        state.standStandardsWhole()
        let spot = try XCTUnwrap(flag.spiral(Standard.reach).first { state.refusal(of: .raiseAllianceHall(at: $0), as: me) == nil })
        let (session, link) = session(state)
        let sworn = try XCTUnwrap(session.state.alliance(of: me))
        XCTAssertTrue(HallRow.offered(at: spot, to: me, of: sworn, in: session.state))
        XCTAssertFalse(HallRow.offered(at: spot, to: (me + 1) % 6, of: sworn, in: session.state), "To its leader alone")
        XCTAssertTrue(AlliancePanel.hallLine(sworn, in: session.state).hasPrefix("Hall: none yet. Its leader begins it"))
        session.selection = .tile(spot)
        draw(SelectionPanel(session: session), width: 330, height: 900)
        XCTAssertTrue(PressableButtons.press("Begin the hall"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .raiseAllianceHall(at: spot))
        let hall = try XCTUnwrap(session.state.hall(at: spot), "Begun at once on the keeper's copy")
        // Named on hover and in its tile's panel, counted on the Alliance screen.
        let named = try XCTUnwrap(HoverInfo.line(for: spot, in: session.state, explored: true, territory: session.state.territory()))
        XCTAssertTrue(named.contains("the hall of The Tall Hall, rising, 0 of 4 watches done, ward 40 of 40"), named)
        XCTAssertTrue(HoverInfo.described(hall, in: session.state).hasPrefix("Begun by "))
        PressableButtons.isListening = true
        draw(SelectionPanel(session: session), width: 330, height: 900)
        XCTAssertFalse(PressableButtons.press("Begin the hall"), "Not where it stands")
        XCTAssertTrue(AlliancePanel.hallLine(try XCTUnwrap(session.state.alliance(of: me)), in: session.state).hasPrefix("Hall: rising "))
        draw(AlliancePanel(session: session))
        // Drawn in the world rising within its scaffold.
        let frame = session.sceneFrame(at: 1)
        XCTAssertTrue(frame.batches.contains { $0.key == .allianceHall })
        XCTAssertTrue(frame.batches.contains { $0.key == .scaffold })
        // A watch's height at a time, eased.
        let start = Date()
        XCTAssertEqual(session.risen(hall, at: start, animated: true), 0)
        var further = hall
        further.built = 1
        XCTAssertEqual(session.risen(further, at: start, animated: true), 0, accuracy: 1e-5, "From where it stood")
        let halfway = session.risen(further, at: start.addingTimeInterval(WorldStage.riseSeconds / 2), animated: true)
        XCTAssertGreaterThan(halfway, 0)
        XCTAssertLessThan(halfway, 0.25)
        XCTAssertEqual(session.risen(further, at: start.addingTimeInterval(WorldStage.riseSeconds), animated: true), 0.25, accuracy: 1e-5)
        XCTAssertEqual(session.risen(further, at: start, animated: false), 0.25)
        // Whole, and struck low, it burns.
        var whole = state
        _ = try whole.perform(.raiseAllianceHall(at: spot), as: me)
        whole.halls![0].built = AllianceHall.raising
        whole.halls![0].ward = 30
        // A company of the keeper's keeping it, to see it burn.
        let keeperID = whole.takeID()
        whole.units.append(NullmereCore.Unit(id: keeperID, kind: .spear, owner: me, position: spot, tier: 1))
        let (struck, _) = self.session(whole)
        let standing = try XCTUnwrap(struck.state.hall(at: spot))
        XCTAssertTrue(HoverInfo.named(standing, in: struck.state).contains("ward 30 of 240: the land 3 tiles about it is the alliance's"))
        XCTAssertTrue(HoverInfo.described(standing, in: struck.state).hasPrefix("Raised by "))
        XCTAssertTrue(AlliancePanel.hallLine(try XCTUnwrap(struck.state.alliance(of: me)), in: struck.state).hasPrefix("Hall: standing "))
        let stage = WorldStage(map: struck.state.map, relief: Relief(map: struck.state.map))
        let blazes = struck.happenings(poses: [], sights: [], stage: stage, at: Date(), time: 1).blazes
        XCTAssertTrue(blazes.contains { abs($0.at.x - Relief.centre(of: spot).x) < 1e-3 }, "\(blazes)")
        // Placed for its sound; the realm's to tell when struck.
        XCTAssertEqual(GameSession.place(of: .hallRaised(hall: hall.id, alliance: sworn.id, house: me, at: spot), in: session.state), spot)
        XCTAssertTrue(GameSession.isRealmsToTell(.hallStruck(hall: hall.id, alliance: sworn.id, ward: 10, by: 2, at: spot)))
    }

    func testTheAlliancesStorehouseAndYardsAreRaisedShownAndDrawn() throws {
        var state = world("stores shown")
        let me = state.player
        _ = try state.perform(.foundAlliance(name: "The Deep Barn"), as: me)
        let seat = try XCTUnwrap(state.holds.first { $0.owner == me && $0.isSeat })
        state.reveal(around: seat.position, range: 6, for: me)
        state.houses[me].stock = Stock(grain: 900, timber: 900, stone: 900, moonsalt: 90)
        let flag = try XCTUnwrap(seat.position.spiral(3).first { hex in
            (2...3).contains(hex.distance(to: seat.position)) && state.refusal(of: .raiseStandard(at: hex), as: me) == nil
        })
        _ = try state.perform(.raiseStandard(at: flag), as: me)
        state.standStandardsWhole()
        let spot = try XCTUnwrap(flag.spiral(Standard.reach).first { state.refusal(of: .raiseStorehouse(at: $0), as: me) == nil })
        let (session, link) = session(state)
        let sworn = try XCTUnwrap(session.state.alliance(of: me))
        XCTAssertTrue(StorehouseRow.offered(at: spot, to: me, of: sworn, in: session.state))
        XCTAssertFalse(StorehouseRow.offered(at: spot, to: (me + 1) % 6, of: sworn, in: session.state), "To its leader alone")
        XCTAssertEqual(YardRow.stores(at: spot, for: me, of: sworn, in: session.state), Resource.allCases)
        XCTAssertEqual(YardRow.stores(at: spot, for: (me + 1) % 6, of: sworn, in: session.state), [])
        XCTAssertTrue(AlliancePanel.coffersLine(sworn, in: session.state)
            .hasPrefix("Coffers: nothing yet. Its land yields them 5 grain, 5 timber, 5 stone a watch"))
        XCTAssertTrue(AlliancePanel.storehouseLine(sworn, in: session.state).hasPrefix("Storehouse: none yet. Its leader raises it"))
        XCTAssertTrue(AlliancePanel.yardsLine(sworn, in: session.state).hasPrefix("Yards: none yet. Its leader raises one of each store"))
        session.selection = .tile(spot)
        PressableButtons.isListening = true
        draw(SelectionPanel(session: session), width: 330, height: 1400)
        XCTAssertTrue(PressableButtons.press("Raise the storehouse"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .raiseStorehouse(at: spot))
        let storehouse = try XCTUnwrap(session.state.storehouse(at: spot), "Begun at once on the keeper's copy")
        // Named on hover and in its tile's panel, told on the Alliance screen.
        let named = try XCTUnwrap(HoverInfo.line(for: spot, in: session.state, explored: true, territory: session.state.territory()))
        XCTAssertTrue(named.contains("the storehouse of The Deep Barn, rising, 0 of 2 watches done, ward 120 of 120"), named)
        XCTAssertTrue(HoverInfo.described(storehouse, in: session.state).hasPrefix("Begun by "))
        PressableButtons.isListening = true
        draw(SelectionPanel(session: session), width: 330, height: 1400)
        XCTAssertFalse(PressableButtons.press("Raise the storehouse"), "Not where it stands")
        XCTAssertTrue(AlliancePanel.storehouseLine(try XCTUnwrap(session.state.alliance(of: me)), in: session.state).hasPrefix("Storehouse: rising "))
        let frame = session.sceneFrame(at: 1)
        XCTAssertTrue(frame.batches.contains { $0.key == .storehouse }, "Drawn rising")
        XCTAssertTrue(frame.batches.contains { $0.key == .scaffold })
        XCTAssertEqual(GameSession.cues(for: .raiseStorehouse(at: spot), events: [], in: session.state, player: me), [.rise])

        // A yard of timber, raised from another ground's panel.
        let ground = try XCTUnwrap(flag.spiral(Standard.reach).first { session.state.refusal(of: .raiseYard(.timber, at: $0), as: me) == nil })
        session.selection = .tile(ground)
        PressableButtons.isListening = true
        draw(SelectionPanel(session: session), width: 330, height: 1400)
        XCTAssertTrue(PressableButtons.press("A timber yard"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .raiseYard(.timber, at: ground))
        let yard = try XCTUnwrap(session.state.site(at: ground))
        XCTAssertTrue(yard.isYard)
        XCTAssertEqual(SelectionPanel.siteTitle(yard, in: session.state), "Timber Yard of The Deep Barn")
        XCTAssertTrue(SelectionPanel.siteLine(yard, in: session.state).hasPrefix("1500 timber left to gather. Only its alliance's companies work it"))
        // A site of the land: none has come up yet at the first watch, so one is put there.
        let acre = try XCTUnwrap(state.map.hexes.first { hex in
            state.map[hex].map { $0.terrain.isPassable && $0.feature == nil && Site.store(of: $0.terrain) != nil } == true
                && state.unit(at: hex) == nil && state.hold(at: hex) == nil && hex.distance(to: seat.position) > 6
        })
        let store = try XCTUnwrap(state.map[acre].flatMap { Site.store(of: $0.terrain) })
        state.sites = state.sitesInLand + [Site(id: state.takeID(), store: store, level: 2, position: acre, found: 0)]
        let land = try XCTUnwrap(state.sitesInLand.first { !$0.isYard })
        XCTAssertEqual(SelectionPanel.siteTitle(land, in: session.state), land.title + " " + Narration.roman(land.level))
        XCTAssertTrue(SelectionPanel.siteLine(land, in: session.state).hasSuffix("Choose a company of war and right-click here to send it."))
        XCTAssertEqual(HoverInfo.named(yard, in: session.state), "Timber Yard of The Deep Barn, 1500 timber left")
        XCTAssertEqual(HoverInfo.named(yard), "Timber Yard of an alliance, 1500 timber left")
        PressableButtons.isListening = true
        draw(SelectionPanel(session: session), width: 330, height: 1400)
        XCTAssertFalse(PressableButtons.press("A timber yard"), "One of each store")
        XCTAssertTrue(AlliancePanel.yardsLine(try XCTUnwrap(session.state.alliance(of: me)), in: session.state)
            .hasPrefix("Yards: the Timber Yard, 1500 timber left"))
        XCTAssertTrue(session.sceneFrame(at: 1).batches.contains { $0.key == .yard(.timber) }, "Drawn in its alliance's colour")
        XCTAssertEqual(GameSession.place(of: .yardRaised(site: yard.id, alliance: sworn.id, house: me, store: .timber, at: ground),
                                         in: session.state), ground)

        // Whole, the keeper lays up stores there from the Alliance screen, and takes them back.
        var kept = state
        _ = try kept.perform(.raiseStorehouse(at: spot), as: me)
        kept.storehouses![0].built = Storehouse.raising
        kept.houses[me].stock = Stock(grain: 300, timber: 300, stone: 300, moonsalt: 30)
        let (keeper, keeperLink) = self.session(kept)
        XCTAssertTrue(AlliancePanel.storehouseLine(try XCTUnwrap(keeper.state.alliance(of: me)), in: keeper.state).hasPrefix("Storehouse: standing "))
        XCTAssertEqual(AlliancePanel.laidUpLine(.zero),
                       "You have laid up nothing yet: as much as 600 grain, 600 timber, 600 stone, 50 moonsalt, out of any taker's reach.")
        XCTAssertEqual(AlliancePanel.laidUpLine(Stock(grain: 100)), "You have laid up 100 grain, of as much as 600 grain, 600 timber, 600 stone, 50 moonsalt.")
        PressableButtons.isListening = true
        draw(AlliancePanel(session: keeper), width: 360, height: 2400)
        XCTAssertFalse(PressableButtons.press("Take back 100 grain"), "Nothing laid up yet")
        XCTAssertTrue(PressableButtons.press("Lay up 100 grain"), "Among \(shown)")
        XCTAssertEqual(keeperLink.sent.last, .layUp(Stock(grain: 100)))
        XCTAssertEqual(keeper.state.laidUp(by: me), Stock(grain: 100), "Laid up at once on the keeper's copy")
        PressableButtons.isListening = true
        draw(AlliancePanel(session: keeper), width: 360, height: 2400)
        XCTAssertTrue(PressableButtons.press("Take back all"), "Among \(shown)")
        XCTAssertEqual(keeperLink.sent.last, .takeBack(Stock(grain: 100)))
        XCTAssertEqual(keeper.state.laidUp(by: me), .zero)
        XCTAssertEqual(GameSession.cues(for: .layUp(Stock(grain: 100)), events: [], in: keeper.state, player: me), [.coin])
        XCTAssertEqual(AlliancePanel.measures.count, 4)

        // Struck low, it burns; the realm's to tell when struck, heard where it stands.
        var struck = kept
        struck.storehouses![0].ward = 20
        let keeperID = struck.takeID()
        struck.units.append(NullmereCore.Unit(id: keeperID, kind: .spear, owner: me, position: spot, tier: 1))
        let (burning, _) = self.session(struck)
        let stage = WorldStage(map: burning.state.map, relief: Relief(map: burning.state.map))
        let blazes = burning.happenings(poses: [], sights: [], stage: stage, at: Date(), time: 1).blazes
        XCTAssertTrue(blazes.contains { abs($0.at.x - Relief.centre(of: spot).x) < 1e-3 }, "\(blazes)")
        let hit = GameEvent.storehouseStruck(storehouse: storehouse.id, alliance: sworn.id, ward: 10, by: 2, at: spot)
        XCTAssertTrue(GameSession.isRealmsToTell(hit))
        XCTAssertEqual(GameSession.place(of: hit, in: burning.state), spot)
        XCTAssertTrue(burning.state.storehousesStanding.allSatisfy { HoverInfo.named($0, in: burning.state).contains("ward 20 of 120") })
        XCTAssertTrue(HoverInfo.described(try XCTUnwrap(burning.state.storehouse(at: spot)), in: burning.state).hasPrefix("Raised by "))
    }

    func testACompanyDrillsAtItsHallFromItsPanel() throws {
        var state = world("drilled from the panel")
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        let hall = try XCTUnwrap(state.holds.firstIndex { $0.id == seat.id })
        state.holds[hall].levels[.musterHall] = 2
        state.houses[me].stock = Stock(grain: 500, timber: 500, stone: 500, moonsalt: 100)
        state.units.removeAll { $0.position == seat.position }
        let id = state.takeID()
        state.units.append(NullmereCore.Unit(id: id, kind: .spear, owner: me, position: seat.position, tier: 1))
        let (session, link) = session(state)
        let unit = try XCTUnwrap(session.state.unit(id))
        XCTAssertEqual(UnitPanel.drillLine(unit, in: session.state), "It may lead 39,600, drilled at or beside one of your holds with a Muster Hall.")
        session.selection = .unit(id)
        draw(SelectionPanel(session: session), width: 330, height: 700)
        XCTAssertTrue(PressableButtons.press("Drill"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .drill(unit: id))
        let drilling = try XCTUnwrap(session.state.unit(id))
        XCTAssertTrue(session.state.isDrilling(drilling))
        XCTAssertEqual(UnitPanel.drillLine(drilling, in: session.state), "Drilling: 1,200 more as the watch turns, for 12 grain; it may lead 39,600.")
        draw(SelectionPanel(session: session), width: 330, height: 700)
        XCTAssertFalse(PressableButtons.press("Drilling"), "Drilling already")
        XCTAssertNil(PressableButtons.actions["Drill"])
        // Drilled whole, it says so.
        var whole = drilling
        whole.drilled = 38_400
        XCTAssertTrue(UnitPanel.drillLine(whole, in: session.state)?.hasPrefix("It musters as many as it may lead, 39,600") == true)
        XCTAssertEqual(UnitPanel.troopsLine(whole, in: session.state), "39,600 of 39,600 troops standing")
        XCTAssertNil(UnitPanel.drillLine(NullmereCore.Unit(id: 0, kind: .lantern, owner: me, position: seat.position), in: session.state))
        // Told once drilled whole; its panel shows it growing till then.
        let told = Narration.line(for: .drilled(unit: id, owner: me, troops: 1_200, whole: true), in: session.state, viewer: me)
        XCTAssertEqual(told?.text, "Your Spears at \(seat.name) are drilled whole: \(GameState.counted(session.state.fullMuster(of: drilling))) troops.")
        XCTAssertNil(Narration.line(for: .drilled(unit: id, owner: me, troops: 1_200, whole: false), in: session.state, viewer: me))
        XCTAssertNil(Narration.line(for: .drilled(unit: id, owner: me, troops: 1_200, whole: true), in: session.state, viewer: (me + 1) % 6))
    }

    func testCompaniesAndArmiesAreCountedInTroops() throws {
        var state = world("troops shown")
        let me = state.player
        let index = try XCTUnwrap(state.units.firstIndex { $0.owner == me && $0.kind.isMilitary })
        state.units[index].health = 50
        let unit = state.units[index]
        let (session, _) = session(state)
        let full = unit.kind.troops(tier: unit.tier)
        XCTAssertEqual(UnitPanel.troopsLine(unit, in: session.state),
                       "\(GameState.counted(full / 2)) of \(GameState.counted(full)) troops standing")
        let companies = session.state.units(of: me).filter(\.kind.isMilitary).count
        XCTAssertTrue(RealmPanel.armyLine(session.state, player: me)
            .hasPrefix("Your army: \(GameState.counted(session.state.army(of: me))) troops in \(companies) compan"))
        session.selection = .unit(unit.id)
        draw(SelectionPanel(session: session), width: 330, height: 700)
        draw(RealmPanel(session: session))
        // A blow is told in the troops it slew.
        let foe = (me + 1) % session.state.houses.count
        let blow = Battle(attacker: unit.id, attackerOwner: me, attackerKind: unit.kind, defender: 900, defenderOwner: foe, defenderKind: .bow,
                          hold: nil, at: unit.position, damageDealt: 30, damageTaken: 0, attackerFell: false, defenderFell: false,
                          slain: 300, lost: 0)
        let told = try XCTUnwrap(Narration.line(for: .battle(blow), in: session.state, viewer: me)?.text)
        XCTAssertTrue(told.contains("for 30, slaying 300"), told)
        let struck = try XCTUnwrap(Narration.line(for: .battle(blow), in: session.state, viewer: foe)?.text)
        XCTAssertTrue(struck.hasSuffix("for 30, slaying 300."), struck)
    }

    func testTheRealmScreenTellsHowTheShoresStand() throws {
        var state = world("shores shown")
        let me = state.player
        XCTAssertEqual(RealmPanel.sunderingLine(state, player: me), "The Sundering comes at the 55th watch: the shores war as kingdoms.")
        state.watch = Sundering.first
        _ = state.turnSundering()
        let shore = try XCTUnwrap(state.sundering?.shore(of: me))
        state.sundering!.points[me] = 12
        let east = state.sundering!.score(of: .eastern), west = state.sundering!.score(of: .western)
        let stands = "the Eastern Shore \(east), the Western \(west), until the 67th watch."
        XCTAssertEqual(RealmPanel.sunderingLine(state, player: me), "The Sundering: you stand with \(shore.title), your House 12 points; \(stands)")
        XCTAssertEqual(RealmPanel.sunderingLine(state, player: 99), "The Sundering: \(stands)")
        let (session, _) = session(state)
        draw(RealmPanel(session: session))
        XCTAssertEqual(GameSession.cues(for: [.sunderingEnded(winner: shore, eastern: 12, western: 0, hailed: me)], in: session.state, player: me),
                       [.watch, .triumph], "Its own kingdom prevailing is a triumph")
        XCTAssertEqual(GameSession.cues(for: [.sunderingEnded(winner: shore.other, eastern: 12, western: 0, hailed: nil)], in: session.state,
                                        player: me), [.watch, .herald])
        state.watch = state.sundering!.ends
        _ = state.turnSundering()
        let settled = RealmPanel.sunderingLine(state, player: me)
        XCTAssertTrue(settled.hasPrefix("The last Sundering: \(shore.title) prevailed, 12 to 0; the next at the 145th watch"), settled)
        state.sundering = Sundering(begins: 55, shores: state.houses.map { _ in nil })
        state.sundering!.settled = true
        XCTAssertEqual(RealmPanel.sunderingLine(state, player: me), "The last Sundering ended with neither shore ahead; the next at the 145th watch.")
    }

    func testTheRealmScreenShowsTheKeepersFavour() throws {
        let state = world("favour shown")
        let (session, _) = session(state)
        var keeper = Keeper(id: "k", name: "Ama", house: state.player, isReady: false, isOnline: true, arrival: 0)
        XCTAssertEqual(RealmPanel.favourLine(keeper), "No favour yet: 0 favour won, 60 more to Favour I.")
        XCTAssertEqual(RealmPanel.favourProgress(0), 0)
        XCTAssertEqual(RealmPanel.streakLine(keeper),
                       "0 watches kept unbroken: the next brings 10 favour, and a favour chest comes in 10 watches.")
        keeper.favour = 300
        keeper.streak = 9
        XCTAssertEqual(RealmPanel.favourLine(keeper), "Favour II: 300 favour won, 100 more to Favour III.")
        XCTAssertEqual(RealmPanel.favourProgress(300), Double(300 - 180) / Double(400 - 180), accuracy: 1e-9)
        XCTAssertEqual(RealmPanel.streakLine(keeper), "9 watches kept unbroken: the next brings 28 favour, and a favour chest comes in 1 watch.")
        session.keeper = keeper
        draw(RealmPanel(session: session))
        keeper.favour = 12_000
        keeper.streak = 1
        XCTAssertEqual(RealmPanel.favourLine(keeper), "Favour X: 12,000 favour won, the highest there is.")
        XCTAssertEqual(RealmPanel.favourProgress(12_000), 1)
        XCTAssertEqual(RealmPanel.streakLine(keeper), "1 watch kept unbroken: the next brings 12 favour, and a favour chest comes in 9 watches.")
        session.keeper = keeper
        draw(RealmPanel(session: session))
    }

    func testTheForgeShowsItsMakingsAndForgesAPieceOfASet() throws {
        var state = world("forge shown")
        let me = state.player
        let seat = try XCTUnwrap(state.holds.first { $0.owner == me && $0.isSeat })
        // No Forge yet: it says how to have one, and offers nothing.
        let (bare, _) = session(state)
        PressableButtons.isListening = true
        draw(CommandersPanel(session: bare), width: 360, height: 2400)
        XCTAssertFalse(PressableButtons.press("Forge"), "Nothing to forge with")
        XCTAssertEqual(ForgeView.makingsLine(bare.state, me), "No makings yet.")
        XCTAssertTrue(ForgeView.noForge.hasPrefix("Raise a Forge at one of your holds"))
        // A Forge of the second level, with makings: the finest it makes is chosen.
        state.holds[try XCTUnwrap(state.holdIndex(seat.id))].levels[.forge] = 2
        _ = state.give(makings: [.hide: 40, .iron: 40, .heartwood: 40, .moonglass: 40], to: me)
        state.houses[me].stock.moonsalt = 60
        let (session, link) = session(state)
        XCTAssertEqual(ForgeView.quality(nil, atLevel: 2), .fine)
        XCTAssertEqual(ForgeView.quality(.fabled, atLevel: 2), .fine, "No finer than the Forge makes")
        XCTAssertEqual(ForgeView.quality(.plain, atLevel: 2), .plain)
        XCTAssertEqual(ForgeView.quality(nil, atLevel: 0), .plain)
        XCTAssertEqual(ForgeView.recipeLine(.wardensBlade, .fine, in: session.state, for: me), "7 iron, 4 heartwood, 8 moonsalt")
        PressableButtons.isListening = true
        draw(CommandersPanel(session: session), width: 360, height: 2400)
        XCTAssertTrue(PressableButtons.press("Forge"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .forge(.pathfindersLodestone, quality: .fine))
        XCTAssertEqual(session.state.gear(of: me).first?.title, "Fine Pathfinder's Lodestone", "Forged at once on the keeper's copy")
        XCTAssertEqual(GameSession.cues(for: .forge(.pathfindersLodestone, quality: .fine), events: [], in: session.state, player: me), [.anvil])
    }

    func testTheSatchelIsShownAndItsItemsUsed() throws {
        var state = world("satchel shown")
        let me = state.player
        let seat = try XCTUnwrap(state.holds.first { $0.owner == me && $0.isSeat })
        let index = try XCTUnwrap(state.holdIndex(seat.id))
        // Empty, it says what fills it, and nothing is offered.
        let (empty, _) = session(state)
        PressableButtons.isListening = true
        draw(RealmPanel(session: empty))
        XCTAssertFalse(PressableButtons.press("Open"))
        _ = state.give(.hourglass, 2, to: me)
        _ = state.give(.timberCache, to: me)
        _ = state.give(.wardStone, to: me)
        state.holds[index].project = Hold.Project(kind: .granary, targetLevel: 1, watchesLeft: 3)
        state.holds[index].ward = 2
        state.houses[me].stock = .zero
        let (session, link) = session(state)
        PressableButtons.isListening = true
        draw(RealmPanel(session: session))
        XCTAssertTrue(PressableButtons.press("Open"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .useItem(.timberCache, hold: nil))
        XCTAssertEqual(session.state.houses[me].stock.timber, 120, "Opened at once on the keeper's copy")
        XCTAssertFalse(PressableButtons.press("Hasten your study"), "No study under way")
        XCTAssertFalse(PressableButtons.press("Make the ward whole"), "A ward stone is used from its hold's panel")
        // The hold's own panel hastens its work and makes its ward whole.
        session.selection = .hold(seat.id)
        PressableButtons.isListening = true
        draw(SelectionPanel(session: session), width: 330, height: 1400)
        XCTAssertTrue(PressableButtons.press("Hasten"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .useItem(.hourglass, hold: seat.id))
        XCTAssertEqual(session.state.hold(seat.id)?.project?.watchesLeft, 2)
        XCTAssertTrue(PressableButtons.press("Make the ward whole"))
        XCTAssertEqual(link.sent.last, .useItem(.wardStone, hold: seat.id))
        XCTAssertEqual(session.state.hold(seat.id)?.ward, session.state.hold(seat.id)?.maximumWard)
        // What each says, and where it is used.
        XCTAssertEqual(RealmPanel.about(.hourglass),
                       "A hold's work and muster a watch nearer, or the House's study. Use it from a hold's panel, or here on your study.")
        XCTAssertEqual(RealmPanel.about(.wardStone), "A hold's ward made whole. Use it from the hold's panel.")
        XCTAssertEqual(RealmPanel.about(.timberCache), "120 timber to the House's stores.")
        XCTAssertNil(RealmPanel.use(.wardStone))
        XCTAssertEqual(RealmPanel.use(.mendingDraught), .useItem(.mendingDraught, hold: nil))
        XCTAssertEqual(ItemKind.allCases.filter { RealmPanel.use($0) != nil }.map(RealmPanel.useTitle),
                       ["Hasten your study", "Open", "Open", "Open", "Open", "Share it out"])
        XCTAssertEqual(GameSession.place(of: .itemUsed(house: me, kind: .wardStone, hold: seat.id), in: session.state), seat.position)
        XCTAssertNil(GameSession.place(of: .itemUsed(house: me, kind: .timberCache, hold: nil), in: session.state))
    }

    func testAHeritageIsShownAndAnotherTakenUp() throws {
        var state = world("heritage shown")
        let me = state.player
        let dealt = state.heritage(of: me)
        let other = try XCTUnwrap(Heritage.allCases.first { $0 != dealt })
        state.houses[me].stock[.moonsalt] = 0
        // The briefing says what the House comes of.
        let briefing = SeatBriefing(world: state, player: me)
        XCTAssertEqual(briefing.facts[1], SeatBriefing.heritageLine(state, me))
        XCTAssertTrue(briefing.facts[1].hasPrefix("Your House comes of \(dealt.title): \(dealt.strengths[0]), and \(dealt.strengths[1])."))
        XCTAssertTrue(briefing.facts[1].hasSuffix("of the fifth tier. You may take up another heritage in the Realm (6), the first time freely."), briefing.facts[1])
        // The Realm shows it, and takes up another, the first time freely.
        let (session, link) = session(state)
        PressableButtons.isListening = true
        draw(RealmPanel(session: session), width: 360, height: 1600)
        XCTAssertTrue(PressableButtons.press("Take up \(other.title)"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .takeHeritage(other))
        XCTAssertEqual(session.state.heritage(of: me), other, "Taken up at once on the keeper's copy")
        XCTAssertFalse(PressableButtons.press("Take up \(dealt.title)"), "Its own is not offered")
        // Then for moonsalt, which the House lacks: the rows say so.
        let third = try XCTUnwrap(Heritage.allCases.first { $0 != dealt && $0 != other })
        PressableButtons.isListening = true
        draw(RealmPanel(session: session), width: 360, height: 1600)
        XCTAssertFalse(PressableButtons.press("Take up \(third.title)"), "Short of moonsalt")
        XCTAssertEqual(RealmPanel.heritageChange(session.state, player: me), "Take up another instead, for 30 moonsalt:")
        XCTAssertEqual(RealmPanel.heritageChange(state, player: me), "Take up another instead, the first time freely:")
        XCTAssertTrue(SeatBriefing.heritageLine(session.state, me).hasSuffix("of the fifth tier. Another heritage costs 30 moonsalt in the Realm (6)."))
        XCTAssertEqual(RealmPanel.heritageLine(.fenfolk),
                       "Its Bows strike a tenth harder; its companies see a tile further. Its own company: the Reed Bows, Bows of the fifth tier.")
        // A company of its own is named so in its panel.
        var armed = session.state
        let seat = try XCTUnwrap(armed.holds.first { $0.owner == me && $0.isSeat })
        let own = try XCTUnwrap(armed.placeUnit(other.signature, tier: 5, for: me, near: seat.position))
        let (keeper, _) = self.session(armed)
        keeper.selection = .unit(own.id)
        draw(SelectionPanel(session: keeper), width: 330, height: 700)
        XCTAssertEqual(keeper.state.title(of: try XCTUnwrap(keeper.state.unit(own.id))), other.signatureTitle)
        draw(HousesPanel(session: keeper), width: 360, height: 900)
    }

    func testAnAllianceStudiesTogetherFromItsScreen() throws {
        var state = world("studies shown")
        let me = state.player
        _ = try state.perform(.foundAlliance(name: "The Long Table"), as: me)
        state.houses[me].stock = Stock(grain: 400, timber: 400, stone: 400, moonsalt: 20)
        // Nothing pursued: its leader is shown the studies to choose from.
        let (session, link) = session(state)
        PressableButtons.isListening = true
        draw(AlliancePanel(session: session), width: 360, height: 1600)
        XCTAssertFalse(PressableButtons.press("Give 50 grain"), "Nothing to give toward")
        XCTAssertTrue(PressableButtons.press("Pursue"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .pursueAllianceStudy(.sharedScrolls))
        // Pursued: the House gives toward it.
        PressableButtons.isListening = true
        draw(AlliancePanel(session: session), width: 360, height: 1600)
        XCTAssertTrue(PressableButtons.press("Give 50 grain"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .giveToAlliance(Stock(grain: 50)))
        XCTAssertEqual(session.state.alliance(of: me)?.lore?.given, Stock(grain: 50))
        XCTAssertEqual(AlliancePanel.paid(Stock(grain: 60, moonsalt: 6), of: Stock(grain: 120, moonsalt: 6)), Double(60 + 18) / Double(120 + 18))
        XCTAssertEqual(AlliancePanel.paid(.zero, of: .zero), 1)
        XCTAssertEqual(AlliancePanel.given(Stock(grain: 60, timber: 500), of: Stock(grain: 120, timber: 100)), "60 of 120 grain, 100 of 100 timber")
        XCTAssertEqual(AlliancePanel.gifts.count, 4)
    }

    func testACompanySaysWhatItWasSentToDo() throws {
        var state = world("errands")
        let me = state.player
        let index = try XCTUnwrap(state.units.firstIndex { $0.owner == me && $0.kind.isMilitary })
        let seat = try XCTUnwrap(state.seat(of: me))
        state.units[index].load = Stock(grain: 40)
        XCTAssertEqual(UnitPanel.errand(of: state.units[index], in: state), "Carrying 40 grain.")
        state.units[index].errand = .homeward
        XCTAssertEqual(UnitPanel.errand(of: state.units[index], in: state), "Bringing 40 grain home.")
        state.units[index].errand = .reinforce(hold: seat.id)
        XCTAssertEqual(UnitPanel.errand(of: state.units[index], in: state), "Keeping the gates of \(seat.name).")
        state.units[index].errand = .rally(99)
        XCTAssertEqual(UnitPanel.errand(of: state.units[index], in: state), "Sent to the rally.")
        state.units[index].load = nil
        state.units[index].errand = .gather(site: 99)
        XCTAssertEqual(UnitPanel.errand(of: state.units[index], in: state), "Gathering at a site of the land.")
        state.units[index].destination = seat.position
        XCTAssertEqual(UnitPanel.errand(of: state.units[index], in: state), "Bound to gather at a site of the land.")
        state.units[index].destination = nil
        state.units[index].errand = nil
        XCTAssertNil(UnitPanel.errand(of: state.units[index], in: state))
        XCTAssertNil(UnitPanel.leader(of: state.units[index], in: state))
        // In a field of battle, in a realm's watch.
        let foe = state.units.first { $0.owner != me && $0.kind.isMilitary }!
        let mine = state.units[index]
        var field = Field(id: 900, at: foe.position, joined: state.watch, first: me, second: foe.owner)
        field.fighters = [Fighter(unit: mine.id, owner: me, side: 0, kind: mine.kind, tier: mine.tier, leader: nil, troops: 1_200),
                          Fighter(unit: foe.id, owner: foe.owner, side: 1, kind: foe.kind, tier: foe.tier, leader: nil, troops: 1_000)]
        field.fighters[0].foe = foe.id
        field.fighters[0].lost = 300
        field.fighters[1].lost = 400
        state.fields = [field]
        XCTAssertEqual(UnitPanel.errand(of: state.units[index], in: state),
                       "In battle \(state.placeName(of: foe.position)) against \(state.houses[foe.owner].title)'s \(foe.kind.title): "
                       + "its side 1 company, 900 troops, the other 1 company, 600 troops. It fights on at every pace until it draws off.")
        state.fields![0].fighters[0].foe = 9_999
        XCTAssertTrue(UnitPanel.errand(of: state.units[index], in: state)?.hasPrefix("In battle \(state.placeName(of: foe.position)) against the foe") == true)
        state.fields![0].fighters[0].standing = false
        XCTAssertNil(UnitPanel.errand(of: state.units[index], in: state), "Drawn off, in none")
        state.fields = nil
        let (session, _) = session(state)
        session.selection = .unit(state.units[index].id)
        draw(SelectionPanel(session: session), width: 330, height: 600)
    }

    /// The oaths between the keeper's House and another are told on the
    /// other's line in the Houses' list, the keeper's own and the other's
    /// to them; each of the keeper's is renounced from there, and told as
    /// renounced; and the realm's word of oaths is heard.
    func testAnOathIsToldOnItsHousesLineAndRenouncedThere() throws {
        var state = world("oaths told")
        let me = state.player
        let others = state.livingHouses.map(\.id).filter { $0 != me }
        let other = try XCTUnwrap(others.first), third = try XCTUnwrap(others.last)
        state.houses[me].stock.grain = 500
        let sworn = state.watch
        _ = try state.perform(.swear(.peace, to: other, watches: 10), as: me)
        _ = try state.perform(.swear(.send(.grain, 30), to: other, watches: 5), as: me)
        XCTAssertEqual(HouseRow.oathLines(between: me, and: other, in: state),
                       ["Your oath: peace until watch \(sworn + 10).", "Your oath: 30 grain each watch until watch \(sworn + 5)."])
        XCTAssertEqual(HouseRow.oathLines(between: other, and: me, in: state),
                       ["Their oath to you: peace until watch \(sworn + 10).", "Their oath to you: 30 grain each watch until watch \(sworn + 5)."])
        XCTAssertEqual(HouseRow.oathLines(between: me, and: third, in: state), [], "None between them")

        let (session, link) = session(state)
        let house = session.state.houses[other]
        draw(HouseRow(session: session, house: house, draft: OfferDraft(for: house)))
        XCTAssertTrue(shown.contains("Renounce the oath of 30 grain each watch"), "Among \(shown)")
        XCTAssertTrue(PressableButtons.press("Renounce the oath of peace"), "Among \(shown)")
        let peace = try XCTUnwrap(session.state.oathsInForce.first { $0.term == .peace })
        XCTAssertEqual(link.sent.last, .renounce(oath: peace.id))
        XCTAssertEqual(peace.renounced, session.state.watch)
        XCTAssertEqual(HouseRow.oathLines(between: me, and: other, in: session.state).first,
                       "Your oath: peace until watch \(session.state.watch + GameState.oathNotice), renounced.")
        // Renounced, it is renounced no more.
        PressableButtons.forget("Renounce the oath of peace")
        draw(HouseRow(session: session, house: house, draft: OfferDraft(for: house)))
        XCTAssertFalse(shown.contains("Renounce the oath of peace"), "Renounced once")
        XCTAssertEqual(HouseRow.renounceable(by: me, to: other, in: session.state).map(\.term), [.send(.grain, 30)])

        // Heard: an oath sworn or renounced, and one sworn to the keeper's
        // House, renounced, broken or kept.
        XCTAssertEqual(GameSession.cues(for: .swear(.peace, to: third, watches: 4), events: [], in: session.state, player: me), [.banner])
        XCTAssertEqual(GameSession.cues(for: .renounce(oath: peace.id), events: [], in: session.state, player: me), [.refusal])
        XCTAssertEqual(GameSession.cue(forDepth: .oathSworn(peace), in: session.state, player: other), .banner)
        XCTAssertEqual(GameSession.cue(forDepth: .oathRenounced(peace), in: session.state, player: other), .refusal)
        XCTAssertEqual(GameSession.cue(forDepth: .oathEnded(peace, why: .broken), in: session.state, player: me), .dread)
        XCTAssertEqual(GameSession.cue(forDepth: .oathEnded(peace, why: .kept), in: session.state, player: me), .accord)
        XCTAssertNil(GameSession.cue(forDepth: .oathSworn(peace), in: session.state, player: third))
        // And told in the rules' own words.
        XCTAssertEqual(Narration.line(for: .oathSworn(peace), in: session.state, viewer: other)?.tone, .good)
    }
}

extension DepthPanelTests {
    // MARK: Ferries of the Still

    /// Two shore holds of the keeper's apart across the lake, a company at
    /// the first.
    private func ferryWorld() throws -> (GameState, from: Int, to: Int, company: Int) {
        var state = world("pressed ferries")
        let me = state.player
        state.houses[me].stock = Stock(grain: 500, timber: 100, stone: 100, moonsalt: 10)
        let shores = state.map.hexes.filter { hex in
            state.map[hex]?.terrain.isSettleable == true && state.hold(at: hex) == nil && state.unit(at: hex) == nil
                && state.map.neighbors(of: hex).contains { [.still, .shallows].contains(state.map[$0]?.terrain) }
        }
        let first = try XCTUnwrap(shores.first)
        let second = try XCTUnwrap(shores.max { $0.distance(to: first) < $1.distance(to: first) })
        let from = Hold(id: state.takeID(), name: "Saltwatch", owner: me, position: first, isSeat: false, foundedWatch: 1)
        let to = Hold(id: state.takeID(), name: "Farmere", owner: me, position: second, isSeat: false, foundedWatch: 1)
        state.holds += [from, to]
        // Holds of the House are ground it knows, as founding them makes it.
        state.reveal(around: first, range: 2, for: me)
        state.reveal(around: second, range: 2, for: me)
        let company = Unit(id: state.takeID(), kind: .spear, owner: me, position: first, tier: 1)
        state.units.append(company)
        return (state, from.id, to.id, company.id)
    }

    func testTheFerryLineSendsACompanyAcrossTheLake() throws {
        let (state, _, to, company) = try ferryWorld()
        let (session, link) = session(state)
        session.selection = .unit(company)
        draw(SelectionPanel(session: session))
        XCTAssertTrue(PressableButtons.press("To Farmere"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .ferry(unit: company, to: to))
    }

    func testTheFerryLineSaysWhereTheBargeIsBound() throws {
        var (state, _, to, company) = try ferryWorld()
        _ = try state.perform(.ferry(unit: company, to: to), as: state.player)
        let (session, _) = session(state)
        let unit = try XCTUnwrap(session.state.unit(company))
        XCTAssertNotNil(session.state.crossing(of: company), "The keeper sees their own barge")
        draw(FerryLine(session: session, unit: unit, landings: []), height: 120)
        XCTAssertFalse(shown.contains("To Farmere"), "On the water, no landing to choose")
    }
}

extension DepthPanelTests {
    // MARK: The Drowned Crown

    /// The band tells the keeper who bears the crown and who leads, and is
    /// gone once it sinks; its cues sound for the keeper's side.
    func testTheCrownsBandSaysWhoBearsItAndWhoLeads() throws {
        var state = world("pressed crown")
        state.watch = Sundering.first - 1
        _ = state.endWatch()
        let crown = try XCTUnwrap(state.crown)
        let me = state.player
        XCTAssertEqual(MoonBand.crownLine(in: state, for: me), "The Drowned Crown lies on the ford for whoever takes it up.")
        state.units.removeAll { $0.position == crown.hex }
        let company = Unit(id: state.takeID(), kind: .rider, owner: me, position: crown.hex, tier: 1)
        state.units.append(company)
        let taken = state.takeUpCrown()
        XCTAssertEqual(MoonBand.crownLine(in: state, for: me), "The Drowned Crown is borne by your side; your side leads with 1 watch.")
        let other = try XCTUnwrap(state.houses.indices.first { $0 != me && state.crownSide(of: $0) != state.crownSide(of: me) })
        XCTAssertEqual(MoonBand.crownLine(in: state, for: other),
                       "The Drowned Crown is borne by \(state.houses[me].name); \(state.houses[me].name) leads with 1 watch.")
        draw(MoonBand(line: try XCTUnwrap(MoonBand.crownLine(in: state, for: me))), width: 700, height: 40)

        let (session, _) = session(state)
        XCTAssertEqual(GameSession.cue(forDepth: taken[0], in: session.state, player: me), .horn)
        XCTAssertEqual(GameSession.cue(forDepth: taken[0], in: session.state, player: other), .dread)
        XCTAssertEqual(GameSession.cue(forDepth: .crownSurfaced(at: crown.hex), in: session.state, player: me), .herald)
        XCTAssertEqual(GameSession.cue(forDepth: .crownSank(side: -1 - me, houses: [me]), in: session.state, player: me), .triumph)
        XCTAssertNotNil(Narration.line(for: taken[0], in: session.state, viewer: me))

        state.ford = nil
        _ = state.contestCrown()
        XCTAssertNil(MoonBand.crownLine(in: state, for: me), "Gone with the ford")
    }
}

/// A line to a realm that only listens: what was sent, in order.
private final class DepthLink: RealmLink {
    var onEvent: ((RealmEvent) -> Void)?
    private(set) var sent: [Command] = []
    func connect() {}
    func arrive(name: String?) {}
    func send(_ command: Command) { sent.append(command) }
    func setReady(_ ready: Bool) {}
    func leave() {}
}

extension DepthPanelTests {
    /// The Monument on the Realm screen: the stone being raised, the lake's
    /// part and the keeper's, and the stones set.
    func testTheMonumentShowsTheStoneBeingRaised() throws {
        var state = world("the monument shown")
        let hold = try XCTUnwrap(state.holds(of: state.player).first)
        state.countMonument([.buildingCompleted(hold: hold.id, kind: .granary, level: 2)])
        XCTAssertEqual(MonumentSection.summary(state.lakeMonument), "Stone 1 of \(MonumentStone.allCases.count) · 1 of \(MonumentStone.foundations.measure)")
        XCTAssertEqual(MonumentSection.summary(Monument(set: MonumentStone.allCases.count, done: 0, parts: [:])), "Whole: every stone set")
        let (session, _) = session(state)
        draw(MonumentSection(session: session, open: true))
        draw(RealmPanel(session: session))
        // With stones set, each is named under the one being raised.
        state.monument = Monument(set: 2, done: 0, parts: [:])
        let (raised, _) = self.session(state)
        draw(MonumentSection(session: raised, open: true))
    }
}
