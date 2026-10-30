import Foundation
import XCTest
@testable import NullmereCore

/// Heritages: the people of the lake each House comes of, with two
/// strengths and a company of its own at the fifth tier; dealt round the
/// lake as an age begins, and taken up by keepers, the first time freely.
final class HeritageTests: XCTestCase {
    func testEveryHeritageIsDealtItsSeatsRoundTheLake() {
        let state = GameState(settings: GameSettings(seedText: "heritages dealt", houseCount: 12, radius: 36, keepers: 1))
        let dealt = state.houses.map { state.heritage(of: $0.id) }
        for heritage in Heritage.allCases {
            XCTAssertEqual(dealt.filter { $0 == heritage }.count, 2, "\(heritage) has two of the twelve seats")
        }
        let all = Heritage.allCases
        XCTAssertEqual(all.firstIndex(of: dealt[1]), (all.firstIndex(of: dealt[0])! + 1) % all.count, "Round the lake in turn")
        XCTAssertGreaterThan(Set((0..<24).map { Heritage.dealt(seat: 0, seed: UInt64($0)) }).count, 1, "The seed chooses where the round begins")
        XCTAssertEqual(state.heritage(of: 99), Heritage.dealt(seat: 99, seed: state.settings.seed), "Any seat has one")
        XCTAssertEqual(Set(all.map(\.title)).count, all.count)
        XCTAssertEqual(Set(all.map(\.signatureTitle)).count, all.count)
        XCTAssertEqual(Heritage.moundClans.name, "The Mound Clans")
        XCTAssertTrue(all.allSatisfy { $0.strengths.count == 2 && !$0.origin.isEmpty })
        XCTAssertEqual(Set(all.map(\.signature)), [.spear, .bow, .rider], "Every kind of company of war has its heritages' own")
        XCTAssertEqual(state.problems(), [])
    }

    func testEachHeritagesStrengthsChangeTheRules() throws {
        let figures: [(Heritage, Bonus, Int)] = [
            (.saltborn, .yield(.moonsalt), 50), (.saltborn, .wardMending, 50),
            (.fenfolk, .attack(.bow), 10), (.fenfolk, .sight, 1),
            (.blackwood, .yield(.timber), 25), (.blackwood, .attack(.rider), 10),
            (.spinewardens, .yield(.stone), 25), (.spinewardens, .defense(.spear), 10),
            (.moundClans, .commanderExperience, 25), (.moundClans, .studySpeed, 10),
            (.strandfolk, .yield(.grain), 25), (.strandfolk, .gathering, 20),
        ]
        for (heritage, bonus, figure) in figures {
            XCTAssertEqual(heritage.bonus(bonus), figure, "\(heritage) \(bonus)")
            for other in Heritage.allCases where other != heritage {
                XCTAssertEqual(other.bonus(bonus), 0, "\(other) \(bonus)")
            }
        }

        // Each reaches the rules that ask for it.
        var state = Scene.world("heritage strengths", houses: 4, radius: 16)
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        state.omen = nil
        func taking(_ heritage: Heritage) -> GameState {
            var taken = state
            taken.houses[me].heritage = heritage
            return taken
        }
        let plain = taking(.fenfolk).income(of: seat)
        XCTAssertEqual(taking(.strandfolk).income(of: seat).grain, plain.grain * 125 / 100)
        XCTAssertEqual(taking(.blackwood).income(of: seat).timber, plain.timber * 125 / 100)
        XCTAssertEqual(taking(.spinewardens).income(of: seat).stone, plain.stone * 125 / 100)
        XCTAssertEqual(taking(.saltborn).yieldBonuses(for: me), Stock(moonsalt: 50))
        XCTAssertEqual(taking(.saltborn).wardMending(for: me), state.wardMending * 150 / 100)
        XCTAssertEqual(taking(.strandfolk).bonus(.gathering, for: me), 20)
        XCTAssertEqual(taking(.moundClans).bonus(.commanderExperience, for: me), 25)
        XCTAssertEqual(taking(.moundClans).bonus(.studySpeed, for: me), taking(.fenfolk).bonus(.studySpeed, for: me) + 10)
        let bowID = state.put(.bow, of: me, at: try XCTUnwrap(state.freeHex(near: seat.position, within: 2...3)))
        let bow = try XCTUnwrap(state.unit(bowID))
        let spear = try XCTUnwrap(state.units(of: me).first { $0.kind == .spear })
        XCTAssertEqual(taking(.fenfolk).attackPercent(of: bow), taking(.strandfolk).attackPercent(of: bow) * 110 / 100)
        XCTAssertEqual(taking(.fenfolk).sight(of: bow), taking(.strandfolk).sight(of: bow) + 1)
        XCTAssertEqual(taking(.spinewardens).defensePercent(of: spear), taking(.strandfolk).defensePercent(of: spear) * 110 / 100)
        XCTAssertEqual(taking(.spinewardens).attackPercent(of: spear), taking(.strandfolk).attackPercent(of: spear))
    }

