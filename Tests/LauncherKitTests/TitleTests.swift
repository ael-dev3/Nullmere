import SwiftUI
import XCTest
@testable import LauncherKit

/// The title is "Nullmere Online", set wide as NULLMERE ONLINE, and
/// nothing else: written in one place, and placed by one view on every
/// screen on the lake, so it never changes or moves between them.
final class TitleTests: XCTestCase {
    private var sources: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources")
    }

    private func swiftFiles() throws -> [URL] {
        let walker = try XCTUnwrap(FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil))
        return walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    func testTheWordsAreExactlyNullmereOnline() {
        XCTAssertEqual(TitleBlock.text, "NULLMERE ONLINE")
        XCTAssertEqual(TitleBlock.text.capitalized, "Nullmere Online")
    }

    func testTheTitleIsWrittenInOnePlace() throws {
        let writing = try swiftFiles().filter { try String(contentsOf: $0, encoding: .utf8).contains("NULLMERE ONLINE") }
        XCTAssertEqual(writing.map(\.lastPathComponent), ["TitleBlock.swift"], "The wordmark's words, in one file")
    }

    func testEveryScreenOnTheLakeSetsTheTitleOneWay() throws {
        for name in ["LauncherRootView.swift", "FrontDoor.swift", "ModelGate.swift"] {
            let file = try XCTUnwrap(try swiftFiles().first { $0.lastPathComponent == name }, name)
            XCTAssertTrue(try String(contentsOf: file, encoding: .utf8).contains("LakeTitle(size:"), "\(name) sets the title by LakeTitle")
        }
    }

    @MainActor
    func testTheTitleRestsAboveTheShoreAtEverySize() {
        for size in [CGSize(width: 960, height: 600), CGSize(width: 1512, height: 982), CGSize(width: 2560, height: 1440)] {
            let band = LakeTitle.band(for: size)
            XCTAssertGreaterThan(band, size.height * 0.3, "Below the moon")
            XCTAssertLessThan(band, LakeTitle.waterline(for: size), "Above the water")
            let renderer = ImageRenderer(content: LakeTitle(size: size).frame(width: size.width, height: size.height).background(Color.black))
            XCTAssertNotNil(renderer.cgImage)
        }
    }
}
