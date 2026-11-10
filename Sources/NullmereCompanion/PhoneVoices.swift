import Foundation
import NullmereCore
import NullmereCounsel
import Observation
import SwiftUI

/// The realm's characters given words by Apple's on-device model on this
/// iPhone, as the keeper's Mac gives them theirs: each moment the ledger
/// keys (a steward's envoy, what the Still showed the House, its riddle, a
/// prisoner's telling) asked once, one at a time, from the realm's own
/// facts in one wording with the Mac's (`Voicing.Moment`); its words kept
/// while the phone keeps the House. While the model is at it, whom it
/// speaks for and the seconds so far; where it gave none, why. Where the
/// phone can't run the model at all, nothing is asked and the realm's
/// plain words stand alone, as on a Mac without it.
@MainActor
@Observable
final class PhoneVoices {
    static let shared = PhoneVoices()

    /// The words each moment was given, by its key.
    private(set) var spoken: [String: String] = [:]
    /// Why the model gave a moment none, where it gave none.
    private(set) var unvoiced: [String: String] = [:]
    /// The moment the model is giving words to now, and since when.
    private(set) var voicing: (key: String, began: Date)?

    @ObservationIgnored private var asked: Set<String> = []
    @ObservationIgnored private var queue: [Voicing.Keyed] = []
    @ObservationIgnored private var asking: Task<Void, Never>?
    private let writer: ModelWriter

    init(writer: ModelWriter = ModelWriter()) {
        self.writer = writer
    }

    /// Why no character is given words on this phone; nil where the model
    /// can be asked.
    var unavailable: String? { writer.unvoiced }

    /// The moments the ledger keys now: each not yet asked is asked in its
    /// turn, in the order keyed, where the model can be asked at all. One
    /// the ledger keys no longer (an envoy answered or gone, a plea answered
    /// or withdrawn, a commander the keeper turned from) is not asked, and
    /// its asking is stopped there, the model going on at once to what
    /// still waits, as on the Mac; keyed again, it is asked again.
    func hear(_ moments: [Voicing.Keyed]) {
        guard writer.unvoiced == nil else { return }
        let keyed = Set(moments.map(\.key))
        for gone in queue where !keyed.contains(gone.key) { asked.remove(gone.key) }
        queue.removeAll { !keyed.contains($0.key) }
        if let speaking = voicing, !keyed.contains(speaking.key) {
            asking?.cancel()
            asking = nil
            voicing = nil
            asked.remove(speaking.key)
        }
        for moment in moments where !asked.contains(moment.key) {
            asked.insert(moment.key)
            queue.append(moment)
        }
        // Asked in the order the ledger keys them, so one the keeper looks
        // to now (a commander they asked to hear) goes before the rest.
        let order = Dictionary(moments.enumerated().map { ($0.element.key, $0.offset) }, uniquingKeysWith: { first, _ in first })
        queue.sort { order[$0.key, default: .max] < order[$1.key, default: .max] }
        next()
    }

    private func next() {
        guard asking == nil, !queue.isEmpty else { return }
        let moment = queue.removeFirst()
        voicing = (moment.key, Date())
        let writer = self.writer
        asking = Task { [weak self] in
            let written = await writer.write(moment.moment)
            guard let self, !Task.isCancelled else { return }
            self.voicing = nil
            if let words = written.words {
                withAnimation(.easeOut(duration: 0.6)) { self.spoken[moment.key] = words }
            } else if let trouble = written.trouble {
                self.unvoiced[moment.key] = trouble.unvoiced
            }
            self.asking = nil
            self.next()
        }
    }

    /// The phone no longer keeps the House: every word forgotten, the
    /// asking stopped.
    func forget() {
        asking?.cancel()
        asking = nil
        queue = []
        asked = []
        spoken = [:]
        unvoiced = [:]
        voicing = nil
    }
}

/// One of the realm's characters in the words this phone's model gave them,
/// beside the realm's plain ones: while the model is at it, whom it speaks
/// for and the seconds so far; where it gave none, why. Nothing for a
/// moment the phone doesn't voice.
struct VoicedWords: View {
    let key: String?
    /// Whom the model gives words to: "the envoy", "the Still", "the prisoner".
    let who: String

    var body: some View {
        let voices = PhoneVoices.shared
        if let key {
            if let words = voices.spoken[key] {
                Text(verbatim: "\u{201C}\(words)\u{201D}")
                    .font(Night.small.italic())
                    .foregroundStyle(Night.moon)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("In \(who)'s own words: \(words)")
            } else if let voicing = voices.voicing, voicing.key == key {
                TimelineView(.periodic(from: .now, by: 0.1)) { context in
                    Text(verbatim: Voicing.atWork(who, seconds: context.date.timeIntervalSince(voicing.began)))
                        .font(Night.small.monospacedDigit())
                        .foregroundStyle(Night.ink.opacity(0.5))
                }
            } else if let why = voices.unvoiced[key] {
                Text(verbatim: why)
                    .font(Night.small)
                    .foregroundStyle(Night.ink.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