    func testAHousesOwnCompanyIsItsHeritagesFifthTier() throws {
        var state = Scene.world("own company", houses: 4, radius: 16)
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        state.houses[me].heritage = .saltborn
        state.houses[1].heritage = .fenfolk
        func company(_ tier: Int, of house: Int, _ ring: ClosedRange<Int>) throws -> NullmereCore.Unit {
            let id = state.put(.spear, tier: tier, of: house, at: try XCTUnwrap(state.freeHex(near: seat.position, within: ring)))
            return try XCTUnwrap(state.unit(id))
        }
        let wardens = try company(5, of: me, 2...2)
        let theirs = try company(5, of: 1, 3...3)
        let lesser = try company(4, of: me, 4...4)
        XCTAssertTrue(state.isSignature(wardens))
        XCTAssertFalse(state.isSignature(theirs), "Not the Fenfolk's own")
        XCTAssertFalse(state.isSignature(lesser), "Only at the fifth tier")
        XCTAssertEqual(state.title(of: wardens), "Salt Wardens")
        XCTAssertEqual(state.title(of: theirs), "Spears")
        let might = NullmereCore.Unit.tierMight[NullmereCore.Unit.tierIndex(5, of: .spear)]
        XCTAssertEqual(state.attackPercent(of: wardens), might * 105 / 100)
        XCTAssertEqual(state.defensePercent(of: wardens), might * 105 / 100)
        XCTAssertEqual(state.attackPercent(of: theirs), might)
        XCTAssertEqual(state.movement(of: wardens), state.movement(of: theirs), "Its own strikes and stands better, no more")
        // The Spinewardens' own stand firmer still: a tenth for their
        // heritage, and a twentieth their own.
        state.houses[me].heritage = .spinewardens
        XCTAssertEqual(state.title(of: wardens), "Spine Guard")
        XCTAssertEqual(state.defensePercent(of: wardens), might * 115 / 100)
    }

