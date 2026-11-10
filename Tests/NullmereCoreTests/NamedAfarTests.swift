import Foundation
import XCTest
@testable import NullmereCore

/// The Houses a keeper's map names over their land from afar, as Rise of
/// Kingdoms' kingdom map names each governor's city: only Houses whose seat
/// the keeper has seen, and still standing; the keeper's own always; placed
/// own first, then the alliance's, then foes at war, then the rest, each the
/// nearest the view's heart first.
final class NamedAfarTests: XCTestCase {
    func testOnlySeatsSeenAreNamedOwnFirstThenAlliesFoesAndTheRestNearestFirst() throws {
        var world = GameState(settings: GameSettings(seedText: "named from afar", houseCount: 6, radius: 18, keepers: 1))
        let me = world.player
        let home = try XCTUnwrap(world.seat(of: me)).position
        let others = world.houses.map(\.id).filter { $0 != me }
        let unseen = others.filter { other in world.seat(of: other).map { !world.isExplored($0.position, by: me) } == true }
        XCTAssertFalse(unseen.isEmpty, "a seat the keeper has yet to see, at the age's start")

        // At first: the keeper's own, and no seat the keeper has not seen.
        let early = world.namedFromAfar(by: me, around: home)
        XCTAssertEqual(early.first, NamedAfar(house: me, seat: home, standing: .own))
        XCTAssertTrue(early.allSatisfy { $0.house == me || world.isExplored($0.seat, by: me) })
        XCTAssertTrue(Set(early.map(\.house)).isDisjoint(with: unseen), "an unseen seat named")

        // Every seat seen; one House allied, one at war, one fallen.
        world.reveal(around: home, range: 60, for: me)
        let seats = Dictionary(uniqueKeysWithValues: others.compactMap { other in world.seat(of: other).map { (other, $0.position) } })
        XCTAssertEqual(seats.count, others.count)
        let bySeat = others.sorted { (seats[$0]!.distance(to: home), $0) < (seats[$1]!.distance(to: home), $1) }
        let ally = bySeat[bySeat.count - 1], foe = bySeat[bySeat.count - 2], fallen = bySeat[0]
        var accord = Alliance(id: 1, name: "the Far Accord", leader: me, founded: world.watch)
        accord.members.append(ally)
        world.alliances = [accord]
        _ = try world.declareWar(by: foe, on: me)
        world.houses[fallen].isEliminated = true

        let named = world.namedFromAfar(by: me, around: home)
        XCTAssertEqual(named.map(\.house).first, me)
        XCTAssertEqual(named.map(\.standing), [.own, .allied, .atWar, .other, .other], "own, the alliance's, at war, the rest")
        XCTAssertEqual(named[1].house, ally, "the ally, though the furthest")
        XCTAssertEqual(named[2].house, foe)
        XCTAssertFalse(named.contains { $0.house == fallen }, "a fallen House is not named")
        // Each at its seat; the rest the nearest the view's heart first.
        for name in named {
            XCTAssertEqual(name.seat, try XCTUnwrap(world.seat(of: name.house)).position)
        }
        let rest = named.filter { $0.standing == .other }
        XCTAssertLessThanOrEqual(rest[0].seat.distance(to: home), rest[1].seat.distance(to: home))
        // From the far side of the lake, the rest come the other way about.
        let far = try XCTUnwrap(world.seat(of: ally)).position
        let fromAfar = world.namedFromAfar(by: me, around: far).filter { $0.standing == .other }
        XCTAssertLessThanOrEqual(fromAfar[0].seat.distance(to: far), fromAfar[1].seat.distance(to: far))
        XCTAssertEqual(Set(fromAfar.map(\.house)), Set(rest.map(\.house)))
    }
}
