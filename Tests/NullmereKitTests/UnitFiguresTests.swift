import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// A company's figures on its card: health always; attack and defence for
/// a company of war; its tier where it has tiers; moves for the keeper's
/// own alone. Each label drawn whole: run 924's commander's card broke
/// them mid-word ("HEALT H") where five did not fit the card's width, and
/// now they fall to two rows there instead.
@MainActor
final class UnitFiguresTests: XCTestCase {
    func testACompanysFiguresAreWhatItsKindAndOwnerShow() throws {
        let state = GameState(settings: GameSettings(seedText: "a company's figures", houseCount: 4, radius: 16, keepers: 1))
        let me = state.player
        // Every House begins with a company of spears and one of Lanterns.
        let spear = try XCTUnwrap(state.units(of: me).first { $0.kind == .spear })
        let lantern = try XCTUnwrap(state.units.first { $0.kind == .lantern && $0.owner != me })
        XCTAssertTrue(spear.kind.isMilitary && spear.kind.hasTiers)
        XCTAssertFalse(lantern.kind.isMilitary || lantern.kind.hasTiers)

        let mine = UnitPanel.figures(of: spear, in: state, mine: true)
        XCTAssertEqual(mine.map(\.label), ["Health", "Attack", "Defence", "Tier", "Moves"])
        XCTAssertEqual(mine.first?.value, "\(spear.health)")
        XCTAssertEqual(mine.first { $0.label == "Tier" }?.value, Narration.roman(spear.tier))
        XCTAssertEqual(mine.last?.value, "\(spear.movesLeft)/\(state.movement(of: spear))")
        XCTAssertEqual(UnitPanel.figures(of: spear, in: state, mine: false).map(\.label), ["Health", "Attack", "Defence", "Tier"],
                       "another's moves are not the keeper's to know")
        XCTAssertEqual(UnitPanel.figures(of: lantern, in: state, mine: false).map(\.label), ["Health"])
        XCTAssertEqual(Set(mine.map(\.id)).count, mine.count, "each figure its own")
    }
}
