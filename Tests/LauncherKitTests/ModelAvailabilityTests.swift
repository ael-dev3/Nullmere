import FoundationModels
import LauncherCore
import XCTest
@testable import LauncherKit

/// Stands in for the Foundation Models framework: any availability, which
/// a test can change at any moment, as macOS changes it when Apple
/// Intelligence is turned on or its model finishes downloading.
final class FakeModelAvailability: ModelAvailabilityProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var current: SystemLanguageModel.Availability

    init(_ availability: SystemLanguageModel.Availability) {
        current = availability
    }

    var availability: SystemLanguageModel.Availability {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    func set(_ availability: SystemLanguageModel.Availability) {
        lock.lock(); current = availability; lock.unlock()
    }
}

final class ModelAvailabilityTests: XCTestCase {
    func testEveryAvailabilityThroughAProvider() {
        let cases: [(SystemLanguageModel.Availability, ModelReadiness)] = [
            (.available, .ready),
            (.unavailable(.deviceNotEligible), .deviceNotEligible),
            (.unavailable(.appleIntelligenceNotEnabled), .appleIntelligenceNotEnabled),
            (.unavailable(.modelNotReady), .modelNotReady),
        ]
        let fake = FakeModelAvailability(.available)
        for (availability, expected) in cases {
            fake.set(availability)
            XCTAssertEqual(OnDeviceModel.readiness(from: fake), expected)
        }
    }

    func testDebugStatesAreNamed() {
        XCTAssertEqual(OnDeviceModel.readiness(named: "ready"), .ready)
        XCTAssertEqual(OnDeviceModel.readiness(named: "notEligible"), .deviceNotEligible)
        XCTAssertEqual(OnDeviceModel.readiness(named: "notEnabled"), .appleIntelligenceNotEnabled)
        XCTAssertEqual(OnDeviceModel.readiness(named: "downloading"), .modelNotReady)
        XCTAssertEqual(OnDeviceModel.readiness(named: "unavailable"), .unavailable)
        XCTAssertNil(OnDeviceModel.readiness(named: "maybe"))
    }

    /// No test process sets a debug state, so `current()` is the system's.
    func testTheAppsAskTheSystem() {
        XCTAssertNil(OnDeviceModel.debugReadiness)
        XCTAssertEqual(OnDeviceModel.current(), OnDeviceModel.readiness(from: SystemModelAvailability()))
    }
}

/// The launcher driven by the fake framework through every state a Mac can
/// be in, in the order a person might meet them.
@MainActor
final class LauncherAvailabilityTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var opened: [URL] = []

    override func setUp() async throws {
        suiteName = "LauncherAvailabilityTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        opened = []
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeModel(_ readiness: @escaping () -> ModelReadiness) -> LauncherModel {
        let environment = LauncherEnvironment(
            modelReadiness: readiness,
            systemSavesEnergy: { false },
            downloadNews: { throw URLError(.notConnectedToInternet) },
            open: { [weak self] url in
                self?.opened.append(url)
                return true
            },
            terminate: {}
        )
        let model = LauncherModel(defaults: defaults, environment: environment)
        model.refreshReadiness()
        model.completeIntro()
        return model
    }

    /// What the launcher shows for one state: the requirement screen with
    /// exactly its actions, or the menu.
    private func assertShows(_ expected: ModelReadiness, on model: LauncherModel, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(model.readiness, expected, file: file, line: line)
        XCTAssertEqual(model.isGated, !expected.allowsPlay, file: file, line: line)
        if model.isGated {
            XCTAssertFalse(expected.actions.isEmpty, "A gated launcher always offers a way out", file: file, line: line)
            XCTAssertEqual(expected.actions.last, .quit, file: file, line: line)
            XCTAssertNil(model.footerHint, file: file, line: line)
            model.activate(.news)
            XCTAssertEqual(model.screen, .title, "Nothing behind the requirement screen opens", file: file, line: line)
        } else {
            model.handle(.right)
            model.handle(.confirm)
            XCTAssertEqual(model.screen, .news, "The menu works once the model is ready", file: file, line: line)
            model.handle(.back)
            XCTAssertEqual(model.screen, .title, file: file, line: line)
            model.handle(.left)
        }
    }

    func testEveryStateOfTheFrameworkInTurn() {
        let fake = FakeModelAvailability(.unavailable(.appleIntelligenceNotEnabled))
        let model = makeModel { OnDeviceModel.readiness(from: fake) }
        defer { model.pauseReadinessChecks() }

        // Apple Intelligence is off: System Settings is offered first.
        assertShows(.appleIntelligenceNotEnabled, on: model)
        XCTAssertEqual(model.readiness.actions, [.openSystemSettings, .quit])
        model.handle(.confirm)
        XCTAssertEqual(opened, [Destination.appleIntelligenceSettings])

        // Turned on, the model downloads: only waiting, or Quit.
        fake.set(.unavailable(.modelNotReady))
        model.refreshReadiness()
        assertShows(.modelNotReady, on: model)
        XCTAssertEqual(model.readiness.actions, [.quit])
        XCTAssertTrue(model.readiness.needsRecheck)

        // Downloaded: the launcher opens by itself.
        fake.set(.available)
        model.refreshReadiness()
        assertShows(.ready, on: model)
        XCTAssertEqual(model.readiness.status, "On-device model ready")

        // Turned off again: it closes again.
        fake.set(.unavailable(.appleIntelligenceNotEnabled))
        model.refreshReadiness()
        assertShows(.appleIntelligenceNotEnabled, on: model)
    }

    func testAMacThatCanNeverRunTheModel() {
        let fake = FakeModelAvailability(.unavailable(.deviceNotEligible))
        let model = makeModel { OnDeviceModel.readiness(from: fake) }
        assertShows(.deviceNotEligible, on: model)
        XCTAssertEqual(model.readiness.actions, [.quit])
        XCTAssertFalse(model.readiness.needsRecheck, "There is nothing to wait for")
    }

    /// A reason this version doesn't know, which the framework can't be made
    /// to give in a test, still has a clear way forward.
    func testAnUnknownReason() {
        let model = makeModel { .unavailable }
        defer { model.pauseReadinessChecks() }
        assertShows(.unavailable, on: model)
        XCTAssertEqual(model.readiness.actions, [.openSystemSettings, .quit])
        XCTAssertTrue(model.readiness.needsRecheck)
        XCTAssertFalse(model.readiness.headline.isEmpty)
        XCTAssertFalse(model.readiness.explanation.isEmpty)
    }

    func testEveryStateHasItsOwnWords() {
        let states: [ModelReadiness] = [.checking, .ready, .deviceNotEligible, .appleIntelligenceNotEnabled, .modelNotReady, .unavailable]
        XCTAssertEqual(Set(states.map(\.headline)).count, states.count)
        XCTAssertEqual(Set(states.map(\.explanation)).count, states.count)
        XCTAssertEqual(Set(states.map(\.status)).count, states.count)
    }
}
