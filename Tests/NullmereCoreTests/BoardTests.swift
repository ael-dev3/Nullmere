import Foundation
import XCTest
@testable import NullmereCore

/// The boards a House's screens draw: the Archive's tree, its commanders,
/// the alliances and its side's rallies, and the realm's course. Each
/// agrees with the rules it is drawn from, line for line.
final class BoardTests: XCTestCase {
    private func world(_ seed: String, archive: Int = 4) throws -> (GameState, me: Int, seat: Int) {
        var state = Scene.world(seed, houses: 6, radius: 20)
        let me = state.player
        state.richen(me)
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == me && $0.isSeat })
        state.holds[seat].levels[.archive] = archive
        return (state, me, seat)
    }

    // MARK: The Archive

    func testTheArchivesTreeStandsAsTheRulesSay() throws {
        var (state, me, seat) = try world("archive board")
        func check(_ note: String) {
            let board = state.archiveBoard(for: me)
            XCTAssertEqual(board.shelves.map(\.branch), Branch.allCases, note)
            XCTAssertEqual(board.shelves.flatMap(\.lines).map(\.study), Branch.allCases.flatMap(Study.of), "every study, in the tree's order")
            // What the rules would say with no study under way, for the
            // studies that wait on it or on more than it.
            let pursuit = state.houses[me].research.pursuit
            var free = state
            free.houses[me].research.pursuit = nil
            for line in board.shelves.flatMap(\.lines) {
                let refusal = state.studyRefusal(of: line.study, for: me)
                let unhurried = free.studyRefusal(of: line.study, for: me)
                let named = "\(note): \(line.study)"
                switch line.standing {
                case .open: XCTAssertNil(refusal, named)
                case .short(let lack): XCTAssertEqual(refusal, .shortOf(lack), named)
                case .locked(let why): XCTAssertEqual(unhurried, why, named)
                case .mastered: XCTAssertEqual(unhurried, .studiedFully, named)
                case .underWay(let left):
                    XCTAssertEqual(pursuit?.study, line.study, named)
                    XCTAssertEqual(pursuit?.watchesLeft, left, named)
                case .waiting:
                    XCTAssertNotNil(pursuit, named)
                    XCTAssertNotEqual(pursuit?.study, line.study, named)
                    switch unhurried {
                    case nil, .shortOf?: break
                    default: XCTFail("\(named) waits on more than the study under way: \(String(describing: unhurried))")
                    }
                }
                if let next = line.next {
                    XCTAssertEqual(line.price, state.studyPrice(of: line.study, grade: next, for: me))
                    XCTAssertEqual(line.watches, state.studyWatches(of: line.study, grade: next, for: me))
                } else {
                    XCTAssertNil(line.price)
                    XCTAssertNil(line.watches)
                }
            }
        }
        check("rich, with an Archive IV")
        XCTAssertEqual(state.archiveBoard(for: me).line(.furrowLore)?.standing, .open)
        XCTAssertEqual(state.archiveBoard(for: me).line(.ladenCarts)?.standing, .locked(.needsStudy(.gleaning, 2)))

        // A study under way: it counts down, and the rest wait on it.
        _ = try state.perform(.study(.furrowLore), as: me)
        check("a study under way")
        let pursued = try XCTUnwrap(state.houses[me].research.pursuit)
        XCTAssertEqual(state.archiveBoard(for: me).line(.furrowLore)?.standing, .underWay(watchesLeft: pursued.watchesLeft))
        XCTAssertEqual(state.archiveBoard(for: me).line(.woodcraft)?.standing, .waiting)
        XCTAssertEqual(state.archiveBoard(for: me).pursuit, pursued)

        // Learned to its last grade, a study is mastered; the grades are counted.
        state.houses[me].research = Research(known: [Learned(study: .drill, grade: 1), Learned(study: .furrowLore, grade: 2)])
        check("some learned")
        let board = state.archiveBoard(for: me)
        XCTAssertEqual(board.line(.drill)?.standing, .mastered)
        XCTAssertEqual(board.line(.furrowLore)?.grade, 2)
        XCTAssertEqual(board.line(.furrowLore)?.next, 3)
        XCTAssertEqual(board.learned, 3)
        XCTAssertEqual(ArchiveBoard.gradesInAll, Study.allCases.reduce(0) { $0 + $1.grades })

        // A smaller Archive keeps its higher circles shut; poverty shows what is lacking.
        state.holds[seat].levels[.archive] = 1
        state.houses[me].stock = Stock(grain: 5)
        check("poor, with an Archive I")
        XCTAssertEqual(state.archiveBoard(for: me).line(.saltRaking)?.standing, .locked(.needsArchive(2)))
        guard case .short(let lack)? = state.archiveBoard(for: me).line(.woodcraft)?.standing else {
            return XCTFail("short of stores")
        }
        XCTAssertGreaterThan(lack.timber, 0)
        XCTAssertEqual(state.archiveBoard(for: 99).line(.drill)?.standing, .locked(.needsArchive(1)), "no House, no Archive")
    }

    // MARK: Commanders

    func testTheCommandersBoardShowsLevelsSkillsAndWhoLeads() throws {
        var (state, me, _) = try world("commanders board")
        var random = SeededRandom(seed: 77)
        state.raiseCommander(for: me, archetype: .vanguard, using: &random)
        state.raiseCommander(for: me, archetype: .warden, using: &random)
        let ids = state.commanders(of: me).map(\.id)
        XCTAssertEqual(ids.count, 3)
        var board = state.commandersBoard(for: me)
        XCTAssertEqual(board.lines.map(\.commander.id), ids, "all free, in the order they came")
        XCTAssertEqual(board.limit, GameState.rosterLimit)
        XCTAssertTrue(board.lines.allSatisfy { $0.leads == nil && $0.woundedFor == nil && !$0.furyReady })
        XCTAssertEqual(board.lines[0].skills.map(\.skill), board.lines[0].commander.archetype.skills)
        XCTAssertEqual(board.lines[0].skills.filter(\.isKnown).count, 1, "a new commander knows its first skill")

        // One leads a company, one is risen, one is wounded.
        let company = try XCTUnwrap(state.units(of: me).first { $0.kind.isMilitary })
        _ = try state.perform(.assign(commander: ids[0], unit: company.id), as: me)
        let risen = try XCTUnwrap(state.commanderIndex(ids[1]))
        state.commanders![risen].experience = Commander.experience(forLevel: 10) + 40
        let hurt = try XCTUnwrap(state.commanderIndex(ids[2]))
        state.commanders![hurt].woundedUntil = state.watch + 3
        board = state.commandersBoard(for: me)
        XCTAssertEqual(board.lines.map(\.commander.id), [ids[1], ids[0], ids[2]], "free, leading, then wounded")
        XCTAssertEqual(board.line(ids[0])?.leads?.id, company.id)
        XCTAssertEqual(board.line(ids[2])?.woundedFor, 3)
        let line = try XCTUnwrap(board.line(ids[1]))
        XCTAssertEqual(line.level, 10)
        XCTAssertEqual(line.progress, 40)
        XCTAssertEqual(line.span, Commander.experience(forLevel: 11) - Commander.experience(forLevel: 10))
        XCTAssertEqual(line.skills.filter(\.isKnown).count, 3, "skills at levels I, V and X")

        // Its fury risen, the leader's skill fires next battle; at the highest level there is no next.
        state.commanders![try XCTUnwrap(state.commanderIndex(ids[0]))].experience = Commander.experience(forLevel: Commander.highestLevel)
        state.commanders![try XCTUnwrap(state.commanderIndex(ids[0]))].fury = 5
        XCTAssertTrue(try XCTUnwrap(state.commandersBoard(for: me).line(ids[0])).furyReady)
        XCTAssertNil(try XCTUnwrap(state.commandersBoard(for: me).line(ids[0])).span)
        XCTAssertNil(board.line(-1))
    }

    // MARK: Alliances

    func testTheAlliancesBoardShowsFellowsAnswersAndWhoMayBeAsked() throws {
        // Two keepers, for a keeper's invitations and requests wait on their
        // answer, where a steward's are answered at once.
        var (state, me, _) = try world("alliance board")
        let (one, two, three, four) = ((me + 1) % 6, (me + 2) % 6, (me + 3) % 6, (me + 4) % 6)
        state.houses[one].isPlayer = true
        var board = state.allianceBoard(for: me)
        XCTAssertNil(board.alliance)
        XCTAssertTrue(board.members.isEmpty && board.invitable.isEmpty && board.asking.isEmpty && board.rallies.isEmpty)
        XCTAssertEqual(board.limit, state.allianceLimit)

        // Another raises a banner: the keeper may ask to join it.
        _ = try state.perform(.foundAlliance(name: "The Salt Oath"), as: three)
        board = state.allianceBoard(for: me)
        XCTAssertEqual(board.others.map(\.alliance.name), ["The Salt Oath"])
        XCTAssertNil(try XCTUnwrap(board.others.first).refusal)

        // The keeper raises its own: it leads, and may invite those at peace.
        _ = try state.perform(.foundAlliance(name: "The Grey Hand"), as: me)
        board = state.allianceBoard(for: me)
        let banner = try XCTUnwrap(board.alliance)
        XCTAssertEqual(banner.name, "The Grey Hand")
        XCTAssertTrue(board.isLeader)
        XCTAssertEqual(board.members.map(\.house), [me])
        XCTAssertEqual(board.others.first?.refusal, .inAnAlliance, "sworn, it can't ask another")
        XCTAssertFalse(board.invitable.contains(me))
        XCTAssertFalse(board.invitable.contains(three), "sworn elsewhere")
        XCTAssertTrue(board.invitable.contains(one))
        _ = try state.declareWar(by: me, on: two)
        XCTAssertFalse(state.allianceBoard(for: me).invitable.contains(two), "not those at war with it")

        // A House asks: its leader sees it, and the House sees it has asked.
        _ = try state.perform(.askToJoin(alliance: banner.id), as: four)
        XCTAssertEqual(state.allianceBoard(for: me).asking, [four], "its leader sees who asks")
        XCTAssertEqual(state.allianceBoard(for: four).others.first { $0.alliance.id == banner.id }?.refusal, .alreadyAsked)
        _ = try state.perform(.answerRequest(house: four, accept: false), as: me)
        XCTAssertTrue(state.allianceBoard(for: me).asking.isEmpty)

        // Invited, a House sees the invitation; joined, it is a fellow the keeper may help.
        _ = try state.perform(.inviteToAlliance(house: one), as: me)
        XCTAssertFalse(state.allianceBoard(for: me).invitable.contains(one), "invited already")
        XCTAssertEqual(state.allianceBoard(for: one).invitations.map(\.name), ["The Grey Hand"])
        _ = try state.perform(.answerInvitation(alliance: banner.id, accept: true), as: one)
        let seatOfOne = try XCTUnwrap(state.holds.firstIndex { $0.owner == one && $0.isSeat })
        state.holds[seatOfOne].project = Hold.Project(kind: .granary, targetLevel: 1, watchesLeft: 3)
        board = state.allianceBoard(for: me)
        XCTAssertEqual(board.members.map(\.house), [me, one])
        XCTAssertEqual(board.members.map(\.isLeader), [true, false])
        let fellow = try XCTUnwrap(board.members.last)
        XCTAssertEqual(fellow.helpable, state.helpable(by: me, for: one))
        XCTAssertGreaterThan(fellow.helpable, 0)
        XCTAssertEqual(fellow.might, state.might(of: one))
        XCTAssertFalse(state.allianceBoard(for: one).isLeader)
        XCTAssertTrue(state.allianceBoard(for: one).asking.isEmpty, "only the leader answers")

        // A rally of the keeper's side: when it sets out, and how full it is.
        let seat = try XCTUnwrap(state.seat(of: me))
        let mine = try XCTUnwrap(state.holds.firstIndex { $0.id == seat.id })
        state.holds[mine].levels[.musterHall] = 2
        let target = try XCTUnwrap(state.holds.first { $0.owner == two })
        state.reveal(around: target.position, range: 1, for: me)
        _ = try state.perform(.callRally(from: seat.id, against: target.id, watches: 3), as: me)
        let rally = try XCTUnwrap(state.allianceBoard(for: me).rallies.first)
        XCTAssertEqual(rally.watchesLeft, 3)
        XCTAssertEqual(rally.companies, 0)
        XCTAssertEqual(rally.capacity, Rally.capacity(musterHall: 2))
        XCTAssertTrue(rally.isCaller)
        XCTAssertEqual(state.allianceBoard(for: one).rallies.map(\.isCaller), [false], "its fellows see it too")
        XCTAssertTrue(state.allianceBoard(for: four).rallies.isEmpty, "others don't")
    }

    // MARK: The realm's course

    func testTheRealmsBoardShowsTheHappeningChargesDeedsAndMight() throws {
        var (state, me, _) = try world("realm board")
        let (two, four) = ((me + 2) % 6, (me + 4) % 6)
        state.watch = 3
        var board = state.realmBoard(for: me)
        XCTAssertNil(board.happening)
        XCTAssertEqual(board.nextBegins, Happening.first)
        XCTAssertEqual(board.nextKind, Happening.kind(number: 0, seed: state.settings.seed))
        XCTAssertEqual(board.charge, .raiseGranary)
        XCTAssertEqual(board.chargesKept, 0)
        XCTAssertEqual(board.deeds, [])
        XCTAssertEqual(board.deedsLeft, Deed.allCases)
        XCTAssertEqual(board.might, state.might(of: me))
        XCTAssertEqual(board.mightPlace, state.byMight.firstIndex(of: me).map { $0 + 1 })
        XCTAssertEqual(board.points, 0)
        XCTAssertNil(board.place)
        XCTAssertEqual(board.nextMark, Happening.marks[0])

        // Between happenings, the next is due at its course's next turn.
        state.watch = Happening.first + 4
        XCTAssertEqual(state.nextHappeningWatch, Happening.first + Happening.every)
        state.watch = Happening.first
        XCTAssertEqual(state.nextHappeningWatch, Happening.first + Happening.every)

        // A happening under way: points, marks, the foremost and the keeper's place.
        var happening = Happening(number: 0, kind: .longHunt, begins: state.watch, houses: state.houses.count)
        happening.points[me] = 30
        happening.passed[me] = 2
        happening.points[two] = 45
        happening.points[four] = 5
        state.happening = happening
        board = state.realmBoard(for: me)
        XCTAssertEqual(board.happening?.kind, .longHunt)
        XCTAssertNil(board.nextBegins)
        XCTAssertNil(board.nextKind)
        XCTAssertEqual(board.points, 30)
        XCTAssertEqual(board.marksPassed, 2)
        XCTAssertEqual(board.nextMark, Happening.marks[2])
        XCTAssertEqual(board.foremost, [Placing(house: two, points: 45), Placing(house: me, points: 30), Placing(house: four, points: 5)])
        XCTAssertEqual(board.place, 2)
        happening.passed[me] = Happening.marks.count
        state.happening = happening
        XCTAssertNil(state.realmBoard(for: me).nextMark, "every mark passed")
        XCTAssertEqual(state.realmBoard(for: 99).points, 0, "no House, no points")

        // Charges kept, and deeds done.
        state.chargesDone = Array(repeating: 0, count: state.houses.count)
        state.chargesDone![me] = 3
        state.deedsDone = [DeedDone(house: me, deed: .wildbane, watch: 2, told: true), DeedDone(house: two, deed: .founder, watch: 2, told: true)]
        board = state.realmBoard(for: me)
        XCTAssertEqual(board.charge, Charge(rawValue: 3))
        XCTAssertEqual(board.chargesKept, 3)
        XCTAssertEqual(board.deeds, [.wildbane])
        XCTAssertEqual(board.deedsLeft.count, Deed.allCases.count - 1)
        state.chargesDone![me] = Charge.allCases.count
        XCTAssertNil(state.realmBoard(for: me).charge)
        XCTAssertEqual(state.realmBoard(for: me).chargesKept, Charge.allCases.count)
    }
}
