import Foundation
import XCTest
@testable import NullmereCore

/// What an alliance keeps of its own: coffers its land fills each watch and
/// that pay first for what its Houses raise for it; a storehouse where its
/// Houses lay up their stores out of any taker's reach; and yards its
/// companies alone work, tithing to the coffers.
final class AllianceStoresTests: XCTestCase {
    private struct Stage {
        var state: GameState
        let me: Int
        let ally: Int
        let alliance: Int
        let seat: Hold
        /// The alliance's standard, near the keeper's seat.
        let flag: Hex
        /// Open ground on the alliance's land.
        let spot: Hex
    }

    private func staged(_ seed: String = "alliance stores") throws -> Stage {
        var state = Scene.world(seed, houses: 4, radius: 18)
        let me = state.player, ally = 1
        _ = try state.perform(.foundAlliance(name: "The Stone Accord"), as: me)
        state.houses[ally].isPlayer = true
        let alliance = try XCTUnwrap(state.alliance(of: me)).id
        _ = try state.perform(.inviteToAlliance(house: ally), as: me)
        _ = try state.perform(.answerInvitation(alliance: alliance, accept: true), as: ally)
        state.houses[me].stock = Stock(grain: 900, timber: 900, stone: 900, moonsalt: 90)
        let seat = try XCTUnwrap(state.seat(of: me))
        state.reveal(around: seat.position, range: 7, for: me)
        let flag = try XCTUnwrap(seat.position.spiral(3).first { hex in
            (2...3).contains(hex.distance(to: seat.position)) && state.refusal(of: .raiseStandard(at: hex), as: me) == nil
        })
        _ = try state.perform(.raiseStandard(at: flag), as: me)
        let spot = try XCTUnwrap(flag.spiral(Standard.reach).first { state.storehouseRefusal(at: $0, by: me) == nil })
        return Stage(state: state, me: me, ally: ally, alliance: alliance, seat: seat, flag: flag, spot: spot)
    }

    private func raisedStorehouse(_ stage: inout Stage, whole: Bool = true) throws -> Storehouse {
        _ = try stage.state.perform(.raiseStorehouse(at: stage.spot), as: stage.me)
        if whole {
            for _ in 0..<Storehouse.raising { _ = stage.state.keepAllianceStores() }
        }
        return try XCTUnwrap(stage.state.storehouse(at: stage.spot))
    }

    // MARK: The coffers

    func testTheCoffersFillFromTheLandAndPayFirstForTheAlliancesWorks() throws {
        var stage = try staged()
        let me = stage.me, id = stage.alliance
        XCTAssertEqual(stage.state.alliance(id)?.stores, .zero, "Empty at first")
        XCTAssertNil(stage.state.alliance(id)?.coffers)
        XCTAssertEqual(stage.state.coffersYield(of: id), Standard.yield, "Its one standard's land")
        _ = stage.state.keepAllianceStores()
        XCTAssertEqual(stage.state.alliance(id)?.stores, Standard.yield)
        // Its hall, whole, yields more.
        let hallAt = try XCTUnwrap(stage.flag.spiral(Standard.reach).first { stage.state.hallRefusal(at: $0, by: me) == nil })
        _ = try stage.state.perform(.raiseAllianceHall(at: hallAt), as: me)
        XCTAssertEqual(stage.state.coffersYield(of: id), Standard.yield, "Not while it rises")
        stage.state.halls![0].built = AllianceHall.raising
        XCTAssertEqual(stage.state.coffersYield(of: id), Standard.yield + AllianceHall.yield)
        // They keep so much and no more.
        stage.state.fill(coffersOf: id, with: Alliance.coffersKept * 2)
        XCTAssertEqual(stage.state.alliance(id)?.stores, Alliance.coffersKept)
        stage.state.fill(coffersOf: 9_999, with: Standard.yield)
        XCTAssertEqual(stage.state.problems(), [])

        // A standard raised draws on the coffers first, its House the rest.
        var paying = try staged("coffers paying")
        let alliance = paying.alliance
        paying.state.fill(coffersOf: alliance, with: Stock(timber: 30, moonsalt: 5))
        XCTAssertEqual(paying.state.purse(of: me), paying.state.houses[me].stock + Stock(timber: 30, moonsalt: 5))
        XCTAssertEqual(paying.state.purse(of: 3), paying.state.houses[3].stock, "A House of no alliance has its own stores alone")
        let before = paying.state.houses[me].stock
        let second = try XCTUnwrap(paying.seat.position.spiral(4).first { paying.state.standardRefusal(at: $0, by: me) == nil })
        _ = try paying.state.perform(.raiseStandard(at: second), as: me)
        XCTAssertEqual(paying.state.alliance(alliance)?.stores, Stock(moonsalt: 3), "The coffers' timber and moonsalt went first")
        XCTAssertEqual(before.timber - paying.state.houses[me].stock.timber, Standard.cost.timber - 30)
        XCTAssertEqual(before.stone - paying.state.houses[me].stock.stone, Standard.cost.stone)
        XCTAssertEqual(before.moonsalt, paying.state.houses[me].stock.moonsalt, "None of the House's moonsalt")
        // With its stores spent, the coffers still raise what they cover.
        paying.state.houses[me].stock = .zero
        let lacking = Stock(timber: Standard.cost.timber, stone: Standard.cost.stone)
        let third = try XCTUnwrap(paying.seat.position.spiral(4).first { hex in
            !paying.state.isOccupied(hex) && paying.state.standardRefusal(at: hex, by: me) == .shortOf(lacking)
        })
        paying.state.fill(coffersOf: alliance, with: Standard.cost)
        XCTAssertNil(paying.state.standardRefusal(at: third, by: me))
        // What the coffers hold is the alliance's own to know.
        XCTAssertEqual(paying.state.view(for: paying.ally).alliance(alliance)?.coffers, paying.state.alliance(alliance)?.coffers)
        XCTAssertNil(paying.state.view(for: 3).alliance(alliance)?.coffers)
        // Coffers out of true are found.
        paying.state.alliances![0].coffers = Stock(grain: -1)
        XCTAssertEqual(paying.state.problems(), ["The coffers of The Stone Accord hold -1 grain"])
    }

