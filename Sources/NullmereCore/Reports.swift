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
    /// Of a field of battle, each side as it came and as it left: the
    /// keeper's own first.
    public var sides: [Side] = []

    /// A side of a field of battle, as a report counts it.
    public struct Side: Equatable, Sendable {
        public let title: String
        public let houses: Int
        public let companies: Int
        /// Its troops as they came, and those of them lost.
        public let troops: Int
        public let lost: Int
        /// Its companies fallen.
        public let fallen: Int

        /// Its troops still standing.
        public var standing: Int { max(troops - lost, 0) }
    }

    /// The keeper's own companies told one by one in a field's report.
    public static let companiesTold = 6
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

    /// A field of battle the viewer's House fought in, as its report tells
    /// it: which side held the field, each side's companies and troops, the
    /// slain and the fallen, and the House's own companies one by one; nil
    /// if it had no part in it.
    public func report(of field: Field, id: Int, for viewer: Int) -> BattleReport? {
        guard let side = field.side(of: viewer) else { return nil }
        let foe = 1 - side
        let outcome: BattleReport.Outcome = field.held == side ? .won : field.held == foe ? .lost : .held
        let mine = field.fighters(of: side).count, theirs = field.fighters(of: foe).count
        let against = "\(mine == 1 ? "1 company" : "\(mine) companies") against \(theirs)"
        let title: String
        switch outcome {
        case .won: title = "Your side held the field, \(against)"
        case .lost: title = "Your side was driven from the field, \(against)"
        default: title = "Neither side gave way, \(against)"
        }
        var lines: [String] = []
        let own = field.fighters.filter { $0.owner == viewer }
        for fighter in own.prefix(BattleReport.companiesTold) {
            let named = "Your \(fighter.kind.title)" + (fighter.kind.hasTiers ? " \(BuildingKind.numeral(fighter.tier))" : "")
            let led = fighter.leader.map { ", led by \($0)," } ?? ""
            let fate = fighter.fell ? "fell" : fighter.standing ? "held" : "drew off"
            lines.append("\(named)\(led) slew \(GameState.counted(fighter.slain)), lost \(GameState.counted(fighter.lost)), and \(fate)")
        }
        if own.count > BattleReport.companiesTold {
            let more = own.count - BattleReport.companiesTold
            lines.append("And \(more == 1 ? "1 more company" : "\(more) more companies") of your House")
        }
        let allies = field.fighters(of: side).filter { $0.owner != viewer }
        if !allies.isEmpty {
            let companies = allies.count == 1 ? "1 company" : "\(allies.count) companies"
            lines.append("Your allies' \(companies) slew \(GameState.counted(allies.reduce(0) { $0 + $1.slain })), "
                         + "lost \(GameState.counted(allies.reduce(0) { $0 + $1.lost }))")
        }
        func told(_ side: Int, _ title: String) -> BattleReport.Side {
            BattleReport.Side(title: title, houses: field.sides[side].count, companies: field.fighters(of: side).count,
                              troops: field.troops(of: side), lost: field.lost(by: side), fallen: field.fallen(of: side))
        }
        var report = BattleReport(id: id, watch: watch, title: title, place: placeName(of: field.at), outcome: outcome, lines: lines)
        report.sides = [told(side, "Your side"), told(foe, "The foe")]
        return report
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
        // In troops, where the realm counted them.
        let slaying = battle.slain.map { $0 > 0 ? ", slaying \(GameState.counted($0))" : "" } ?? ""
        let losing = battle.lost.map { $0 > 0 ? ", losing \(GameState.counted($0))" : "" } ?? ""
        var lines = ["\(striker) dealt \(battle.damageDealt)" + (battle.defenderKind == nil ? " to the ward" : "") + slaying,
                     "\(striker) took \(battle.damageTaken) back" + losing]
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

    /// A host's strike on a lair of the wilds, as a House of the host
    /// reads it: its own companies' blows, its allies' together, and how
    /// the lair stood after or what fell to the House with it; nil for a
    /// House not of the host.
    public func report(of assault: LairAssault, id: Int, for viewer: Int) -> BattleReport? {
        guard assault.houses.contains(viewer) else { return nil }
        let lair = "the \(assault.kind.lairTitle) of the \(ordinal(assault.level)) level"
        var lines: [String] = []
        for strike in assault.strikes where strike.owner == viewer {
            lines.append("Your \(strike.kind.title) dealt \(strike.dealt)" + (strike.taken > 0 ? ", took \(strike.taken)" : "")
                         + (strike.fell ? ", and fell" : ""))
        }
        let others = assault.strikes.filter { $0.owner != viewer }
        if !others.isEmpty {
            let companies = others.count == 1 ? "1 company" : "\(others.count) companies"
            lines.append("Your allies' \(companies) dealt \(others.reduce(0) { $0 + $1.dealt })")
        }
        if assault.broken {
            let share = assault.shares.first { $0.house == viewer }?.spoils ?? .zero
            lines.append(share.isZero ? "It broke" : "It broke, and your House carried off \(share)")
        } else {
            lines.append("It holds, \(assault.strength) of \(assault.might) still standing")
        }
        let lost = assault.strikes.contains { $0.owner == viewer && $0.fell }
        let outcome: BattleReport.Outcome = assault.broken ? .won : (lost ? .lost : .held)
        return BattleReport(id: id, watch: watch, title: "Your host " + (assault.broken ? "broke " : "struck ") + lair,
                            place: placeName(of: assault.at), outcome: outcome, lines: lines)
    }
}
