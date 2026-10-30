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
}
