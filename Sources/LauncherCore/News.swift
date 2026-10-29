import Foundation

/// A calendar day as written in the news feed: `YYYY-MM-DD`.
public struct NewsDate: Comparable, Hashable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    private static let monthAbbreviations = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ]
    private static let monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December",
    ]

    public init?(year: Int, month: Int, day: Int) {
        guard year >= 1, (1...12).contains(month), (1...31).contains(day) else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    /// Parses `YYYY-MM-DD`.
    public init?(_ text: String) {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ part in part.allSatisfy { $0.isASCII && $0.isNumber } }),
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    public static func < (lhs: NewsDate, rhs: NewsDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    /// "24 Oct 2026".
    public var shortText: String {
        "\(day) \(Self.monthAbbreviations[month - 1]) \(year)"
    }

    /// "24 October 2026", for VoiceOver.
    public var spokenText: String {
        "\(day) \(Self.monthNames[month - 1]) \(year)"
    }
}

/// One entry in the launcher's news.
public struct NewsItem: Identifiable, Equatable, Sendable {
    /// Longer text is cut so a story always fits its panel, even in the
    /// smallest window.
    public static let maximumTitleLength = 80
    public static let maximumBodyLength = 280

    public let id: String
    public let date: NewsDate
    public let title: String
    public let body: String
    /// An https link to read more, if the entry has one.
    public let link: URL?

    public init(id: String, date: NewsDate, title: String, body: String, link: URL? = nil) {
        self.id = id
        self.date = date
        self.title = title
        self.body = body
        self.link = link
    }

    /// Accepts only absolute https links, so a feed can't open other schemes.
    public static func secureLink(_ text: String) -> URL? {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https",
              let host = url.host, !host.isEmpty
        else { return nil }
        return url
    }
}

/// The launcher's news, newest first.
public struct NewsFeed: Equatable, Sendable {
    public enum ParseError: Error, Equatable {
        /// The feed parsed but held no usable entries.
        case noEntries
    }

    public let items: [NewsItem]

    /// Orders entries newest first. Entries from the same day keep their
    /// order, and an entry whose id repeats an earlier one is dropped.
    public init(items: [NewsItem]) {
        var seen = Set<String>()
        let unique = items.filter { seen.insert($0.id).inserted }
        self.items = unique.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.date != rhs.element.date {
                    return lhs.element.date > rhs.element.date
                }
                return lhs.offset < rhs.offset
            }
            .map { $0.element }
    }

    /// Reads a feed in the format of `news/news.json`:
    ///
    ///     { "items": [ { "id": "…", "date": "2026-10-24", "title": "…", "body": "…", "link": "https://…" } ] }
    ///
    /// Entries without a title, body or valid date are skipped, links other
    /// than https are dropped, and long text is cut to a length the panel can
    /// show. The id is optional.
    public init(json data: Data) throws {
        let raw = try JSONDecoder().decode(RawFeed.self, from: data)
        let items = raw.items.compactMap(NewsItem.init(raw:))
        guard !items.isEmpty else { throw ParseError.noEntries }
        self.init(items: items)
    }
}

extension NewsFeed {
    /// The news the launcher ships with, shown until a newer feed arrives.
    /// It matches `news/news.json`; a test keeps the two in step.
    public static let builtIn = NewsFeed(items: [
        NewsItem(
            id: "still-water",
            date: NewsDate(year: 2026, month: 10, day: 27)!,
            title: "Still water",
            body: "The lake has gone dead still. It holds the full moon whole and gives back every star above it, black glass from shore to shore. On the map, too, the water lies unmoving, a black mirror for the moon and every star.",
            link: URL(string: "https://github.com/ael-dev3/Nullmere")
        ),
        NewsItem(
            id: "twelve-seats",
            date: NewsDate(year: 2026, month: 10, day: 26)!,
            title: "Twelve seats around the lake",
            body: "Nullmere Online is one realm, shared by every keeper. Enter under a name of your choosing and hold one of twelve seats. Your orders take effect at once; when the watch turns, the stewards act and the lake yields. The realm opens with the first release.",
            link: nil
        ),
        NewsItem(
            id: "full-moon",
            date: NewsDate(year: 2026, month: 10, day: 24)!,
            title: "A full moon over Nullmere",
            body: "The launcher now opens on the lake under a full moon. The water moves, the stars flicker, and now and then one falls. Play, News, Settings and Repository live here while the first realm is shaped.",
            link: URL(string: "https://github.com/ael-dev3/Nullmere")
        ),
        NewsItem(
            id: "apple-intelligence",
            date: NewsDate(year: 2026, month: 10, day: 24)!,
            title: "Made for Apple Intelligence",
            body: "Nullmere Online runs on Macs with Apple silicon and macOS 26 or later, with Apple Intelligence turned on. Its characters will speak through Apple's on-device model, so the launcher checks that your Mac has it before you cross.",
            link: nil
        ),
        NewsItem(
            id: "out-of-warpkeep",
            date: NewsDate(year: 2026, month: 10, day: 24)!,
            title: "Out of Warpkeep",
            body: "Nullmere keeps Warpkeep's universe and principles, and leaves its Farcaster identity behind. The notes on what carries over are in the repository.",
            link: URL(string: "https://github.com/ael-dev3/Nullmere/blob/main/docs/warpkeep-carryover.md")
        ),
    ])
}

// MARK: Decoding

/// The feed as written, before validation.
private struct RawFeed: Decodable {
    var items: [RawItem]
}

/// One entry as written. Every field is optional and a field of the wrong
/// type reads as missing, so one bad entry doesn't spoil the feed.
private struct RawItem: Decodable {
    var id: String?
    var date: String?
    var title: String?
    var body: String?
    var link: String?

    private enum CodingKeys: String, CodingKey {
        case id, date, title, body, link
    }

    init(from decoder: any Decoder) throws {
        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else { return }
        id = try? container.decode(String.self, forKey: .id)
        date = try? container.decode(String.self, forKey: .date)
        title = try? container.decode(String.self, forKey: .title)
        body = try? container.decode(String.self, forKey: .body)
        link = try? container.decode(String.self, forKey: .link)
    }
}

private extension NewsItem {
    init?(raw: RawItem) {
        let title = raw.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let body = raw.body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty, !body.isEmpty,
              let date = raw.date.flatMap({ NewsDate($0) })
        else { return nil }
        let id = raw.id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.init(
            id: id.isEmpty ? "\(date.shortText) \(title)" : id,
            date: date,
            title: String(title.prefix(Self.maximumTitleLength)),
            body: String(body.prefix(Self.maximumBodyLength)),
            link: raw.link.flatMap { Self.secureLink($0) }
        )
    }
}
