import Foundation
import XCTest
@testable import NullmereCore

/// Fields of battle, in a realm's watch: a blow between companies at war
/// joins battle there, and the field takes in every company that strikes
/// or is struck near it and its Houses' idle companies standing near; at
/// every pace each strikes a foe within reach, the struck striking back,
/// until a pace passes without a blow or a side is gone from it; then
/// every House that fought in it has its report.
final class FieldTests: XCTestCase {
    /// A realm's world of four Houses, every one kept so no steward stirs,
    /// the first two at war, and open ground well away from every hold.
    private func lake(_ seed: String) throws -> (state: GameState, me: Int, foe: Int, ground: Hex) {
        var state = Scene.world(seed, houses: 4, radius: 18)
        for index in state.houses.indices { state.houses[index].isPlayer = true }
        state.pacing = Pacing()
        let me = state.player, foe = (me + 1) % state.houses.count
        _ = try state.declareWar(by: me, on: foe)
        let ground = try XCTUnwrap(state.map.hexes.first { hex in
            hex.spiral(3).allSatisfy { state.map[$0]?.terrain.isPassable == true && state.isClear($0) && state.wild(at: $0) == nil }
                && hex.spiral(7).allSatisfy { state.hold(at: $0) == nil }
        })
        return (state, me, foe, ground)
    }

    private func blows(_ events: [GameEvent]) -> [Battle] {
        events.compactMap { event in
            if case .battle(let battle) = event { return battle }
            return nil
        }
    }

    private func ended(_ events: [GameEvent]) -> [Field] {
        events.compactMap { event in
            if case .fieldEnded(let field) = event { return field }
            return nil
        }
    }

    /// Walks the watch's paces until the field is over, or the watch is.
    private func fightItOut(_ state: inout GameState) -> [GameEvent] {
        var events: [GameEvent] = []
        for pace in 1..<GameState.pacesPerWatch where !state.fieldsOfBattle.isEmpty {
            events += state.walk(to: pace)
        }
        return events
    }

