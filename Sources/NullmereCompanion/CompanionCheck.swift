#if DEBUG
import Foundation
import NullmereCompanionCore
import NullmereCore
import NullmereCounsel

/// The companion run in the iOS Simulator as a keeper runs it, for
/// scripts/smoke-test-companion.sh: it takes the link the keeper's Mac
/// offered (NULLMERE_COMPANION_LINK, the link its QR code carries), comes
/// in as the keeper, keeps their House as a keeper does from the phone (a
/// company dug in, words said to the realm, an alliance's banner raised and
/// words said to it, the keeper made ready for the watch to turn, a hold set
/// to work), hearing
/// the realm's word on each, is
/// set aside and comes in again, and writes
/// what it saw to Documents/companion-report.txt in its own container,
/// ending with the word on it all once it is done. NULLMERE_COMPANION_TAB
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
    /// The line a report ends with while its steps go on.
    static let keeping = "Still keeping its keeper's House…"

    /// What a hold is set to by an order, as the Mac's report names it: the
    /// hold and the work raised or company mustered there.
    static func work(of command: Command) -> String? {
        switch command {
        case .build(let hold, let kind): return "\(hold):\(kind.rawValue)"
        case .train(let hold, let kind, _): return "\(hold):\(kind.rawValue)"
        default: return nil
        }
    }

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

    /// Whether the phone is a simulator, whose model is its Mac's.
    static var simulated: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    /// Counsel taken through this phone's own model, if asked for.
    static func takeCounselIfAsked() {
        guard ProcessInfo.processInfo.environment["NULLMERE_COUNSEL_REPORT"] != nil else { return }
        let written = documents.appendingPathComponent("counsel-report.txt")
        try? FileManager.default.removeItem(at: written)
        Task {
            let report = await CounselCheck.run(on: device, simulated: simulated)
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
        func write(done: Bool = true) {
            let last = !broken.isEmpty ? "Broken: " + broken.joined(separator: "; ") : done ? passed : keeping
            let text = (lines + ["", last]).joined(separator: "\n")
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
        write(done: false)
        /// An order given from the phone, the realm's word on it heard and
        /// written under `what`: never a name the smoke test reads a line by
        /// (Fortified company, Said to the realm, Raised the banner of, Said
        /// to the alliance, Watch, At work), or it reads the realm's word for
        /// what was done.
        func give(_ command: Command, told: String, as what: String) async {
            let asked = Date()
            session.give(command, told: told)
            if await until(30, { session.word?.awaited == false }), let word = session.word {
                lines.append(String(format: "%@: %@ (%.2f s)", what, word.text, Date().timeIntervalSince(asked)))
                if word.refused { broken.append("the realm refused \(told.lowercased()): \(word.text)") }
            } else {
                broken.append("no word from the realm on \(told.lowercased())")
            }
        }
        // Words said to the whole realm, from the phone.
        let said = "Kept from \(session.keeper?.name ?? "a keeper")'s phone at watch \(ledger.watch)."
        await give(.say(words: said, toAlliance: false), told: "Said to the realm", as: "Said")
        lines.append("Said to the realm: \(said)")
        // An alliance's banner raised from the phone, where the keeper's
        // House is sworn to none, and words said to it.
        if session.ledger?.alliance == nil {
            let banner = "The Phone's Accord"
            await give(.foundAlliance(name: banner), told: "Raise the banner of \(banner)", as: "Raised")
            if await until(30, { session.ledger?.alliance != nil }) {
                lines.append("Raised the banner of: \(banner)")
            } else {
                broken.append("the banner raised from the phone never stood")
            }
        }
        if let alliance = session.ledger?.alliance {
            let toAllies = "Sworn to \(alliance), from \(session.keeper?.name ?? "a keeper")'s phone."
            await give(.say(words: toAllies, toAlliance: true), told: "Said to your alliance", as: "Said to allies")
            lines.append("Said to the alliance: \(toAllies)")
        } else {
            lines.append("Sworn to no alliance: nothing said to one")
        }
        write(done: false)
        // Ready for the watch to turn, from the phone: the watch turns once
        // every keeper there is ready, and a third of it has passed while a
        // keeper whose House stands is away. The House's holds may be at
        // work already as the keeper comes in (a seat taken from its steward
        // is kept as it stood); a watch on, what they mustered is done.
        let before = session.ledger?.watch ?? ledger.watch
        let readied = Date()
        session.setReady(true)
        if await until(90, { (session.ledger?.watch ?? before) > before }) {
            lines.append(String(format: "Made ready: the watch turned to %ld in %.2f s", session.ledger?.watch ?? before,
                                Date().timeIntervalSince(readied)))
        } else {
            lines.append("Made ready: the watch didn't turn in 90 s, a keeper there not yet ready")
        }
        lines.append("Watch: \(session.ledger?.watch ?? before)")
        // A hold set to work: a work raised, or where none can be paid for, a company mustered.
        let now = session.ledger ?? ledger
        var raising: (hold: CompanionLedger.Hold, order: CompanionLedger.Order)?
        if let hold = now.holds.first(where: { !$0.works.isEmpty }) {
            raising = (hold, hold.works[0])
        } else if let hold = now.holds.first(where: { !$0.musters.isEmpty }) {
            raising = (hold, hold.musters[0])
        }
        if let raising, let setTo = CompanionCheck.work(of: raising.order.command) {
            await give(raising.order.command, told: "\(raising.order.title) at \(raising.hold.name)", as: "Set to work")
            lines.append("At work: \(setTo)")
        } else {
            broken.append("no hold its stores could set to work: " + now.holds.map { "\($0.name), \($0.work.joined(separator: ", "))" }.joined(separator: "; "))
        }
        write(done: false)
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
