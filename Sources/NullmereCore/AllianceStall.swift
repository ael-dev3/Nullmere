/// Merit with an alliance and its stall (Rise of Kingdoms' alliance credits
/// and its alliance shop): a House earns merit with its alliance for every
/// work, muster and study of an ally's it lends a hand to, and for what it
/// gives toward the alliance's study; and spends it at the alliance's
/// stall on what the stall keeps for its Houses: hourglasses, caches,
/// draughts, ward stones and tomes. The alliance keeps each House's merit,
/// so a House that leaves and comes back finds its merit as it left it.
/// Stewards earn merit as they help, and spend none, so their ages play as
/// they did.
extension GameState {
    /// Merit for each work, muster or study of an ally's a House helps.
    public static let meritPerHelp = 10
    /// The worth given toward the alliance's study for each merit.
    public static let worthPerMerit = 10
    /// The most merit a House keeps with its alliance.
    public static let mostMerit = 9_999

    /// What the stall keeps, in the order it shows them: one of every kind
    /// of thing a satchel holds.
    public static var stall: [ItemKind] { ItemKind.allCases }

    /// A thing's price at the stall, in merit.
    public static func stallPrice(of kind: ItemKind) -> Int {
        switch kind {
        case .hourglass: return 60
        case .grainCache, .timberCache, .stoneCache: return 30
        case .moonsaltCache: return 90
        case .mendingDraught: return 80
        case .wardStone: return 120
        case .tome: return 150
        }
    }

    /// A House's merit with its alliance: none while it is sworn to none.
    public func merit(of house: Int) -> Int {
        alliance(of: house)?.merit?[String(house)] ?? 0
    }

    /// How a House stands at its alliance's stall, as the Mac's Alliance
    /// panel and the phone tell it: "Your merit with the Still Accord: 120."
    public func meritSaid(of house: Int) -> String? {
        guard let sworn = alliance(of: house) else { return nil }
        return "Your merit with \(sworn.name): \(GameState.counted(merit(of: house)))."
    }

    /// How merit is earned, in one wording for the Mac and the phone.
    public static let meritEarned = "Earned helping your allies' works, musters and studies (\(meritPerHelp) for each), "
        + "and giving toward the alliance's study (1 for each \(worthPerMerit) worth)."

    /// What taking one of a kind from the stall reads as on its button:
    /// "Take a Salt Hourglass for 60 merit".
    public static func stallSaid(_ kind: ItemKind) -> String {
        "Take \(kind.counted(1)) for \(stallPrice(of: kind)) merit"
    }

    /// Merit earned by a House, kept by its alliance; nothing while it is
    /// sworn to none.
    mutating func earnMerit(_ amount: Int, by house: Int) {
        guard amount > 0, let index = allianceIndex(of: house) else { return }
        var kept = alliances![index].merit ?? [:]
        kept[String(house)] = min((kept[String(house)] ?? 0) + amount, GameState.mostMerit)
        alliances![index].merit = kept
    }

    /// Why a House can't take a thing from its alliance's stall now, if it
    /// can't: it is sworn to none, or its merit falls short of the price.
    public func stallRefusal(_ kind: ItemKind, as house: Int) -> RuleError? {
        guard alliance(of: house) != nil else { return .notInAlliance }
        let price = GameState.stallPrice(of: kind), held = merit(of: house)
        return held < price ? .shortOfMerit(price - held) : nil
    }

    /// A House takes a thing from its alliance's stall for its merit.
    mutating func takeFromStall(_ kind: ItemKind, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = stallRefusal(kind, as: house) { throw refusal }
        guard let index = allianceIndex(of: house) else { throw .notInAlliance }
        let price = GameState.stallPrice(of: kind)
        var kept = alliances![index].merit ?? [:]
        kept[String(house)] = merit(of: house) - price
        alliances![index].merit = kept
        return [.takenFromStall(house: house, item: kind, merit: price)] + give(kind, 1, to: house)
    }
}