    func testABattleOfWholeArmiesDrawsInEveryCompanyNear() throws {
        var (state, me, foe, ground) = try lake("whole armies")
        let east = Hex.directions[0], northEast = Hex.directions[1]
        // Three of mine face three of theirs: Spears to Spears, Bows behind,
        // Riders on the flank.
        let spear = state.put(.spear, tier: 2, of: me, at: ground)
        let bow = state.put(.bow, of: me, at: ground - east)
        let rider = state.put(.rider, tier: 3, of: me, at: ground + northEast)
        let theirSpear = state.put(.spear, tier: 2, of: foe, at: ground + east)
        let theirBow = state.put(.bow, of: foe, at: ground + east + east)
        let theirRider = state.put(.rider, of: foe, at: ground + east + northEast)
        // One of theirs on the march through, and a Lantern: neither fights.
        let passing = state.put(.spear, of: foe, at: ground + northEast + northEast)
        state.units[try XCTUnwrap(state.unitIndex(passing))].destination = ground + northEast * 6
        _ = state.put(.lantern, of: me, at: ground - northEast)
        let before = state.army(of: me) + state.army(of: foe) - state.troops(of: try XCTUnwrap(state.unit(passing)))

        let first = try state.perform(.attack(unit: spear, target: ground + east), as: me)
        let field = try XCTUnwrap(state.fieldsOfBattle.first)
        XCTAssertEqual(first.first, .fieldJoined(field: field.id, at: ground + east, first: me, second: foe))
        XCTAssertEqual(blows(first).map(\.field), [field.id], "The first blow is the field's")
        XCTAssertEqual(field.fighters.map(\.unit), [spear, theirSpear])
        XCTAssertTrue(field.fighters[0].sent && !field.fighters[1].sent, "Sent against its foe; the struck only strikes back")
        XCTAssertEqual(field.fighters[1].foe, spear)

        // At the first pace both armies come into it, and every company strikes.
        let pace = state.walk(to: 1)
        let grown = try XCTUnwrap(state.field(field.id) ?? ended(pace).first)
        XCTAssertEqual(Set(grown.fighters.map(\.unit)), [spear, bow, rider, theirSpear, theirBow, theirRider], "Both whole armies, no more")
        XCTAssertEqual(grown.sides, [[me], [foe]])
        let strikers = blows(pace).map(\.attacker)
        XCTAssertEqual(strikers.first.flatMap { state.unit($0)?.kind ?? grown.fighter($0)?.kind }, .bow, "Arrows first")
        XCTAssertTrue(strikers.contains(theirSpear), "The struck strikes back")
        XCTAssertTrue(blows(pace).allSatisfy { $0.field == field.id })
        state.units.removeAll { $0.id == passing }

        let rest = pace + fightItOut(&state)
        let over = try XCTUnwrap(ended(rest).first, "It is fought out within the watch")
        XCTAssertEqual(state.fieldsOfBattle, [])
        XCTAssertEqual(over.fighters.count, 6)
        // What each side slew is what the other lost, blow by blow.
        XCTAssertEqual(over.fighters(of: 0).reduce(0) { $0 + $1.slain }, over.lost(by: 1))
        XCTAssertEqual(over.fighters(of: 1).reduce(0) { $0 + $1.slain }, over.lost(by: 0))
        XCTAssertEqual(over.lost(by: 0) + over.lost(by: 1), before - state.army(of: me) - state.army(of: foe), "Every troop lost counted")
        XCTAssertEqual(over.troops(of: 0), UnitKind.spear.troops(tier: 2) + UnitKind.bow.troops(tier: 1) + UnitKind.rider.troops(tier: 3))
        XCTAssertEqual(over.standing(of: 0), over.troops(of: 0) - over.lost(by: 0))
        XCTAssertGreaterThan(over.paces, 0)
        XCTAssertTrue(over.fighters.allSatisfy { $0.fell == (state.unit($0.unit) == nil) }, "The fallen marked as they fell")
        if let held = over.held {
            XCTAssertTrue(over.fighters(of: held).contains(where: \.standing))
            XCTAssertFalse(over.fighters(of: 1 - held).contains(where: \.standing))
        }
        // A battle of six companies is the chronicle's.
        let told = try XCTUnwrap(state.chronicle.last { $0.kind == .battle })
        XCTAssertTrue(told.text.hasPrefix("The battle \(state.placeName(of: ground + east)): \(state.houses[me].title) against \(state.houses[foe].title), "
                                          + "\(GameState.counted(over.troops(of: 0) + over.troops(of: 1))) troops in all"), told.text)
        XCTAssertEqual(Set(told.houses), [me, foe])

        // Each side's report: the sides, its own companies one by one.
        let mine = try XCTUnwrap(state.report(of: over, id: 7, for: me))
        XCTAssertEqual(mine.sides.map(\.title), ["Your side", "The foe"])
        XCTAssertEqual(mine.sides.map(\.companies), [3, 3])
        XCTAssertEqual(mine.sides[0].troops, over.troops(of: 0))
        XCTAssertEqual(mine.sides[1].lost, over.lost(by: 1))
        XCTAssertEqual(mine.lines.count, 3, "\(mine.lines)")
        XCTAssertTrue(mine.lines[0].hasPrefix("Your Spears II slew "), mine.lines[0])
        XCTAssertTrue(mine.title.hasSuffix(", 3 companies against 3"), mine.title)
        let theirs = try XCTUnwrap(state.report(of: over, id: 8, for: foe))
        XCTAssertEqual(theirs.sides.map(\.troops), [over.troops(of: 1), over.troops(of: 0)])
        XCTAssertNil(state.report(of: over, id: 9, for: (me + 2) % 4), "None for a House that wasn't there")
        XCTAssertEqual(state.problems(), [])
    }