    // MARK: The storehouse

    func testAStorehouseIsRaisedOnTheAlliancesLandAndRisesOverTwoWatches() throws {
        var stage = try staged()
        let me = stage.me, at = stage.spot
        let before = stage.state.houses[me].stock
        let events = try stage.state.perform(.raiseStorehouse(at: at), as: me)
        let storehouse = try XCTUnwrap(stage.state.storehouse(at: at))
        XCTAssertEqual(events, [.storehouseRaised(storehouse: storehouse.id, alliance: stage.alliance, house: me, at: at)])
        XCTAssertEqual(stage.state.houses[me].stock + Storehouse.cost, before, "For the leader's stores, the coffers being empty")
        XCTAssertEqual(storehouse.ward, Storehouse.maximumWard)
        XCTAssertEqual(storehouse.progress, 0)
        XCTAssertFalse(storehouse.isWhole)
        XCTAssertEqual(stage.state.storehouse(of: stage.alliance), storehouse)
        XCTAssertEqual(stage.state.storehouse(storehouse.id), storehouse)
        XCTAssertNil(stage.state.storehouse(storehouse.id + 1_000))
        XCTAssertTrue(stage.state.isOccupied(at), "Nothing else rises on it")
        XCTAssertNil(stage.state.wholeStorehouse(for: me))
        XCTAssertEqual(stage.state.refusal(of: .layUp(Stock(grain: 10)), as: me), .noStorehouse, "Nothing is laid up while it rises")
        var risen: [GameEvent] = []
        for _ in 0..<Storehouse.raising { risen += stage.state.keepAllianceStores() }
        XCTAssertEqual(risen, [.storehouseRisen(storehouse: storehouse.id, alliance: stage.alliance, at: at)])
        XCTAssertEqual(stage.state.wholeStorehouse(for: stage.ally)?.id, storehouse.id)
        XCTAssertEqual(stage.state.storehouse(at: at)?.progress, 1)
        XCTAssertNil(stage.state.wholeStorehouse(for: 3), "Of no alliance")
        let place = stage.state.placeName(of: at), title = stage.state.houses[me].title
        XCTAssertTrue(stage.state.chronicle.contains { $0.text == "\(title) begins the storehouse of The Stone Accord \(place)." })
        XCTAssertTrue(stage.state.chronicle.contains { $0.text == "The storehouse of The Stone Accord stands whole \(place)." })
        XCTAssertEqual(stage.state.tidings(of: events[0], for: me)?.text, "You begin the storehouse of The Stone Accord \(place): it rises over 2 watches.")
        XCTAssertEqual(stage.state.tidings(of: events[0], for: stage.ally)?.text,
                       "\(title) begins your alliance's storehouse \(place): it rises over 2 watches.")
        XCTAssertEqual(stage.state.tidings(of: events[0], for: 2)?.text, "\(title) begins a storehouse of The Stone Accord \(place).")
        XCTAssertEqual(stage.state.tidings(of: risen[0], for: stage.ally)?.text,
                       "Your alliance's storehouse stands whole \(place): lay up your stores there, out of any taker's reach.")
        XCTAssertEqual(stage.state.tidings(of: risen[0], for: 2)?.text, "The storehouse of The Stone Accord stands whole \(place).")
        // Told still, once its alliance is gone, to those it concerns.
        XCTAssertEqual(stage.state.tidings(of: .storehouseRisen(storehouse: storehouse.id, alliance: 9_999, at: at), for: me)?.text,
                       "The storehouse of a fallen alliance stands whole \(place).")
        XCTAssertEqual(stage.state.tidings(of: .storehouseRaised(storehouse: storehouse.id, alliance: 9_999, house: me, at: at), for: me)?.text,
                       "You begin the storehouse of a fallen alliance \(place): it rises over 2 watches.")
        XCTAssertNil(stage.state.tidings(of: .storehouseRaised(storehouse: storehouse.id, alliance: 9_999, house: 99, at: at), for: me))
        XCTAssertEqual(stage.state.tidings(of: .storehouseStruck(storehouse: storehouse.id, alliance: 9_999, ward: 5, by: 2, at: at), for: 2)?.text,
                       "Your company strikes the storehouse of a fallen alliance: its ward 5 of 120.")
        XCTAssertNil(stage.state.tidings(of: .storehouseStruck(storehouse: storehouse.id, alliance: 9_999, ward: 5, by: 2, at: at), for: me))
        XCTAssertNil(stage.state.tidings(of: .storehouseStruck(storehouse: storehouse.id, alliance: 9_999, ward: 5, by: 99, at: at), for: me))
        XCTAssertEqual(stage.state.problems(), [])
    }

