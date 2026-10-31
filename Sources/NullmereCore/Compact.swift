/// The realm's compact: what a keeper agrees to by entering the realm, and
/// what the realm keeps of them, in plain words. A keeper reads and
/// accepts it at the front door before they first enter, and again
/// whenever its words change.
public enum Compact {
    /// One part of the compact: a heading and a few plain sentences.
    public struct Article: Equatable, Sendable {
        public let heading: String
        public let text: String
    }

    /// The compact's edition: raised whenever its words change in
    /// substance, so that every keeper is asked to read it again.
    public static let edition = 1

    /// What changed in each edition after the first, told to a keeper who
    /// accepted an earlier one.
    public static let changes: [Int: String] = [:]

    public static let articles: [Article] = [
        Article(heading: "Who you are here",
                text: "The realm knows you by a random key your Mac makes and keeps in its keychain, and by the name you choose. It asks for no address, no account and no password, and learns nothing of your Mac or where you are."),
        Article(heading: "What the realm keeps",
                text: "Your name; your House's orders and what came of them, which the realm's other keepers see as the rules let them; when you are there and when you are away; and the renown, favour, titles and deeds you win, from age to age. The Words you write, the ballads you sing, the bottles you cast and the edicts you put are kept for the realm's keepers to read, the oldest let go as new ones come."),
        Article(heading: "What stays on your Mac",
                text: "The voices of the lake and the ballads offered you are made by your Mac's own on-device model: what it is asked and what it says leave your Mac only when you sing a ballad to the realm. Your settings stay on your Mac. The launcher reads the game's news from its repository and sends nothing of yours."),
        Article(heading: "Keeping the peace of the realm",
                text: "Write to other keepers as you would be written to: no threats, no hatred, no one's private details, nothing for sale. Any keeper may report a line to the realm's steward, who may take it away and bar a House from the Words for a time. Hold one House, under one identity, and play it yourself."),
        Article(heading: "The realm may change",
                text: "Nullmere Online is free and still being made. Its stewards may change its rules, end or begin its ages, or let it rest, for a time or for good; nothing in it is property, and nothing is bought or sold. It is offered as it is, with no promise that it works. Its code is under the Apache License 2.0, and its art and sounds are in the public domain."),
        Article(heading: "Leaving",
                text: "Leave whenever you like. Ask the realm's steward, through the game's repository, to forget you: your name and identity leave the realm's roll, and a steward keeps your House until its age ends. When these words change, the front door asks you to read them again before you enter."),
    ]

    /// Whether a keeper who accepted the compact's `accepted` edition (nil:
    /// never) must read it before entering a realm that holds its keepers
    /// to edition `held`.
    public static func mustRead(accepted: Int?, held: Int = edition) -> Bool {
        (accepted ?? 0) < held
    }

    /// What the front door says above the compact: why it is read now.
    public static func preface(accepted: Int?) -> String {
        guard let accepted, accepted > 0, accepted < edition else {
            return "Before you first enter: what you agree to, and what the realm keeps of you."
        }
        let changed = (accepted + 1...edition).compactMap { changes[$0] }
        let what = changed.isEmpty ? "" : " " + changed.joined(separator: " ")
        return "The compact has changed since you accepted it.\(what) Read it again before you enter."
    }

    /// The compact whole, for reading aloud.
    public static var spoken: String {
        articles.map { "\($0.heading). \($0.text)" }.joined(separator: " ")
    }
}

/// The tongue a realm and its keepers' Macs speak to each other: the
/// requests, views and statuses between them. It is raised whenever a Mac
/// with an earlier build could no longer play on a realm of this one, and a
/// realm tells the oldest it still hears.
public enum Speech {
    /// The tongue this build speaks.
    public static let current = 1
    /// The oldest tongue a realm of this build still hears from a keeper's Mac.
    public static let oldestHeard = 1
    /// Where a keeper gets the newest Nullmere Online.
    public static let newestBuild = "https://github.com/ael-dev3/Nullmere/releases/latest"
}

extension RealmStatus {
    /// The realm has moved on past this build: it no longer hears the
    /// tongue this Mac speaks, or holds its keepers to a compact newer than
    /// this build can show. Its keeper must get a newer Nullmere Online to
    /// enter.
    public var wantsNewerBuild: Bool {
        (oldestSpeech ?? 0) > Speech.current || (compact ?? 0) > Compact.edition
    }

    /// What the front door says when the realm has moved on past this build.
    public static let newerBuildNote = "The realm has moved on to a newer Nullmere Online than this one. Get the new one from github.com/ael-dev3/Nullmere/releases, then come back."
}