    func testAlliesJoinTheSideTheyStrikeForAndHousesAtWarWithBothCannot() throws {
        var (state, me, foe, ground) = try lake("allied field")
        let ally = (me + 2) % 4, other = (me + 3) % 4
        var sworn = Alliance(id: state.takeID(), name: "The Grey Hand", leader: me, founded: state.watch)
        sworn.members = [me, ally]
        state.alliances = [sworn]
        _ = try state.declareWar(by: ally, on: foe)
        let east = Hex.directions[0]
        let spear = state.put(.spear, of: me, at: ground)
        let theirs = state.put(.spear, of: foe, at: ground + east)
        let allied = state.put(.spear, of: ally, at: ground + east + Hex.directions[1])
        _ = try state.perform(.attack(unit: spear, target: ground + east), as: me)
        // An ally standing near with nothing to do isn't drawn in by another's battle...
        XCTAssertEqual(state.fieldsOfBattle.first?.sides, [[me], [foe]])
        // ...but strikes into it, on the side it fights for.
        let struck = try state.perform(.attack(unit: allied, target: ground + east), as: ally)
        XCTAssertFalse(struck.contains { if case .fieldJoined = $0 { return true } else { return false } }, "The same field")
        let field = try XCTUnwrap(state.fieldsOfBattle.first)
        XCTAssertEqual(state.fieldsOfBattle.count, 1)
        XCTAssertEqual(field.sides, [[me, ally], [foe]])
        XCTAssertEqual(field.fighter(allied)?.side, 0)
        if state.unit(theirs) != nil { XCTAssertEqual(field.fighter(theirs)?.foe, spear, "Still on the one it fights while it can reach it") }

        // A House at war with both sides fits neither: its blow joins battle anew.
        var three = try lake("three ways")
        let a = three.me, b = three.foe
        _ = try three.state.declareWar(by: other, on: a)
        _ = try three.state.declareWar(by: other, on: b)
        let first = three.state.put(.spear, of: a, at: three.ground)
        let target = three.state.put(.spear, tier: 5, of: b, at: three.ground + east)
        let third = three.state.put(.spear, of: other, at: three.ground + east + east)
        _ = try three.state.perform(.attack(unit: first, target: three.ground + east), as: a)
        let joined = try three.state.perform(.attack(unit: third, target: three.ground + east), as: other)
        XCTAssertTrue(joined.contains { if case .fieldJoined(_, _, other, b) = $0 { return true } else { return false } })
        XCTAssertEqual(three.state.fieldsOfBattle.count, 2)
        XCTAssertEqual(three.state.field(of: target)?.sides, [[other], [b]], "Taken into the newer battle, out of the first")
        XCTAssertEqual(three.state.fieldsOfBattle.first?.fighter(target)?.standing, false)
        XCTAssertEqual(three.state.problems(), [])
    }

    func testACompanyStruckStrikesBackIfItCanReachAndHoldsItsGround() throws {
        var (state, me, foe, ground) = try lake("struck back")
        let east = Hex.directions[0], south = Hex.directions[5]
        let bow = state.put(.bow, of: me, at: ground)
        let theirBow = state.put(.bow, of: foe, at: ground + east + east)
        _ = try state.perform(.attack(unit: bow, target: ground + east + east), as: me)
        let back = state.walk(to: 1)
        XCTAssertTrue(blows(back).contains { $0.attacker == theirBow && $0.defender == bow && $0.damageTaken == 0 }, "Arrows answer arrows")

        // A Spear struck from two tiles off can't answer; the Bows shoot on.
        var (far, mine, theirs, open) = try lake("out of reach")
        let archer = far.put(.bow, of: mine, at: open)
        let spear = far.put(.spear, of: theirs, at: open + south + south)
        _ = try far.perform(.attack(unit: archer, target: open + south + south), as: mine)
        let shot = far.walk(to: 1)
        XCTAssertFalse(blows(shot).contains { $0.attacker == spear }, "Nothing in its reach")
        XCTAssertTrue(blows(shot).contains { $0.attacker == archer && $0.defender == spear })
        // Striking back, a company holds its ground: it never steps onto
        // the fallen's. Sent against its foe, it takes it.
        for sent in [false, true] {
            var (held, me3, foe3, at3) = try lake("holds its ground")
            let strong = held.put(.spear, tier: 5, of: foe3, at: at3 + east)
            let weak = held.put(.spear, of: me3, at: at3, health: 1)
            var field = Field(id: held.takeID(), at: at3, joined: held.watch, first: foe3, second: me3)
            field.fighters = [Fighter(unit: strong, owner: foe3, side: 0, kind: .spear, tier: 5, leader: nil, troops: 2_400),
                              Fighter(unit: weak, owner: me3, side: 1, kind: .spear, tier: 1, leader: nil, troops: 12)]
            field.fighters[0].foe = weak
            field.fighters[0].sent = sent
            held.fields = [field]
            let blow = try XCTUnwrap(blows(held.walk(to: 1)).first)
            XCTAssertEqual(blow.attacker, strong)
            XCTAssertTrue(blow.defenderFell)
            XCTAssertNil(held.unit(weak))
            XCTAssertEqual(held.unit(strong)?.position, sent ? at3 : at3 + east, sent ? "Sent, it takes the field" : "It holds its ground")
            XCTAssertEqual(held.problems(), [])
        }
    }