    func testAStorehouseIsRaisedOnlyWhereItMay() throws {
        var stage = try staged("storehouses refused")
        let me = stage.me
        func refused(_ hex: Hex, as house: Int? = nil, in state: GameState? = nil) -> RuleError? {
            (state ?? stage.state).refusal(of: .raiseStorehouse(at: hex), as: house ?? me)
        }
        XCTAssertNil(refused(stage.spot))
        XCTAssertEqual(refused(stage.spot, as: 3), .notInAlliance)
        XCTAssertEqual(refused(stage.spot, as: stage.ally), .notAllianceLeader, "Its leader raises it")
        XCTAssertEqual(refused(stage.flag), .openGroundOnly, "Not on its standard")
        XCTAssertEqual(refused(Hex(900, 0)), .outsideTheWorld)
        let off = try XCTUnwrap(stage.state.map.hexes.first { hex in
            stage.state.isExplored(hex, by: me) && stage.state.allianceLand(at: hex) == nil
                && stage.state.map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true
                && !stage.state.isOccupied(hex) && stage.state.site(at: hex) == nil && stage.state.shrine(at: hex) == nil
        })
        XCTAssertEqual(refused(off), .notAllianceLand)
        let water = try XCTUnwrap(stage.state.map.hexes.first { hex in
            stage.state.isExplored(hex, by: me) && stage.state.map[hex].map { !$0.terrain.isPassable || $0.terrain.isWater } == true
        })
        XCTAssertNotNil(refused(water))
        let unknown = try XCTUnwrap(stage.state.map.hexes.first { !stage.state.isExplored($0, by: me) })
        XCTAssertEqual(refused(unknown), .unexplored)
        // Too near another House's hold, it is theirs.
        var crowded = stage.state
        let near = try XCTUnwrap(stage.spot.ring(Storehouse.fromOthers).first { crowded.map[$0] != nil && crowded.hold(at: $0) == nil })
        crowded.holds.append(Hold(id: crowded.takeID(), name: "Elsewhere", owner: 3, position: near, isSeat: false, foundedWatch: 0))
        XCTAssertEqual(refused(stage.spot, in: crowded), .foreignTerritory)
        var poor = stage.state
        poor.houses[me].stock = .zero
        XCTAssertEqual(refused(stage.spot, in: poor), .shortOf(Storehouse.cost))
        _ = try raisedStorehouse(&stage, whole: false)
        XCTAssertEqual(refused(stage.flag), .storehouseStanding, "One at a time")
        XCTAssertEqual(RuleError.storehouseStanding.description,
                       "Your alliance has its storehouse already: it raises one, and another only once that one falls.")
        XCTAssertEqual(RuleError.openGroundOnly.description, "It stands only on open land, with nothing on it.")
        XCTAssertEqual(RuleError.notAllianceLand.description, "It stands on your alliance's own land, within reach of its standards.")
    }

    func testHousesLayUpTheirStoresOutOfAnyTakersReach() throws {
        var stage = try staged("storehouses kept")
        let me = stage.me, ally = stage.ally
        let storehouse = try raisedStorehouse(&stage)
        stage.state.houses[me].stock = Stock(grain: 700, timber: 500, stone: 400, moonsalt: 60)
        stage.state.houses[ally].stock = Stock(grain: 300, timber: 300, stone: 300, moonsalt: 30)
        let laying = Stock(grain: 400, timber: 100)
        let events = try stage.state.perform(.layUp(laying), as: me)
        XCTAssertEqual(events, [.laidUp(house: me, stock: laying)])
        XCTAssertEqual(stage.state.houses[me].stock, Stock(grain: 300, timber: 400, stone: 400, moonsalt: 60))
        XCTAssertEqual(stage.state.laidUp(by: me), laying)
        _ = try stage.state.perform(.layUp(Stock(grain: 50)), as: me)
        XCTAssertEqual(stage.state.laidUp(by: me), Stock(grain: 450, timber: 100), "Laid up beside what it laid up before")
        _ = try stage.state.perform(.layUp(Stock(stone: 120, moonsalt: 10)), as: ally)
        XCTAssertEqual(stage.state.storehouse(storehouse.id)?.held, Stock(grain: 450, timber: 100, stone: 120, moonsalt: 10))
        XCTAssertEqual(stage.state.laidUp(by: 3), .zero, "Of no alliance")
        XCTAssertEqual(stage.state.tidings(of: events[0], for: me)?.text, "You lay up 400 grain, 100 timber in your alliance's storehouse.")
        XCTAssertNil(stage.state.tidings(of: events[0], for: ally))
        XCTAssertEqual(stage.state.events(events, heardBy: me), events)
        XCTAssertEqual(stage.state.events(events, heardBy: ally), [])
        // Each House knows what it laid up, and no other's.
        XCTAssertEqual(stage.state.view(for: me).storehouse(storehouse.id)?.laidUp.map(\.house), [me])
        XCTAssertEqual(stage.state.view(for: ally).storehouse(storehouse.id)?.laidUp.map(\.house), [ally])
        // Out of any taker's reach: the spoils of its seat are half of what it keeps at hand.
        let seat = try XCTUnwrap(stage.state.seat(of: me))
        XCTAssertEqual(stage.state.spoils(ofTaking: seat), stage.state.houses[me].stock.share(1, of: 2))
        // Laid up only as far as there is room, and as it has.
        func refused(_ command: Command, as house: Int? = nil) -> RuleError? { stage.state.refusal(of: command, as: house ?? me) }
        XCTAssertEqual(refused(.layUp(Stock(grain: 200))), .storehouseFull, "600 of each at most")
        XCTAssertEqual(refused(.layUp(Stock(stone: 500))), .shortOf(Stock(stone: 100)))
        XCTAssertEqual(refused(.layUp(.zero)), .nothingGiven)
        XCTAssertEqual(refused(.layUp(Stock(grain: -5, timber: 10))), .nothingGiven)
        XCTAssertEqual(refused(.layUp(Stock(grain: 10)), as: 3), .notInAlliance)
        XCTAssertEqual(RuleError.storehouseFull.description, "Your room in the storehouse holds no more: \(Storehouse.room) at most.")
        // Taken back as it was laid up, and as there is room to keep it.
        XCTAssertEqual(refused(.takeBack(Stock(timber: 101))), .notLaidUp)
        XCTAssertEqual(refused(.takeBack(Stock(grain: -1, timber: 1))), .nothingGiven)
        XCTAssertEqual(refused(.takeBack(Stock(grain: 1)), as: 3), .notInAlliance)
        stage.state.houses[me].stock.grain = stage.state.storage(of: me) - 10
        XCTAssertEqual(refused(.takeBack(Stock(grain: 11))), .storageFull)
        let back = try stage.state.perform(.takeBack(Stock(grain: 10, timber: 100)), as: me)
        XCTAssertEqual(back, [.tookBack(house: me, stock: Stock(grain: 10, timber: 100))])
        XCTAssertEqual(stage.state.laidUp(by: me), Stock(grain: 440))
        XCTAssertEqual(stage.state.houses[me].stock.grain, stage.state.storage(of: me))
        XCTAssertEqual(stage.state.tidings(of: back[0], for: me)?.text, "You take back 10 grain, 100 timber from your alliance's storehouse.")
        XCTAssertNil(stage.state.tidings(of: back[0], for: ally))
        stage.state.houses[me].stock.grain = 0
        _ = try stage.state.perform(.takeBack(Stock(grain: 440)), as: me)
        XCTAssertEqual(stage.state.storehouse(storehouse.id)?.laidUp.map(\.house), [ally], "Nothing left of it laid up")
        XCTAssertEqual(stage.state.problems(), [])
        // A House going from the alliance takes back all it laid up.
        let stock = stage.state.houses[ally].stock
        _ = try stage.state.perform(.leaveAlliance, as: ally)
        XCTAssertEqual(stage.state.houses[ally].stock, stock + Stock(stone: 120, moonsalt: 10))
        XCTAssertEqual(stage.state.storehouse(storehouse.id)?.laidUp, [])
        XCTAssertEqual(stage.state.refusal(of: .takeBack(Stock(stone: 1)), as: ally), .notInAlliance)
        XCTAssertEqual(stage.state.problems(), [])
    }

