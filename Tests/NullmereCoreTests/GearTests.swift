import Foundation
import XCTest
@testable import NullmereCore

/// Gear for commanders: each kind of the wilds leaves its own as it falls,
/// finer from the higher levels; a commander wears a weapon, an armour and
/// a charm, each giving the company it leads its edges; the armoury keeps
/// twelve pieces, and a piece is broken up for moonsalt.
final class GearTests: XCTestCase {
    /// A keeper's House with its commander at the head of its Spears.
    private func armed(_ seed: String = "gear") throws -> (GameState, me: Int, commander: Int, spear: Int) {
        var state = Scene.world(seed)
        let me = state.player
        let commander = try XCTUnwrap(state.commanders(of: me).first).id
        let spear = try XCTUnwrap(state.units(of: me).first { $0.kind == .spear })
        state.units[try XCTUnwrap(state.unitIndex(spear.id))].leader = commander
        return (state, me, commander, spear.id)
    }

    /// Gives a House a piece of gear; its id.
    @discardableResult
    private func give(_ kind: GearKind, _ quality: GearQuality, to house: Int, in state: inout GameState) -> Int {
        let piece = Gear(id: state.takeID(), kind: kind, quality: quality, owner: house)
        state.armoury = state.gear + [piece]
        return piece.id
    }

    func testEachKindOfTheWildsLeavesItsOwnFinerFromHigherLevels() {
        XCTAssertEqual(Set(WildKind.allCases.map(GearKind.left(by:))), Set(GearKind.allCases.filter { $0.set == nil }),
                       "Every kind of gear not forged has its wilds")
        let left = GearKind.allCases.filter { $0.set == nil }
        XCTAssertEqual(GearSlot.allCases.map { slot in left.filter { $0.slot == slot }.count }, [2, 2, 1])
        XCTAssertEqual((1...10).map { GearQuality.of(level: $0) },
                       [.plain, .plain, .plain, .fine, .fine, .fine, .masterwork, .masterwork, .masterwork, .fabled])
        XCTAssertTrue(GearQuality.plain < .fabled)
        XCTAssertEqual(GameState.gearChance(level: 1), 26)
        XCTAssertEqual(GameState.gearChance(level: 10), 80)
        let glaive = Gear(id: 1, kind: .saltGlaive, quality: .fine, owner: 0)
        XCTAssertEqual(glaive.title, "Fine Salt Glaive")
        XCTAssertEqual(glaive.edges, [.attack: 6, .hunting: 10], "Each step of quality gives it again")
        XCTAssertEqual(glaive.effect, "+6% attack, +10% against the wilds")
        XCTAssertEqual(Gear(id: 2, kind: .barrowPlate, quality: .plain, owner: 0).effect, "+4% defence, heals 1 more")
        XCTAssertEqual(Gear(id: 3, kind: .drownedMail, quality: .plain, owner: 0).effect, "+3% defence, +5% defence within its walls")
        XCTAssertEqual(Gear(id: 4, kind: .reaverAxe, quality: .plain, owner: 0).effect, "+2% attack, +5% to blows on a ward")
        XCTAssertEqual(Gear(id: 5, kind: .huntersEye, quality: .fabled, owner: 0).effect, "+16% against the wilds, +16% gathered, +16% carried")
        XCTAssertEqual(glaive.scrap, 10)
        XCTAssertEqual(left.map(\.title), ["Salt Glaive", "Reaver's Axe", "Barrowplate", "Drowned Mail", "Hunter's Eye"])
        XCTAssertEqual(GearSlot.allCases.map(\.title), ["Weapon", "Armour", "Charm"])
        XCTAssertEqual(GearQuality.allCases.map(\.title), ["Plain", "Fine", "Masterwork", "Fabled"])
    }

