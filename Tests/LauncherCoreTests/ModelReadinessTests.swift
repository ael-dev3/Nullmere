import LauncherCore
import XCTest

final class ModelReadinessTests: XCTestCase {
    private let all: [ModelReadiness] = [
        .checking, .ready, .deviceNotEligible, .appleIntelligenceNotEnabled, .modelNotReady, .unavailable,
    ]

    func testOnlyAReadyModelAllowsPlay() {
        XCTAssertEqual(all.filter(\.allowsPlay), [.ready])
    }

    func testSettledStatesAreNotCheckedAgain() {
        XCTAssertEqual(all.filter { !$0.needsRecheck }, [.ready, .deviceNotEligible])
    }

    func testSystemSettingsIsOfferedOnlyWhereItHelps() {
        XCTAssertEqual(all.filter(\.isFixedInSystemSettings), [.appleIntelligenceNotEnabled, .unavailable])
    }

    func testEveryStateExplainsItself() {
        for readiness in all {
            XCTAssertFalse(readiness.status.isEmpty)
            XCTAssertFalse(readiness.headline.isEmpty)
            XCTAssertFalse(readiness.explanation.isEmpty)
        }
        XCTAssertEqual(Set(all.map(\.status)).count, all.count)
    }

    func testPlayOutcome() {
        XCTAssertEqual(PlayOutcome(readiness: .ready, isGameInstalled: true), .launchGame)
        XCTAssertEqual(PlayOutcome(readiness: .ready, isGameInstalled: false), .awaitFirstRealm)
        XCTAssertEqual(
            PlayOutcome(readiness: .appleIntelligenceNotEnabled, isGameInstalled: true),
            .explainRequirement(.appleIntelligenceNotEnabled),
            "An installed game still needs the on-device model"
        )
        XCTAssertEqual(PlayOutcome(readiness: .deviceNotEligible, isGameInstalled: false), .explainRequirement(.deviceNotEligible))
    }
}
