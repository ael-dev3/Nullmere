import XCTest
@testable import NullmereCore

/// How great the stewards' battles grow over whole ages: each age of
/// twelve seats (or NULLMERE_BATTLE_SEATS) played to its end, its greatest
/// battle's troops kept. Run only when NULLMERE_BATTLE_AGES names how many
/// ages to play (and NULLMERE_BATTLE_FROM, if set, the first age's number):
/// a measure for the work on battles of hundreds of thousands, not a check
/// on every push.
final class BattleSizeTests: XCTestCase {
    func testTheGreatestBattlesOfWholeAges() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let count = environment["NULLMERE_BATTLE_AGES"].flatMap(Int.init), count > 0 else {
            throw XCTSkip("Set NULLMERE_BATTLE_AGES to measure")
        }
        let from = environment["NULLMERE_BATTLE_FROM"].flatMap(Int.init) ?? 1
        let seats = min(max(environment["NULLMERE_BATTLE_SEATS"].flatMap(Int.init) ?? 12, 2), WorldGenerator.mostHouses)
        var greatest: [Int] = []
        var wins: [String: Int] = [:]
        for age in from..<(from + count) {
            var world = RealmState.world(seed: "battles of the lake \(age)", age: age, seats: seats, radius: RealmState.radius(forSeats: seats))
            var most = 0
            for _ in 1...400 where world.outcome == nil {
                var events: [GameEvent] = []
                for pace in 1..<GameState.pacesPerWatch { events += world.walk(to: pace) }
                events += world.endWatch()
                for case let .fieldEnded(field) in events { most = max(most, field.troops(of: 0) + field.troops(of: 1)) }
            }
            greatest.append(most)
            let winner = world.outcome.map { world.houses[$0.winner].temperament.rawValue } ?? "none"
            wins[winner, default: 0] += 1
            let how = world.outcome.map { "by \($0.kind.rawValue)" } ?? "unended"
            print("BATTLES age \(age) of \(seats) seats: greatest \(most) troops, ended at watch \(world.watch) \(how), won by the \(winner)")
        }
        let sorted = greatest.sorted()
        let median = sorted.count % 2 == 1 ? sorted[sorted.count / 2] : (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
        print("BATTLES \(count) ages: median \(median), most \(sorted.last ?? 0), over 100,000 in \(greatest.filter { $0 > 100_000 }.count), "
              + "over 200,000 in \(greatest.filter { $0 > 200_000 }.count); won by \(wins.sorted { $0.key < $1.key })")
    }
}
