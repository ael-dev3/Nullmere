import NullmereCompanionCore
import NullmereCore
import SwiftUI

/// Linking the phone to its keeper: the code their Mac shows at the realm's
/// door, scanned by the phone's camera (its QR code opens this app) or
/// typed here with the realm's address.
struct PairingView: View {
    let session: CompanionSession
    @State private var realm = CompanionInvite.realmProper.absoluteString
    @State private var code = ""
    @FocusState private var typing: Bool

    private var invite: CompanionInvite? { CompanionInvite(realm: realm, code: code) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: "Nullmere")
                        .font(Night.title)
                        .foregroundStyle(Night.ink)
                    Text(verbatim: "Companion")
                        .font(Night.heading)
                        .foregroundStyle(Night.moon)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

                Text(verbatim: "Keep your House from your phone, beside your Mac. On your Mac, at the realm's door, choose Link your phone: scan the code it shows with this phone's camera, or type it here.")
                    .font(Night.body)
                    .foregroundStyle(Night.ink.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: "The code your Mac shows")
                        .font(Night.small)
                        .foregroundStyle(Night.ink.opacity(0.7))
                    TextField("XXXX-XXXX-XXXX", text: $code)
                        .font(.system(.title2, design: .monospaced))
                        .foregroundStyle(Night.ink)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.characters)
                        #endif
                        .focused($typing)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Night.panel))
                        .accessibilityLabel("The code your Mac shows")
                        .accessibilityHint("Twelve letters and figures, as the realm's door on your Mac shows them")
                    Text(verbatim: "The realm")
                        .font(Night.small)
                        .foregroundStyle(Night.ink.opacity(0.7))
                        .padding(.top, 6)
                    TextField("maincloud.spacetimedb.com/nullmere", text: $realm)
                        .font(Night.small)
                        .foregroundStyle(Night.ink.opacity(0.85))
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Night.panel))
                        .accessibilityLabel("The realm's address")
                }

                Button {
                    typing = false
                    if let invite { session.take(invite) }
                } label: {
                    Text(verbatim: "Link this phone")
                        .font(Night.heading)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(Night.moon)
                .foregroundStyle(Night.background)
                .disabled(invite == nil)
                .accessibilityHint(invite == nil ? "Type the twelve letters and figures your Mac shows first" : "Links this phone to the keeper whose Mac shows the code")

                if let problem = session.problem {
                    Text(verbatim: problem)
                        .font(Night.body)
                        .foregroundStyle(Night.bad)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Problem: \(problem)")
                }

                Text(verbatim: "This phone is known to the realm by a key of its own, kept in its keychain and never carried off it. Your Mac's key never leaves your Mac, and your Mac can let this phone go at any time.")
                    .font(Night.small)
                    .foregroundStyle(Night.ink.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
        }
    }
}
