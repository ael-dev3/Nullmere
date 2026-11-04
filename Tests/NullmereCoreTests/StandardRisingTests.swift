import XCTest
@testable import NullmereCore

extension GameState {
    /// Every rising standard stood whole at once, for tests of their land.
    mutating func standStandardsWhole() {
        for index in (standards ?? []).indices { standards![index].built = Standard.raising }
    }
}

/// Standards rise like Rise of Kingdoms' alliance flags: over watches,
/// their land the alliance's only once whole, sooner for allies' hands.
final class StandardRisingTests: XCTestCase {
    func testAStandardRisesOverWatchesAndAlliesHastenIt() throws {
        var state = GameState(settings: GameSettings(seedText: "rising standards", houseCount: 4, radius: 14, keepers: 2))
        let me = state.player
        let ally = (me + 1) % state.houses.count, stranger = (me + 2) % state.houses.count
        state.houses[ally].isPlayer = true
        _ = try state.perform(.foundAlliance(name: "The Rising Banner"), as: me)
        let sworn = try XCTUnwrap(state.alliance(of: me))
        state.alliances![state.alliances!.firstIndex { $0.id == sworn.id }!].members.append(ally)
        for house in [me, ally, stranger] { state.houses[house].stock = Stock(grain: 500, timber: 500, stone: 500, moonsalt: 50) }
        let seat = try XCTUnwrap(state.holds.first { $0.owner == me && $0.isSeat })
        let spot = try XCTUnwrap(seat.position.spiral(4).first {
            (2...3).contains($0.distance(to: seat.position)) && state.refusal(of: .raiseStandard(at: $0), as: me) == nil
        })
        _ = try state.perform(.raiseStandard(at: spot), as: me)
        let id = try XCTUnwrap(state.standard(at: spot)).id
        XCTAssertFalse(try XCTUnwrap(state.standard(id)).isWhole)
        XCTAssertNil(state.allianceLand(at: spot), "no land of the alliance's until it stands")
        XCTAssertTrue(state.allianceBorders().isEmpty)
        // Refused to the raiser, to a stranger; given once by the ally.
        XCTAssertEqual(state.refusal(of: .helpStandard(standard: id), as: me), .standardHelped)
        XCTAssertEqual(state.refusal(of: .helpStandard(standard: id), as: stranger), .notInAlliance)
        XCTAssertEqual(state.refusal(of: .helpStandard(standard: 9_999), as: ally), .noSuchStandard)
        let before = state.houses[ally].stock
        let helped = try state.perform(.helpStandard(standard: id), as: ally)
        XCTAssertTrue(helped.contains(.standardHelped(standard: id, by: ally, at: spot)))
        XCTAssertEqual(state.houses[ally].stock.timber, before.timber - Standard.helpCost.timber)
        XCTAssertEqual(state.standard(id)?.built, 1)
        XCTAssertEqual(state.refusal(of: .helpStandard(standard: id), as: ally), .standardHelped, "once each")
        XCTAssertNotNil(state.tidings(of: .standardHelped(standard: id, by: ally, at: spot), for: me))
        // The watches do the rest: whole after the third.
        var risen: [GameEvent] = []
        for _ in 0..<(Standard.raising - 1) { risen += state.keepStandards() }
        XCTAssertTrue(try XCTUnwrap(state.standard(id)).isWhole)
        XCTAssertEqual(risen.filter { if case .standardRisen = $0 { true } else { false } }.count, 1)
        XCTAssertEqual(state.allianceLand(at: spot), sworn.id, "its land the alliance's once whole")
        XCTAssertFalse(state.allianceBorders().isEmpty)
        XCTAssertEqual(state.refusal(of: .helpStandard(standard: id), as: ally), .standardWhole)
        XCTAssertEqual(state.view(for: ally).standard(id)?.isWhole, true, "the ally knows it, wherever it stands")
        XCTAssertNil(state.view(for: stranger).standard(id).flatMap { _ in state.isExplored(spot, by: stranger) ? nil : 1 }, "a stranger only where explored")
    }

    func testAStandardOfAnOlderSaveStandsWhole() throws {
        let json = #"{"id":1,"alliance":2,"raisedBy":0,"position":{"q":1,"r":0},"ward":60,"raised":3}"#
        let standard = try JSONDecoder().decode(Standard.self, from: Data(json.utf8))
        XCTAssertTrue(standard.isWhole)
        XCTAssertEqual(standard.progress, 1)
    }
}
