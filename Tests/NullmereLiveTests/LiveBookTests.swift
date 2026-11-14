import Foundation
@testable import NullmereLive
import NullmereRealm
import XCTest

/// The player's city as a screen lists it, read from rows: what each
/// building's next level costs and why it can't be raised yet, in the
/// realm's own words; the troops; what can be trained; the armies out.
final class LiveBookTests: XCTestCase {
    private func n(_ value: Double) -> JSONValue { .number(value) }
    private func n(_ value: Int) -> JSONValue { .number(Double(value)) }

    /// The module's source, where the repository is at hand.
    private func source(_ name: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard let text = try? String(contentsOf: root.appendingPathComponent("realm/src/\(name)"), encoding: .utf8) else {
            throw XCTSkip("realm/src is not beside the tests here")
        }
        return text
    }

    /// A blueprint's row: a building's level, what it costs in timber and
    /// stone, the Keep level it opens at and what else must stand first.
    private func blueprint(_ kind: Int, _ level: Int, _ name: String, timber: Int, stone: Int = 0, opensAt: Int = 1, needs: (Int, Int) = (0, 0)) -> [JSONValue] {
        [n(kind << 32 | level), n(kind), n(level), .string(name), n(0), n(timber), n(stone), n(0), n(10 * level), n(0), n(0), n(0), n(0),
         n(opensAt), n(needs.0), n(needs.1), n(20 * level)]
    }

    private func soldier(_ kind: Int, _ tier: Int, _ name: String, building: Int, needsLevel: Int, grain: Int, timber: Int) -> [JSONValue] {
        [n(kind << 8 | tier), n(kind), n(tier), .string(name), n(90), n(110), n(110), n(60), n(12), n(tier), n(grain), n(timber), n(0), n(0),
         n(8_000), n(building), n(needsLevel)]
    }

    /// Ada's city at Keep 2: a Keep, a Farm at the Keep's level, a
    /// Sawmill rising to its second, a Barracks training a batch, a Wall
    /// that waits on nothing. 1,000 timber and 300 stone in the stock.
    private func rows(timber: Int = 1_000, stone: Int = 300, jobs: [[JSONValue]]? = nil) -> [String: [[JSONValue]]] {
        var blueprints: [[JSONValue]] = []
        for level in 1...4 {
            blueprints.append(blueprint(1, level, "Keep", timber: 300 * level, stone: 100 * level, needs: level >= 4 ? (12, level - 1) : (0, 0)))
            blueprints.append(blueprint(2, level, "Farm", timber: 100 * level))
            blueprints.append(blueprint(3, level, "Sawmill", timber: 100 * level))
            blueprints.append(blueprint(7, level, "Barracks", timber: 200 * level, opensAt: 2))
            blueprints.append(blueprint(11, level, "Hospital", timber: 2_000 * level, opensAt: 3))
            blueprints.append(blueprint(12, level, "Wall", timber: 150 * level, stone: 400 * level, opensAt: 2))
        }
        return [
            "realm": [[n(0), n(42), n(1_000), n(1), n(1_000), n(1), n(128)]],
            "me": [[n(1), n(9), .string("Ada"), n(1_000), .bool(true), n(1_000)]],
            "my_city": [[n(7), n(1), n(Double(LiveHex(q: 3, r: 4).packed)), .string("Ada"), n(2), n(500), n(1_000), n(1)]],
            "my_buildings": [[n(21), n(7), n(1), n(2)], [n(22), n(7), n(2), n(2)], [n(23), n(7), n(3), n(1)], [n(24), n(7), n(7), n(1)], [n(25), n(7), n(12), n(1)]],
            "my_jobs": jobs ?? [[n(4), n(7), n(1), n(23), n(2), n(0), n(2_000), n(2_020), n(9)], [n(5), n(7), n(2), n(24), n(1), n(30), n(2_000), n(2_240), n(10)]],
            "my_stock": [[n(7), n(5_000), n(timber), n(stone), n(0), n(2_000), n(0), n(0), n(0), n(0), n(0), n(0), n(0), n(0), n(30_000)]],
            "blueprint": blueprints,
            "soldier": [soldier(1, 1, "Spearmen", building: 7, needsLevel: 1, grain: 50, timber: 50),
                        soldier(1, 2, "Spearmen", building: 7, needsLevel: 5, grain: 100, timber: 100),
                        soldier(2, 1, "Archers", building: 8, needsLevel: 1, grain: 40, timber: 70)],
            "my_troops": [[n(7 << 16 | 1 << 8 | 1), n(7), n(1), n(1), n(40), n(6)], [n(7 << 16 | 2 << 8 | 1), n(7), n(2), n(1), n(0), n(4)]],
        ]
    }

