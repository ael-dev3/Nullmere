import Foundation
import os

/// What this Mac keeps for its keeper, in Application Support: the words
/// characters spoke, so a world entered again keeps them, and a realm
/// hosted here. The world itself is the realm's to keep.
public struct LocalStore: Sendable {
    private static let logger = Logger(subsystem: "online.nullmere.game", category: "store")

    public let directory: URL
    /// The store an age's store was made from: what is kept across ages,
    /// as the first steps a keeper has taken, is kept there.
    let root: URL

    public init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else if let kept = Self.keptElsewhere {
            self.directory = kept
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.directory = base.appendingPathComponent("Nullmere Online", isDirectory: true)
        }
        root = self.directory
    }

    /// Debug builds may keep all of it in another folder: NULLMERE_STORE,
    /// for the UI tests, which mustn't touch what this Mac keeps.
    static var keptElsewhere: URL? {
        #if DEBUG
        if let path = ProcessInfo.processInfo.environment["NULLMERE_STORE"], !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        #endif
        return nil
    }

    private init(directory: URL, root: URL) {
        self.directory = directory
        self.root = root
    }

    /// The store for one age of one realm: its words are its own.
    public func forAge(_ age: Int, of realm: String) -> LocalStore {
        let folder = realm.map { $0.isLetter || $0.isNumber ? $0 : "-" }
        return LocalStore(directory: directory.appendingPathComponent("realms/\(String(folder))/age-\(age)", isDirectory: true), root: root)
    }

    /// Where a realm hosted on this Mac is kept.
    public var hostedRealmURL: URL {
        directory.appendingPathComponent("hosted-realm.json")
    }

    // MARK: Voices

    public var voicesURL: URL {
        directory.appendingPathComponent("voices.json")
    }

    public func saveVoices(_ lines: [String: String]) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(lines).write(to: voicesURL, options: .atomic)
        } catch {
            LocalStore.logger.error("Keeping voices failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func loadVoices() -> [String: String] {
        guard let data = try? Data(contentsOf: voicesURL) else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }
}
