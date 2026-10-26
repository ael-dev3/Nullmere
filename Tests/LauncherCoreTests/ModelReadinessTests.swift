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

    func testTheRequirementScreenOffersSettingsOnlyWhereTheyHelp() {
        XCTAssertEqual(ModelReadiness.appleIntelligenceNotEnabled.actions, [.openSystemSettings, .quit])
        XCTAssertEqual(ModelReadiness.unavailable.actions, [.openSystemSettings, .quit])
        XCTAssertEqual(ModelReadiness.deviceNotEligible.actions, [.quit])
        XCTAssertEqual(ModelReadiness.modelNotReady.actions, [.quit])
        XCTAssertEqual(ModelReadiness.checking.actions, [], "Nothing to press while the launcher is still checking")
        XCTAssertEqual(ModelReadiness.ready.actions, [])
        XCTAssertEqual(RequirementAction.openSystemSettings.title, "Open System Settings")
    }

    func testPlayOutcome() {
        XCTAssertEqual(PlayOutcome(readiness: .ready, canEnterRealm: true), .enterRealm)
        XCTAssertEqual(PlayOutcome(readiness: .ready, canEnterRealm: false), .awaitFirstRealm)
        XCTAssertEqual(
            PlayOutcome(readiness: .appleIntelligenceNotEnabled, canEnterRealm: true),
            .explainRequirement(.appleIntelligenceNotEnabled),
            "The realm still needs the on-device model"
        )
        XCTAssertEqual(PlayOutcome(readiness: .deviceNotEligible, canEnterRealm: false), .explainRequirement(.deviceNotEligible))
    }
}
