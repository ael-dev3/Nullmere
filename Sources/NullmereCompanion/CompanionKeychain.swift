import Foundation
import NullmereRealm
import Security
import SwiftUI

/// The phone's own identity on a realm, kept in its keychain for this
/// device alone: never synced to another device nor restored to one from a
/// backup, so a phone's key is the phone's, and a lost phone is let go
/// from the keeper's Mac without touching their own key.
struct CompanionKeychain: IdentityStore {
    private let service = "online.nullmere.companion"
    private let account: String

    init(realm: URL) {
        account = URLComponents(url: realm, resolvingAgainstBaseURL: false)?.host ?? realm.absoluteString
    }

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    func load() -> String? {
        var search = query
        search[kSecReturnData as String] = true
        search[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(search as CFDictionary, &item) == errSecSuccess, let data = item as? Data else {
            #if DEBUG && targetEnvironment(simulator)
            return try? String(contentsOf: fallback, encoding: .utf8)
            #else
            return nil
            #endif
        }
        return String(data: data, encoding: .utf8)
    }

    func save(_ identity: String) throws {
        let data = Data(identity.utf8)
        let update = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let status = SecItemAdd(item as CFDictionary, nil)
            #if DEBUG && targetEnvironment(simulator)
            if status == errSecMissingEntitlement { return try keepInFallback(data) }
            #endif
            guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
        } else if update != errSecSuccess {
            #if DEBUG && targetEnvironment(simulator)
            if update == errSecMissingEntitlement { return try keepInFallback(data) }
            #endif
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(update))
        }
    }

    #if DEBUG && targetEnvironment(simulator)
    /// Where a debug build run in the simulator keeps its key when the
    /// simulator's keychain refuses an app not signed by a developer team:
    /// in the app's own container, protected until first unlock. Never in a
    /// device build, nor a release one; the smoke test's report says which.
    var fallback: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("identity-\(account).json")
    }

    private func keepInFallback(_ data: Data) throws {
        try FileManager.default.createDirectory(at: fallback.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fallback, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    #endif
}

/// The night the lake is shown in: the Mac's palette, on the phone.
enum Night {
    static let background = Color(red: 0.035, green: 0.055, blue: 0.10)
    static let panel = Color(red: 0.07, green: 0.10, blue: 0.16)
    static let ink = Color(red: 0.92, green: 0.89, blue: 0.81)
    static let moon = Color(red: 0.85, green: 0.78, blue: 0.58)
    static let good = Color(red: 0.55, green: 0.80, blue: 0.62)
    static let bad = Color(red: 0.95, green: 0.55, blue: 0.48)

    static let title = Font.system(.largeTitle, design: .serif).weight(.light)
    static let heading = Font.system(.title3, design: .serif)
    static let body = Font.system(.body, design: .serif)
    static let small = Font.system(.footnote, design: .serif)
    static let figures = Font.system(.body, design: .serif).monospacedDigit()
}
