import XCTest

/// Nullmere Online as VoiceOver and Accessibility Inspector meet it, through
/// the Mac's own accessibility: the app opened as a keeper opens it, every
/// screen put to Xcode's accessibility audit, and the lake's map walked
/// through the elements VoiceOver reads.
///
/// It opens the debug build CI makes (`CONFIGURATION=debug
/// scripts/build-app.sh`) and registers with Launch Services: only a debug
/// build reads the variables that open it as a Mac whose on-device model is
/// ready would, with a realm of its own.
final class NullmereUITests: XCTestCase {
    private static let bundleIdentifier = "online.nullmere.launcher"

    private var app: XCUIApplication!
    /// What the audits and the walk find, said together at the end, so one
    /// run shows all of it.
    private var findings: [String] = []

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(bundleIdentifier: Self.bundleIdentifier)
        let identity = FileManager.default.temporaryDirectory.appendingPathComponent("nullmere-ui-\(UUID().uuidString)")
        app.launchEnvironment = [
            "NULLMERE_MODEL_STATE": "ready",
            "NULLMERE_REALM": "local",
            "NULLMERE_REALM_SEED": "walked by VoiceOver",
            "NULLMERE_IDENTITY_FILE": identity.path,
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

    /// The realm's front door, entered by name, and the world beyond it:
    /// each passes the audit, and the map is walked as VoiceOver walks it.
    func testTheDoorAndTheWorldPassTheAuditAndTheMapIsWalked() throws {
        let window = try openTheLauncher()
        window.buttons["Play"].click()
        let name = window.textFields["Your name on the lake"]
        XCTAssertTrue(name.waitForExistence(timeout: 30), "Play crosses to the realm's door, which asks for a name")
        XCTAssertTrue(window.buttons["Enter the world"].waitForExistence(timeout: 30), "The way in")
        audit("the realm's front door")
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
            } else {
                found("UIWALK the \(panel) panel didn't open with \(key)")
            }
            app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
        }
        report()
    }

    // MARK: The walk

    /// The map as VoiceOver walks it: an element for each hold and company
    /// the keeper knows of, the keeper's own first, each saying what it is,
    /// whose and how it stands, and lying where it is drawn, so that
    /// choosing one there selects it.
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
    }

    // MARK: Helpers

    private func openTheLauncher() throws -> XCUIElement {
        app.launch()
        let window = app.windows["Nullmere Online"]
        XCTAssertTrue(window.waitForExistence(timeout: 30), "One window, named Nullmere Online")
        // A click skips the opening, as it does for a keeper.
        window.click()
        XCTAssertTrue(window.buttons["Play"].waitForExistence(timeout: 20), "The menu, Play first")
        XCTAssertTrue(labelled("Nullmere Online", in: window).exists, "The title reads Nullmere Online")
        return window
    }

    /// The first element under `root` with these words, of any kind.
    private func labelled(_ label: String, in root: XCUIElement) -> XCUIElement {
        root.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    /// Xcode's accessibility audit of what is on screen: every issue it
    /// finds is kept, so each screen is still audited, and all are told.
    private func audit(_ screen: String) {
        do {
            try app.performAccessibilityAudit { issue in
                let element = issue.element.map { element in
                    let described = element.debugDescription.split(separator: "\n").prefix(2).joined(separator: " / ")
                    return "\(element.elementType.rawValue) '\(element.label)' \(element.frame) [\(described.prefix(300))]"
                } ?? "the screen"
                self.found("UIAUDIT \(screen): \(issue.compactDescription). \(issue.detailedDescription) Element: \(element)")
                return true
            }
        } catch {
            found("UIAUDIT \(screen): the audit couldn't run: \(error)")
        }
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
