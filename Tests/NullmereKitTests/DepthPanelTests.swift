import AppKit
@testable import LauncherKit
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
        XCTAssertEqual(session.beckon, .work(.musterHall), "its Build button ringed")
        draw(SelectionPanel(session: session), width: 330, height: 900)
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
        draw(PanelRail(session: session), width: 420, height: 40)
        for (title, panel, _) in PanelRail.panels {
            XCTAssertTrue(PressableButtons.press(title), "Among \(shown)")
            XCTAssertEqual(session.panel, panel)
            XCTAssertTrue(PressableButtons.press(title))
            XCTAssertNil(session.panel, "\(title) again closes it")
        }
    }

    // MARK: Words

    func testWordsAreHeardSaidAndShown() throws {
        var state = world("pressed words")
        let me = state.player
        let other = (me + 1) % 6
        state.houses[other].isPlayer = true
        _ = try state.perform(.say(words: "Well met", toAlliance: false), as: other)
        let (session, link) = session(state)
        XCTAssertEqual(session.state.words(heardBy: me).map(\.text), ["Well met"])
        draw(WordsPanel(session: session))
        XCTAssertFalse(PressableButtons.press("Say"), "Nothing written, nothing to say")
        XCTAssertTrue(session.perform(.say(words: "And you", toAlliance: false)))
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
                                                                  woundedFor: 1, furyReady: false)),
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
        XCTAssertEqual(InfirmaryRows.lying(try XCTUnwrap(session.state.hold(seat.id)?.wounded)), "Spears II · Bows I, healing")
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
        // The Realm lists the lairs found.
        draw(RealmPanel(session: session))
        XCTAssertEqual(RealmPanel.standing(lair), "Whole, 450")
        var struck = lair
        struck.strength = 120
        XCTAssertEqual(RealmPanel.standing(struck), "120 of 450 standing")
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
        // Locked in battle, in a realm's watch.
        let foe = state.units.first { $0.owner != me && $0.kind.isMilitary }!
        state.engagements = [Engagement(attacker: state.units[index].id, defender: foe.id, attackerAt: state.units[index].position,
                                        defenderAt: foe.position, rounds: 2)]
        XCTAssertEqual(UnitPanel.errand(of: state.units[index], in: state),
                       "Locked in battle with \(state.houses[foe.owner].title)'s \(foe.kind.title): 2 more exchanges of blows this watch, unless one side draws off.")
        state.engagements = [Engagement(attacker: foe.id, defender: state.units[index].id, attackerAt: foe.position,
                                        defenderAt: state.units[index].position, rounds: 1)]
        XCTAssertTrue(UnitPanel.errand(of: state.units[index], in: state)?.contains(": one more exchange of blows") == true)
        state.engagements = [Engagement(attacker: 9_999, defender: state.units[index].id, attackerAt: .origin, defenderAt: .origin, rounds: 1)]
        XCTAssertTrue(UnitPanel.errand(of: state.units[index], in: state)?.hasPrefix("Locked in battle with the foe") == true)
        state.engagements = nil
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
