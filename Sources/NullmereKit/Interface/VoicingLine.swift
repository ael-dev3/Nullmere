import Foundation
import NullmereCore
import SwiftUI

/// Where one of the realm's characters is given words by this Mac's
/// on-device model: while the model is at it, whom it speaks for and the
/// seconds so far; where it gave them none, why, plainly, the realm's own
/// words standing alone beneath. Nothing once they have spoken, nor where
/// no model speaks on this Mac.
struct VoicingLine: View {
    let session: GameSession
    let key: GameSession.Spoken
    /// Whom the model gives words to: "the envoy", "the prisoner", "the
    /// Still".
    let who: String

    var body: some View {
        if let voicing = session.voicing, voicing.key == key {
            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                Text(verbatim: Self.atWork(who, began: voicing.began, now: context.date))
                    .font(.nm(10, weight: .light).monospacedDigit())
                    .foregroundStyle(Palette.text(0.5))
            }
        } else if session.spoken[key] == nil, let why = session.unvoiced[key] {
            Text(verbatim: why)
                .font(.nm(10, weight: .light))
                .foregroundStyle(Palette.text(0.5))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// While the model is at it: "Apple's on-device model gives the envoy
    /// words… 1.4 s".
    static func atWork(_ who: String, began: Date, now: Date) -> String {
        Voicing.atWork(who, seconds: now.timeIntervalSince(began))
    }
}