    func testAStorehouseWhoseAllianceIsNoMoreGivesBackWhatWasLaidUp() throws {
        var stage = try staged("storehouses ruined")
        let me = stage.me, ally = stage.ally
        let storehouse = try raisedStorehouse(&stage)
        XCTAssertEqual(stage.state.keepAllianceStores(), [], "Kept while its alliance stands")
        _ = try stage.state.perform(.layUp(Stock(grain: 100)), as: me)
        stage.state.houses[ally].stock.timber = 200
        _ = try stage.state.perform(.layUp(Stock(timber: 80)), as: ally)
        let allyStock = stage.state.houses[ally].stock
        // Its last two Houses leave together, the alliance gone at once:
        // what one of them laid up is still there.
        stage.state.alliances![0].members = [me]
        _ = try stage.state.perform(.leaveAlliance, as: me)
        XCTAssertNil(stage.state.alliance(stage.alliance))
        let mine = stage.state.houses[me].stock
        let events = stage.state.keepAllianceStores()
        XCTAssertEqual(events, [.storehouseTorn(storehouse: storehouse.id, alliance: stage.alliance, by: nil, at: stage.spot, carried: .zero)])
        XCTAssertNil(stage.state.storehouse(at: stage.spot))
        XCTAssertEqual(stage.state.houses[me].stock, mine, "It had taken back its own on leaving")
        XCTAssertEqual(stage.state.houses[ally].stock, allyStock + Stock(timber: 80), "What was left is given back")
        XCTAssertEqual(stage.state.tidings(of: events[0], for: 2)?.text,
                       "A storehouse \(stage.state.placeName(of: stage.spot)) falls into ruin, its alliance no more.")
        XCTAssertEqual(stage.state.events(events, heardBy: 2), [], "Heard only where it is seen")
        // No hold is founded on an alliance's storehouse, or its yard.
        var founding = stage.state
        let open = try XCTUnwrap(founding.map.hexes.first { founding.canFound(at: $0, for: me) == nil && !founding.isOccupied($0) })
        founding.storehouses = [Storehouse(id: founding.takeID(), alliance: 1, raisedBy: me, position: open, begun: 0)]
        XCTAssertEqual(founding.canFound(at: open, for: me), .allianceGround)
        founding.storehouses = nil
        founding.sites = [Site(id: founding.takeID(), store: .grain, level: 1, position: open, found: 0, alliance: 1)]
        XCTAssertEqual(founding.canFound(at: open, for: me), .allianceGround)
    }

