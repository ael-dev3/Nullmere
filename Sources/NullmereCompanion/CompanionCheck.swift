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
/// words said to it and a study of it chosen and given toward, a commander
/// given a company, another company marched from the chart of the House's
/// land, the keeper made ready for the watch to turn, a hold set to work),
/// hearing
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
        if counselShown || wordsShown { return .army }
        return ProcessInfo.processInfo.environment["NULLMERE_COMPANION_TAB"].flatMap(CompanionTab.init(rawValue:))
    }

    /// Counsel opened with the House's first free commander, to be seen:
    /// NULLMERE_COMPANION_TAB=counsel.
    static var counselShown: Bool {
        ProcessInfo.processInfo.environment["NULLMERE_COMPANION_TAB"] == "counsel"
    }

    /// Orders in the keeper's own words opened, a line of the order book
    /// read, to be seen: NULLMERE_COMPANION_TAB=words.
    static var wordsShown: Bool {
        ProcessInfo.processInfo.environment["NULLMERE_COMPANION_TAB"] == "words"
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

    /// Counsel taken through this phone's own model, if asked for, and then
    /// the House's clerk reading a keeper's own words through it, each
    /// written to a report of its own (Documents/counsel-report.txt, then
    /// Documents/clerk-report.txt).
    static func takeCounselIfAsked() {
        guard ProcessInfo.processInfo.environment["NULLMERE_COUNSEL_REPORT"] != nil else { return }
        let written = documents.appendingPathComponent("counsel-report.txt")
        let read = documents.appendingPathComponent("clerk-report.txt")
        try? FileManager.default.removeItem(at: written)
        try? FileManager.default.removeItem(at: read)
        Task {
            let report = await CounselCheck.run(on: device, simulated: simulated)
            try? FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
            try? report.text.write(to: written, atomically: true, encoding: .utf8)
            try? await clerkReport().write(to: read, atomically: true, encoding: .utf8)
        }
    }

    /// The words the clerk is given to read in the check.
    static let clerkWords = "Dig in my first company of war, and raise a granary at my seat."

    /// The House's clerk reading a keeper's own words through this phone's
    /// model, against a keeper's view as the realm gives it: what came of
    /// the reading, and each line's order or why it can't be given; or why
    /// the model couldn't read them, the words read as written instead.
    static func clerkReport() async -> String {
        let world = GameState(settings: GameSettings(seedText: "the phone's clerk", houseCount: 4, radius: 18, keepers: 1))
        let player = world.player
        let began = Date()
        let reading = await OrderClerk().read(clerkWords, in: world.view(for: player), player: player)
        var lines = ["The House's clerk on \(device), asked: \(clerkWords)",
                     String(format: "%@ (%.2f s in all)", reading.summary, Date().timeIntervalSince(began))]
        if let trouble = reading.trouble { lines.append(trouble) }
        lines += reading.lines.map { "  \($0.text): \($0.why ?? $0.told)" }
        return lines.joined(separator: "\n")
    }

    /// The line a report of the line cut ends with when all came as it should.
    static let cameBack = "The companion came back to the realm."

    /// The phone's line to the realm cut and mended by the smoke test
    /// (NULLMERE_COMPANION_LOST): in again by its own key, it says when the
    /// realm is out of reach and keeps the House, says words to the realm
    /// while it is, and once the line is mended says how soon it was in
    /// reach again and the realm's word on the words; each written to
    /// Documents/lost-report.txt as it comes. The smoke test cuts the line
    /// once it reads that the phone is in, and mends it once it reads the
    /// words were said, each time leaving word of it in Documents
    /// (line-cut, line-mended) for the phone to time itself by.
    static func loseTheLineIfAsked(_ session: CompanionSession) {
        guard ProcessInfo.processInfo.environment["NULLMERE_COMPANION_LOST"] != nil else { return }
        let file = documents.appendingPathComponent("lost-report.txt")
        let cut = documents.appendingPathComponent("line-cut")
        let mended = documents.appendingPathComponent("line-mended")
        Task {
            var lines: [String] = []
            var broken: [String] = []
            func write(done: Bool = false) {
                let last = !broken.isEmpty ? "Broken: " + broken.joined(separator: "; ") : done ? cameBack : keeping
                try? FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
                try? (lines + ["", last]).joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8)
            }
            /// Seconds since the smoke test left word at `marker`, if it has.
            func since(_ marker: URL) -> String {
                guard let left = (try? FileManager.default.attributesOfItem(atPath: marker.path))?[.modificationDate] as? Date else { return "" }
                return String(format: " (%.2f s after the %@)", Date().timeIntervalSince(left), marker == cut ? "cut" : "mending")
            }
            let began = Date()
            guard await until(60, { session.phase == .keeping && session.ledger != nil }) else {
                broken.append("never came in again: \(session.problem ?? "no word")")
                write()
                return
            }
            lines.append(String(format: "In again by its own key in %.2f s", Date().timeIntervalSince(began)))
            write()
            guard await until(90, { session.outOfReach != nil }), let said = session.outOfReach else {
                broken.append("never said the realm was out of reach")
                write()
                return
            }
            lines.append("Out of reach: \(said)" + since(cut))
            if session.phase != .keeping || session.ledger == nil {
                broken.append("let the House go while out of reach")
            }
            let words = "Said from \(session.keeper?.name ?? "a keeper")'s phone while its line was down."
            session.say(words, toAlliance: false)
            lines.append("Said while cut off: \(words)")
            write()
            guard await until(120, { session.outOfReach == nil && FileManager.default.fileExists(atPath: mended.path) }) else {
                broken.append("never in reach again once the line was mended")
                write()
                return
            }
            lines.append("In reach again" + since(mended))
            if await until(60, { session.word?.awaited == false }), let word = session.word {
                lines.append("Once in reach: \(word.text)" + since(mended))
                if word.refused { broken.append("the realm refused the words said while cut off: \(word.text)") }
            } else {
                broken.append("no word from the realm on the words said while cut off")
            }
            write(done: true)
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
        // A commander given a company of war from the phone, where one is free.
        if let commander = session.ledger?.commanders.first(where: { !$0.leads.isEmpty }), let lead = commander.leads.first {
            await give(lead.command, told: "\(commander.name): \(lead.title)", as: "Commanded")
        } else {
            lines.append("No commander free to take up a company by a hold")
        }
        // The chart of the House's land, and another company marched from
        // it to open ground the House has explored near its seat.
        if let world = session.world, let house = session.keeper?.house {
            let chart = CompanionChart(world: world, player: house)
            lines.append("Charted: \(chart.cells.count) hexes about \(world.seat(of: house)?.name ?? "the House"), "
                         + "\(chart.cells.filter(\.explored).count) explored, \(chart.marks.count) marked, "
                         + "\(chart.marks.filter { $0.side == .own }.count) the House's own")
            let ground = chart.cells.filter { cell in
                cell.explored && cell.terrain.isPassable && !cell.terrain.isWater && cell.hex.distance(to: chart.center) == 2
                    && !chart.marks.contains { $0.hex == cell.hex }
            }
            let march = ground.lazy.compactMap { cell in
                chart.place(at: cell.hex, in: world, player: house).marches.first { order in
                    if case .move(let unit, _) = order.command { return unit != company.id }
                    return false
                }
            }.first
            if let march {
                await give(march.command, told: march.title, as: "Marched from the chart")
            } else {
                lines.append("Nothing marched from the chart: no company but the one dug in could go")
            }
            // A line of the order book read by the clerk, through this
            // phone's own model where it can read, as written where it can't.
            let reading = await OrderClerk().read("FORTIFY C1", in: world, player: house)
            lines.append("Read in the keeper's words: " + reading.summary + (reading.trouble.map { " " + $0 } ?? ""))
        }
        write(done: false)
        // The Mac's answer: seeing the company dug in, it says so to the
        // realm (NULLMERE_ANSWER_PHONE), and the phone hears it come back.
        let answered = "Seen on the Mac: "
        if await until(45, { session.ledger?.realmWords.contains { $0.text.hasPrefix(answered) } == true }),
           let heard = session.ledger?.realmWords.last(where: { $0.text.hasPrefix(answered) }) {
            lines.append("Heard from the Mac: \(heard.text)")
        } else {
            lines.append("Nothing heard from the Mac in 45 s")
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
        // The alliance's study chosen from the phone and given toward, once
        // the hold is at work: a gift of the House's stores spent before it
        // left nothing to muster with (run 674).
        if session.ledger?.alliance != nil, let pursue = session.ledger?.pursuits.first {
            await give(pursue.command, told: pursue.title, as: "Pursued")
            if await until(30, { session.ledger?.allianceGifts.isEmpty == false }), let gift = session.ledger?.allianceGifts.first {
                await give(gift.command, told: gift.title, as: "Given toward the study")
            } else {
                lines.append("Nothing the House could give toward the study")
            }
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
