import Foundation
import LauncherCore
import XCTest

final class NewsTests: XCTestCase {
    func testDatesParseCompareAndPrint() throws {
        let date = try XCTUnwrap(NewsDate("2026-10-24"))
        XCTAssertEqual(date.shortText, "24 Oct 2026")
        XCTAssertEqual(date.spokenText, "24 October 2026")
        XCTAssertLessThan(try XCTUnwrap(NewsDate("2026-09-30")), date)
        XCTAssertLessThan(try XCTUnwrap(NewsDate("2025-12-31")), date)
        for invalid in ["", "2026-10", "2026-13-01", "2026-00-10", "2026-10-32", "26-10-24", "2026-1-24", "2026-+1-24", "yesterday"] {
            XCTAssertNil(NewsDate(invalid), invalid)
        }
    }

    func testFeedIsSortedNewestFirstAndKeepsSameDayOrder() throws {
        let json = """
        {"items": [
          {"id": "a", "date": "2026-10-01", "title": "Older", "body": "First written."},
          {"id": "b", "date": "2026-10-24", "title": "Newest", "body": "Second written."},
          {"id": "c", "date": "2026-10-24", "title": "Newest too", "body": "Third written."}
        ]}
        """
        let feed = try NewsFeed(json: Data(json.utf8))
        XCTAssertEqual(feed.items.map(\.id), ["b", "c", "a"])
    }

    func testBadEntriesAreSkippedAndUnsafeLinksDropped() throws {
        let json = """
        {"items": [
          {"date": "2026-10-24", "title": "  Kept  ", "body": "Has no id.", "link": "https://nullmere.online/news"},
          {"id": "no-title", "date": "2026-10-24", "body": "Missing its title."},
          {"id": "bad-date", "date": "24/10/2026", "title": "Bad date", "body": "Skipped."},
          {"id": "wrong-type", "date": "2026-10-24", "title": 7, "body": "Skipped."},
          "not an object",
          {"id": "plain", "date": "2026-10-23", "title": "Plain link", "body": "Dropped link.", "link": "http://example.com"},
          {"id": "script", "date": "2026-10-22", "title": "Script link", "body": "Dropped link.", "link": "javascript:alert(1)"},
          {"id": "plain", "date": "2026-10-21", "title": "Repeated id", "body": "Dropped."}
        ]}
        """
        let feed = try NewsFeed(json: Data(json.utf8))
        XCTAssertEqual(feed.items.map(\.title), ["Kept", "Plain link", "Script link"])
        XCTAssertEqual(feed.items[0].link, URL(string: "https://nullmere.online/news"))
        XCTAssertFalse(feed.items[0].id.isEmpty)
        XCTAssertNil(feed.items[1].link)
        XCTAssertNil(feed.items[2].link)
    }

    func testLongTextIsCut() throws {
        let long = String(repeating: "lake ", count: 400)
        let json = "{\"items\": [{\"date\": \"2026-10-24\", \"title\": \"\(long)\", \"body\": \"\(long)\"}]}"
        let item = try XCTUnwrap(NewsFeed(json: Data(json.utf8)).items.first)
        XCTAssertEqual(item.title.count, NewsItem.maximumTitleLength)
        XCTAssertEqual(item.body.count, NewsItem.maximumBodyLength)
    }

    func testFeedsWithoutUsableEntriesAreRejected() {
        XCTAssertThrowsError(try NewsFeed(json: Data("{\"items\": []}".utf8))) { error in
            XCTAssertEqual(error as? NewsFeed.ParseError, .noEntries)
        }
        XCTAssertThrowsError(try NewsFeed(json: Data("<html>404</html>".utf8)))
        XCTAssertThrowsError(try NewsFeed(json: Data("{\"news\": []}".utf8)))
    }

    /// The launcher ships with the same news the repository publishes.
    func testBuiltInNewsMatchesTheRepositoryFeed() throws {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("news/news.json")
        let feed = try NewsFeed(json: Data(contentsOf: file))
        XCTAssertEqual(feed, NewsFeed.builtIn)
        XCTAssertFalse(NewsFeed.builtIn.items.isEmpty)
    }
}
