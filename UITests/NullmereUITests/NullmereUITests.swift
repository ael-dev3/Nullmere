import AppKit
import XCTest

/// Nullmere Online as VoiceOver and Accessibility Inspector meet it, through
/// the Mac's own accessibility: the app opened as a keeper opens it, every
/// screen put to Xcode's accessibility audit, and the lake's map walked
/// through the elements VoiceOver reads.
///
/// It opens the debug build scripts/ui-test.sh makes and registers with
/// Launch Services: only a debug build reads the variables that open it as
/// a Mac whose on-device model is ready would, with a realm of its own. That
/// build goes by a name of its own, so Launch Services can't open an
/// installed copy in its place and its settings never mix with a keeper's;
/// what it keeps, it keeps in a folder of the test's.
final class NullmereUITests: XCTestCase {
    private static let bundleIdentifier = "online.nullmere.launcher.uitest"

    private var app: XCUIApplication!
    private var window: XCUIElement!
    /// What the audits and the walk find, said together at the end, so one
    /// run shows all of it.
    private var findings: [String] = []

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(bundleIdentifier: Self.bundleIdentifier)
        let kept = FileManager.default.temporaryDirectory.appendingPathComponent("nullmere-ui-\(UUID().uuidString)", isDirectory: true)
        app.launchEnvironment = [
            "NULLMERE_MODEL_STATE": "ready",
            "NULLMERE_REALM": "local",
            "NULLMERE_REALM_SEED": "walked by VoiceOver",
            "NULLMERE_IDENTITY_FILE": kept.appendingPathComponent("identity").path,
            // The hosted realm and the voices, kept apart from any on this Mac.
            "NULLMERE_STORE": kept.path,
            // The news this build ships with, not whatever the repository
            // holds today.
            "NULLMERE_NEWS_URL": "https://nullmere.invalid/news.json",
            // The map offers its orders as when VoiceOver runs.
            "NULLMERE_VOICEOVER": "1",
        ]
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    /// The window is Nullmere Online; its menu, News and Settings pass the
    /// audit; Settings hold only how the lake is shown, nothing of a game
    /// played alone.
    func testTheLauncherPassesTheAudit() throws {
        let window = try openTheLauncher()
        audit("the launcher's menu")

        window.buttons["News"].click()
        XCTAssertTrue(window.buttons["Back"].waitForExistence(timeout: 10), "News opens")
        audit("News")
        window.buttons["Back"].click()

        window.buttons["Settings"].click()
        XCTAssertTrue(window.buttons["Back"].waitForExistence(timeout: 10), "Settings opens")
        for row in ["Motion", "Resolution", "Frame rate", "Text", "Full screen at launch"] {
            if !labelled(row, in: window).exists { found("UIWALK Settings has no row \(row)") }
        }
        for alone in ["Seed", "Difficulty", "Rivals", "Lake size", "House", "Single player"] {
            if labelled(alone, in: window).exists { found("UIWALK Settings offers \(alone), a game played alone") }
        }
        audit("Settings")
        window.buttons["Back"].click()
        report()
    }

    /// Without Apple Intelligence the launcher offers only what is missing,
    /// a way to mend it and Quit; that passes the audit too.
    func testTheRequirementPassesTheAudit() throws {
        app.launchEnvironment["NULLMERE_MODEL_STATE"] = "notEnabled"
        app.launch()
        window = app.windows["Nullmere Online"]
        XCTAssertTrue(window.waitForExistence(timeout: 30), "One window, named Nullmere Online")
        window.click()
        XCTAssertTrue(window.buttons["Open System Settings"].waitForExistence(timeout: 20), "What is missing, and its mending")
        XCTAssertFalse(window.buttons["Play"].exists, "No way in without the model")
        audit("the requirement")
        report()
    }

    /// A realm that doesn't answer: its door says so, offers to try again,
    /// and passes the audit.
    func testAnUnansweringRealmsDoorPassesTheAudit() throws {
        app.launchEnvironment["NULLMERE_REALM"] = "http://127.0.0.1:9/nullmere"
        let window = try openTheLauncher()
        window.buttons["Play"].click()
        XCTAssertTrue(window.buttons["Try again"].waitForExistence(timeout: 60), "Out of reach, the door offers to try again")
        audit("the door of a realm out of reach")
        report()
    }