    func testNumbersAndTimesAreWordedAsTheRealmWordsThem() throws {
        XCTAssertEqual([0, 7, 999, 1_000, 12_500, 1_234_567].map { LiveWords.grouped($0) }, ["0", "7", "999", "1,000", "12,500", "1,234,567"])
        XCTAssertEqual([0, 1, 45, 60, 61, 3_600, 12_000, 86_400, 90_000, 200_000, -5].map { LiveWords.spoken($0) },
                       ["0 seconds", "1 second", "45 seconds", "1 minute", "1 minute 1 second", "1 hour", "3 hours 20 minutes", "1 day",
                        "1 day 1 hour", "2 days 7 hours", "0 seconds"])
        XCTAssertEqual([0, 5, 65, 3_605, 12_005, 90_000, -1].map { LiveWords.clock($0) }, ["0:00", "0:05", "1:05", "1:00:05", "3:20:05", "1d 1h", "0:00"])
        XCTAssertEqual(LiveGoods().words, "nothing")
        XCTAssertEqual(LiveGoods(timber: 620).words, "620 timber")
        XCTAssertEqual([LiveGoods().sentence, LiveGoods(timber: 620).sentence], ["Nothing", "620 timber"])
        XCTAssertEqual(LiveGoods(timber: 620, stone: 310).words, "620 timber and 310 stone")
        XCTAssertEqual(LiveGoods(grain: 1_500, timber: 620, stone: 310, moonsalt: 4).words, "1,500 grain, 620 timber, 310 stone and 4 moonsalt")
        XCTAssertEqual(LiveGoods(grain: 10, timber: 700).short(of: LiveGoods(grain: 50, timber: 620, stone: 310)), LiveGoods(grain: 40, stone: 310))
        XCTAssertTrue(LiveGoods(grain: 10).short(of: LiveGoods(grain: 5)).isNone)

        // Every reason is worded as the module words its refusal.
        let rules = try source("rules/mod.rs")
        for sentence in ["Raise your Keep to level {level} first.", "Raise your {} to level {level} first.", "Your {} is already being built.",
                         "Your {} is training troops. Wait for them to finish.", "Your {} is already training troops.",
                         "Your builders are busy. Wait for them to finish.", "You need {short} more.", "Your {} is at its highest level.",
                         // And those the card for what is chosen gives (`LiveCard`).
                         "That city is at peace for another {}.", "Clear a level {level} barrow first.", "Another army is fighting there.",
                         "Another army is gathering there.", "That army is fighting. Wait for the fight to end.", "That army is already on its way home.",
                         "Your one army is out. Raise your Keep to send more.", "All {most} of your armies are out."] {
            XCTAssertTrue(rules.contains("\"\(sentence)\""), "the module says: \(sentence)")
        }
        XCTAssertEqual(LiveBlock.needsKeep(4).words, "Raise your Keep to level 4 first.")
        XCTAssertEqual(LiveBlock.needsOther("Wall", 3).words, "Raise your Wall to level 3 first.")
        XCTAssertEqual(LiveBlock.rising("Farm").words, "Your Farm is already being built.")
        XCTAssertEqual(LiveBlock.training("Barracks").words, "Your Barracks is training troops. Wait for them to finish.")
        XCTAssertEqual(LiveBlock.alreadyTraining("Barracks").words, "Your Barracks is already training troops.")
        XCTAssertEqual(LiveBlock.buildersBusy.words, "Your builders are busy. Wait for them to finish.")
        XCTAssertEqual(LiveBlock.short(LiveGoods(timber: 620, stone: 310)).words, "You need 620 timber and 310 stone more.")
        XCTAssertEqual(LiveBlock.top("Keep").words, "Your Keep is at its highest level.")

        // And the catalogue's own numbers are the module's.
        let catalog = try source("catalog.rs")
        XCTAssertTrue(catalog.contains("pub const TOP_LEVEL: u32 = 25;"))
        XCTAssertTrue(catalog.contains("10 + 40 * level.min(TOP_LEVEL) as u64"))
        XCTAssertEqual([0, 1, 10, 25, 40].map { LiveWorld.batch(level: $0) }, [10, 50, 410, 1_010, 1_010])
        XCTAssertTrue(catalog.contains("0..=4 => 1,") && catalog.contains("5..=10 => 2,") && catalog.contains("11..=16 => 3,") && catalog.contains("17..=21 => 4,"))
        XCTAssertEqual([1, 4, 5, 10, 11, 16, 17, 21, 22, 25].map { LiveWorld.marches(keep: $0) }, [1, 1, 2, 2, 3, 3, 4, 4, 5, 5])
        XCTAssertTrue(catalog.contains("50 + 150 * level + 10 * level * level"))
        XCTAssertTrue(catalog.contains("pub const ENERGY_A_HUNT: u32 = \(LiveWorld.energyAnAttack);"))
    }

