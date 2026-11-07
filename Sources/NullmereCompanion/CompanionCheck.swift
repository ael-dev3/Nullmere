#if DEBUG
import Foundation
import NullmereCompanionCore
import NullmereCore
import NullmereCounsel

/// The companion run in the iOS Simulator as a keeper runs it, for
/// scripts/smoke-test-companion.sh: it takes the link the keeper's Mac
/// offered (NULLMERE_COMPANION_LINK, the link its QR code carries), comes
/// in as the keeper, gives one order and hears the realm's word on it, is
/// set aside and comes in again, and writes what it saw to
/// Documents/companion-report.txt in its own container. NULLMERE_COMPANION_TAB
/// opens a tab to be seen, or counsel with the first free commander
/// (NULLMERE_COMPANION_TAB=counsel). And NULLMERE_COUNSEL_REPORT takes counsel of a
/// commander through this phone's own on-device model, as the Mac's check
/// does (CounselCheck), writing what was heard to
/// Documents/counsel-report.txt. Debug builds alone heed any of them.
@MainActor
enum CompanionCheck {
    static var tabShown: CompanionTab? {
        if counselShown { return .army }
        return ProcessInfo.processInfo.environment["NULLMERE_COMPANION_TAB"].flatMap(CompanionTab.init(rawValue:))
    }

    /// Counsel opened with the House's first free commander, to be seen:
    /// NULLMERE_COMPANION_TAB=counsel.
    static var counselShown: Bool {
        ProcessInfo.processInfo.environment["NULLMERE_COMPANION_TAB"] == "counsel"
    }

    /// The line a report ends with when every step came as it should.
    static let passed = "The companion kept its keeper's House."

    static func startIfAsked(_ session: CompanionSession) {
        guard let text = ProcessInfo.processInfo.environment["NULLMERE_COMPANION_LINK"], let url = URL(string: text),
              let invite = CompanionInvite(url: url) else { return }
        Task { await run(session, invite: invite) }
    }

    private static var report: URL { documents.appendingPathComponent("companion-report.txt") }

    private static var documents: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }

    /// The device the phone's model is asked on, as the report names it.
    static var device: String {
        #if targetEnvironment(simulator)
        return "this iPhone Simulator"
        #else
        return "this iPhone"
        #endif
    }

    /// Counsel taken through this phone's own model, if asked for.
    static func takeCounselIfAsked() {
        guard ProcessInfo.processInfo.environment["NULLMERE_COUNSEL_REPORT"] != nil else { return }
        let written = documents.appendingPathComponent("counsel-report.txt")
        try? FileManager.default.removeItem(at: written)
        Task {
            let report = await CounselCheck.run(on: device)
            try? FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
            try? report.text.write(to: written, atomically: true, encoding: .utf8)
        }
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