    /// A steward that can muster its own company at the fifth tier reaches
    /// for it more often than not.
    func testAStewardMustersItsOwnCompanyMoreOftenThanNot() throws {
        var kinds: [UnitKind] = []
        for round in 0..<12 {
            var state = Scene.world("own company mustered \(round)", houses: 3, radius: 16)
            let steward = 2
            state.watch = 25
            state.houses[steward].heritage = .blackwood
            let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == steward && $0.isSeat })
            state.holds[seat].levels[.musterHall] = 5
            state.houses[steward].research.known = [Study.drill, .ironRanks, .greyCompanies, .moonsteel].map { Learned(study: $0, grade: 1) }
            state.houses[steward].stock = Stock(grain: 3_000, timber: 3_000, stone: 3_000, moonsalt: 300)
            XCTAssertEqual(state.highestTier(of: .rider, at: state.holds[seat], for: steward), 5)
            _ = state.stewardTurn(for: steward)
            if let training = state.holds[seat].training { kinds.append(training.kind) }
        }
        XCTAssertGreaterThanOrEqual(kinds.count, 10, "\(kinds)")
        XCTAssertGreaterThan(kinds.filter { $0 == .rider }.count * 2, kinds.count, "The Blackwood Kin's own are Riders: \(kinds)")
    }

    func testAKeeperTakesUpAHeritageTheFirstTimeFreely() throws {
        var state = Scene.world("heritage taken", houses: 4, radius: 16)
        let me = state.player
        let dealt = state.heritage(of: me)
        XCTAssertThrowsError(try state.perform(.takeHeritage(dealt), as: me)) { XCTAssertEqual($0 as? RuleError, .alreadyOfHeritage) }
        let other = try XCTUnwrap(Heritage.allCases.first { $0 != dealt })
        let before = state.houses[me].stock
        let events = try state.perform(.takeHeritage(other), as: me)
        XCTAssertEqual(events, [.heritageTaken(house: me, heritage: other)])
        XCTAssertEqual(state.houses[me].stock, before, "The first time freely")
        XCTAssertEqual(state.heritage(of: me), other)
        // After that, for moonsalt.
        let third = try XCTUnwrap(Heritage.allCases.first { $0 != dealt && $0 != other })
        state.houses[me].stock[.moonsalt] = 10
        XCTAssertThrowsError(try state.perform(.takeHeritage(third), as: me)) {
            XCTAssertEqual($0 as? RuleError, .shortOf(Stock(moonsalt: 20)))
        }
        state.houses[me].stock[.moonsalt] = 40
        _ = try state.perform(.takeHeritage(third), as: me)
        XCTAssertEqual(state.houses[me].stock[.moonsalt], 10)
        XCTAssertEqual(state.heritage(of: me), third)
        // Known to every House, told, chronicled, and kept in saves.
        XCTAssertEqual(state.events(events, heardBy: 2), events)
        XCTAssertEqual(state.tidings(of: events[0], for: me)?.text,
                       "Your House takes up the ways of \(other.title): \(other.strengths[0]), and \(other.strengths[1]).")
        XCTAssertEqual(state.tidings(of: events[0], for: 2)?.text, "\(state.houses[me].title) takes up the ways of \(other.title).")
        XCTAssertEqual(state.chronicle.last?.text, "\(state.houses[me].title) takes up the ways of \(third.title).")
        XCTAssertEqual(state.view(for: 2).heritage(of: me), third)
        let kept = try JSONDecoder().decode(GameState.self, from: try JSONEncoder().encode(state))
        XCTAssertEqual(kept.heritage(of: me), third)
        XCTAssertEqual(kept.houses[1].heritage, nil, "Dealt, not taken: nothing kept")
        XCTAssertEqual(RuleError.alreadyOfHeritage.description, "Your House is of that heritage already.")
        XCTAssertEqual(state.problems(), [])
    }

    /// A keeper's copy has no seed, so the realm gives it where its rounds
    /// begin: it deals every House the heritage the realm does, and
    /// foretells the happening the realm will raise.
    func testAKeepersCopyDealsAndForetellsAsTheRealmDoes() throws {
        let state = Scene.world("rounds given", houses: 6)
        let view = state.view(for: state.player)
        XCTAssertEqual(view.settings.seedText, "", "The copy has no seed")
        XCTAssertEqual(state.houses.indices.map(view.heritage(of:)), state.houses.indices.map(state.heritage(of:)))
        XCTAssertEqual(view.realmBoard(for: state.player).nextKind, state.realmBoard(for: state.player).nextKind)
        XCTAssertEqual(view.realmBoard(for: state.player).nextKind, Happening.kind(number: 0, seed: state.settings.seed))
        // As sent across the network, and from a copy of a copy.
        let sent = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(view))
        XCTAssertEqual(sent.heritage(of: 4), state.heritage(of: 4))
        XCTAssertEqual(sent.view(for: state.player).heritage(of: 5), state.heritage(of: 5))
        // A save from before the rounds were kept finds them from its seed.
        let older = try JSONDecoder().decode(GameState.self, from: try Scene.without(["dealing"], in: state))
        XCTAssertNil(older.dealing)
        XCTAssertEqual(older.heritage(of: 2), state.heritage(of: 2))
        XCTAssertEqual(older.view(for: 0).heritage(of: 3), state.heritage(of: 3))
        var turned = older
        _ = turned.endWatch()
        XCTAssertEqual(turned.dealing, state.dealing, "Kept from its next watch")
    }
}