    func testEachBuildingIsListedWithWhatItsNextLevelAsks() throws {
        let world = LiveWorld(snapshot: rows())
        let lines = world.buildingLines(at: 2_000)
        XCTAssertEqual(lines.map(\.name), ["Keep", "Farm", "Sawmill", "Barracks", "Wall", "Hospital"], "what stands first, each group by kind")
        let line = { (name: String) in try XCTUnwrap(lines.first { $0.name == name }) }

        // One builder, and the Sawmill has it: everything else waits on that
        // unless something stops it sooner.
        XCTAssertEqual(try line("Keep").block, .buildersBusy)
        XCTAssertEqual(try line("Keep").next?.cost, LiveGoods(timber: 900, stone: 300))
        XCTAssertEqual(try line("Farm").block, .needsKeep(3), "nothing rises above the Keep")
        XCTAssertEqual(try line("Sawmill").block, .rising("Sawmill"))
        XCTAssertEqual(try line("Sawmill").job?.level, 2)
        XCTAssertEqual(try line("Barracks").block, .training("Barracks"))
        XCTAssertEqual(try line("Wall").block, .buildersBusy)
        XCTAssertEqual(try line("Hospital").block, .needsKeep(3))
        XCTAssertNil(try line("Hospital").building)
        XCTAssertEqual(try line("Hospital").level, 0)
        XCTAssertEqual(try line("Hospital").next?.level, 1)

        // With the builder free: the Keep may rise; the Wall is too dear.
        let idle = LiveWorld(snapshot: rows(jobs: []))
        let free = idle.buildingLines(at: 2_000)
        XCTAssertNil(free.first { $0.kind == 1 }?.block)
        XCTAssertEqual(free.first { $0.kind == 12 }?.block, .short(LiveGoods(stone: 500)), "300 stone against the 800 it costs")
        XCTAssertEqual(free.first { $0.kind == 12 }?.block?.words, "You need 500 stone more.")
        XCTAssertNil(free.first { $0.kind == 3 }?.block)
        XCTAssertNil(free.first { $0.kind == 7 }?.block)
        // A first building too dear, and a Keep that waits on its Wall.
        var keepThree = rows(timber: 5_000, stone: 5_000, jobs: [])
        keepThree["my_city"] = [[n(7), n(1), n(Double(LiveHex(q: 3, r: 4).packed)), .string("Ada"), n(3), n(500), n(1_000), n(1)]]
        keepThree["my_buildings"] = [[n(21), n(7), n(1), n(3)], [n(22), n(7), n(2), n(2)], [n(25), n(7), n(12), n(1)]]
        let waiting = LiveWorld(snapshot: keepThree).buildingLines(at: 2_000)
        XCTAssertEqual(waiting.first { $0.kind == 1 }?.block, .needsOther("Wall", 3))
        XCTAssertNil(waiting.first { $0.kind == 2 }?.block)
        XCTAssertNil(waiting.first { $0.kind == 11 }?.block, "the Hospital opens at Keep 3, and 2,000 timber pays for it")
        XCTAssertEqual(LiveWorld(snapshot: rows(timber: 150, jobs: [])).buildingLines(at: 2_000).first { $0.kind == 12 }?.block,
                       .short(LiveGoods(timber: 150, stone: 500)), "short of two goods at once")
        // At its highest level there is no next.
        keepThree["my_buildings"] = [[n(21), n(7), n(1), n(25)]]
        let top = LiveWorld(snapshot: keepThree).buildingLines(at: 2_000).first { $0.kind == 1 }
        XCTAssertEqual(top?.block, .top("Keep"))
        XCTAssertNil(top?.next)
        // A building first being raised stands at level 0.
        keepThree["my_buildings"] = [[n(21), n(7), n(1), n(3)], [n(26), n(7), n(11), n(0)]]
        XCTAssertEqual(LiveWorld(snapshot: keepThree).buildingLines(at: 2_000).first { $0.kind == 11 }?.block, .rising("Hospital"))
        // No city, nothing to list.
        XCTAssertTrue(LiveWorld().buildingLines(at: 0).isEmpty)
    }