    func testOnlyItsAlliancesCompaniesEnterIt() throws {
        var stage = try staged("storehouses entered")
        let at = stage.spot
        _ = try raisedStorehouse(&stage)
        let gates = at.ring(1).filter { stage.state.map[$0].map { $0.terrain.isPassable && !$0.terrain.isWater } == true
            && !stage.state.isOccupied($0) }
        XCTAssertGreaterThanOrEqual(gates.count, 3)
        let stranger = stage.state.put(.spear, of: 2, at: gates[0])
        _ = try stage.state.perform(.move(unit: stranger, to: at), as: 2)
        XCTAssertEqual(stage.state.unit(stranger)?.position, gates[0], "Only its alliance's companies enter")
        let around = try XCTUnwrap(stage.state.path(for: try XCTUnwrap(stage.state.unit(stranger)), to: gates[1]))
        XCTAssertFalse(around.contains(at), "And none passes through it")
        XCTAssertNil(stage.state.reach(of: try XCTUnwrap(stage.state.unit(stranger)))[at])
        let keeper = stage.state.put(.spear, of: stage.ally, at: gates[1])
        XCTAssertNotNil(stage.state.reach(of: try XCTUnwrap(stage.state.unit(keeper)))[at])
        _ = try stage.state.perform(.move(unit: keeper, to: at), as: stage.ally)
        XCTAssertEqual(stage.state.unit(keeper)?.position, at)
        let foe = stage.state.put(.spear, of: 3, at: gates[2])
        XCTAssertFalse(stage.state.takesTheField(try XCTUnwrap(stage.state.unit(foe)), at: at), "A foe that wins at its gate never steps in")
    }

    func testAFoeTearsItDownAndCarriesOffWhatWasLaidUp() throws {
        var stage = try staged("storehouses torn")
        let me = stage.me, foe = 3, at = stage.spot
        let storehouse = try raisedStorehouse(&stage)
        _ = try stage.state.perform(.layUp(Stock(grain: 300, moonsalt: 20)), as: me)
        let beside = try XCTUnwrap(stage.state.freeHex(near: at, within: 1...1))
        let spear = stage.state.put(.spear, tier: 5, of: foe, at: beside)
        XCTAssertFalse(stage.state.isFoe(foe, ofAlliance: stage.alliance))
        XCTAssertEqual(stage.state.refusal(of: .attack(unit: spear, target: at), as: foe), .notAtWar(me), "Only at war")
        _ = try stage.state.declareWar(by: foe, on: stage.ally)
        XCTAssertTrue(stage.state.isFoe(foe, ofAlliance: stage.alliance))
        XCTAssertFalse(stage.state.isFoe(stage.ally, ofAlliance: stage.alliance), "Never its own")
        XCTAssertFalse(stage.state.isFoe(foe, ofAlliance: 9_999))
        stage.state.houses[foe].stock = .zero
        var events: [GameEvent] = []
        for _ in 0..<40 where stage.state.storehouse(at: at) != nil {
            stage.state.units[stage.state.unitIndex(spear)!].movesLeft = 2
            events += try stage.state.perform(.move(unit: spear, to: at), as: foe)
        }
        XCTAssertNil(stage.state.storehouse(at: at), "Torn down")
        XCTAssertNotEqual(stage.state.unit(spear)?.position, at, "Struck from beside it")
        let carried = Stock(grain: 300, moonsalt: 20)
        let torn = GameEvent.storehouseTorn(storehouse: storehouse.id, alliance: stage.alliance, by: foe, at: at, carried: carried)
        XCTAssertTrue(events.contains(torn), "\(events)")
        XCTAssertEqual(stage.state.houses[foe].stock, carried, "It carries off what was laid up")
        XCTAssertEqual(stage.state.laidUp(by: me), .zero)
        let struck = try XCTUnwrap(events.first { if case .storehouseStruck = $0 { return true } else { return false } })
        guard case .storehouseStruck(_, _, let ward, _, _) = struck else { return XCTFail() }
        let place = stage.state.placeName(of: at), name = stage.state.houses[foe].title
        XCTAssertEqual(stage.state.events([struck], heardBy: stage.ally), [struck], "Its alliance hears it")
        XCTAssertEqual(stage.state.tidings(of: struck, for: foe)?.text, "Your company strikes the storehouse of The Stone Accord: its ward \(ward) of 120.")
        XCTAssertEqual(stage.state.tidings(of: struck, for: stage.ally)?.text, "\(name) strikes your alliance's storehouse \(place): its ward \(ward) of 120.")
        XCTAssertNil(stage.state.tidings(of: struck, for: 2))
        XCTAssertEqual(stage.state.tidings(of: torn, for: foe)?.text,
                       "Your company tears down the storehouse of The Stone Accord, and carries off 300 grain, 20 moonsalt.")
        XCTAssertEqual(stage.state.tidings(of: torn, for: me)?.text,
                       "\(name) tears down your alliance's storehouse \(place), and carries off what was laid up in it.")
        XCTAssertEqual(stage.state.tidings(of: torn, for: me)?.tone, .bad)
        XCTAssertEqual(stage.state.tidings(of: torn, for: 2)?.text, "\(name) tears down the storehouse of The Stone Accord \(place).")
        XCTAssertNil(stage.state.tidings(of: .storehouseTorn(storehouse: 1, alliance: stage.alliance, by: nil, at: at, carried: .zero), for: me))
        XCTAssertEqual(stage.state.tidings(of: .storehouseTorn(storehouse: 1, alliance: stage.alliance, by: foe, at: at, carried: .zero),
                                           for: foe)?.text, "Your company tears down the storehouse of The Stone Accord.")
        XCTAssertTrue(stage.state.chronicle.contains {
            $0.text == "\(name) tears down the storehouse of The Stone Accord \(place), and carries off what was laid up in it."
        })
        // What it gave up is its taker's and its alliance's to know; others
        // who see it fall hear only that it fell.
        XCTAssertEqual(stage.state.events([torn], heardBy: me), [torn])
        XCTAssertEqual(stage.state.events([torn], heardBy: foe), [torn])
        var watched = stage.state
        _ = watched.put(.lantern, of: 2, at: try XCTUnwrap(watched.freeHex(near: at, within: 1...2)))
        XCTAssertEqual(watched.events([torn], heardBy: 2),
                       [.storehouseTorn(storehouse: storehouse.id, alliance: stage.alliance, by: foe, at: at, carried: .zero)])
        XCTAssertEqual(stage.state.problems(), [])

        // Empty, it gives up nothing, and the chronicle says only that it fell.
        var bare = try staged("storehouses torn empty")
        _ = try raisedStorehouse(&bare)
        let striker = bare.state.put(.spear, tier: 5, of: foe, at: try XCTUnwrap(bare.state.freeHex(near: bare.spot, within: 1...1)))
        _ = try bare.state.declareWar(by: foe, on: bare.me)
        for _ in 0..<40 where bare.state.storehouse(at: bare.spot) != nil {
            bare.state.units[bare.state.unitIndex(striker)!].movesLeft = 2
            _ = try bare.state.perform(.attack(unit: striker, target: bare.spot), as: foe)
        }
        let fallen = "\(bare.state.houses[foe].title) tears down the storehouse of The Stone Accord \(bare.state.placeName(of: bare.spot))."
        XCTAssertTrue(bare.state.chronicle.contains { $0.text == fallen })
        // Out of reach, it is not struck.
        var far = try staged("storehouses far")
        _ = try raisedStorehouse(&far)
        let distant = far.state.put(.spear, tier: 5, of: foe, at: try XCTUnwrap(far.state.freeHex(near: far.spot, within: 3...4)))
        _ = try far.state.declareWar(by: foe, on: far.me)
        XCTAssertEqual(far.state.refusal(of: .attack(unit: distant, target: far.spot), as: foe), .outOfReach)
    }

