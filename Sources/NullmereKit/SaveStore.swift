import Foundation
import NullmereCore
import os

/// Keeps the game on disk: one autosave, written after every watch, in
/// Application Support.
public struct SaveStore: Sendable {
    private static let logger = Logger(subsystem: "online.nullmere.game", category: "saves")

    public let directory: URL

    public init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.directory = base.appendingPathComponent("Nullmere", isDirectory: true)
        }
    }

    public var autosaveURL: URL {
        directory.appendingPathComponent("autosave.json")
    }

    public var hasSave: Bool {
        FileManager.default.fileExists(atPath: autosaveURL.path)
    }

    public func save(_ state: GameState) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(state)
            try data.write(to: autosaveURL, options: .atomic)
        } catch {
            SaveStore.logger.error("Saving failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The saved game, if there is one this version can read.
    public func load() -> GameState? {
        guard let data = try? Data(contentsOf: autosaveURL) else { return nil }
        do {
            let state = try JSONDecoder().decode(GameState.self, from: data)
            guard state.formatVersion == GameState.formatVersion else { return nil }
            return state
        } catch {
            SaveStore.logger.error("The save could not be read: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    public func delete() {
        try? FileManager.default.removeItem(at: autosaveURL)
    }
}