    func testTroopsAndTrainingAreListedTierByTier() throws {
        var snapshot = rows()
        snapshot["my_squads"] = [[n(3 << 16 | 1 << 8 | 1), n(3), n(1), n(1), n(20), n(2)]]
        let world = LiveWorld(snapshot: snapshot)
        let troops = world.troopLines()
        XCTAssertEqual(troops.map(\.name), ["Spearmen", "Archers"])
        XCTAssertEqual(troops.map { [$0.ready, $0.wounded, $0.out] }, [[40, 6, 20], [0, 4, 0]])
        XCTAssertEqual(troops.map(\.id), [1 << 8 | 1, 2 << 8 | 1])
        // Room for wounded: fifty with no Hospital, less the ten lying there and the two carried home.
        XCTAssertEqual(world.roomForWounded, 50 - 10 - 2)
        snapshot["my_buildings"]?.append([n(27), n(7), n(11), n(1)])
        XCTAssertEqual(LiveWorld(snapshot: snapshot).roomForWounded, 210 - 12)

        // The Barracks is training: nothing more until it is done.
        let training = try XCTUnwrap(world.trainLines(at: 2_000).first)
        XCTAssertEqual(world.trainLines(at: 2_000).count, 1, "one building that trains")
        XCTAssertEqual([training.name, String(training.kind), String(training.most)], ["Barracks", "1", "50"])
        XCTAssertEqual(training.job?.amount, 30)
        XCTAssertEqual(training.tiers.map(\.block), [.alreadyTraining("Barracks"), .alreadyTraining("Barracks")])

        // Idle: the first tier may be trained, the second waits on the Barracks' level.
        let idle = LiveWorld(snapshot: rows(jobs: []))
        let line = try XCTUnwrap(idle.trainLines(at: 2_000).first)
        XCTAssertEqual(line.tiers.map(\.tier), [1, 2])
        XCTAssertNil(line.tiers[0].block)
        XCTAssertEqual(line.tiers[1].block, .needsOther("Barracks", 5))
        XCTAssertEqual(idle.mostTrainable(line, tier: 1, at: 2_000), 20, "1,000 timber pays for twenty at fifty each")
        XCTAssertEqual(LiveWorld(snapshot: rows(timber: 9_000, jobs: [])).mostTrainable(line, tier: 1, at: 2_000), 50, "no more than a batch holds")
        XCTAssertEqual(idle.mostTrainable(line, tier: 9, at: 2_000), 0)
        let poor = LiveWorld(snapshot: rows(timber: 20, jobs: []))
        XCTAssertEqual(poor.trainLines(at: 2_000).first?.tiers[0].block, .short(LiveGoods(timber: 30)))
        XCTAssertEqual(poor.mostTrainable(line, tier: 1, at: 2_000), 0)
        // Rising, it trains nothing.
        let rising = LiveWorld(snapshot: rows(jobs: [[n(4), n(7), n(1), n(24), n(2), n(0), n(2_000), n(2_020), n(9)]]))
        XCTAssertEqual(rising.trainLines(at: 2_000).first?.tiers[0].block, .rising("Barracks"))
    }