    /// The realm's front door, entered by name, and the world beyond it:
    /// each passes the audit, the map is walked as VoiceOver walks it, and
    /// what a keeper opens over the map passes too.
    func testTheDoorAndTheWorldPassTheAuditAndTheMapIsWalked() throws {
        let window = try openTheLauncher()
        window.buttons["Play"].click()
        let name = window.textFields["Your name on the lake"]
        XCTAssertTrue(name.waitForExistence(timeout: 30), "Play crosses to the realm's door, which asks for a name")
        XCTAssertTrue(window.buttons["Enter the world"].waitForExistence(timeout: 30), "The way in")
        // The name field is being written in as the door opens; then the
        // door as it is with the field left.
        audit("the realm's front door", editing: true)
        app.typeKey(XCUIKeyboardKey.tab.rawValue, modifierFlags: [])
        audit("the realm's front door, the name field left")
        name.click()
        name.typeText("Ama\r")

        // The card a keeper first meets holds the keys and VoiceOver until
        // it is put away; the world lies behind it.
        let begin = window.buttons["Begin"]
        XCTAssertTrue(begin.waitForExistence(timeout: 60), "Entering, the seat's briefing")
        audit("the seat's briefing")
        begin.click()
        let map = labelled("The world map", in: window)
        XCTAssertTrue(map.waitForExistence(timeout: 30), "Then the world")
        audit("the world")
        walk(map, in: window)

        // Each panel over the map, opened and closed by its key.
        for (key, panel) in [("1", "Houses"), ("2", "Chronicle"), ("/", "Guide")] {
            app.typeKey(key, modifierFlags: [])
            if window.staticTexts[panel].waitForExistence(timeout: 10) {
                audit("the \(panel) panel")
                if panel == "Houses" { houses(in: window) }
            } else {
                found("UIWALK the \(panel) panel didn't open with \(key)")
            }
            app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
        }

        // The realm's Settings, over the world.
        app.typeKey(",", modifierFlags: .command)
        let done = app.buttons["Done"]
        if done.waitForExistence(timeout: 10) {
            audit("the realm's Settings")
            done.click()
        } else {
            found("UIWALK the realm's Settings didn't open with ⌘,")
        }
        report()
    }

    // MARK: The walk