    func testItsWardMendsAndStorehousesOutOfTrueAreFound() throws {
        var stage = try staged("storehouses mended")
        let storehouse = try raisedStorehouse(&stage)
        stage.state.storehouses![0].ward = 50
        _ = stage.state.keepAllianceStores()
        XCTAssertEqual(stage.state.storehouse(storehouse.id)?.ward, 50 + Storehouse.mending)
        stage.state.storehouses![0].ward = Storehouse.maximumWard - 1
        _ = stage.state.keepAllianceStores()
        XCTAssertEqual(stage.state.storehouse(storehouse.id)?.ward, Storehouse.maximumWard)
        // Seen on ground explored, and kept in saves.
        XCTAssertFalse(stage.state.isExplored(stage.spot, by: 2))
        XCTAssertEqual(stage.state.view(for: 2).storehousesStanding, [], "Not on ground unexplored")
        let kept = try JSONDecoder().decode(GameState.self, from: try JSONEncoder().encode(stage.state))
        XCTAssertEqual(kept.storehouse(at: stage.spot), stage.state.storehouse(at: stage.spot))
        let older = try JSONDecoder().decode(GameState.self, from: try Scene.without(["storehouses"], in: stage.state))
        XCTAssertEqual(older.storehousesStanding, [], "Saves from before storehouses have none")

        stage.state.storehouses![0].built = 9
        stage.state.storehouses![0].ward = 500
        stage.state.storehouses![0].laidUp = [Storehouse.LaidUp(house: 3, stock: Stock(grain: 5)),
                                             Storehouse.LaidUp(house: stage.me, stock: Stock(grain: 900)),
                                             Storehouse.LaidUp(house: stage.me, stock: Stock(grain: 1))]
        stage.state.storehouses!.append(Storehouse(id: 9_001, alliance: storehouse.alliance, raisedBy: stage.me, position: stage.spot, begun: 0))
        stage.state.storehouses!.append(Storehouse(id: 9_002, alliance: 8_888, raisedBy: stage.me, position: stage.seat.position, begun: 0))
        let water = try XCTUnwrap(stage.state.map.hexes.first { stage.state.map[$0]?.terrain.isPassable == false })
        stage.state.storehouses!.append(Storehouse(id: 9_003, alliance: storehouse.alliance, raisedBy: stage.me, position: water, begun: 0))
        stage.state.sites = stage.state.sitesInLand + [Site(id: 9_004, store: .stone, level: 1, position: stage.seat.position, found: 0,
                                                            alliance: 8_888),
                                                       Site(id: 9_005, store: .stone, level: 1, position: water, found: 0, alliance: 8_888)]
        let problems = stage.state.problems()
        let id = storehouse.id
        for problem in ["Storehouse \(id) is built 9 of 2", "Storehouse \(id) has ward 500", "Alliance \(storehouse.alliance) has two storehouses",
                        "Storehouse \(id) keeps stores of House 3, not of its alliance", "Storehouse \(id) keeps 900 grain of House \(stage.me)",
                        "Storehouse \(id) keeps House \(stage.me)'s stores twice", "Storehouse 9001 shares its ground at \(stage.spot)",
                        "Storehouse 9002 stands for no alliance", "Storehouse 9003 stands where none can", "Yard 9004 is of no alliance",
                        "Alliance 8888 has two yards of stone"] {
            XCTAssertTrue(problems.contains(problem), "\(problem) in \(problems)")
        }
    }

    // MARK: Yards

