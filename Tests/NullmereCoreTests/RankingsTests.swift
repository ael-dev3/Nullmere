import Foundation
import XCTest
@testable import NullmereCore

/// The Rankings, Rise of Kingdoms' boards of power and of kill points: the
/// foes each House has slain counted from its battles with other Houses;
/// every House and every alliance ranked by might or by foes slain, the
/// foremost and the keeper's own beneath them; known to every keeper and
/// kept with the world.
final class RankingsTests: XCTestCase {
    private func field(_ seed: String) throws -> (GameState, me: Int, foe: Int, mine: NullmereCore.Unit, theirs: NullmereCore.Unit) {
        var state = GameState(settings: GameSettings(seedText: seed, houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        let foe = try XCTUnwrap(state.livingHouses.first { $0.id != me }).id
        state.setStance(.war, between: me, and: foe, by: me)
        func open(_ hex: Hex) -> Bool {
            guard let terrain = state.map[hex]?.terrain else { return false }
            return terrain.isPassable && !terrain.isWater && !state.isOccupied(hex) && state.shrine(at: hex) == nil
                && state.holds.allSatisfy { $0.position.distance(to: hex) >= 3 }
        }
        let ground = try XCTUnwrap(state.map.hexes.first { open($0) && $0.neighbors.contains(where: open) }, "Open ground for a field")
        let beside = try XCTUnwrap(ground.neighbors.first(where: open))
        let mine = try XCTUnwrap(state.units(of: me).first { $0.kind == .spear })
        state.units[try XCTUnwrap(state.unitIndex(mine.id))].position = ground
        let theirs = try XCTUnwrap(state.placeUnit(.spear, tier: 1, for: foe, near: beside))
        state.units[try XCTUnwrap(state.unitIndex(theirs.id))].position = beside
        return (state, me, foe, try XCTUnwrap(state.unit(mine.id)), try XCTUnwrap(state.unit(theirs.id)))
    }

    private func battle(_ attacker: Int, on defender: Int, company: Bool = true, slain: Int?, lost: Int?) -> GameEvent {
        .battle(Battle(attacker: 1, attackerOwner: attacker, attackerKind: .spear, defender: company ? 2 : nil, defenderOwner: defender,
                       defenderKind: company ? .bow : nil, hold: company ? nil : 3, at: Hex(0, 0), damageDealt: 10, damageTaken: 4,
                       attackerFell: false, defenderFell: false, slain: slain, lost: lost))
    }

    /// A blow on another House's company counts what it felled to the
    /// striker and what it lost to the company struck; a hold's walls count
    /// those of its strikers they slew; nothing a House does to itself, and
    /// nothing of a blow with one the realm doesn't know as a House.
    func testFoesSlainAreCountedFromTheBattlesBetweenHouses() throws {
        var (state, me, foe, mine, theirs) = try field("foes slain")
        XCTAssertNil(state.foesSlain, "none fallen, none counted")
        XCTAssertEqual(state.slain(by: me), 0)

        // A real blow, through the rules.
        let events = try state.perform(.attack(unit: mine.id, target: theirs.position), as: me)
        let struck = try XCTUnwrap(events.compactMap { event -> Battle? in if case .battle(let b) = event { return b } else { return nil } }.first)
        let felled = try XCTUnwrap(struck.slain), lost = try XCTUnwrap(struck.lost)
        XCTAssertGreaterThan(felled, 0)
        XCTAssertEqual(state.slain(by: me), felled, "the striker's House counts what it felled")
        XCTAssertEqual(state.slain(by: foe), lost, "the House struck counts what it slew of the striker")
        XCTAssertEqual(state.foesSlain?.count, state.houses.count)

        // A hold's walls count what they slew; the striker, nothing.
        let other = try XCTUnwrap(state.livingHouses.first { $0.id != me && $0.id != foe }).id
        var walls = state
        walls.tally([battle(me, on: other, company: false, slain: nil, lost: 700)])
        XCTAssertEqual(walls.slain(by: other), 700)
        XCTAssertEqual(walls.slain(by: me), felled)

        // Nothing a House does to itself, nor any blow with one the realm
        // doesn't know as a House, on either side.
        var odd = state
        odd.tally([battle(me, on: me, slain: 900, lost: 100), battle(-1, on: foe, slain: 50, lost: 60), battle(me, on: 99, slain: 70, lost: 80)])
        XCTAssertEqual(odd.slain(by: me), felled)
        XCTAssertEqual(odd.slain(by: foe), lost)
        XCTAssertEqual(odd.slain(by: -1), 0)
        XCTAssertEqual(odd.slain(by: 99), 0)
    }

    /// Over a stewards' age, the realm's count is every blow between
    /// Houses its watches told of: those the stewards struck as they acted
    /// and those of the watch's turn alike, counted once each.
    func testAnAgesFoesSlainAreEveryBlowBetweenHouses() {
        var state = GameState(settings: GameSettings(seedText: "an age of blows", houseCount: 5, radius: 18))
        var expected = [Int](repeating: 0, count: state.houses.count)
        for _ in 0..<90 {
            for case .battle(let battle) in state.endWatch() where battle.attackerOwner != battle.defenderOwner {
                if battle.defender != nil { expected[battle.attackerOwner] += battle.slain ?? 0 }
                expected[battle.defenderOwner] += battle.lost ?? 0
            }
        }
        XCTAssertGreaterThan(expected.reduce(0, +), 0, "the stewards came to blows")
        XCTAssertEqual(state.houses.indices.map { state.slain(by: $0) }, expected)
    }

    /// Every House by might and by foes slain, those with none left out,
    /// ties to the lower id; the keeper's own beneath the foremost shown;
    /// the alliances by their Houses together; and where the keeper's own
    /// stands, in a line.
    func testTheRankingsRankHousesAndAlliances() throws {
        var state = GameState(settings: GameSettings(seedText: "the rankings", houseCount: 6, radius: 18, keepers: 1))
        let me = state.player
        let might = state.houses.map { state.might(of: $0.id) }
        let ranking = state.ranking(.might, for: me)
        XCTAssertEqual(ranking.lines.map(\.id), state.byMight, "foremost first, as the Houses stand")
        XCTAssertEqual(ranking.lines.map(\.place), Array(1...state.livingHouses.count))
        XCTAssertEqual(ranking.lines.map(\.figure), state.byMight.map { might[$0] })
        XCTAssertEqual(ranking.lines.filter(\.isOwn).map(\.id), [me])
        XCTAssertEqual(ranking.count, state.livingHouses.count)
        XCTAssertNil(ranking.own, "among those shown")
        let place = try XCTUnwrap(state.byMight.firstIndex(of: me)) + 1
        XCTAssertEqual(ranking.place, place)
        XCTAssertEqual(ranking.standing, "Your House stands \(briefOrdinal(place)) of 6 by might.")
        XCTAssertEqual(ranking.title, "Houses by might")
        XCTAssertNil(ranking.lines.first?.note, "sworn to no alliance")
        XCTAssertEqual(ranking.lines.map(\.at), state.byMight.map { state.seat(of: $0)?.position }, "each line leads to its House's seat")

        // Foes slain: only those who slew any, ties to the lower id.
        let (a, b, c) = (state.houses[(me + 1) % 6].id, state.houses[(me + 2) % 6].id, state.houses[(me + 3) % 6].id)
        XCTAssertTrue(state.ranking(.slain, for: me).lines.isEmpty)
        XCTAssertEqual(state.ranking(.slain, for: me).standing, "Your House has slain no foe this age.")
        XCTAssertEqual(state.ranking(.slain, for: me).none, "No House has slain a foe this age.")
        state.foesSlain = [Int](repeating: 0, count: 6)
        state.foesSlain![a] = 4_000
        state.foesSlain![b] = 1_500
        state.foesSlain![c] = 1_500
        state.foesSlain![me] = 300
        let slain = state.ranking(.slain, for: me, most: 2)
        XCTAssertEqual(slain.lines.map(\.id), [a, min(b, c)])
        XCTAssertEqual(slain.lines.map(\.figure), [4_000, 1_500])
        XCTAssertEqual(slain.count, 4)
        XCTAssertEqual(slain.own, RankingLine(id: me, place: 4, name: state.houses[me].title, figure: 300, isOwn: true, note: nil,
                                              at: state.seat(of: me)?.position),
                       "the keeper's own beneath the foremost shown")
        XCTAssertEqual(slain.standing, "Your House stands fourth of 4 by foes slain.")
        XCTAssertEqual(slain.lines[0].said(.slain), "1st, \(state.houses[a].title): 4,000 foes slain")
        XCTAssertEqual(state.rankingsSaid(for: me), "Your House stands \(briefOrdinal(place)) of 6 by might and fourth of 4 by foes slain.")
        var unblooded = state
        unblooded.foesSlain![me] = 0
        XCTAssertEqual(unblooded.rankingsSaid(for: me), "Your House stands \(briefOrdinal(place)) of 6 by might and has slain no foe this age.")
        XCTAssertEqual(state.rankingsSaid(for: -1), "", "a keeper of no House")
        XCTAssertNil(state.ranking(.might, for: -1).standing)

        // The alliances, by their Houses together.
        XCTAssertEqual(state.ranking(.might, alliances: true, for: me).standing, "Your House is sworn to no alliance.")
        _ = try state.perform(.foundAlliance(name: "The Salt Pact"), as: me)
        let pact = try XCTUnwrap(state.alliance(of: me))
        var other = Alliance(id: state.takeID(), name: "the Reed Accord", leader: a, founded: state.watch)
        other.members = [a, b]
        state.alliances = (state.alliances ?? []) + [other]
        let alliances = state.ranking(.slain, alliances: true, for: me)
        XCTAssertEqual(alliances.lines.map(\.id), [other.id, pact.id])
        XCTAssertEqual(alliances.lines.map(\.figure), [5_500, 300])
        XCTAssertEqual(alliances.lines.map(\.name), ["The Reed Accord", "The Salt Pact"])
        XCTAssertEqual(alliances.lines.map(\.note), ["2 Houses", "1 House"])
        XCTAssertEqual(alliances.lines.map(\.isOwn), [false, true])
        XCTAssertEqual(alliances.standing, "Your alliance stands second of 2 by foes slain.")
        XCTAssertEqual(alliances.title, "Alliances by foes slain")
        XCTAssertEqual(alliances.lines.map(\.at), [state.seat(of: a)?.position, state.seat(of: me)?.position],
                       "an alliance's line leads to its leader's seat while it has no hall")
        let hallAt = Hex(2, -1)
        state.halls = [AllianceHall(id: state.takeID(), alliance: pact.id, raisedBy: me, position: hallAt, begun: state.watch)]
        XCTAssertEqual(state.ranking(.slain, alliances: true, for: me).lines.last?.at, hallAt, "and to its hall once it has one")
        let byMight = state.ranking(.might, alliances: true, for: me)
        XCTAssertEqual(Set(byMight.lines.map(\.figure)), [might[a] + might[b], might[me]])
        XCTAssertEqual(state.ranking(.might, for: me).lines.first { $0.id == a }?.note, "of the Reed Accord", "a House's alliance beneath its name")
        // Every ranking, in the Rankings' order.
        XCTAssertEqual(state.rankings(for: me).map(\.title), ["Houses by might", "Houses by foes slain", "Alliances by might", "Alliances by foes slain"])
        XCTAssertEqual(RankedBy.allCases.map(\.said), ["by might", "by foes slain"])
    }

    /// What the Rankings say when the keeper's House is ranked by neither
    /// figure, and when it is sworn to an alliance whose Houses have slain
    /// nothing: the might none, the foes slain alone, and each alliance's line.
    func testTheRankingsSayWhenTheKeeperIsNotRanked() throws {
        var state = GameState(settings: GameSettings(seedText: "unranked", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        state.reputedMight = [Int](repeating: 0, count: state.houses.count)
        XCTAssertEqual(state.ranking(.might, for: me).standing, "Your House has no might to rank.")
        XCTAssertEqual(state.ranking(.might, for: me).none, "No House stands.")
        XCTAssertEqual(state.ranking(.might, alliances: true, for: me).none, "No alliance stands.")
        XCTAssertEqual(state.rankingsSaid(for: me), "Your House is not yet ranked.")
        // Foes slain alone: ranked by them, with no might said.
        state.foesSlain = [Int](repeating: 0, count: state.houses.count)
        state.foesSlain![me] = 50
        XCTAssertEqual(state.rankingsSaid(for: me), "Your House stands first of 1 by foes slain.")
        XCTAssertEqual(state.ranking(.slain, alliances: true, for: me).standing, "Your House is sworn to no alliance.")
        // Sworn to an alliance whose Houses have slain nothing.
        _ = try state.perform(.foundAlliance(name: "The Salt Pact"), as: me)
        state.foesSlain![me] = 0
        XCTAssertEqual(state.ranking(.slain, alliances: true, for: me).standing, "Your alliance's Houses have slain no foe this age.")
        XCTAssertEqual(state.ranking(.slain, alliances: true, for: me).none, "No alliance's Houses have slain a foe this age.")
        XCTAssertEqual(state.ranking(.might, alliances: true, for: me).standing, "Your alliance has no might to rank.")
        XCTAssertEqual(RankingLine(id: 1, place: 2, name: "Orren", figure: 1_240, isOwn: false, note: "of the Salt Pact", at: nil).said(.might),
                       "2nd, Orren, of the Salt Pact: might 1,240")
    }

    /// Known to every keeper as the realm counts them, in the part of the
    /// realm every keeper is told alike, and kept with the world.
    func testTheFoesSlainAreKnownToEveryKeeperAndKept() throws {
        var (state, me, foe, mine, theirs) = try field("foes slain told")
        _ = try state.perform(.attack(unit: mine.id, target: theirs.position), as: me)
        let counted = try XCTUnwrap(state.foesSlain)
        XCTAssertEqual(state.view(for: me).foesSlain, counted)
        XCTAssertEqual(state.view(for: foe).foesSlain, counted, "every keeper alike")
        XCTAssertEqual(state.view(for: foe).ranking(.slain, for: foe).lines.map(\.figure), counted.filter { $0 > 0 }.sorted(by: >))
        let kept = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(kept.foesSlain, counted)
        let old = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(GameState(settings: GameSettings(seedText: "before the count", houseCount: 3))))
        XCTAssertNil(old.foesSlain)

        // In a realm's parts: in the part told alike, out of the head.
        var realm = RealmState(name: "The Nullmere", seed: "slain in parts", seats: 4, radius: 18, watchLength: 600, now: 0)
        _ = try realm.arrive("id-ama", name: "Ama", now: 1)
        realm.world.foesSlain = [1_200, 0, 300, 0]
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let parts = try realm.parts(using: encoder)
        XCTAssertTrue(try XCTUnwrap(parts[GameState.commonPart]).contains("\"foesSlain\":[1200,0,300,0]"))
        XCTAssertFalse(try XCTUnwrap(parts["head"]).contains("foesSlain"))
        XCTAssertEqual(try RealmState(parts: parts).world.foesSlain, [1_200, 0, 300, 0])
        let keeper = try XCTUnwrap(realm.keepers.first)
        let view = try XCTUnwrap(realm.view(for: keeper.id))
        XCTAssertEqual(view.world.foesSlain, [1_200, 0, 300, 0])
        XCTAssertEqual(try RealmView(parts: try view.parts(using: encoder)).world.foesSlain, [1_200, 0, 300, 0])
    }
}
