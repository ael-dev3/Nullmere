import Security
import XCTest
@testable import NullmereKit

/// The keeper's identity kept in the keychain: saved, read back, replaced.
final class KeychainStoreTests: XCTestCase {
    func testAnIdentityIsKeptAndReplaced() throws {
        let realm = "test-\(UUID().uuidString)"
        let store = KeychainIdentityStore(realm: realm)
        defer {
            SecItemDelete([kSecClass as String: kSecClassGenericPassword,
                           kSecAttrService as String: "online.nullmere.keeper",
                           kSecAttrAccount as String: realm] as CFDictionary)
        }
        XCTAssertNil(store.load(), "Nothing kept yet")
        do {
            try store.save("first")
        } catch {
            throw XCTSkip("No keychain to write to here: \(error)")
        }
        XCTAssertEqual(store.load(), "first")
        try store.save("second")
        XCTAssertEqual(store.load(), "second", "Kept again, replaced")
        XCTAssertNil(KeychainIdentityStore(realm: realm + "-other").load(), "Each realm its own")
    }
}