    func testYardsAreTheAlliancesOwnSitesItsCompaniesAloneWork() throws {
        var stage = try staged("alliance yards")
        let me = stage.me, ally = stage.ally, id = stage.alliance
        stage.state.fill(coffersOf: id, with: Stock(grain: 80, timber: 100))
        let before = stage.state.houses[me].stock
        let events = try stage.state.perform(.raiseYard(.timber, at: stage.spot), as: me)
        let yard = try XCTUnwrap(stage.state.site(at: stage.spot))
        XCTAssertEqual(events, [.yardRaised(site: yard.id, alliance: id, house: me, store: .timber, at: stage.spot)])
        XCTAssertEqual(yard.alliance, id)
        XCTAssertTrue(yard.isYard)
        XCTAssertEqual(yard.store, .timber)
        XCTAssertEqual(yard.remaining, Yard.richness(of: .timber))
        XCTAssertEqual(yard.title, "Timber Yard")
        XCTAssertEqual(stage.state.yards(of: id), [yard])
        XCTAssertEqual(stage.state.alliance(id)?.stores, .zero, "The coffers paid what they held")
        XCTAssertEqual(before.timber - stage.state.houses[me].stock.timber, Yard.cost.timber - 100)
        XCTAssertEqual(before.stone - stage.state.houses[me].stock.stone, Yard.cost.stone)
        XCTAssertEqual(before.grain, stage.state.houses[me].stock.grain)
        XCTAssertEqual(Resource.allCases.map(Yard.title), ["Tilled Acre", "Timber Yard", "Quarry", "Salt Works"])
        XCTAssertEqual(Yard.richness(of: .moonsalt), 300)
        let place = stage.state.placeName(of: stage.spot), title = stage.state.houses[me].title
        XCTAssertEqual(stage.state.tidings(of: events[0], for: me)?.text,
                       "You raise a timber yard for The Stone Accord \(place): your alliance's companies work it 25% faster, and its coffers take a tithe.")
        XCTAssertEqual(stage.state.tidings(of: events[0], for: ally)?.text,
                       "\(title) raises a timber yard for your alliance \(place): its companies alone work it, 25% faster.")
        XCTAssertEqual(stage.state.tidings(of: events[0], for: 2)?.text, "\(title) raises a timber yard for The Stone Accord.")
        XCTAssertEqual(stage.state.tidings(of: .yardRaised(site: yard.id, alliance: 9_999, house: me, store: .timber, at: stage.spot), for: 2)?.text,
                       "\(title) raises a timber yard for a fallen alliance.")
        XCTAssertNil(stage.state.tidings(of: .yardRaised(site: yard.id, alliance: 9_999, house: 99, store: .timber, at: stage.spot), for: me))
        XCTAssertEqual(stage.state.events(events, heardBy: ally), events)
        XCTAssertTrue(stage.state.chronicle.contains { $0.text == "\(title) raises a timber yard for The Stone Accord \(place)." })
        // One of each store.
        let other = try XCTUnwrap(stage.flag.spiral(Standard.reach).first { stage.state.yardRefusal(.stone, at: $0, by: me) == nil })
        XCTAssertEqual(stage.state.refusal(of: .raiseYard(.timber, at: other), as: me), .yardStanding(.timber))
        XCTAssertEqual(RuleError.yardStanding(.timber).description, "Your alliance has its timber yard already.")
        XCTAssertEqual(stage.state.refusal(of: .raiseYard(.stone, at: other), as: ally), .notAllianceLeader)
        XCTAssertEqual(stage.state.refusal(of: .raiseYard(.stone, at: other), as: 3), .notInAlliance)
        XCTAssertEqual(stage.state.refusal(of: .raiseYard(.stone, at: stage.spot), as: me), .openGroundOnly, "Not on a site")
        var poor = stage.state
        poor.houses[me].stock = .zero
        XCTAssertEqual(poor.refusal(of: .raiseYard(.stone, at: other), as: me), .shortOf(Yard.cost))
        // Not the land's own: the land raises its sites as if it weren't there.
        XCTAssertEqual(stage.state.sitesInLand.filter { $0.alliance == nil }.count, stage.state.sitesInLand.count - 1)

        // Its alliance's companies alone work it, a quarter faster, and the coffers take a tithe.
        let gate = try XCTUnwrap(stage.state.freeHex(near: stage.spot, within: 1...1))
        let stranger = stage.state.put(.spear, of: 2, at: gate)
        stage.state.reveal(around: stage.spot, range: 2, for: 2)
        XCTAssertEqual(stage.state.refusal(of: .gather(unit: stranger, site: yard.id), as: 2), .foreignYard)
        XCTAssertEqual(RuleError.foreignYard.description, "Only the companies of the alliance that raised a yard work it.")
        stage.state.units.removeAll { $0.id == stranger }
        let worker = stage.state.put(.rider, of: ally, at: gate)
        stage.state.reveal(around: stage.spot, range: 2, for: ally)
        _ = try stage.state.perform(.gather(unit: worker, site: yard.id), as: ally)
        stage.state.units[stage.state.unitIndex(worker)!].position = stage.spot
        let unit = try XCTUnwrap(stage.state.unit(worker))
        let rate = stage.state.gatheringRate(of: unit, at: try XCTUnwrap(stage.state.site(yard.id)))
        XCTAssertEqual(rate, stage.state.gatheringRate(of: unit, for: .timber) * (100 + Yard.gathering) / 100)
        XCTAssertGreaterThan(rate, stage.state.gatheringRate(of: unit, for: .timber))
        let coffers = stage.state.alliance(id)?.stores ?? .zero
        _ = stage.state.workTheLand()
        let gathered = try XCTUnwrap(stage.state.unit(worker)?.load?.timber)
        XCTAssertEqual(gathered, rate)
        XCTAssertEqual(stage.state.site(yard.id)?.remaining, Yard.richness(of: .timber) - rate)
        XCTAssertEqual(stage.state.alliance(id)?.stores.timber, coffers.timber + (rate * Yard.tithe + 99) / 100, "A tenth besides, to the coffers")
        // A company whose House leaves the alliance is no more its to work: it turns for home.
        _ = try stage.state.perform(.leaveAlliance, as: ally)
        _ = stage.state.workTheLand()
        XCTAssertEqual(stage.state.unit(worker)?.errand, .homeward)
        XCTAssertEqual(stage.state.problems(), [])
        // An alliance gone, its yards go with it.
        _ = try stage.state.perform(.leaveAlliance, as: me)
        _ = stage.state.keepAllianceStores()
        XCTAssertNil(stage.state.site(yard.id))
        XCTAssertEqual(stage.state.yards(of: id), [])
    }

