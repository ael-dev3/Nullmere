/// Expeditions into the Spine (after Rise of Kingdoms' expedition): twelve
/// stages up into the mountains behind the lake, each held by a host of
/// the wilds stronger than the last. Once a watch a House sends one of its
/// commanders at its next stage: the commander is weighed as the Ring
/// weighs it, against the stage's host, the realm's chance a tenth either
/// way. Won, the stage is the House's, and its stores; every third stage
/// sculptures for its commanders' stars. Lost, the commander comes back
/// wounded a watch. No company on the lake is put at hazard.
public struct ExpeditionStage: Equatable, Sendable {
    public let number: Int
    public let name: String
    /// What the stage's host weighs.
    public let strength: Int
    public let spoils: Stock
    public let sculptures: Int

    public static let count = 12
    static let names = ["the Scree Gate", "the Cairn Steps", "Hollow Ford", "the Ravens' Shelf", "the Saltwights' Cut",
                        "Barrowhead", "the Long Stair", "the Frozen Tarn", "the Spine Hunters' Fall", "the Drowned Ledge",
                        "the Grey Crown", "the Spine's Heart"]

    public static func stage(_ number: Int) -> ExpeditionStage? {
        guard (1...count).contains(number) else { return nil }
        return ExpeditionStage(number: number, name: names[number - 1], strength: 140 + 55 * (number - 1),
                               spoils: Stock(grain: 40 * number, timber: 30 * number, stone: 30 * number, moonsalt: number),
                               sculptures: number % 3 == 0 ? 2 * number / 3 + 2 : 0)
    }
}

/// How an expedition went, as its House is told it.
public struct ExpeditionResult: Codable, Equatable, Sendable {
    public let house: Int
    public let commander: Int
    public let stage: Int
    public let weight: Int
    public let against: Int
    public let won: Bool
}

extension GameState {
    /// The stages a House has won.
    public func expeditionStage(of house: Int) -> Int {
        expeditions?[house] ?? 0
    }

    /// Whether a House has sent an expedition this watch.
    public func hasVentured(_ house: Int) -> Bool {
        ventured?.contains(house) == true
    }

    /// Why a House can't send a commander at its next stage now.
    public func expeditionRefusal(_ commanderID: Int, as house: Int) -> RuleError? {
        guard let commander = commander(commanderID), commander.owner == house, commander.captive == nil else { return .unknownCommander }
        if let until = commander.woundedUntil, until > watch { return .commanderWounded(until) }
        guard ExpeditionStage.stage(expeditionStage(of: house) + 1) != nil else { return .expeditionsDone }
        guard !hasVentured(house) else { return .venturedThisWatch }
        return nil
    }

    /// The realm's chance on an expedition: a tenth either way, the same
    /// for the same House, stage and watch.
    static func expeditionSwing(house: Int, stage: Int, watch: Int) -> Int {
        ((house * 7919 + stage * 104_729 + watch * 31) % 21) - 10
    }

    mutating func venture(_ commanderID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = expeditionRefusal(commanderID, as: house) { throw refusal }
        let number = expeditionStage(of: house) + 1
        let stage = ExpeditionStage.stage(number)!
        let weight = ringWeight(of: commander(commanderID)!)
        let against = stage.strength * (100 + GameState.expeditionSwing(house: house, stage: number, watch: watch)) / 100
        let won = weight >= against
        ventured = (ventured ?? []) + [house]
        let result = ExpeditionResult(house: house, commander: commanderID, stage: number, weight: weight, against: against, won: won)
        var events: [GameEvent] = [.expedition(result)]
        if won {
            var kept = expeditions ?? [:]
            kept[house] = number
            expeditions = kept
            store(stage.spoils, for: house)
            events += giveSculptures(stage.sculptures, to: house)
            record(.hunt, [house], "\(houses[house].title)'s \(commander(commanderID)!.name) takes \(stage.name), stage \(number) of the Spine.")
        } else {
            commanders![commanderIndex(commanderID)!].woundedUntil = watch + 1
        }
        return events
    }

    /// As the watch turns, every House may venture again.
    mutating func turnExpeditions() {
        ventured = nil
    }
}
