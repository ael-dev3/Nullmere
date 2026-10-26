import Foundation

/// Downloads `news/news.json` from the repository's main branch.
enum NewsDownloader {
    static let mainFeedURL = URL(string: "https://raw.githubusercontent.com/ael-dev3/Nullmere/main/news/news.json")!

    /// The feed on `main`. Debug builds can read another `https` feed with
    /// NULLMERE_NEWS_URL, such as a branch's copy, so CI can check the whole
    /// download before the feed reaches `main`.
    static var feedURL: URL {
        #if DEBUG
        if let override = ProcessInfo.processInfo.environment["NULLMERE_NEWS_URL"],
           let url = URL(string: override), url.scheme == "https" {
            return url
        }
        #endif
        return mainFeedURL
    }

    /// Anything larger is not news.
    static let maximumSize = 256 * 1024

    static func download() async throws -> Data {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }

        let (data, response) = try await session.data(from: feedURL)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        guard data.count <= maximumSize else {
            throw URLError(.dataLengthExceedsMaximum)
        }
        return data
    }
}
