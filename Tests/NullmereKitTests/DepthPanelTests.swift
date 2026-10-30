import AppKit
@testable import LauncherKit
import NullmereRealm
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
        XCTAssertTrue(PressableButtons.press("Ask to join"), "Among \(shown)")
        guard case .askToJoin? = asked.sent.last else { return XCTFail("Asked: \(String(describing: asked.sent.last))") }
    }

    func testASwornHouseInvitesHelpsAndLeaves() throws {
        let state = world("pressed alliance")
        let (session, link) = session(state)
        XCTAssertTrue(session.perform(.foundAlliance(name: "The Ashen Ring")))
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
    }

    func testTheRailOpensAndClosesEachPanel() throws {
        let (session, _) = session(world("pressed rail"))
        draw(PanelRail(session: session), width: 420, height: 40)
        for (title, panel, _) in PanelRail.panels {
            XCTAssertTrue(PressableButtons.press(title), "Among \(shown)")
            XCTAssertEqual(session.panel, panel)
            XCTAssertTrue(PressableButtons.press(title))
            XCTAssertNil(session.panel, "\(title) again closes it")
        }
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
        session.order(spot)
        XCTAssertEqual(link.sent.last, .gather(unit: company.id, site: site.id))
        let sent = try XCTUnwrap(session.state.unit(company.id))
        XCTAssertEqual(UnitPanel.errand(of: sent, in: session.state), "Gathering at the Deadfall II, 600 timber left.")
        session.selection = .tile(spot)
        draw(SelectionPanel(session: session), width: 330, height: 600)
        session.selection = .tile(lair)
        draw(SelectionPanel(session: session), width: 330, height: 600)
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
        state.units[index].errand = nil
        XCTAssertNil(UnitPanel.errand(of: state.units[index], in: state))
        XCTAssertNil(UnitPanel.leader(of: state.units[index], in: state))
        let (session, _) = session(state)
        session.selection = .unit(state.units[index].id)
        draw(SelectionPanel(session: session), width: 330, height: 600)
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
