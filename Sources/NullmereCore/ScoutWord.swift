import Foundation

/// The word of the keeper's Lanterns back from scouting another House's
/// hold, given by a device's own model on the Mac and the phone alike from
/// their report alone (`GameState.report(of:id:for:)` of a `ScoutReport`):
/// the companies at its gates and who leads them, its ward, what it raises
/// and musters, what its taking would carry off and who lies in its beds.
/// A word, never an order: the Lanterns propose nothing, and their report's
/// own lines stand beside it.
extension Voicing {
    /// What the model is asked for the Lanterns' word (`BattleReport.scoutWord`).
    public static let scoutTask = "Speak as the keeper's Lanterns, back from scouting a hold of another House, telling the keeper "
        + "what they saw there: the companies at its gates and who leads them, its ward, what it raises and musters, and what its "
        + "taking would carry off, keeping every name and number as given. Propose nothing and promise nothing. One or two "
        + "sentences, at most 40 words."
}

extension BattleReport {
    /// The Lanterns' word on what they saw, for the device's model to give,
    /// from their report's own words: what they scouted and when, then each
    /// of its lines; nil for a report of anything but a scouting.
    public var scoutWord: Voicing.Moment? {
        guard outcome == .scouted else { return nil }
        let place = self.place.isEmpty ? "" : ", \(self.place)"
        return Voicing.Moment(task: Voicing.scoutTask, facts: ["\(title)\(place), at watch \(watch)."] + lines.map { "\($0)." })
    }

    /// The key the Lanterns' word is kept under, the same on the Mac and
    /// the phone for the same scouting: from its watch and its report's own
    /// words, so a hold scouted again, or seen otherwise, is heard afresh;
    /// nil for a report of anything but a scouting.
    public var scoutWordKey: Int? {
        guard outcome == .scouted else { return nil }
        // FNV-1a over the report's words: the same in every process, as a
        // key kept across launches must be, where Swift's own hashing is not.
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in "\(watch)|\(title)|\(place)|\(lines.joined(separator: "|"))".utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01b3
        }
        return Int(hash >> 12)
    }
}
