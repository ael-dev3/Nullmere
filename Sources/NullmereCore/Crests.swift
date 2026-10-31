/// A House's crest: a shield of one tincture bearing a charge of another.
/// A keeper chooses their House's once an age; every other House bears the
/// one the lake gave it, the same for the same realm.
public struct Crest: Codable, Equatable, Hashable, Sendable {
    /// The colours a crest is painted in.
    public enum Tincture: String, Codable, CaseIterable, Sendable {
        case silver, gold, black, blue, red, green, purple

        public var title: String { rawValue }
    }

    /// What a shield bears.
    public enum Charge: String, Codable, CaseIterable, Sendable {
        case moon, tower, heron, star, oar, key, wave, flame, antler, bell

        public var title: String { rawValue }
    }

    public var field: Tincture
    public var charge: Charge
    public var tincture: Tincture

    public init(field: Tincture, charge: Charge, tincture: Tincture) {
        self.field = field
        self.charge = charge
        self.tincture = tincture
    }

    /// The crest in words: "a silver heron on blue".
    public var blazon: String {
        "\(article(tincture.title)) \(tincture.title) \(charge.title) on \(field.title)"
    }

    /// Whether the charge stands out from its field, as it must.
    public var isReadable: Bool { field != tincture }

    /// The crest the lake gives House `house` of a realm grown from
    /// `seedText`: the same every time, and no two of seventy Houses side
    /// by side alike in both charge and field.
    public static func given(to house: Int, seedText: String) -> Crest {
        // Its own reckoning from the realm's words, never the rules' own
        // randomness: the world grows as it always did.
        let digest = SHA256.digest(Array("crest \(seedText)".utf8))
        let start = Int(digest[0]) | Int(digest[1]) << 8
        let charges = Charge.allCases, tinctures = Tincture.allCases
        let charge = charges[(start + house) % charges.count]
        let field = tinctures[(start / charges.count + house * 3) % tinctures.count]
        let others = tinctures.filter { $0 != field }
        let tincture = others[(Int(digest[2]) + house) % others.count]
        return Crest(field: field, charge: charge, tincture: tincture)
    }

    private func article(_ word: String) -> String {
        "aeiou".contains(word.prefix(1)) ? "an" : "a"
    }
}

extension GameState {
    /// The crest House `house` bears: its keeper's choice, or the lake's,
    /// as the atlas keeps it for every keeper's view, which has no words to
    /// work it out from.
    public func crest(of house: Int) -> Crest {
        guard houses.indices.contains(house) else { return Crest(field: .black, charge: .moon, tincture: .silver) }
        if let chosen = houses[house].crest { return chosen }
        if let atlas, atlas.crests.indices.contains(house) { return atlas.crests[house] }
        return Crest.given(to: house, seedText: settings.seedText)
    }

    /// Why a House can't take this crest now, if it can't.
    public func crestRefusal(_ crest: Crest, as house: Int) -> RuleError? {
        guard crest.isReadable else { return .crestUnreadable }
        guard houses.indices.contains(house), houses[house].crest == nil else { return .crestChosenAlready }
        return nil
    }

    /// A House takes its crest, once an age.
    mutating func take(_ crest: Crest, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = crestRefusal(crest, as: house) { throw refusal }
        houses[house].crest = crest
        record(.seating, [house], "\(houses[house].title) takes for its crest \(crest.blazon).")
        return [.crestTaken(house: house, crest: crest)]
    }
}