    func testAFieldEndsWhenItsCourseIsRunOrItsFoesAreGone() throws {
        var (state, me, foe, ground) = try lake("long field")
        let east = Hex.directions[0]
        let spear = state.put(.spear, tier: 5, of: me, at: ground)
        let theirs = state.put(.spear, tier: 5, of: foe, at: ground + east)
        _ = try state.perform(.attack(unit: spear, target: ground + east), as: me)
        state.fields![0].paces = Field.longest - 1
        let last = state.walk(to: 1)
        let over = try XCTUnwrap(ended(last).first, "Two watches is the most a field goes on")
        XCTAssertEqual(over.paces, Field.longest)
        XCTAssertEqual(state.fieldsOfBattle, [])
        if state.unit(spear) != nil, state.unit(theirs) != nil { XCTAssertNil(over.held, "Neither gave way") }

        // Peace between them, and no blow falls: it ends.
        var (calm, mine, theirsHouse, open) = try lake("peace made")
        let a = calm.put(.spear, tier: 5, of: mine, at: open)
        _ = calm.put(.spear, tier: 5, of: theirsHouse, at: open + east)
        _ = try calm.perform(.attack(unit: a, target: open + east), as: mine)
        calm.setStance(.peace, between: mine, and: theirsHouse, by: mine)
        let quiet = calm.walk(to: 1)
        XCTAssertTrue(blows(quiet).isEmpty)
        XCTAssertNil(try XCTUnwrap(ended(quiet).first).held, "Both still there")

        // A company lost outside its blows counts as fallen; a House fallen
        // leaves it; and a fighter of a side gone from it ends it.
        var (lost, m, f, g) = try lake("fallen elsewhere")
        let x = lost.put(.spear, tier: 5, of: m, at: g)
        let y = lost.put(.spear, tier: 5, of: f, at: g + east)
        _ = try lost.perform(.attack(unit: x, target: g + east), as: m)
        lost.units.removeAll { $0.id == y }
        let gone = try XCTUnwrap(ended(lost.walk(to: 1)).first)
        XCTAssertEqual(gone.fighter(y)?.fell, true)
        XCTAssertEqual(gone.held, 0)
    }