    func testAFallenCompanyOfTheWildsMayLeaveGear() throws {
        // Over many companies of the wilds struck down, about as many leave
        // gear as their levels' chance, each of its own kind and quality;
        // the draw is the wild's own, the same however often it is asked.
        var (state, me, _, spear) = try armed("hunting gear")
        state.wilds = []
        var found = 0
        let tries = 200
        for index in 0..<tries {
            let wild = Wild(id: 10_000 + index, kind: WildKind.allCases[index % 5], level: 5, position: .origin, raised: 1)
            XCTAssertEqual(state.leavesGear(wild), state.leavesGear(wild))
            let events = state.findGear(on: wild, by: me)
            guard case .gearFound(me, let piece, wild.kind)? = events.first else { continue }
            found += 1
            XCTAssertEqual(piece.kind, GearKind.left(by: wild.kind))
            XCTAssertEqual(piece.quality, .fine)
            XCTAssertNil(piece.wornBy)
            if state.gear(of: me).count >= GameState.armouryLimit { state.armoury = [] }
        }
        let expected = tries * GameState.gearChance(level: 5) / 100
        XCTAssertTrue(abs(found - expected) < 25, "\(found) found of an expected \(expected)")

        // In a hunt: a company of the wilds struck down, gear found with it.
        let ground = try XCTUnwrap(state.unit(spear)).position
        var hex = ground + Hex.directions[0]
        if state.map[hex]?.terrain.isPassable != true || state.unit(at: hex) != nil || state.hold(at: hex) != nil {
            hex = try XCTUnwrap(state.freeHex(near: ground))
        }
        state.armoury = []
        var tries2 = 0
        var events: [GameEvent] = []
        while tries2 < 60, !events.contains(where: { if case .gearFound = $0 { return true } else { return false } }) {
            let wild = state.raise(.saltwights, level: 10, at: hex)
            state.wilds![state.wilds!.firstIndex { $0.id == wild }!].health = 1
            let index = try XCTUnwrap(state.unitIndex(spear), "The Spears stand")
            state.units[index].movesLeft = 2
            state.units[index].health = 100
            events = (try? state.perform(.attack(unit: spear, target: hex), as: me)) ?? []
            state.wilds = []
            tries2 += 1
        }
        guard let found = events.compactMap({ event -> Gear? in
            if case .gearFound(_, let piece, _) = event { return piece } else { return nil }
        }).first else { return XCTFail("No gear in sixty hunts at four chances in five") }
        XCTAssertEqual(found.title, "Fabled Salt Glaive")
        XCTAssertEqual(state.gear(of: me).map(\.id), [found.id])
        let found1 = try XCTUnwrap(events.first { if case .gearFound = $0 { return true } else { return false } })
        XCTAssertEqual(state.tidings(of: found1, for: me)?.text, "Among the fallen Saltwights, your company finds a Fabled Salt Glaive.")
        XCTAssertEqual(state.tidings(of: .gearFound(house: me, gear: found, from: .drowned), for: me)?.text,
                       "Among the fallen Drowned, your company finds a Fabled Salt Glaive.")
        XCTAssertNil(state.tidings(of: found1, for: 1))
        XCTAssertEqual(state.events([found1], heardBy: 1), [], "A House's finds are its own")
        XCTAssertEqual(state.problems(), [])
    }

    func testACommanderWearsAPieceInEachSlotAndItsCompanyGainsItsEdges() throws {
        var (state, me, commander, spear) = try armed()
        let unit = try XCTUnwrap(state.unit(spear))
        let attack = state.bonus(.attack(.spear), for: unit)
        let defense = state.bonus(.defense(.spear), for: unit)
        let glaive = give(.saltGlaive, .fine, to: me, in: &state)
        let axe = give(.reaverAxe, .plain, to: me, in: &state)
        let plate = give(.barrowPlate, .masterwork, to: me, in: &state)
        let theirs = give(.huntersEye, .plain, to: 1, in: &state)

        XCTAssertEqual(state.refusal(of: .wear(gear: theirs, commander: commander), as: me), .unknownGear)
        XCTAssertEqual(state.refusal(of: .wear(gear: glaive, commander: 999), as: me), .unknownCommander)
        XCTAssertEqual(state.refusal(of: .takeOff(gear: glaive), as: me), .notWorn)
        XCTAssertEqual(RuleError.unknownGear.description, "Your House holds no such gear.")

        let worn = try state.perform(.wear(gear: glaive, commander: commander), as: me)
        XCTAssertEqual(worn, [.gearWorn(commander: commander, house: me, gear: glaive)])
        XCTAssertEqual(state.tidings(of: worn[0], for: me)?.text, "\(try XCTUnwrap(state.commander(commander)).name) takes up the Fine Salt Glaive.")
        XCTAssertEqual(state.refusal(of: .wear(gear: glaive, commander: commander), as: me), .alreadyWorn)
        try state.perform(.wear(gear: plate, commander: commander), as: me)
        let led = try XCTUnwrap(state.unit(spear))
        XCTAssertEqual(state.bonus(.attack(.spear), for: led), attack + 6)
        XCTAssertEqual(state.bonus(.defense(.spear), for: led), defense + 12)
        XCTAssertEqual(state.edge(.hunting, of: try XCTUnwrap(state.commander(commander))), try XCTUnwrap(state.commander(commander)).edge(.hunting) + 10)

        // The axe in the weapon's slot: the glaive goes back to the armoury.
        try state.perform(.wear(gear: axe, commander: commander), as: me)
        XCTAssertEqual(Set(state.worn(by: commander).map(\.id)), [axe, plate])
        XCTAssertNil(state.gear(glaive)?.wornBy)
        XCTAssertEqual(state.problems(), [])

        let off = try state.perform(.takeOff(gear: plate), as: me)
        XCTAssertEqual(off, [.gearTakenOff(commander: commander, house: me, gear: plate)])
        XCTAssertEqual(state.tidings(of: off[0], for: me)?.text, "\(try XCTUnwrap(state.commander(commander)).name) lays down the Masterwork Barrowplate.")
        XCTAssertEqual(state.worn(by: commander).map(\.id), [axe])

        let moonsalt = state.houses[me].stock.moonsalt
        let broken = try state.perform(.breakUp(gear: axe), as: me)
        XCTAssertEqual(broken, [.gearScrapped(house: me, gear: axe, moonsalt: 5)])
        XCTAssertEqual(state.tidings(of: broken[0], for: me)?.text, "A piece of gear is broken up for 5 moonsalt.")
        XCTAssertEqual(state.houses[me].stock.moonsalt, moonsalt + 5)
        XCTAssertNil(state.gear(axe))
        XCTAssertEqual(state.worn(by: commander), [])
        XCTAssertEqual(state.problems(), [])
    }

