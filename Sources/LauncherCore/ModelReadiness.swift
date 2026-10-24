/// Whether this Mac can run Apple's on-device language model, the roughly
/// 3-billion-parameter model behind Apple Intelligence. Nullmere requires it:
/// its characters will speak through it. LauncherKit reads the state from
/// the Foundation Models framework.
public enum ModelReadiness: Equatable, Sendable {
    /// Not checked yet.
    case checking
    /// The on-device model is available.
    case ready
    /// This Mac doesn't support Apple Intelligence.
    case deviceNotEligible
    /// Apple Intelligence is turned off in System Settings.
    case appleIntelligenceNotEnabled
    /// The model is still downloading, or otherwise not ready yet.
    case modelNotReady
    /// Unavailable for a reason this version of the launcher doesn't know.
    case unavailable

    public var allowsPlay: Bool {
        self == .ready
    }

    /// Whether the state can still change while the launcher is open, so it
    /// is worth checking again.
    public var needsRecheck: Bool {
        switch self {
        case .ready, .deviceNotEligible: return false
        case .checking, .appleIntelligenceNotEnabled, .modelNotReady, .unavailable: return true
        }
    }

    /// Whether System Settings is where the person can fix it.
    public var isFixedInSystemSettings: Bool {
        self == .appleIntelligenceNotEnabled || self == .unavailable
    }

    /// A few words for the footer.
    public var status: String {
        switch self {
        case .checking: return "Checking Apple Intelligence"
        case .ready: return "On-device model ready"
        case .deviceNotEligible: return "Apple Intelligence not supported"
        case .appleIntelligenceNotEnabled: return "Apple Intelligence is off"
        case .modelNotReady: return "On-device model downloading"
        case .unavailable: return "On-device model unavailable"
        }
    }

    /// The heading Play shows for this state.
    public var headline: String {
        switch self {
        case .checking: return "Checking this Mac"
        case .ready: return "This Mac is ready"
        case .deviceNotEligible: return "This Mac can't run Nullmere"
        case .appleIntelligenceNotEnabled: return "Apple Intelligence is off"
        case .modelNotReady: return "The model is still arriving"
        case .unavailable: return "The model is unavailable"
        }
    }

    /// One or two sentences under the heading.
    public var explanation: String {
        switch self {
        case .checking:
            return "The launcher is checking for Apple's on-device model."
        case .ready:
            return "Apple's on-device model is here, and Nullmere's characters will speak through it."
        case .deviceNotEligible:
            return "Nullmere's characters speak through Apple's on-device model, which needs a Mac that supports Apple Intelligence. This Mac doesn't."
        case .appleIntelligenceNotEnabled:
            return "Nullmere's characters speak through Apple's on-device model. Turn on Apple Intelligence in System Settings, then come back to the shore."
        case .modelNotReady:
            return "Apple's on-device model isn't ready yet, usually because it's still downloading. Stay here, and Play continues by itself once it is."
        case .unavailable:
            return "macOS reports that Apple's on-device model can't be used right now. Check Apple Intelligence in System Settings."
        }
    }
}

/// What choosing Play does.
public enum PlayOutcome: Equatable, Sendable {
    /// Open the installed game client.
    case launchGame
    /// Explain why this Mac can't play yet.
    case explainRequirement(ModelReadiness)
    /// The Mac is ready, but there is no game client yet: the first realm
    /// hasn't opened.
    case awaitFirstRealm

    public init(readiness: ModelReadiness, isGameInstalled: Bool) {
        if !readiness.allowsPlay {
            self = .explainRequirement(readiness)
        } else if isGameInstalled {
            self = .launchGame
        } else {
            self = .awaitFirstRealm
        }
    }
}
