import FoundationModels
import LauncherCore

/// Reads whether Apple's on-device language model can be used on this Mac.
enum OnDeviceModel {
    /// The current state, as the Foundation Models framework reports it.
    static func readiness() -> ModelReadiness {
        readiness(for: SystemLanguageModel.default.availability)
    }

    static func readiness(for availability: SystemLanguageModel.Availability) -> ModelReadiness {
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
}
