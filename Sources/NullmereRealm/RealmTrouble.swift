import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// What went wrong between a keeper and the realm, in plain words: never
/// an error's raw description, its domain and code and user info.
public enum RealmTrouble {
    /// The realm module's own refusals a keeper may meet, written for them.
    public static let realmRefusals: Set<String> = [
        "Too many of your requests are waiting; give the realm a moment.",
        "The request is too long.",
    ]

    /// The device a keeper meets the trouble on, as the words name it: their
    /// Mac, or the phone that speaks for them.
    public enum Device: String, Sendable {
        case mac = "Mac"
        case phone = "phone"
    }

    public static func words(for error: any Error, on device: Device = .mac) -> String {
        if let spacetime = error as? SpacetimeError { return words(for: spacetime, on: device) }
        if let url = error as? URLError {
            switch url.code {
            case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff:
                return "This \(device.rawValue) isn't connected to the internet."
            case .timedOut:
                return "The realm didn't answer in time."
            case .cannotFindHost, .dnsLookupFailed:
                return "The realm can't be found."
            case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate,
                 .serverCertificateNotYetValid, .serverCertificateHasUnknownRoot, .clientCertificateRejected:
                return "The realm couldn't be reached safely."
            default:
                return "The realm can't be reached."
            }
        }
        if error is DecodingError {
            return "The realm answered in words this version of Nullmere Online doesn't know. A newer version may be out."
        }
        let described = error as NSError
        if described.domain == "NSOSStatusErrorDomain" {
            // A phone's keychain opens with the phone; a Mac's may be locked apart.
            return device == .mac ? "This Mac's keychain wouldn't keep your key. Unlock the keychain, then try again."
                : "This \(device.rawValue)'s keychain wouldn't keep your key. Unlock the \(device.rawValue), then try again."
        }
        return "The realm can't be reached."
    }

    /// The realm turning a device's key away for now.
    public static func unaccepted(on device: Device) -> String {
        "The realm doesn't accept this \(device.rawValue)'s key just now. The key is kept, and offered again in a while."
    }

    /// The link's own words, and the realm's own refusals, as they are;
    /// whatever else the server said, which is for whoever runs it, in plain
    /// words: never a status code, a stack or the server's own wording.
    private static func words(for spacetime: SpacetimeError, on device: Device) -> String {
        if spacetime.isUnauthorized { return unaccepted(on: device) }
        guard let status = spacetime.status, status != 401, status != 404, !realmRefusals.contains(spacetime.description) else {
            return spacetime.description
        }
        return status >= 500 ? "The realm couldn't answer just now." : "The realm couldn't take that request."
    }
}
