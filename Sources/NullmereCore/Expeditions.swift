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
    /// The first commander of the line sent.
    public let commander: Int
    public let stage: Int
    public let weight: Int
    public let against: Int
    public let won: Bool
    /// The whole line sent, in its order; absent for a line of one.
    public var line: [Int]?
    /// The stars it was won with, one to three; absent when lost.
    public var stars: Int?
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

    /// The most commanders a line sent up the Spine.
    public static let expeditionLine = 3

    /// The stars a House won a stage with, its best; 0 if not won.
    public func expeditionStars(of house: Int, stage: Int) -> Int {
        expeditionBest?[house]?[stage] ?? 0
    }

    /// The stars a stage is won with, by how far the line outweighs its host.
    public static func stars(weight: Int, against: Int) -> Int? {
        guard weight >= against else { return nil }
        if weight * 10 >= against * 15 { return 3 }
        if weight * 10 >= against * 12 { return 2 }
        return 1
    }

    /// Why a House can't send a line of commanders at a stage of the Spine
    /// now: its next, or one it has won to win it with more stars.
    public func expeditionRefusal(_ line: [Int], stage: Int? = nil, as house: Int) -> RuleError? {
        guard !line.isEmpty, line.count <= GameState.expeditionLine, Set(line).count == line.count else { return .lineTooLong(GameState.expeditionLine) }
        for id in line {
            guard let commander = commander(id), commander.owner == house, commander.captive == nil else { return .unknownCommander }
            if let until = commander.woundedUntil, until > watch { return .commanderWounded(until) }
        }
        let number = stage ?? expeditionStage(of: house) + 1
        guard ExpeditionStage.stage(number) != nil, number <= expeditionStage(of: house) + 1 else { return .expeditionsDone }
        guard !hasVentured(house) else { return .venturedThisWatch }
        return nil
    }

    /// Why a House can't send one commander at its next stage now.
    public func expeditionRefusal(_ commanderID: Int, as house: Int) -> RuleError? {
        expeditionRefusal([commanderID], as: house)
    }

    /// The realm's chance on an expedition: a tenth either way, the same
    /// for the same House, stage and watch.
    static func expeditionSwing(house: Int, stage: Int, watch: Int) -> Int {
        ((house * 7919 + stage * 104_729 + watch * 31) % 21) - 10
    }

    mutating func venture(_ commanderID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        try venture([commanderID], stage: nil, as: house)
    }

    /// A line sent at a stage: weighed together against its host; won, the
    /// stage is the House's with its stars, its stores the first time and
    /// sculptures the first time it is won with three; lost, every
    /// commander of it home wounded a watch.
    mutating func venture(_ line: [Int], stage chosen: Int?, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = expeditionRefusal(line, stage: chosen, as: house) { throw refusal }
        let number = chosen ?? expeditionStage(of: house) + 1
        let stage = ExpeditionStage.stage(number)!
        let weight = line.reduce(0) { $0 + ringWeight(of: commander($1)!) }
        let against = stage.strength * (100 + GameState.expeditionSwing(house: house, stage: number, watch: watch)) / 100
        let stars = GameState.stars(weight: weight, against: against)
        ventured = (ventured ?? []) + [house]
        var result = ExpeditionResult(house: house, commander: line[0], stage: number, weight: weight, against: against, won: stars != nil)
        result.line = line.count > 1 ? line : nil
        result.stars = stars
        var events: [GameEvent] = [.expedition(result)]
        if let stars {
            let firstWin = number > expeditionStage(of: house)
            let before = expeditionStars(of: house, stage: number)
            if firstWin {
                var kept = expeditions ?? [:]
                kept[house] = number
                expeditions = kept
                store(stage.spoils, for: house)
                events += giveSculptures(stage.sculptures, to: house)
                record(.hunt, [house], "\(houses[house].title)'s \(commander(line[0])!.name) takes \(stage.name), stage \(number) of the Spine.")
            }
            if stars > before {
                var best = expeditionBest ?? [:]
                best[house, default: [:]][number] = stars
                expeditionBest = best
                if stars == 3 { events += giveSculptures(GameState.threeStarSculptures, to: house) }
            }
        } else {
            for id in line { commanders![commanderIndex(id)!].woundedUntil = watch + 1 }
        }
        return events
    }

    /// Sculptures for a stage first won with three stars.
    public static let threeStarSculptures = 4

    /// As the watch turns, every House may venture again.
    mutating func turnExpeditions() {
        ventured = nil
    }
}
