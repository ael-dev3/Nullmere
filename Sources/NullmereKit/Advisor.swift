import AppKit
import AVFoundation

/// What speaks the advisor's words: the Mac's own voice, or a test's ear.
@MainActor
public protocol Speaking: AnyObject {
    func say(_ words: String)
    func hush()
}

/// The Mac's own voice, a little low and unhurried, as a steward counsels.
@MainActor
final class MacVoice: Speaking {
    private let synthesizer = AVSpeechSynthesizer()

    func say(_ words: String) {
        let utterance = AVSpeechUtterance(string: words)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        utterance.pitchMultiplier = 0.9
        utterance.volume = 0.85
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB") ?? AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    func hush() {
        synthesizer.stopSpeaking(at: .word)
    }
}

/// The advisor: the House's steward, who reads each new charge aloud as it
/// comes, so the first hour's counsel is heard as well as shown. Silent
/// while VoiceOver speaks (it reads the charges itself), while the game's
/// sound is off, or when the keeper turns it off; never the same counsel
/// twice running.
@MainActor
public final class Advisor {
    /// Where the keeper's choice is kept.
    public static let defaultsKey = "advisor.speaks"

    private let voice: Speaking
    private let voiceOver: () -> Bool
    private var last: String?

    /// The keeper lets the advisor speak.
    public var isEnabled: Bool {
        didSet { if !isEnabled { voice.hush() } }
    }

    /// The game's sound is on.
    public var isSoundOn = true {
        didSet { if !isSoundOn { voice.hush() } }
    }

    public init(voice: Speaking? = nil, enabled: Bool, voiceOver: @escaping () -> Bool = { NSWorkspace.shared.isVoiceOverEnabled }) {
        self.voice = voice ?? MacVoice()
        self.isEnabled = enabled
        self.voiceOver = voiceOver
    }

    /// Speaks counsel if it may and it is new; whether it was spoken.
    @discardableResult
    public func counsel(_ words: String) -> Bool {
        guard isEnabled, isSoundOn, !voiceOver(), words != last else { return false }
        last = words
        voice.say(words)
        return true
    }
}