    func testAFieldIsSeenByThoseInItOrWhoSeeItAndKeptWhole() throws {
        var (state, me, foe, ground) = try lake("fields seen")
        let east = Hex.directions[0]
        let spear = state.put(.spear, tier: 5, of: me, at: ground)
        _ = state.put(.spear, tier: 5, of: foe, at: ground + east)
        let joined = try state.perform(.attack(unit: spear, target: ground + east), as: me)
        let field = try XCTUnwrap(state.fieldsOfBattle.first)
        XCTAssertEqual(state.view(for: me).fieldsOfBattle, [field])
        XCTAssertEqual(state.view(for: foe).fieldsOfBattle, [field])
        let far = try XCTUnwrap(state.houses.indices.first { house in
            house != me && house != foe && !state.visibility(for: house)[state.map.index(of: field.at)!]
        })
        XCTAssertEqual(state.view(for: far).fieldsOfBattle, [], "Out of sight, unknown")
        let opened = try XCTUnwrap(joined.first)
        XCTAssertEqual(state.events([opened], heardBy: me), [opened])
        XCTAssertEqual(state.events([opened], heardBy: far), [])
        XCTAssertEqual(state.tidings(of: opened, for: me)?.text,
                       "Battle is joined \(state.placeName(of: field.at)): your companies fall upon \(state.houses[foe].title)'s.")
        XCTAssertEqual(state.tidings(of: opened, for: foe)?.text,
                       "Battle is joined \(state.placeName(of: field.at)): \(state.houses[me].title) falls upon your companies.")
        XCTAssertEqual(state.tidings(of: opened, for: far)?.text,
                       "Battle is joined \(state.placeName(of: field.at)) between \(state.houses[me].title) and \(state.houses[foe].title).")
        // Kept in saves, and absent from one from before it.
        let kept = try JSONDecoder().decode(GameState.self, from: try JSONEncoder().encode(state))
        XCTAssertEqual(kept, state)
        let older = try JSONDecoder().decode(GameState.self, from: try Scene.without(["fields", "field"], in: state))
        XCTAssertEqual(older.fieldsOfBattle, [])

        // Its end, told to each side and to those who saw it.
        var over = field
        over.fighters[0].slain = 1_800
        over.fighters[0].lost = 600
        over.fighters[1].slain = 600
        over.fighters[1].lost = 1_800
        over.fighters[1].fell = true
        over.fighters[1].standing = false
        over.held = 0
        let end = GameEvent.fieldEnded(over)
        XCTAssertEqual(state.events([end], heardBy: foe), [end])
        XCTAssertEqual(state.events([end], heardBy: far), [])
        let place = state.placeName(of: field.at)
        XCTAssertEqual(state.tidings(of: end, for: me)?.text, "The battle \(place) is over: your side holds the field, slaying 1,800 and losing 600.")
        XCTAssertEqual(state.tidings(of: end, for: foe)?.text, "The battle \(place) is over: your side is driven from the field, slaying 600 and losing 1,800.")
        XCTAssertEqual(state.tidings(of: end, for: far)?.text, "The battle \(place) is over: \(state.houses[me].title)'s side holds the field.")
        over.held = nil
        XCTAssertEqual(state.tidings(of: .fieldEnded(over), for: me)?.text,
                       "The battle \(place) is over: neither side gives way, your side slaying 1,800 and losing 600.")
        XCTAssertEqual(state.tidings(of: .fieldEnded(over), for: far)?.text, "The battle \(place) is over: neither side gives way.")
        let report = try XCTUnwrap(state.report(of: over, id: 1, for: foe))
        XCTAssertEqual(report.outcome, .held)
        XCTAssertEqual(report.title, "Neither side gave way, 1 company against 1")
        XCTAssertEqual(report.lines, ["Your Spears V slew 600, lost 1,800, and fell"])
        over.held = 1
        XCTAssertEqual(state.report(of: over, id: 1, for: foe)?.outcome, .won)
        XCTAssertEqual(state.report(of: over, id: 1, for: me)?.title, "Your side was driven from the field, 1 company against 1")
    }

