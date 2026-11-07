import Foundation
import NullmereCompanionCore
import NullmereCore
import NullmereRealm
import SwiftUI

/// Nullmere Companion: a keeper's iPhone on their realm, beside their Mac.
/// Linked by the code the Mac shows at the realm's door, it keeps the
/// keeper's House from the phone: how the realm and the House stand, the
/// companies and their orders, the alliance and its words, readiness for
/// the watch. Its identity is its own, kept in this phone's keychain and
/// never carried off it; the Mac's key never leaves the Mac.
@main
struct CompanionApp: App {
    @State private var session = CompanionSession(memory: DefaultsMemory()) { address in
        guard let transport = SpacetimeHTTP(address: address) else { return nil }
        return NetworkRealmLink(transport: transport, credentials: CompanionKeychain(realm: address), pollInterval: 2)
    }
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            CompanionRoot(session: session)
                .onOpenURL { url in
                    if let invite = CompanionInvite(url: url) { session.take(invite) }
                }
                .onAppear {
                    session.resume()
                    #if DEBUG
                    CompanionCheck.startIfAsked(session)
                    CompanionCheck.takeCounselIfAsked()
                    #endif
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: session.resume()
            case .background: session.pause()
            default: break
            }
        }
    }
}

/// The realm the phone was linked to, kept in its defaults: an address,
/// never a key; and what the keeper's commanders remember of counsel taken
/// on this phone, which stays on it.
final class DefaultsMemory: CompanionMemory {
    private let key = "companion.realm"
    private let counselKey = "companion.counsel"
    private let seenKey = "companion.lastSeen"
    var realm: URL? {
        get { UserDefaults.standard.string(forKey: key).flatMap(URL.init(string:)) }
        set { UserDefaults.standard.set(newValue?.absoluteString, forKey: key) }
    }
    var lastSeen: LastSeen? {
        get { UserDefaults.standard.data(forKey: seenKey).flatMap { try? JSONDecoder().decode(LastSeen.self, from: $0) } }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: seenKey)
            } else {
                UserDefaults.standard.removeObject(forKey: seenKey)
            }
        }
    }
    var counsel: [Int: CounselMemory] {
        get {
            UserDefaults.standard.data(forKey: counselKey).flatMap { try? JSONDecoder().decode([Int: CounselMemory].self, from: $0) } ?? [:]
        }
        set {
            if newValue.isEmpty {
                UserDefaults.standard.removeObject(forKey: counselKey)
            } else {
                UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: counselKey)
            }
        }
    }
}

/// The phone's screen: pairing until it speaks for a keeper, then the House.
struct CompanionRoot: View {
    let session: CompanionSession

    var body: some View {
        ZStack {
            Night.background.ignoresSafeArea()
            switch session.phase {
            case .pairing:
                PairingView(session: session)
            case .entering, .away:
                VStack(spacing: 14) {
                    ProgressView().tint(Night.moon)
                    Text(verbatim: session.realm.map { "Coming in to \($0.host() ?? "the realm")…" } ?? "Coming in…")
                        .font(Night.body)
                        .foregroundStyle(Night.ink.opacity(0.8))
                }
                .accessibilityElement(children: .combine)
            case .keeping:
                KeepingView(session: session)
            }
        }
        .preferredColorScheme(.dark)
    }
}