    func testAFullArmouryBreaksUpWhatItCantKeep() throws {
        var (state, me, _, _) = try armed("full armoury")
        for _ in 0..<GameState.armouryLimit { give(.huntersEye, .plain, to: me, in: &state) }
        var wild = Wild(id: 0, kind: .barrowkin, level: 10, position: .origin, raised: 1)
        for id in 50_000... where state.leavesGear(Wild(id: id, kind: .barrowkin, level: 10, position: .origin, raised: 1)) {
            wild = Wild(id: id, kind: .barrowkin, level: 10, position: .origin, raised: 1)
            break
        }
        let moonsalt = state.houses[me].stock.moonsalt
        let events = state.findGear(on: wild, by: me)
        XCTAssertEqual(events.count, 2)
        guard case .gearScrapped(me, _, 20)? = events.last else { return XCTFail("Broken up: \(events)") }
        XCTAssertEqual(state.gear(of: me).count, GameState.armouryLimit)
        XCTAssertEqual(state.houses[me].stock.moonsalt, moonsalt + 20)
    }

    func testStewardsArmTheirCommandersWithTheFinest() throws {
        var state = Scene.world("steward gear", houses: 3)
        let steward = 1
        let commander = try XCTUnwrap(state.commanders(of: steward).first).id
        let plain = give(.saltGlaive, .plain, to: steward, in: &state)
        let fine = give(.reaverAxe, .fine, to: steward, in: &state)
        let mail = give(.drownedMail, .plain, to: steward, in: &state)
        let events = state.armCommanders(for: steward)
        XCTAssertEqual(Set(state.worn(by: commander).map(\.id)), [fine, mail])
        XCTAssertNil(state.gear(plain)?.wornBy)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(state.armCommanders(for: steward), [], "Nothing finer to wear")
        let fabled = give(.saltGlaive, .fabled, to: steward, in: &state)
        state.stewardTurn(for: steward)
        XCTAssertEqual(state.gear(fabled)?.wornBy, commander, "In its turn, the finer taken up")
        XCTAssertEqual(state.problems(), [])
    }

    func testGearIsKeptSeenAsItShouldBeAndOlderSavesHaveNone() throws {
        var (state, me, commander, spear) = try armed("kept gear")
        let glaive = give(.saltGlaive, .fine, to: me, in: &state)
        give(.huntersEye, .plain, to: me, in: &state)
        let foreign = give(.drownedMail, .plain, to: 1, in: &state)
        try state.perform(.wear(gear: glaive, commander: commander), as: me)
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state)), state)
        let older = try JSONDecoder().decode(GameState.self, from: try Scene.without(["armoury"], in: state))
        XCTAssertEqual(older.gear, [])

        // Its own gear to a House; of another's, only what a commander in
        // sight at the head of a company wears.
        let mine = state.view(for: me)
        XCTAssertEqual(Set(mine.gear.map(\.id)), Set(state.gear(of: me).map(\.id)))
        XCTAssertNil(mine.gear(foreign))
        let theirs = state.view(for: 1)
        let seen = theirs.unit(spear) != nil
        XCTAssertEqual(theirs.gear.map(\.id), (seen ? [glaive] : []) + [foreign], "Its own, and what a commander in sight wears")

        // And in the realm's parts, a page at a time.
        var realm = RealmState(name: "The Nullmere", seed: "parted gear", seats: 3, radius: 14, now: 0)
        realm.world.armoury = state.gear
        let parts = try realm.parts(using: Scene.encoder)
        XCTAssertNotNil(parts["armoury.0"])
        XCTAssertEqual(try RealmState(parts: parts).world.gear, state.gear)
    }
}
