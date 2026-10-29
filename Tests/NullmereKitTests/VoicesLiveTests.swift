import Foundation
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The voices as a keeper hears them, from Apple's on-device model itself:
/// run only where it can be, by scripts/check-voices.sh on a Mac with Apple
/// Intelligence. Each envoy's offer and each kind of chronicle entry is
/// spoken, and every line held to the voices' rules: spoken at all, short,
/// grave (no exclamations), no numbers but the facts', and no talk of games
/// or players. The lines are written to build/voices-report.txt to be read.
final class VoicesLiveTests: XCTestCase {
    static let forbidden = ["game", "player", "turn", "rules", "level", "click", " ai ", "artificial"]

    func testTheVoicesSpeakWithinTheirRules() async throws {
        guard ProcessInfo.processInfo.environment["NULLMERE_LIVE_VOICES"] == "1" else {
            throw XCTSkip("Run by scripts/check-voices.sh on a Mac with Apple Intelligence")
        }
        guard OnDeviceVoice.isAvailable else {
            return XCTFail("Apple's on-device model isn't ready on this Mac: turn on Apple Intelligence and let it finish downloading")
        }
        var state = GameState(settings: GameSettings(seedText: "voices", houseCount: 6, radius: 22, keepers: 1))
        for _ in 0..<60 where state.outcome == nil {
            _ = state.stewardTurn(for: state.player)
            _ = state.endWatch()
        }
        var moments: [(String, VoiceMoment)] = []
        let other = state.livingHouses.first { $0.id != state.player }?.id ?? 1
        for (index, proposal) in Proposal.allCases.enumerated() {
            let trade = proposal == .trade ? Trade(give: .timber, 20, for: .grain, 15) : nil
            let envoy = Envoy(id: 9_000 + index, from: other, to: state.player, proposal: proposal, arrived: state.watch, trade: trade)
            moments.append(("envoy offering \(proposal.title.lowercased())", VoiceFacts.envoy(envoy, in: state)))
        }
        var kinds = Set<String>()
        for entry in state.chronicle.reversed() where VoiceFacts.isVoiced(entry.kind) && kinds.insert(entry.kind.rawValue).inserted {
            moments.append(("chronicle of \(entry.kind.rawValue)", VoiceFacts.chronicle(entry, in: state)))
        }

        let voice = OnDeviceVoice()
        var report = ["Nullmere Online's voices, spoken by Apple's on-device model on this Mac.", ""]
        var failures: [String] = []
        for (name, moment) in moments {
            let started = Date()
            let line = await voice.speak(moment)
            let seconds = Date().timeIntervalSince(started)
            report.append(String(format: "%@ (%.1f s): %@", name, seconds, line ?? "(silent)"))
            guard let line else {
                failures.append("\(name): silent")
                continue
            }
            let words = line.split(separator: " ").count
            if words > 60 { failures.append("\(name): \(words) words") }
            if line.contains("!") { failures.append("\(name): an exclamation") }
            let lowered = " " + line.lowercased() + " "
            for word in Self.forbidden where lowered.contains(word) { failures.append("\(name): speaks of \"\(word.trimmingCharacters(in: .whitespaces))\"") }
            let facts = moment.facts.joined(separator: " ")
            for number in line.split(whereSeparator: { !$0.isNumber }) where !facts.contains(number) {
                failures.append("\(name): invents the number \(number)")
            }
        }
        report += ["", failures.isEmpty ? "Every line within the rules." : "Out of bounds:"] + failures
        let text = report.joined(separator: "\n")
        print(text)
        try? FileManager.default.createDirectory(atPath: "build", withIntermediateDirectories: true)
        try text.write(toFile: "build/voices-report.txt", atomically: true, encoding: .utf8)
        XCTAssertGreaterThanOrEqual(moments.count, Proposal.allCases.count + 2, "Envoys and chronicle entries enough to hear")
        XCTAssertEqual(failures, [], "Every voice within its rules")
    }
}
