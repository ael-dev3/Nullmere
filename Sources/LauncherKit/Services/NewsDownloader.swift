import Foundation

/// Downloads `news/news.json` from the repository's main branch.
enum NewsDownloader {
    static let feedURL = URL(string: "https://raw.githubusercontent.com/ael-dev3/Nullmere/main/news/news.json")!

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
