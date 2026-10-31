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
        let (session, _) = session(state)
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
        XCTAssertTrue(named.contains("a standard of The Tall Pole, ward 60 of 60"), named)
        let about = try XCTUnwrap(spot.ring(1).first { session.state.standard(at: $0) == nil && session.state.hold(at: $0) == nil })
        let land = try XCTUnwrap(HoverInfo.line(for: about, in: session.state, explored: true, territory: session.state.territory()))
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
        XCTAssertEqual(UnitPanel.drillLine(unit, in: session.state), "It may lead 20,400, drilled at or beside one of your holds with a Muster Hall.")
        session.selection = .unit(id)
        draw(SelectionPanel(session: session), width: 330, height: 700)
        XCTAssertTrue(PressableButtons.press("Drill"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .drill(unit: id))
        let drilling = try XCTUnwrap(session.state.unit(id))
        XCTAssertTrue(session.state.isDrilling(drilling))
        XCTAssertEqual(UnitPanel.drillLine(drilling, in: session.state), "Drilling: 1,200 more as the watch turns, for 12 grain; it may lead 20,400.")
        draw(SelectionPanel(session: session), width: 330, height: 700)
        XCTAssertFalse(PressableButtons.press("Drilling"), "Drilling already")
        XCTAssertNil(PressableButtons.actions["Drill"])
        // Drilled whole, it says so.
        var whole = drilling
        whole.drilled = 19_200
        XCTAssertTrue(UnitPanel.drillLine(whole, in: session.state)?.hasPrefix("It musters as many as it may lead, 20,400") == true)
        XCTAssertEqual(UnitPanel.troopsLine(whole, in: session.state), "20,400 of 20,400 troops standing")
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
        XCTAssertEqual(RealmPanel.favourLine(keeper), "No favour yet: 0 won; 60 more to I.")
        XCTAssertEqual(RealmPanel.favourProgress(0), 0)
        XCTAssertEqual(RealmPanel.streakLine(keeper),
                       "0 watches kept unbroken: the next brings 10 favour, and a favour chest comes in 10 watches.")
        keeper.favour = 300
        keeper.streak = 9
        XCTAssertEqual(RealmPanel.favourLine(keeper), "Favour II: 300 won; 100 more to III.")
        XCTAssertEqual(RealmPanel.favourProgress(300), Double(300 - 180) / Double(400 - 180), accuracy: 1e-9)
        XCTAssertEqual(RealmPanel.streakLine(keeper), "9 watches kept unbroken: the next brings 28 favour, and a favour chest comes in 1 watch.")
        session.keeper = keeper
        draw(RealmPanel(session: session))
        keeper.favour = 12_000
        keeper.streak = 1
        XCTAssertEqual(RealmPanel.favourLine(keeper), "Favour X: 12000 won, the highest there is.")
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
        XCTAssertEqual(ForgeView.makingsLine(bare.state, me), "Makings: 0 hide, 0 iron, 0 heartwood, 0 moonglass.")
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
        XCTAssertTrue(briefing.facts[1].hasSuffix("take up another from the Realm (6), the first time freely."), briefing.facts[1])
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
        XCTAssertTrue(SeatBriefing.heritageLine(session.state, me).hasSuffix("another costs 30 moonsalt in the Realm (6)."))
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
