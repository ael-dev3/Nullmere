import XCTest
@testable import NullmereCore

/// The kinds written by their names compare and hash by which case they
/// are, and every answer is the one their names give: each the same as
/// itself alone, each its own in a set, each found in a table it keys,
/// and each read back from its name.
final class PlainCasesTests: XCTestCase {
    private func check<Kind: PlainCases & CaseIterable>(_ kind: Kind.Type, file: StaticString = #filePath, line: UInt = #line) {
        let all = Array(Kind.allCases)
        XCTAssertEqual(MemoryLayout<Kind>.size, 1, "\(Kind.self) is held in a byte", file: file, line: line)
        for first in all {
            for second in all {
                XCTAssertEqual(first == second, first.rawValue == second.rawValue, "\(first), \(second)", file: file, line: line)
            }
            XCTAssertEqual(Kind(rawValue: first.rawValue), first, file: file, line: line)
        }
        XCTAssertEqual(Set(all).count, all.count, "\(Kind.self): each its own", file: file, line: line)
        let table = Dictionary(uniqueKeysWithValues: all.map { ($0, $0.rawValue) })
        XCTAssertTrue(all.allSatisfy { table[$0] == $0.rawValue }, "\(Kind.self)", file: file, line: line)
    }

    func testEveryKindComparesByCaseAsByName() {
        check(AllianceStudy.self)
        check(BuildingKind.self)
        check(Archetype.self)
        check(Skill.self)
        check(Crest.Tincture.self)
        check(Crest.Charge.self)
        check(Stance.self)
        check(Proposal.self)
        check(EdictKind.self)
        check(Making.self)
        check(GearSet.self)
        check(GearSlot.self)
        check(GearKind.self)
        check(HappeningKind.self)
        check(Heritage.self)
        check(Temperament.self)
        check(ItemKind.self)
        check(OmenKind.self)
        check(Deed.self)
        check(Resource.self)
        check(ShrineKind.self)
        check(Branch.self)
        check(Study.self)
        check(Shore.self)
        check(TalentTree.self)
        check(Talent.self)
        check(Terrain.self)
        check(Feature.self)
        check(Title.self)
        check(UnitKind.self)
        check(WildKind.self)
        check(Lake.self)
    }

    /// And those not listed case by case, by the cases they have.
    func testTheRestCompareByCaseAsByName() {
        let ends: [OathEnd] = [.kept, .renounced, .broken, .fallen]
        let freed: [Freed] = [.ransomed, .released, .escaped]
        for (index, end) in ends.enumerated() { XCTAssertEqual(ends.firstIndex(of: end), index) }
        for (index, way) in freed.enumerated() { XCTAssertEqual(freed.firstIndex(of: way), index) }
        XCTAssertEqual(Set(ends).count, 4)
        XCTAssertEqual(Set(freed).count, 3)
        XCTAssertNotEqual(Tidings.Tone.good, .bad)
        XCTAssertEqual(Tidings.Tone(rawValue: Tidings.Tone.neutral.rawValue), .neutral)
    }
}