    func testAReportTellsTheHousesOwnCompaniesAndItsAllies() {
        var field = Field(id: 5, at: Hex(0, 0), joined: 3, first: 0, second: 1)
        field.sides[0].append(2)
        for index in 0..<8 {
            var fighter = Fighter(unit: 100 + index, owner: 0, side: 0, kind: .rider, tier: 3, leader: index == 0 ? "Ilsa Vane" : nil, troops: 1_200)
            fighter.slain = 100 * index
            fighter.standing = index % 2 == 0
            field.fighters.append(fighter)
        }
        var friend = Fighter(unit: 200, owner: 2, side: 0, kind: .lantern, tier: 1, leader: nil, troops: 60)
        friend.slain = 5
        field.fighters.append(friend)
        field.fighters.append(Fighter(unit: 300, owner: 1, side: 1, kind: .bow, tier: 1, leader: nil, troops: 1_000))
        field.held = 0
        XCTAssertEqual(field.inField(0).companies, 5, "Those still in it")
        XCTAssertEqual(field.inField(0).troops, 4 * 1_200 + 60)
        XCTAssertEqual(field.inField(1).troops, 1_000)
        let state = Scene.world("field report", houses: 3)
        let report = state.report(of: field, id: 2, for: 0)!
        XCTAssertEqual(report.outcome, .won)
        XCTAssertEqual(report.title, "Your side held the field, 9 companies against 1")
        XCTAssertEqual(report.lines[0], "Your Riders III, led by Ilsa Vane, slew 0, lost 0, and held")
        XCTAssertEqual(report.lines[1], "Your Riders III slew 100, lost 0, and drew off")
        XCTAssertEqual(report.lines[6], "And 2 more companies of your House")
        XCTAssertEqual(report.lines[7], "Your allies' 1 company slew 5, lost 0")
        XCTAssertEqual(report.sides[0], BattleReport.Side(title: "Your side", houses: 2, companies: 9, troops: 9_660, lost: 0, fallen: 0))
        XCTAssertEqual(report.sides[0].standing, 9_660)
        field.fighters.removeLast(2)
        field.fighters.removeFirst(6)
        XCTAssertEqual(state.report(of: field, id: 3, for: 0)?.lines.last, "Your Riders III slew 700, lost 0, and drew off")
        field.fighters.removeFirst()
        XCTAssertEqual(state.report(of: field, id: 3, for: 0)?.title, "Your side held the field, 1 company against 0")
    }

    func testACompanyInABattleDoesntHealAndOneBackCountsItsHealed() throws {
        var (state, me, foe, ground) = try lake("healed")
        let south = Hex.directions[5]
        let bow = state.put(.bow, tier: 5, of: me, at: ground)
        let spear = state.put(.spear, of: foe, at: ground + south + south)
        _ = try state.perform(.attack(unit: bow, target: ground + south + south), as: me)
        let hurt = try XCTUnwrap(state.unit(spear)).health
        XCTAssertLessThan(hurt, 100)
        XCTAssertNotNil(state.field(of: spear))
        // Struck, and standing in the battle as the watch turns: it doesn't heal.
        var turned = state
        _ = turned.endWatch()
        XCTAssertEqual(turned.unit(spear)?.health, hurt, "No healing in battle")
        // Out of it, it heals as ever.
        var freed = state
        freed.fields = nil
        _ = freed.endWatch()
        XCTAssertGreaterThan(try XCTUnwrap(freed.unit(spear)).health, hurt)

        // A company that drew off and healed, struck again, counts its healed as come.
        let index = try XCTUnwrap(state.fieldsOfBattle.first?.fighters.firstIndex { $0.unit == spear })
        state.fields![0].fighters[index].standing = false
        let was = state.fields![0].fighters[index]
        state.units[try XCTUnwrap(state.unitIndex(spear))].health = 100
        let healed = UnitKind.spear.troops(tier: 1) - (was.troops - was.lost)
        let fresh = state.put(.spear, tier: 5, of: me, at: ground + south)
        let again = try state.perform(.attack(unit: fresh, target: ground + south + south), as: me)
        let blow = try XCTUnwrap(blows(again).first)
        let back = try XCTUnwrap(state.fieldsOfBattle.first?.fighter(spear))
        XCTAssertEqual(back.troops, was.troops + healed)
        XCTAssertEqual(back.lost, was.lost + (blow.slain ?? 0))
        XCTAssertEqual(back.standing, state.unit(spear) != nil)
        XCTAssertEqual(state.problems(), [])
    }

