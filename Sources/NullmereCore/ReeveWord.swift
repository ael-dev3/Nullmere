import Foundation

/// The reeve's word to the keeper as they turn to a hold of theirs, given by
/// a device's own model on the Mac and the phone alike from what the House
/// knows alone: the hold and its works, what it raises and musters, how its
/// walls and ward stand, who keeps its gates, what the House sees about it,
/// a plea its folk bring, fire on its land and its dead lying unburied by
/// it. A word, never an order: the reeve proposes nothing; the hold's own
/// orders stand on its card beneath.
extension Voicing {
    /// What the model is asked for a reeve's word on their hold
    /// (`GameState.reeveWord`).
    public static let reeveTask = "Speak as the reeve of the keeper's hold, reporting to the keeper, who looks to it: what it raises "
        + "and musters, how its walls and ward stand, who keeps its gates and what lies about it, keeping every name and number as "
        + "given. Propose nothing and promise nothing. One or two sentences, at most 40 words."
}

extension GameState {
    /// The tiles about a hold its reeve's word looks over, the most it tells
    /// of what lies there, the nearest first, and the most of its works it
    /// names, the highest first.
    public static let reeveLooks = 2
    public static let reeveTells = 4
    public static let reeveWorks = 4

    /// The reeve's word on a hold of a House as its keeper turns to it, for
    /// the device's model to give: whose hold it is, its works, what it
    /// raises and musters, its walls and ward, the companies at its gates,
    /// what the House sees about it, a plea its folk bring, fire on its land
    /// and the House's dead unburied by it; nil unless the hold is the
    /// House's own.
    public func reeveWord(of id: Int, for house: Int) -> Voicing.Moment? {
        guard houses.indices.contains(house), let hold = hold(id), hold.owner == house else { return nil }
        var facts = ["\(hold.name) is \(hold.isSeat ? "the seat" : "a hold") of \(houses[house].title)."]
        let works = hold.levels.filter { $0.key != .walls && $0.value > 0 }
            .sorted { ($0.value, $1.key.title) > ($1.value, $0.key.title) }
        if works.isEmpty {
            facts.append("No work is raised in it yet.")
        } else {
            let named = works.prefix(GameState.reeveWorks).map { "\($0.key.title) \(BuildingKind.numeral($0.value))" }
            let more = works.count > GameState.reeveWorks ? ", and \(works.count - GameState.reeveWorks) more" : ""
            facts.append("Its works: " + named.joined(separator: ", ") + more + ".")
        }
        if let project = hold.project {
            facts.append("It raises \(project.kind.title) \(BuildingKind.numeral(project.targetLevel)), done in "
                         + "\(GameState.watches(project.watchesLeft)).")
        } else {
            facts.append("It raises no work now.")
        }
        if let training = hold.training {
            facts.append("It musters \(training.kind.named(tier: training.musteredTier)), ready in \(GameState.watches(training.watchesLeft)).")
        }
        facts.append("\(GameState.wallsSaid(hold.level(.walls))), its ward \(hold.ward) of \(hold.maximumWard).")
        let gates = units.filter { $0.position == hold.position && $0.owner == house }
            .map { "your \(SpokenOrders.named($0, in: self)), \(GameState.counted(troops(of: $0))) troops" }
        let kept = units.filter { $0.owner != house && $0.errand == .reinforce(hold: id) }
            .map { "\(houses.indices.contains($0.owner) ? houses[$0.owner].title : "an ally")'s \(SpokenOrders.named($0, in: self))" }
        let standing = gates + kept.map { "\($0), keeping its gates" }
        facts.append(standing.isEmpty ? "No company stands at its gates." : "At its gates: " + standing.joined(separator: "; ") + ".")
        let near = seen(around: hold.position, by: house, within: GameState.reeveLooks, besides: id).prefix(GameState.reeveTells)
        facts.append(near.isEmpty ? "About it the House sees nothing but the land."
                                  : "About it the House sees: " + near.joined(separator: "; ") + ".")
        if petition(of: house)?.hold == id { facts.append("Its folk wait at the gate with a plea.") }
        let burning = burningLand(of: hold).count
        if burning > 0 {
            facts.append("Fire burns in the blackwood on \(burning == 1 ? "1 tile" : "\(GameState.counted(burning)) tiles") of its land; \(windSaid).")
        }
        if let dead = fieldsOfDead.first(where: { $0.houses.contains(house) && $0.at.distance(to: hold.position) <= 1 }) {
            facts.append("\(GameState.counted(dead.troops)) of the House's dead lie unburied \(placeName(of: dead.at)).")
        }
        return Voicing.Moment(task: Voicing.reeveTask, facts: facts)
    }

    /// The key a reeve's word is kept under on the Mac and the phone: the
    /// hold, the watch, and how it stands (what it raises and musters, its
    /// walls, its ward by the quarter, the foes about it, a plea waiting,
    /// fire on its land), so a word is asked afresh each watch and once its
    /// work or its danger changes. Nil unless the hold is the House's own.
    public func reeveWordKey(of id: Int, for house: Int) -> Int? {
        guard let hold = hold(id), hold.owner == house else { return nil }
        var about = 17
        func mix(_ value: Int) { about = (about * 31 + value) % 1_000_003 }
        mix(hold.project.map { 1 + (BuildingKind.allCases.firstIndex(of: $0.kind) ?? 0) * 16 + $0.targetLevel } ?? 0)
        mix(hold.training.map { 1 + (UnitKind.allCases.firstIndex(of: $0.kind) ?? 0) * 16 + $0.musteredTier } ?? 0)
        mix(hold.level(.walls))
        mix(min(max(hold.ward, 0) * 4 / max(hold.maximumWard, 1), 4))
        let foes = units.filter { $0.owner != house && $0.position.distance(to: hold.position) <= GameState.reeveLooks }.count
        mix(min(foes, 9))
        mix(petition(of: house)?.hold == id ? 1 : 0)
        mix(burningLand(of: hold).isEmpty ? 0 : 1)
        return (id * 100_000 + watch % 100_000) * 1_000 + about % 1_000
    }

    /// A hold's reeve's own name, the same for the hold's life: the reeve
    /// who brings the folk's hands to the keeper's gate (`Petition.Plea.hands`)
    /// and who gives the reeve's word.
    public func reeveName(of hold: Int) -> String {
        let count = Petition.names.count
        return Petition.names[((hold &* 37 &+ 11) % count + count) % count]
    }

    /// A hold's reeve as a line names them: "Alder, the reeve of Wenholme".
    public func reeveSaid(of hold: Hold) -> String {
        "\(reeveName(of: hold.id)), the reeve of \(hold.name)"
    }

    /// The hold a reeve's word's key is of.
    public static func hold(ofWord key: Int) -> Int { key / 100_000_000 }

    /// A hold's walls as its reeve says them, by their height of the five,
    /// never as a level: "Its walls stand at the second of their five
    /// heights", or "It has no walls yet".
    public static func wallsSaid(_ height: Int) -> String {
        let heights = ["first", "second", "third", "fourth", "fifth", "sixth", "seventh"]
        let most = BuildingKind.walls.maxLevel
        guard height > 0 else { return "It has no walls yet" }
        let which = heights.indices.contains(height - 1) ? heights[height - 1] : "\(height)th"
        return "Its walls stand at the \(which) of their \(most == 5 ? "five" : "\(most)") heights"
    }
}
