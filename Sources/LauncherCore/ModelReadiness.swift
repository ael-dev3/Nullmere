/// Whether this Mac can run Apple's on-device language model, the roughly
/// 3-billion-parameter model behind Apple Intelligence. Nullmere requires it:
/// its characters will speak through it, and the launcher shows nothing but
/// what is missing until it is ready. LauncherKit reads the state from the
/// Foundation Models framework.
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
            return "Nullmere needs Apple's on-device model. This Mac is being checked for it."
        case .ready:
            return "Apple's on-device model is here, and Nullmere's characters will speak through it."
        case .deviceNotEligible:
            return "Nullmere's characters speak through Apple's on-device model, which needs a Mac that supports Apple Intelligence. This Mac doesn't, so Nullmere can't run here."
        case .appleIntelligenceNotEnabled:
            return "Nullmere's characters speak through Apple's on-device model. Turn on Apple Intelligence in System Settings, and Nullmere opens by itself."
        case .modelNotReady:
            return "Apple's on-device model isn't ready yet, usually because it's still downloading. Nullmere opens by itself once it is."
        case .unavailable:
            return "macOS reports that Apple's on-device model can't be used right now. Check Apple Intelligence in System Settings; Nullmere opens by itself once the model is available."
        }
    }

    /// What the requirement screen offers in this state. Nothing is offered
    /// while the launcher is still checking, so a stray key can't quit.
    public var actions: [RequirementAction] {
        switch self {
        case .checking, .ready: return []
        case .appleIntelligenceNotEnabled, .unavailable: return [.openSystemSettings, .quit]
        case .deviceNotEligible, .modelNotReady: return [.quit]
        }
    }
}

/// A choice on the requirement screen, the only screen the launcher shows
/// until the on-device model is ready.
public enum RequirementAction: Equatable, Sendable {
    case openSystemSettings
    case quit

    public var title: String {
        switch self {
        case .openSystemSettings: return "Open System Settings"
        case .quit: return "Quit"
        }
    }
}

/// What choosing Play does.
public enum PlayOutcome: Equatable, Sendable {
    /// Cross from the launcher to the realm's front door.
    case enterRealm
    /// Explain why this Mac can't play yet.
    case explainRequirement(ModelReadiness)
    /// The Mac is ready, but this launcher has no way into a realm.
    case awaitFirstRealm

    public init(readiness: ModelReadiness, canEnterRealm: Bool) {
        if !readiness.allowsPlay {
            self = .explainRequirement(readiness)
        } else if canEnterRealm {
            self = .enterRealm
        } else {
            self = .awaitFirstRealm
        }
    }
}
