import Foundation
import FoundationModels
import LauncherCore

/// Where the answer about Apple's on-device model comes from. The apps ask
/// the system; tests supply a fake that can be set to any state.
public protocol ModelAvailabilityProvider: Sendable {
    var availability: SystemLanguageModel.Availability { get }
}

/// The Foundation Models framework's own answer for this Mac.
public struct SystemModelAvailability: ModelAvailabilityProvider {
    public init() {}

    public var availability: SystemLanguageModel.Availability {
        SystemLanguageModel.default.availability
    }
}

/// Reads whether Apple's on-device model can be used on this Mac. Nullmere
/// Online and Nullmere both ask here.
public enum OnDeviceModel {
    /// This Mac's state, as the Foundation Models framework reports it, or
    /// in a debug build as NULLMERE_MODEL_STATE names it.
    public static func current() -> ModelReadiness {
        debugReadiness ?? readiness(from: SystemModelAvailability())
    }

    /// The state a provider reports.
    public static func readiness(from provider: any ModelAvailabilityProvider) -> ModelReadiness {
        readiness(for: provider.availability)
    }

    public static func readiness(for availability: SystemLanguageModel.Availability) -> ModelReadiness {
        switch availability {
        case .available:
            return .ready
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return .deviceNotEligible
            case .appleIntelligenceNotEnabled:
                return .appleIntelligenceNotEnabled
            case .modelNotReady:
                return .modelNotReady
            @unknown default:
                return .unavailable
            }
        }
    }

    /// Debug builds can stand in any state, so every screen can be opened
    /// and photographed on a machine without Apple Intelligence, such as
    /// CI: NULLMERE_MODEL_STATE=ready, notEligible, notEnabled, downloading
    /// or unavailable (NULLMERE_SKIP_MODEL_CHECK=1 means ready). Release
    /// builds always ask the Foundation Models framework.
    public static var debugReadiness: ModelReadiness? {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        if let state = environment["NULLMERE_MODEL_STATE"] {
            return readiness(named: state)
        }
        return environment["NULLMERE_SKIP_MODEL_CHECK"] == "1" ? .ready : nil
        #else
        return nil
        #endif
    }

    static func readiness(named name: String) -> ModelReadiness? {
        switch name.lowercased() {
        case "ready", "available": return .ready
        case "noteligible", "devicenoteligible": return .deviceNotEligible
        case "notenabled", "appleintelligencenotenabled": return .appleIntelligenceNotEnabled
        case "downloading", "notready", "modelnotready": return .modelNotReady
        case "unavailable": return .unavailable
        default: return nil
        }
    }
}
