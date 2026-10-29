import Foundation
import XCTest
@testable import NullmereCore

final class OmenTests: XCTestCase {
    private func world() -> GameState {
        GameState(settings: GameSettings(seedText: "omens", houseCount: 4, radius: 18))
    }

    func testOmensFallNowAndThenAndLift() {
        var state = world()
        var fallen: [OmenKind] = []
        var lifted = 0
        var longest = 0
        // Three hundred watches of the omens' own clock, however the age
        // itself would have gone.
        for _ in 0..<300 {
            let before = state.currentOmen
            state.watch += 1
            state.turnOmens()
            if let omen = state.currentOmen, before == nil {
                fallen.append(omen.kind)
                longest = max(longest, omen.ends - omen.began)
                XCTAssertTrue(state.chronicle.last?.text.hasSuffix(omen.kind.effect) ?? false, "Told when it falls")
            }
            if before != nil, state.currentOmen == nil { lifted += 1 }
        }
        XCTAssertGreaterThanOrEqual(fallen.count, 6, "Over three hundred watches the lake turns again and again: some twelve times, as a rule")
        XCTAssertLessThanOrEqual(longest, 5)
        XCTAssertGreaterThanOrEqual(lifted, fallen.count - 1)
        XCTAssertTrue(state.chronicle.contains { $0.kind == .omen })
    }

    func testEachOmenDoesWhatItSays() {
        var state = world()
        let seat = state.holds(of: state.player).first { $0.isSeat }!
        let plain = state.income(of: seat)
        let sight = state.visibility(for: state.player).filter { $0 }.count

        state.omen = Omen(kind: .moonsaltBloom, began: 1, ends: 4)
        XCTAssertEqual(state.income(of: seat).moonsalt, plain.moonsalt * 2)
        state.omen = Omen(kind: .leanWatch, began: 1, ends: 4)
        XCTAssertEqual(state.income(of: seat).grain, plain.grain * 2 / 3)
        XCTAssertEqual(state.income(of: seat).timber, plain.timber)
        state.omen = Omen(kind: .risingMist, began: 1, ends: 4)
        XCTAssertLessThan(state.visibility(for: state.player).filter { $0 }.count, sight, "The mist shortens sight")
        state.omen = Omen(kind: .stillNight, began: 1, ends: 4)
        XCTAssertEqual(state.wardMending, Hold.wardRecovery * 2)

        // The omen is the realm's: every keeper's view holds it.
        XCTAssertEqual(state.view(for: 1).currentOmen?.kind, .stillNight)
        XCTAssertEqual(Omen(kind: .leanWatch, began: 3, ends: 7).watchesLeft(at: 5), 2)
        // Worlds kept before omens open with none.
        let data = try! JSONEncoder().encode(world())
        XCTAssertNil(try! JSONDecoder().decode(GameState.self, from: data).currentOmen)
    }
}