    /// The map as VoiceOver walks it: an element for each hold and company
    /// the keeper knows of, the keeper's own first, each saying what it is,
    /// whose and how it stands, and lying where it is drawn, so that
    /// choosing one there selects it: a company opens its orders, the seat
    /// its works and musters.
    private func walk(_ map: XCUIElement, in window: XCUIElement) {
        let items = map.buttons.allElementsBoundByIndex
        let labels = items.map(\.label)
        print("UIMAP \(items.count) elements in \(map.frame): "
              + zip(labels, items).map { "\($0) @ \($1.frame)" }.joined(separator: " | "))
        guard items.count >= 2 else {
            found("UIWALK the map holds \(items.count) elements, not its holds and companies")
            return
        }
        if labels.first?.contains("seat, yours") != true {
            found("UIWALK the keeper's seat isn't first: \(labels.first ?? "")")
        }
        for (label, item) in zip(labels, items) where label.isEmpty || item.frame.isEmpty {
            found("UIWALK an element without words or a place: '\(label)' \(item.frame)")
        }
        let mapFrame = map.frame
        let onMap = items.filter { mapFrame.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY)) }
        guard let company = onMap.first(where: { $0.label.contains(", yours,") && $0.label.contains("health") }) else {
            found("UIWALK no company of the keeper's lies on the map in view, among: \(labels.joined(separator: " | "))")
            return
        }
        // Chosen where it lies, as VoiceOver's click there would choose it.
        let kind = String(company.label.prefix { $0 != "," })
        company.click()
        if window.staticTexts[kind].waitForExistence(timeout: 5) {
            audit("a company chosen")
        } else {
            found("UIWALK choosing '\(company.label)' at \(company.frame) opened no panel for \(kind)")
        }
        app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])

        if let seat = onMap.first(where: { $0.label.contains("seat, yours") }) {
            let hold = String(seat.label.prefix { $0 != "," })
            seat.click()
            if window.staticTexts["Works"].waitForExistence(timeout: 5) {
                audit("the seat chosen, \(hold)")
            } else {
                found("UIWALK choosing the seat '\(seat.label)' opened no panel of its works")
            }
            app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
        }
    }

    /// What the Houses panel opens for a House: the gifts to send, a trade
    /// to write, and war asked twice, never declared.
    private func houses(in window: XCUIElement) {
        let gift = window.buttons["Send a gift"].firstMatch
        if gift.waitForExistence(timeout: 5) {
            gift.click()
            if app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Send '")).element(boundBy: 1).waitForExistence(timeout: 5) {
                audit("the gifts to send")
            } else {
                found("UIWALK Send a gift opened no gifts")
            }
            app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
        } else {
            found("UIWALK the Houses panel offers no gift")
        }
        let trade = window.buttons["Offer a trade"].firstMatch
        if trade.waitForExistence(timeout: 5) {
            trade.click()
            if app.buttons["Offer"].waitForExistence(timeout: 5) {
                audit("a trade written")
            } else {
                found("UIWALK Offer a trade opened nothing to write it in")
            }
            app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
        }
        let war = window.buttons["Declare war"].firstMatch
        if war.waitForExistence(timeout: 5) {
            war.click()
            let asked = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'War on '")).firstMatch
            if asked.waitForExistence(timeout: 3) {
                audit("war asked twice")
                // Left to lapse: no war is declared.
                _ = window.buttons["Declare war"].firstMatch.waitForExistence(timeout: 15)
            } else {
                found("UIWALK Declare war asked nothing a second time")
            }
        }
    }

    // MARK: Helpers

    private func openTheLauncher() throws -> XCUIElement {
        app.launch()
        window = app.windows["Nullmere Online"]
        XCTAssertTrue(window.waitForExistence(timeout: 30), "One window, named Nullmere Online")
        // A click skips the opening, as it does for a keeper.
        window.click()
        XCTAssertTrue(window.buttons["Play"].waitForExistence(timeout: 20), "The menu, Play first")
        XCTAssertTrue(labelled("Nullmere Online", in: window).exists, "The title reads Nullmere Online")
        if let screen = NSScreen.main {
            print("UISCREEN \(screen.frame.size) at \(screen.backingScaleFactor)x; the window \(window.frame)")
        }
        return window
    }

    /// The first element under `root` with these words, of any kind: as its
    /// label, its title, or, for text, its value.
    private func labelled(_ label: String, in root: XCUIElement) -> XCUIElement {
        root.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ OR title == %@ OR value == %@", label, label, label)).firstMatch
    }

    /// The Mac's own furniture, which the app neither draws nor names: the
    /// Touch Bar macOS keeps for every window and what it shows (such as
    /// the emoji button beside a text field), above the window's top edge;
    /// and the buttons in the title bar's corner.
    private func isMacChrome(_ element: XCUIElement) -> Bool {
        if element.elementType == .touchBar || element.frame.minY < window.frame.minY { return true }
        let corner = CGRect(x: window.frame.minX, y: window.frame.minY, width: 100, height: 32)
        return element.elementType == .group && element.label.isEmpty && corner.contains(element.frame)
    }

    /// Xcode's accessibility audit of what is on screen: every issue it
    /// finds is kept, so each screen is still audited, and all are told.
    /// Where it finds type too faint, the type is measured again from the
    /// screen's own pixels, so what the audit saw is told beside it.
    private func audit(_ screen: String, editing: Bool = false) {
        // What fades in is audited once it has.
        Thread.sleep(forTimeInterval: 1.2)
        var faint: Set<String> = []
        do {
            try app.performAccessibilityAudit { issue in
                if let element = issue.element, self.isMacChrome(element) { return true }
                // A text field being written in hands its words to AppKit's
                // field editor, which names the field its parent though the
                // field doesn't list it: the Mac's own, in every app.
                if editing, issue.auditType == .parentChild, issue.element == nil {
                    print("UIAUDIT-NOTE \(screen): the field editor's parentage, AppKit's own, left aside")
                    return true
                }
                let element = issue.element.map { element in
                    "type \(element.elementType.rawValue) '\(Self.words(of: element).prefix(70))' at \(element.frame.integral)"
                } ?? "the screen (\(issue.detailedDescription.prefix(160)))"
                self.found("UIAUDIT \(screen): \(issue.compactDescription): \(element)")
                if issue.auditType == .contrast, let text = issue.element { faint.insert(Self.key(of: text)) }
                return true
            }
        } catch {
            found("UIAUDIT \(screen): the audit couldn't run: \(error)")
        }
        // Every text on screen measured, those the audit passed beside those
        // it didn't, so the rule it holds them to can be read off.
        for text in app.staticTexts.allElementsBoundByIndex.prefix(70) where text.exists && !text.frame.isEmpty {
            let verdict = faint.contains(Self.key(of: text)) ? "FAIL" : "pass"
            print("UITEXT \(verdict) h\(Int(text.frame.height)) \(Self.measured(text)) '\(Self.words(of: text).prefix(28))'")
        }
    }

    private static func words(of element: XCUIElement) -> String {
        element.label.isEmpty ? (element.value as? String ?? "") : element.label
    }

    private static func key(of element: XCUIElement) -> String {
        "\(words(of: element))|\(element.frame.integral)"
    }

    /// An element's pixels as the screen draws them: the commonest colour,
    /// taken for the ground; of the rest, those plainly apart from it, taken
    /// for the type: their commonest colour, their brightest, and how many
    /// reach nearly the brightest; each set against the ground.
    private static func measured(_ element: XCUIElement) -> String {
        guard let image = element.screenshot().image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return "unmeasured" }
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: space,
                                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn, width * height > 0 else { return "unmeasured" }
        func linear(_ byte: UInt8) -> Double {
            let value = Double(byte) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        var counts: [UInt32: Int] = [:]
        for index in stride(from: 0, to: bytes.count, by: 4) {
            counts[UInt32(bytes[index]) << 16 | UInt32(bytes[index + 1]) << 8 | UInt32(bytes[index + 2]), default: 0] += 1
        }
        func luminance(_ colour: UInt32) -> Double {
            0.2126 * linear(UInt8(colour >> 16 & 0xFF)) + 0.7152 * linear(UInt8(colour >> 8 & 0xFF)) + 0.0722 * linear(UInt8(colour & 0xFF))
        }
        func ratio(_ a: Double, _ b: Double) -> Double { (max(a, b) + 0.05) / (min(a, b) + 0.05) }
        func rgb(_ colour: UInt32) -> String { "\(colour >> 16 & 0xFF),\(colour >> 8 & 0xFF),\(colour & 0xFF)" }
        guard let ground = counts.max(by: { $0.value < $1.value })?.key else { return "unmeasured" }
        let groundLuminance = luminance(ground)
        let type = counts.filter { ratio(luminance($0.key), groundLuminance) > 1.5 }
        let total = type.values.reduce(0, +)
        guard total > 0, let mode = type.max(by: { $0.value < $1.value })?.key,
              let peak = type.keys.max(by: { ratio(luminance($0), groundLuminance) < ratio(luminance($1), groundLuminance) }) else {
            return "g\(rgb(ground)) none apart"
        }
        let peakRatio = ratio(luminance(peak), groundLuminance)
        let near = type.filter { ratio(luminance($0.key), groundLuminance) >= peakRatio * 0.85 }.values.reduce(0, +)
        return "g\(rgb(ground)) m\(rgb(mode))=\(String(format: "%.1f", ratio(luminance(mode), groundLuminance))) "
            + "p\(rgb(peak))=\(String(format: "%.1f", peakRatio)) n\(near * 100 / total)%/\(total)"
    }

    /// Kept, and said at once, so a test that stops early still tells it.
    private func found(_ finding: String) {
        print(finding)
        findings.append(finding)
    }

    private func report() {
        XCTAssertTrue(findings.isEmpty, "\(findings.count) found:\n" + findings.joined(separator: "\n"))
    }
}
