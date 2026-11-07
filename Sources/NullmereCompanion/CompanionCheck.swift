#if DEBUG
import Foundation
import NullmereCompanionCore
import NullmereCore

/// The companion run in the iOS Simulator as a keeper runs it, for
/// scripts/smoke-test-companion.sh: it takes the link the keeper's Mac
/// offered (NULLMERE_COMPANION_LINK, the link its QR code carries), comes
/// in as the keeper, gives one order and hears the realm's word on it, is
/// set aside and comes in again, and writes what it saw to
/// Documents/companion-report.txt in its own container. NULLMERE_COMPANION_TAB
/// opens a tab to be seen. Debug builds alone heed either.
@MainActor
enum CompanionCheck {
    static var tabShown: CompanionTab? {
        ProcessInfo.processInfo.environment["NULLMERE_COMPANION_TAB"].flatMap(CompanionTab.init(rawValue:))
    }

    /// The line a report ends with when every step came as it should.
    static let passed = "The companion kept its keeper's House."

    static func startIfAsked(_ session: CompanionSession) {
        guard let text = ProcessInfo.processInfo.environment["NULLMERE_COMPANION_LINK"], let url = URL(string: text),
              let invite = CompanionInvite(url: url) else { return }
        Task { await run(session, invite: invite) }
    }

    private static var report: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("companion-report.txt")
    }

    private static func until(_ seconds: Double, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while !condition() {
            if Date() > deadline { return false }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return true
    }

    static func run(_ session: CompanionSession, invite: CompanionInvite) async {
        var lines = ["Nullmere Companion, linked to \(invite.realm.absoluteString)"]
        var broken: [String] = []
        func write() {
            let text = (lines + ["", broken.isEmpty ? passed : "Broken: " + broken.joined(separator: "; ")]).joined(separator: "\n")
            try? FileManager.default.createDirectory(at: report.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? text.write(to: report, atomically: true, encoding: .utf8)
        }
        let began = Date()
        session.take(invite)
        guard await until(60, { session.phase == .keeping }), let ledger = session.ledger else {
            broken.append("never came in as the keeper: \(session.problem ?? "no word")")
            write()
            return
        }
        lines.append(String(format: "In as %@ of %@ in %.2f s: watch %ld, %ld companies, %ld holds", session.keeper?.name ?? "?", ledger.house,
                            Date().timeIntervalSince(began), ledger.watch, ledger.companies.count, ledger.holds.count))
        #if targetEnvironment(simulator)
        let file = CompanionKeychain(realm: invite.realm).fallback
        lines.append(FileManager.default.fileExists(atPath: file.path)
                     ? "Its key kept in its own container: the simulator's keychain refused an app no developer team signed"
                     : "Its key kept in its keychain, for this device alone")
        #else
        lines.append("Its key kept in its keychain, for this device alone")
        #endif
        guard let company = ledger.companies.first(where: { $0.orders.contains { $0.title == "Fortify" } }),
              let fortify = company.orders.first(where: { $0.title == "Fortify" }) else {
            broken.append("no company to fortify")
            write()
            return
        }
        let ordered = Date()
        session.give(fortify.command, told: "Fortify the \(company.name)")
        if await until(30, { session.word?.awaited == false }), let word = session.word {
            lines.append(String(format: "Ordered: %@ (%.2f s)", word.text, Date().timeIntervalSince(ordered)))
            if word.refused { broken.append("the realm refused the order: \(word.text)") }
        } else {
            broken.append("no word from the realm on the order")
        }
        lines.append("Fortified company: \(company.id)")
        write()
        // Set aside and back, by its own key: in again, the order kept.
        session.pause()
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        let returning = Date()
        session.resume()
        if await until(60, { session.phase == .keeping }) {
            let kept = session.world?.unit(company.id)?.fortified == true
            lines.append(String(format: "Came in again in %.2f s; the company is %@", Date().timeIntervalSince(returning),
                                kept ? "dug in, as ordered" : "not dug in"))
            if !kept { broken.append("the order was not kept") }
        } else {
            broken.append("never came in again: \(session.problem ?? "no word")")
        }
        write()
    }
}
#endif
