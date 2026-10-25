/// The launcher's main menu, left to right along the water.
public enum MenuItem: CaseIterable, Sendable {
    case play
    case news
    case settings
    case repository
    case quit

    public var title: String {
        switch self {
        case .play: return "Play"
        case .news: return "News"
        case .settings: return "Settings"
        case .repository: return "Repository"
        case .quit: return "Quit"
        }
    }
}

/// Keyboard input the launcher responds to, independent of AppKit.
public enum KeyCommand: Sendable, Equatable {
    case up
    case down
    case left
    case right
    case confirm
    case back

    /// Maps a macOS virtual key code (`NSEvent.keyCode`) to a command. With
    /// keyboard navigation turned on in System Settings, Space belongs to
    /// the control that has focus, so it maps to nothing.
    public init?(keyCode: UInt16, keyboardNavigation: Bool = false) {
        switch keyCode {
        case 126: self = .up
        case 125: self = .down
        case 123: self = .left
        case 124: self = .right
        case 36, 76: self = .confirm // Return, keypad Enter
        case 49 where !keyboardNavigation: self = .confirm // Space
        case 53: self = .back // Escape
        default: return nil
        }
    }

    /// Whether holding the key down repeats the command. Arrows step on;
    /// Return and Escape act once per press, so a held key can't flip a
    /// panel open and shut.
    public var repeatsWhenHeld: Bool {
        switch self {
        case .up, .down, .left, .right: return true
        case .confirm, .back: return false
        }
    }
}

extension CaseIterable where Self: Equatable, AllCases.Index == Int {
    /// The case `delta` positions away, wrapping around the ends by default.
    public func moved(by delta: Int, wrapping: Bool = true) -> Self {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self), !all.isEmpty else { return self }
        let target = index + delta
        if wrapping {
            return all[((target % all.count) + all.count) % all.count]
        }
        return all[min(max(target, 0), all.count - 1)]
    }
}