    func testEachArmyOutIsToldInPlainWords() throws {
        func route(_ hexes: [LiveHex]) -> JSONValue {
            .string(hexes.flatMap { hex -> [UInt8] in
                let (q, r) = (UInt16(bitPattern: Int16(hex.q)), UInt16(bitPattern: Int16(hex.r)))
                return [UInt8(q & 0xFF), UInt8(q >> 8), UInt8(r & 0xFF), UInt8(r >> 8)]
            }.map { String(format: "%02x", $0) }.joined())
        }
        let way = route([LiveHex(q: 3, r: 4), LiveHex(q: 4, r: 4)])
        func march(_ id: Int, kind: Int, state: Int, target: Int, soldiers: Int = 20) -> [JSONValue] {
            [n(id), n(1), n(7), n(kind), n(state), n(Double(LiveHex(q: 3, r: 4).packed)), n(Double(LiveHex(q: 4, r: 4).packed)), n(target),
             n(2_000), n(2_060), n(soldiers), way, n(1)]
        }
        var snapshot = rows()
        snapshot["site"] = [[n(5), n(Double(LiveHex(q: 4, r: 4).packed)), n(2), n(4), n(80_000), n(0)]]
        snapshot["barrow"] = [[n(9), n(Double(LiveHex(q: 4, r: 4).packed)), n(3), n(0)]]
        snapshot["march"] = [march(1, kind: 1, state: 1, target: 5), march(2, kind: 1, state: 2, target: 5), march(3, kind: 1, state: 3, target: 5),
                             march(4, kind: 2, state: 1, target: 9), march(5, kind: 2, state: 4, target: 9), march(6, kind: 2, state: 3, target: 99, soldiers: 14),
                             march(7, kind: 1, state: 1, target: 77), march(9, kind: 3, state: 1, target: 12), march(10, kind: 3, state: 4, target: 12),
                             march(11, kind: 3, state: 3, target: 13),
                             [n(8), n(2), n(8), n(1), n(1), n(0), n(0), n(5), n(2_000), n(2_060), n(9), way, n(1)]]
        snapshot["city"] = [[n(12), n(2), n(Double(LiveHex(q: 4, r: 4).packed)), .string("Bryn"), n(4), n(900), n(1_000), n(1)]]
        snapshot["my_hauls"] = [[n(3), n(1), n(0), n(240), n(0), n(0)]]
        snapshot["my_squads"] = [[n(6 << 16 | 1 << 8 | 1), n(6), n(1), n(1), n(14), n(6)]]
        let lines = LiveWorld(snapshot: snapshot).marchLines()
        XCTAssertEqual(lines.map(\.id), [1, 2, 3, 4, 5, 6, 7, 9, 10, 11], "her own, not another's")
        XCTAssertEqual(lines.map(\.doing), ["On its way to gather timber", "Gathering timber", "Coming home with 240 timber", "On its way to a level 3 barrow",
                                            "Fighting at a level 3 barrow", "Coming home", "On its way to gather", "On its way to Bryn's city",
                                            "Attacking Bryn's city", "Coming home"])
        XCTAssertEqual(lines.map(\.canRecall), [true, true, false, true, false, false, true, true, false, false])
        XCTAssertEqual(lines[2].carrying, LiveGoods(timber: 240))
        XCTAssertEqual([lines[5].soldiers, lines[5].wounded], [14, 6])
        XCTAssertTrue(LiveWorld().marchLines().isEmpty)
    }
}
