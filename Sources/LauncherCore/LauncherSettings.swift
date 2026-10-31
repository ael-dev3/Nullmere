import Foundation

/// How much the backdrop and interface are allowed to move.
public enum MotionPreference: String, CaseIterable, Sendable {
    /// Follow the system "Reduce motion" accessibility setting.
    case system
    case full
    case reduced
    case still

    public var title: String {
        switch self {
        case .system: return "System"
        case .full: return "Full"
        case .reduced: return "Reduced"
        case .still: return "Still"
        }
    }

    public func resolved(systemReducesMotion: Bool) -> ResolvedMotion {
        switch self {
        case .system: return systemReducesMotion ? .reduced : .full
        case .full: return .full
        case .reduced: return .reduced
        case .still: return .still
        }
    }
}

/// A motion preference with the system setting applied.
public enum ResolvedMotion: Sendable, Equatable {
    case full
    case reduced
    case still

    /// Speed of the scene clock relative to real time.
    public var clockRate: Double {
        switch self {
        case .full: return 1
        case .reduced: return 0.35
        case .still: return 0
        }
    }

    /// How lively the scene is, 0...1. It scales the stars' flicker; only at
    /// full motion do stars fall.
    public var activity: Float {
        switch self {
        case .full: return 1
        case .reduced: return 0.4
        case .still: return 0
        }
    }
}

/// Resolution of the backdrop relative to the display's native pixels.
public enum RenderQuality: String, CaseIterable, Sendable {
    case native
    case balanced
    case efficient

    public var title: String {
        switch self {
        case .native: return "Native"
        case .balanced: return "Balanced"
        case .efficient: return "Efficient"
        }
    }

    public var scale: Double {
        switch self {
        case .native: return 1
        case .balanced: return 0.75
        case .efficient: return 0.5
        }
    }
}

/// The highest frame rate the backdrop renders at.
public enum FrameRateCap: Int, CaseIterable, Sendable {
    case thirty = 30
    case sixty = 60
    case oneTwenty = 120

    public var title: String { String(rawValue) }

    /// The rate the lake renders at: the cap at full motion, otherwise at
    /// most 30 frames a second. Reduced motion is slow enough for 30, and
    /// the lake drops to 30 while the Mac saves energy or the launcher is
    /// behind another app.
    public func framesPerSecond(motion: ResolvedMotion, isSavingEnergy: Bool) -> Int {
        guard motion == .full, !isSavingEnergy else {
            return min(rawValue, FrameRateCap.thirty.rawValue)
        }
        return rawValue
    }
}

/// Launcher preferences, persisted in user defaults: how the lake and the
/// map are drawn, and the type's size, set in the launcher's Settings and
/// the realm's alike.
public struct LauncherSettings: Equatable, Sendable {
    public var motion: MotionPreference
    public var quality: RenderQuality
    public var frameRate: FrameRateCap
    /// All the type a fifth larger, the launcher's and the game's.
    public var largerText: Bool
    /// The score: the title theme of the lake over the launcher, and the
    /// realm's music within it, one choice for both.
    public var music: Bool
    public var startsInFullScreen: Bool

    public init(
        motion: MotionPreference = .system,
        quality: RenderQuality = .native,
        frameRate: FrameRateCap = .sixty,
        largerText: Bool = false,
        music: Bool = true,
        startsInFullScreen: Bool = false
    ) {
        self.motion = motion
        self.quality = quality
        self.frameRate = frameRate
        self.largerText = largerText
        self.music = music
        self.startsInFullScreen = startsInFullScreen
    }

    enum Key {
        static let motion = "launcher.motion"
        static let quality = "launcher.renderQuality"
        static let frameRate = "launcher.frameRate"
        /// Where Larger Text has always kept its choice.
        static let largerText = "text.larger"
        /// Where the realm's Music has always kept its choice.
        static let music = "music.enabled"
        static let startsInFullScreen = "launcher.startsInFullScreen"
    }

    /// Reads stored settings. Missing or unrecognised values fall back to defaults.
    public init(defaults: UserDefaults) {
        self.init()
        if let raw = defaults.string(forKey: Key.motion), let value = MotionPreference(rawValue: raw) {
            motion = value
        }
        if let raw = defaults.string(forKey: Key.quality), let value = RenderQuality(rawValue: raw) {
            quality = value
        }
        if let value = FrameRateCap(rawValue: defaults.integer(forKey: Key.frameRate)) {
            frameRate = value
        }
        largerText = defaults.bool(forKey: Key.largerText)
        music = defaults.object(forKey: Key.music) as? Bool ?? true
        startsInFullScreen = defaults.bool(forKey: Key.startsInFullScreen)
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(motion.rawValue, forKey: Key.motion)
        defaults.set(quality.rawValue, forKey: Key.quality)
        defaults.set(frameRate.rawValue, forKey: Key.frameRate)
        defaults.set(largerText, forKey: Key.largerText)
        defaults.set(music, forKey: Key.music)
        defaults.set(startsInFullScreen, forKey: Key.startsInFullScreen)
    }
}

/// The rows of the settings panel, in display order.
public enum SettingsRow: CaseIterable, Sendable {
    case motion
    case quality
    case frameRate
    case text
    case music
    case startsInFullScreen

    public var title: String {
        switch self {
        case .motion: return "Motion"
        case .quality: return "Resolution"
        case .frameRate: return "Frame rate"
        case .text: return "Text"
        case .music: return "Music"
        case .startsInFullScreen: return "Full screen at launch"
        }
    }
}

extension LauncherSettings {
    /// The choices shown for a settings row.
    public func options(for row: SettingsRow) -> [String] {
        switch row {
        case .motion: return MotionPreference.allCases.map(\.title)
        case .quality: return RenderQuality.allCases.map(\.title)
        case .frameRate: return FrameRateCap.allCases.map(\.title)
        case .text: return ["Standard", "Larger"]
        case .music, .startsInFullScreen: return ["Off", "On"]
        }
    }

    /// The index of the current choice within `options(for:)`.
    public func selectedIndex(for row: SettingsRow) -> Int {
        switch row {
        case .motion: return MotionPreference.allCases.firstIndex(of: motion) ?? 0
        case .quality: return RenderQuality.allCases.firstIndex(of: quality) ?? 0
        case .frameRate: return FrameRateCap.allCases.firstIndex(of: frameRate) ?? 0
        case .text: return largerText ? 1 : 0
        case .music: return music ? 1 : 0
        case .startsInFullScreen: return startsInFullScreen ? 1 : 0
        }
    }

    /// Chooses an option by index. Out-of-range indices are ignored.
    public mutating func select(_ index: Int, for row: SettingsRow) {
        guard options(for: row).indices.contains(index) else { return }
        switch row {
        case .motion: motion = MotionPreference.allCases[index]
        case .quality: quality = RenderQuality.allCases[index]
        case .frameRate: frameRate = FrameRateCap.allCases[index]
        case .text: largerText = index == 1
        case .music: music = index == 1
        case .startsInFullScreen: startsInFullScreen = index == 1
        }
    }

    /// Moves a row's choice left or right, stopping at the ends unless `wrapping`.
    public mutating func step(_ row: SettingsRow, by delta: Int, wrapping: Bool = false) {
        let count = options(for: row).count
        let index = selectedIndex(for: row) + delta
        select(wrapping ? ((index % count) + count) % count : min(max(index, 0), count - 1), for: row)
    }
}
