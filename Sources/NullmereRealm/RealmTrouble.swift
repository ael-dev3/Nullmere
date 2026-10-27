import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// What went wrong between a keeper and the realm, in plain words: never
/// an error's raw description, its domain and code and user info.
public enum RealmTrouble {
    public static func words(for error: any Error) -> String {
        if let spacetime = error as? SpacetimeError { return spacetime.description }
        if let url = error as? URLError {
            switch url.code {
            case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff:
                return "This Mac isn't connected to the internet."
            case .timedOut:
                return "The realm's server didn't answer in time."
            case .cannotFindHost, .dnsLookupFailed:
                return "The realm's server can't be found."
            case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate,
                 .serverCertificateNotYetValid, .serverCertificateHasUnknownRoot, .clientCertificateRejected:
                return "The realm's server couldn't be reached safely."
            default:
                return "The realm's server can't be reached."
            }
        }
        if error is DecodingError {
            return "The realm answered in words this version of Nullmere Online doesn't know. A newer version may be out."
        }
        let described = error as NSError
        if described.domain == "NSOSStatusErrorDomain" {
            return "This Mac's keychain wouldn't keep the realm's key. Unlock the keychain, then try again."
        }
        return "The realm can't be reached."
    }
}