    func testTheLandRaisesItsOwnSitesBesideAnAlliancesYards() throws {
        var state = Scene.world("yards beside sites", houses: 4, radius: 18)
        state.sites = []
        let yard = try XCTUnwrap(state.map.hexes.first { !state.isOccupied($0) && state.map[$0]?.terrain.isPassable == true })
        state.sites = [Site(id: state.takeID(), store: .grain, level: 5, position: yard, found: 0, alliance: 1)]
        for _ in 0..<20 { state.raiseSites() }
        XCTAssertEqual(state.sitesInLand.filter { !$0.isYard }.count, state.houses.count * 3, "As many of the land's own as ever")
        XCTAssertEqual(state.sitesInLand.filter(\.isYard).count, 1)
    }

    // MARK: The stewards

    func testStewardLeadersRaiseStorehousesAndYardsAndLayUpTheirSurplus() throws {
        var state = Scene.world("steward stores", houses: 4, radius: 18)
        let steward = 2
        _ = try state.perform(.foundAlliance(name: "The Far Store"), as: steward)
        let seat = try XCTUnwrap(state.seat(of: steward))
        state.reveal(around: seat.position, range: 6, for: steward)
        state.houses[steward].stock = Stock(grain: 900, timber: 900, stone: 900, moonsalt: 90)
        let flag = try XCTUnwrap(seat.position.spiral(3).first { hex in
            (2...3).contains(hex.distance(to: seat.position)) && state.refusal(of: .raiseStandard(at: hex), as: steward) == nil
        })
        _ = try state.perform(.raiseStandard(at: flag), as: steward)
        let sworn = try XCTUnwrap(state.alliance(of: steward)).id
        // A yard first, of the first store it has none of.
        state.watch = RivalMind.yardsFrom + (5 - (RivalMind.yardsFrom + steward) % 5 + 2) % 5
        state.houses[steward].stock = Stock(grain: 900, timber: 900, stone: 900, moonsalt: 90)
        let yards = state.stewardTurn(for: steward)
        XCTAssertTrue(yards.contains { if case .yardRaised(_, sworn, steward, .grain, _) = $0 { return true } else { return false } }, "\(yards)")
        // Then its storehouse.
        state.watch = RivalMind.storehousesFrom + (4 - (RivalMind.storehousesFrom + steward) % 4 + 1) % 4
        state.houses[steward].stock = Stock(grain: 900, timber: 900, stone: 900, moonsalt: 90)
        let raised = state.stewardTurn(for: steward)
        let at = try XCTUnwrap(raised.compactMap { event -> Hex? in
            if case .storehouseRaised(_, sworn, steward, let at) = event { return at }
            return nil
        }.first, "\(raised)")
        XCTAssertEqual(state.allianceLand(at: at), sworn, "On its alliance's land")
        // Whole, it lays up what it has beyond seven tenths of its room, and
        // takes it back when it runs low.
        for _ in 0..<Storehouse.raising { _ = state.keepAllianceStores() }
        let room = state.storage(of: steward)
        state.houses[steward].stock = Stock(grain: room, timber: room, stone: room, moonsalt: 20)
        _ = state.stewardTurn(for: steward)
        XCTAssertFalse(state.laidUp(by: steward).isZero, "Its surplus laid up")
        XCTAssertTrue(state.laidUp(by: steward).fits(in: Stock(grain: room * 3 / 10, timber: room * 3 / 10, stone: room * 3 / 10)))
        state.houses[steward].stock = .zero
        _ = state.stewardTurn(for: steward)
        XCTAssertEqual(state.laidUp(by: steward), .zero, "Taken back when it runs low")
        XCTAssertEqual(state.problems(), [])
    }

    func testStewardsWorkTheirOwnYardsAndNoOthers() throws {
        var state = Scene.world("steward yards", houses: 4, radius: 18)
        let steward = 2
        let seat = try XCTUnwrap(state.seat(of: steward))
        let ground = try XCTUnwrap(seat.position.spiral(4).first { hex in
            hex.distance(to: seat.position) >= 2 && !state.isOccupied(hex) && state.site(at: hex) == nil && state.shrine(at: hex) == nil
                && state.map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true
        })
        state.reveal(around: seat.position, range: 6, for: steward)
        state.sites = [Site(id: state.takeID(), store: .grain, level: 5, position: ground, found: 0, alliance: 9_999)]
        state.houses[steward].stock = .zero
        let spear = state.put(.spear, of: steward, at: try XCTUnwrap(state.freeHex(near: seat.position, within: 1...1)))
        XCTAssertNil(RivalMind(house: steward).site(for: try XCTUnwrap(state.unit(spear)), in: state), "Another alliance's yard is not its to work")
        _ = try state.perform(.foundAlliance(name: "The Grain Oath"), as: steward)
        let own = try XCTUnwrap(state.alliance(of: steward)).id
        state.sites = [Site(id: state.takeID(), store: .grain, level: 5, position: ground, found: 0, alliance: own)]
        XCTAssertEqual(RivalMind(house: steward).site(for: try XCTUnwrap(state.unit(spear)), in: state), state.sites?.first?.id)
    }
}
