import Foundation
import NullmereCore
import os

/// Keeps the game on disk, in Application Support: an autosave, written
/// after every watch and whenever the game is left or put behind another
/// app, with the save before it kept as a backup. A save that can't be read
/// is never thrown away: it is set aside under its own name.
public struct SaveStore: Sendable {
    /// What opening the saved game found.
    public enum Opened: Equatable {
        case none
        case game(GameState)
        /// The autosave couldn't be read, but its backup could.
        case recovered(GameState)
        /// Neither could be read; the autosave was moved to this file.
        case unreadable(setAside: URL)
    }

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

    /// The save before the latest.
    public var backupURL: URL {
        directory.appendingPathComponent("autosave-previous.json")
    }

    public var hasSave: Bool {
        FileManager.default.fileExists(atPath: autosaveURL.path)
    }

    public func save(_ state: GameState) {
        do {
            let files = FileManager.default
            try files.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(state)
            // Keep the last save that could be read as the backup.
            if files.fileExists(atPath: autosaveURL.path), read(autosaveURL) != nil {
                try? files.removeItem(at: backupURL)
                try? files.copyItem(at: autosaveURL, to: backupURL)
            }
            try data.write(to: autosaveURL, options: .atomic)
            if state.watch == 1, state.chronicle.count <= 1 {
                // A new game starts with nothing said.
                try? FileManager.default.removeItem(at: voicesURL)
            }
        } catch {
            SaveStore.logger.error("Saving failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The saved game, if there is one this version can read.
    public func load() -> GameState? {
        switch open() {
        case .game(let state), .recovered(let state): return state
        case .none, .unreadable: return nil
        }
    }

    /// Opens the saved game, falling back to the backup, and setting aside
    /// a save that can't be read rather than losing it.
    public func open() -> Opened {
        let files = FileManager.default
        guard files.fileExists(atPath: autosaveURL.path) else { return .none }
        if let state = read(autosaveURL) { return .game(state) }

        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let aside = directory.appendingPathComponent("autosave-unreadable-\(stamp).json")
        try? files.moveItem(at: autosaveURL, to: aside)
        SaveStore.logger.error("The save could not be read; it was set aside as \(aside.lastPathComponent, privacy: .public).")
        if let state = read(backupURL) {
            try? files.copyItem(at: backupURL, to: autosaveURL)
            return .recovered(state)
        }
        return .unreadable(setAside: aside)
    }

    private func read(_ url: URL) -> GameState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            let state = try JSONDecoder().decode(GameState.self, from: data)
            guard state.formatVersion == GameState.formatVersion else { return nil }
            return state
        } catch {
            return nil
        }
    }

    /// Forgets the game: its save, backup and voices.
    public func delete() {
        try? FileManager.default.removeItem(at: autosaveURL)
        try? FileManager.default.removeItem(at: backupURL)
        try? FileManager.default.removeItem(at: voicesURL)
    }

    // MARK: Voices

    /// What characters said, kept beside the save so a game picked up again
    /// keeps its words.
    public var voicesURL: URL {
        directory.appendingPathComponent("voices.json")
    }

    public func saveVoices(_ lines: [String: String]) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(lines).write(to: voicesURL, options: .atomic)
        } catch {
            SaveStore.logger.error("Saving voices failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func loadVoices() -> [String: String] {
        guard let data = try? Data(contentsOf: voicesURL) else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }
}
