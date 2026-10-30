import Foundation

/// A battle as a keeper reads it afterwards: who struck whom and where, the
/// blows each side dealt, who fell, and how it came out for their House.
public struct BattleReport: Equatable, Sendable, Identifiable {
    /// How a battle came out for the House the report is for.
    public enum Outcome: String, Equatable, Sendable {
        /// The foe fell, or the hold's ward broke, and the House's company stood.
        case won
        /// The House's company fell.
        case lost
        /// Both stood.
        case held
        /// Not a battle: the House's Lanterns scouted a hold.
        case scouted
    }

    public let id: Int
    public let watch: Int
    public let title: String
    /// Where it was fought, as a keeper would say it.
    public let place: String
    public let outcome: Outcome
    /// What each side dealt and took, and who fell, a line each.
    public let lines: [String]
}

extension GameState {
    /// Where something happened, as a keeper would say it: at a hold, or on
    /// its ground by the nearest hold within a few tiles.
    public func placeName(of hex: Hex) -> String {
        if let hold = hold(at: hex) { return "at \(hold.name)" }
        let ground = map[hex].map { "on the \($0.terrain.title.lowercased())" } ?? "in the field"
        let near = holds.filter { $0.position.distance(to: hex) <= 4 }
            .min { ($0.position.distance(to: hex), $0.id) < ($1.position.distance(to: hex), $1.id) }
        return near.map { "\(ground) by \($0.name)" } ?? ground
    }

    private func whose(_ house: Int, for viewer: Int) -> String {
        guard house != viewer else { return "Your" }
        return houses.indices.contains(house) ? "\(houses[house].title)'s" : "A fallen House's"
    }

    /// A battle the viewer's House fought, as its report tells it; nil if
    /// the House had no part in it.
    public func report(of battle: Battle, id: Int, for viewer: Int) -> BattleReport? {
        let attacking = battle.attackerOwner == viewer
        guard attacking || battle.defenderOwner == viewer else { return nil }
        let striker = "\(whose(battle.attackerOwner, for: viewer)) \(battle.attackerKind.title)"
        let struck: String
        if let kind = battle.defenderKind {
            struck = battle.defenderOwner == viewer ? "your \(kind.title)" : "\(whose(battle.defenderOwner, for: viewer)) \(kind.title)"
        } else {
            struck = "the walls of \(battle.hold.flatMap { hold($0)?.name } ?? "a hold")"
        }
        var lines = ["\(striker) dealt \(battle.damageDealt)" + (battle.defenderKind == nil ? " to the ward" : ""),
                     "\(striker) took \(battle.damageTaken) back"]
        if battle.defenderFell, let kind = battle.defenderKind {
            lines.append("\(whose(battle.defenderOwner, for: viewer)) \(kind.title) fell")
        }
        if battle.attackerFell { lines.append("\(striker) fell") }
        let ours = attacking ? battle.attackerFell : battle.defenderFell
        let theirs = attacking ? battle.defenderFell : battle.attackerFell
        let outcome: BattleReport.Outcome = ours ? .lost : (theirs ? .won : .held)
        return BattleReport(id: id, watch: watch, title: "\(striker) struck \(struck)", place: placeName(of: battle.at),
                            outcome: outcome, lines: lines)
    }

    /// A blow the viewer's House struck at a company of the wilds, as its
    /// report tells it; nil if it was another House's.
    public func report(of hunt: Hunt, id: Int, for viewer: Int) -> BattleReport? {
        guard hunt.attackerOwner == viewer else { return nil }
        let wild = hunt.wildKind.title.prefix(1).uppercased() + hunt.wildKind.title.dropFirst()
        var lines = ["Your \(hunt.attackerKind.title) dealt \(hunt.damageDealt)", "Your \(hunt.attackerKind.title) took \(hunt.damageTaken) back"]
        if hunt.wildFell {
            lines.append("\(wild) fell" + (hunt.spoils.isZero ? "" : ", and gave up \(hunt.spoils)"))
        }
        if hunt.attackerFell { lines.append("Your \(hunt.attackerKind.title) fell") }
        let outcome: BattleReport.Outcome = hunt.attackerFell ? .lost : (hunt.wildFell ? .won : .held)
        return BattleReport(id: id, watch: watch, title: "Your \(hunt.attackerKind.title) struck \(hunt.wildKind.title) of level \(BuildingKind.numeral(hunt.level))",
                            place: placeName(of: hunt.at), outcome: outcome, lines: lines)
    }

    /// A hold the viewer's House scouted, as its report tells it: the
    /// companies at its gates, its ward, what it raises and musters, what
    /// its taking would carry off, and who lies in its beds; nil for
    /// another House's scouting.
    public func report(of scouting: ScoutReport, id: Int, for viewer: Int) -> BattleReport? {
        guard scouting.by == viewer else { return nil }
        let name = hold(scouting.hold)?.name ?? "a hold"
        let theirs = houses.indices.contains(scouting.owner) ? houses[scouting.owner].title : "a fallen House"
        let isSeat = hold(scouting.hold).map { $0.isSeat && $0.owner == scouting.owner } ?? false
        func watches(_ count: Int) -> String { count == 1 ? "1 watch left" : "\(count) watches left" }
        func company(_ seen: ScoutReport.Company) -> String {
            var words = seen.kind.title + (seen.kind.hasTiers ? " \(BuildingKind.numeral(seen.tier))" : "")
            if seen.health < 100 { words += ", \(seen.health) strong" }
            if seen.rank > 0 { words += ", \(Unit.rankTitles[seen.rank])" }
            if let commander = seen.commander { words += ", led by \(commander)" }
            if seen.owner != scouting.owner, houses.indices.contains(seen.owner) { words += " of \(houses[seen.owner].title)" }
            return words
        }
        var lines = [scouting.garrison.isEmpty ? "No company at its gates"
                     : "At its gates: " + scouting.garrison.map(company).joined(separator: "; ")]
        lines.append("Its ward \(scouting.ward) of \(scouting.maximumWard)")
        if let project = scouting.project {
            lines.append("Raising \(project.kind.title) \(BuildingKind.numeral(project.targetLevel)), \(watches(project.watchesLeft))")
        }
        if let training = scouting.training {
            let tier = training.kind.hasTiers ? " \(BuildingKind.numeral(training.musteredTier))" : ""
            lines.append("Mustering \(training.kind.title)\(tier), \(watches(training.watchesLeft))")
        }
        if !scouting.spoils.isZero { lines.append("Its taking would carry off \(scouting.spoils)") }
        if scouting.wounded > 0 { lines.append("\(scouting.wounded) \(scouting.wounded == 1 ? "lies" : "lie") in its Infirmary") }
        let whose = isSeat ? "\(theirs)'s seat" : "a hold of \(theirs)"
        return BattleReport(id: id, watch: scouting.watch, title: "Your Lanterns scouted \(name), \(whose)",
                            place: hold(scouting.hold).map { placeName(of: $0.position) } ?? "", outcome: .scouted, lines: lines)
    }
}