    func testAnUnsoundFieldIsCaught() throws {
        var (state, me, foe, ground) = try lake("unsound fields")
        let east = Hex.directions[0]
        let spear = state.put(.spear, tier: 5, of: me, at: ground)
        _ = state.put(.spear, tier: 5, of: foe, at: ground + east)
        _ = try state.perform(.attack(unit: spear, target: ground + east), as: me)
        XCTAssertEqual(state.problems(), [])
        func caught(_ what: String, _ spoil: (inout GameState) -> Void) {
            var bad = state
            spoil(&bad)
            XCTAssertFalse(bad.problems().isEmpty, what)
        }
        caught("on both sides") { $0.fields![0].sides[1].append(me) }
        caught("one side") { $0.fields![0].sides = [[me]] }
        caught("an empty side") { $0.fields![0].sides[1] = [] }
        caught("a stranger fighting") { $0.fields![0].fighters.append(Fighter(unit: 1, owner: 3, side: 0, kind: .spear, tier: 1, leader: nil, troops: 9)) }
        caught("lost more than it had") { $0.fields![0].fighters[0].lost = 99_999 }
        caught("fallen yet standing") { $0.fields![0].fighters[0].fell = true }
        caught("past its course") { $0.fields![0].paces = Field.longest + 1 }
        caught("off the map") { bad in
            let old = bad.fields![0]
            var moved = Field(id: old.id, at: Hex(500, 500), joined: old.joined, first: me, second: foe)
            moved.fighters = old.fighters
            bad.fields = [moved]
        }
        caught("an id not yet given") { bad in
            var later = Field(id: bad.nextID + 5, at: ground, joined: 0, first: me, second: foe)
            later.fighters = []
            bad.fields!.append(later)
        }
        caught("in two fields") { bad in
            var twice = Field(id: bad.takeID(), at: ground, joined: 0, first: me, second: foe)
            twice.fighters = [bad.fields![0].fighters[0]]
            bad.fields!.append(twice)
        }
    }

    func testAStewardsCompanyGoesToABattleItsHouseFightsNear() throws {
        var (state, me, foe, ground) = try lake("called to battle")
        let east = Hex.directions[0]
        let spear = state.put(.spear, tier: 5, of: foe, at: ground)
        _ = state.put(.spear, tier: 5, of: me, at: ground + east)
        _ = try state.perform(.attack(unit: spear, target: ground + east), as: foe)
        let far = try XCTUnwrap(state.freeHex(near: ground, within: 4...5))
        let called = state.put(.rider, of: foe, at: far)
        let farther = try XCTUnwrap(state.freeHex(near: ground, within: 9...10))
        let away = state.put(.rider, of: foe, at: farther)
        state.houses[foe].isPlayer = false
        _ = state.stewardTurn(for: foe)
        XCTAssertNotEqual(state.unit(called)?.position, far, "Marched to the battle")
        XCTAssertLessThan(try XCTUnwrap(state.unit(called)).position.distance(to: ground + east), far.distance(to: ground + east))
        XCTAssertNotEqual(state.unit(away)?.destination, ground + east, "Too far off to be called")
    }

    func testStewardsFightWholeBattlesThroughAnAge() throws {
        var world = RealmState.world(seed: "fields of the lake", age: 1, seats: 8, radius: 24)
        var fought: [Field] = []
        let started = Date()
        for watch in 1...90 where world.outcome == nil {
            var events: [GameEvent] = []
            for pace in 1..<GameState.pacesPerWatch { events += world.walk(to: pace) }
            events += world.endWatch()
            fought += ended(events)
            if watch % 10 == 0 {
                XCTAssertEqual(world.problems(), [], "At watch \(world.watch)")
            }
        }
        let biggest = try XCTUnwrap(fought.max { $0.fighters.count < $1.fighters.count }, "The stewards' wars come to battle")
        let troops = biggest.troops(of: 0) + biggest.troops(of: 1)
        print("PERF fields: \(fought.count) fought in \(world.watch) watches; the greatest \(biggest.fighters.count) companies, "
              + "\(GameState.counted(troops)) troops, \(biggest.paces) paces; in \(String(format: "%.1f", Date().timeIntervalSince(started))) s")
        XCTAssertGreaterThanOrEqual(biggest.fighters.count, 3, "Battles of more than two companies")
        XCTAssertTrue(fought.allSatisfy { field in
            field.fighters(of: 0).reduce(0) { $0 + $1.slain } == field.lost(by: 1)
                && field.fighters(of: 1).reduce(0) { $0 + $1.slain } == field.lost(by: 0)
        }, "Every field's count holds")
    }
}
