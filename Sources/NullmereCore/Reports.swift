import Foundation

/// A battle as a keeper reads it afterwards: who struck whom and where, the
/// blows each side dealt, who fell, and how it came out for their House.
public struct BattleReport: Equatable, Sendable, Identifiable {
    /// How a battle came out for the House the report is for.
    public enum Outcome: String, Equatable, Sendable, PlainCases {
        /// The foe fell, or the hold's ward broke, and the House's company stood.
        case won
        /// The House's company fell.
        case lost
        /// Both stood.
        case held
        /// Not a battle: the House's Lanterns scouted a hold.
        case scouted

        /// How it came out, in a word or two, on the Mac and the phone alike.
        public var said: String {
            switch self {
            case .won: return "Won"
            case .lost: return "Lost"
            case .held: return "Both stood"
            case .scouted: return "Scouted"
            }
        }
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
    /// The House's own commanders who led its companies there, by name, as
    /// the report was filed: who may be asked of it in counsel, and whose
    /// counsel remembers it.
    public var led: [String] = []
    /// Who stood on each side, as the report pictures them: the House's own
    /// side first and the foe's second, a few faces each, the most troops
    /// first; none for a scouting.
    public var faces: [[Face]] = []

    /// One face of a side in a report's picture: a company as it fought, in
    /// its House's colours; a hold whose ward was struck; a company of the
    /// wilds; or a lair of theirs.
    public struct Face: Equatable, Sendable {
        public enum Look: Equatable, Sendable {
            case company(UnitKind, tier: Int)
            case hold(seat: Bool)
            case wild(WildKind, level: Int)
            case lair(WildKind)
        }

        public let look: Look
        /// The House whose colours and people it is of; nil for the wilds.
        public let house: Int?

        public init(_ look: Look, of house: Int?) {
            self.look = look
            self.house = house
        }
    }

    /// The faces a side is pictured by, at most.
    public static let facesShown = 3

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

        /// The side in a line, on the Mac and the phone alike: its companies
        /// and Houses, its troops as they came, those lost, and its
        /// companies fallen.
        public var said: String {
            let companies = companies == 1 ? "1 company" : "\(companies) companies"
            let houses = houses > 1 ? " of \(houses) Houses" : ""
            let fallen = fallen == 0 ? "" : fallen == 1 ? ", 1 company fallen" : ", \(fallen) companies fallen"
            return "\(title): \(companies)\(houses), \(GameState.counted(troops)) troops; \(GameState.counted(lost)) lost\(fallen)"
        }
    }

    /// The keeper's own companies told one by one in a field's report.
    public static let companiesTold = 6

    /// A side's faces out of its companies' in the order given: each kind of
    /// each House once, at most `facesShown`.
    static func faces(_ all: [Face]) -> [Face] {
        var shown: [Face] = []
        for face in all where !shown.contains(where: { $0.isLike(face) }) {
            shown.append(face)
            if shown.count == facesShown { break }
        }
        return shown
    }
}

extension BattleReport.Face {
    /// The same kind of thing of the same House, whatever a company's tier.
    func isLike(_ other: Self) -> Bool {
        guard house == other.house else { return false }
        if case .company(let kind, _) = look, case .company(let theirs, _) = other.look { return kind == theirs }
        return look == other.look
    }
}

extension GameState {
    /// Where something happened, as a keeper would say it: at a hold, or on
    /// its ground by the nearest hold within a few tiles.
    public func placeName(of hex: Hex) -> String {
        if let hold = hold(at: hex) { return "at \(hold.name)" }
        let ground = map[hex].map { $0.terrain.place } ?? "in the field"
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
            let named = "Your \(self.named(fighter.kind, tier: fighter.tier, of: fighter.owner))"
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
        var named = Set<String>()
        report.led = own.compactMap(\.leader).filter { named.insert($0).inserted }
        report.faces = [side, foe].map { side in
            BattleReport.faces(field.fighters(of: side).sorted { ($0.troops, $1.unit) > ($1.troops, $0.unit) }
                .map { BattleReport.Face(.company($0.kind, tier: $0.tier), of: $0.owner) })
        }
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
        var report = BattleReport(id: id, watch: watch, title: "\(striker) struck \(struck)", place: placeName(of: battle.at),
                                  outcome: outcome, lines: lines)
        report.led = leaders(of: attacking ? battle.attacker : battle.defender)
        let striking = [face(of: battle.attacker, kind: battle.attackerKind, owner: battle.attackerOwner)]
        let standing: [BattleReport.Face]
        if let kind = battle.defenderKind {
            standing = [face(of: battle.defender, kind: kind, owner: battle.defenderOwner)]
        } else {
            let seat = battle.hold.flatMap { hold($0) }.map { $0.isSeat && $0.owner == battle.defenderOwner } ?? false
            standing = [BattleReport.Face(.hold(seat: seat), of: battle.defenderOwner)]
        }
        report.faces = attacking ? [striking, standing] : [standing, striking]
        return report
    }

    /// A blow the viewer's House struck at a company of the wilds, as its
    /// report tells it; nil if it was another House's.
    public func report(of hunt: Hunt, id: Int, for viewer: Int) -> BattleReport? {
        guard hunt.attackerOwner == viewer else { return nil }
        let wild = hunt.wildKind.title.lineBegun
        var lines = ["Your \(hunt.attackerKind.title) dealt \(hunt.damageDealt)", "Your \(hunt.attackerKind.title) took \(hunt.damageTaken) back"]
        if hunt.wildFell {
            lines.append("\(wild) fell" + (hunt.spoils.isZero ? "" : ", and gave up \(hunt.spoils)"))
        }
        if hunt.attackerFell { lines.append("Your \(hunt.attackerKind.title) fell") }
        let outcome: BattleReport.Outcome = hunt.attackerFell ? .lost : (hunt.wildFell ? .won : .held)
        var report = BattleReport(id: id, watch: watch, title: "Your \(hunt.attackerKind.title) struck \(hunt.wildKind.named(level: hunt.level))",
                                  place: placeName(of: hunt.at), outcome: outcome, lines: lines)
        report.led = leaders(of: hunt.attacker)
        report.faces = [[face(of: hunt.attacker, kind: hunt.attackerKind, owner: hunt.attackerOwner)],
                        [BattleReport.Face(.wild(hunt.wildKind, level: hunt.level), of: nil)]]
        return report
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
            // Whose it is with what it is, before how it stands: "Spears I of
            // House Venn, 80 strong", never "Hardened of House Venn".
            var words = named(seen.kind, tier: seen.tier, of: seen.owner)
            if seen.owner != scouting.owner, houses.indices.contains(seen.owner) { words += " of \(houses[seen.owner].title)" }
            if seen.health < 100 { words += ", \(seen.health) strong" }
            if seen.rank > 0 { words += ", \(Unit.rankTitles[seen.rank])" }
            if let commander = seen.commander { words += ", led by \(commander)" }
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
        if scouting.wounded > 0 { lines.append((scouting.wounded == 1 ? "1 company lies" : "\(scouting.wounded) companies lie") + " in its Infirmary") }
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
        let lair = assault.named
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
        var report = BattleReport(id: id, watch: watch, title: (assault.rally == 0 ? "Your company " : "Your host ") + (assault.broken ? "broke " : "struck ") + lair,
                                  place: placeName(of: assault.at), outcome: outcome, lines: lines)
        var named = Set<String>()
        report.led = assault.strikes.filter { $0.owner == viewer }.flatMap { leaders(of: $0.unit) }.filter { named.insert($0).inserted }
        let host = assault.strikes.filter { $0.owner == viewer } + assault.strikes.filter { $0.owner != viewer }
        report.faces = [BattleReport.faces(host.map { face(of: $0.unit, kind: $0.kind, owner: $0.owner) }),
                        [BattleReport.Face(.lair(assault.kind), of: nil)]]
        return report
    }

    /// A company's face in a report: its kind and its tier as it now stands
    /// (a company gone is pictured at the first), in its House's colours.
    func face(of unit: Int?, kind: UnitKind, owner: Int) -> BattleReport.Face {
        BattleReport.Face(.company(kind, tier: unit.flatMap { self.unit($0)?.tier } ?? 1), of: owner)
    }

    /// The commanders at the head of a company as the world now stands, by
    /// name, its leader first and then its second; none for a company gone.
    func leaders(of unit: Int?) -> [String] {
        guard let unit = unit.flatMap({ self.unit($0) }) else { return [] }
        return [unit.leader, unit.second].compactMap { $0.flatMap { commander($0)?.name } }
    }

    /// The House's reports of the battles a commander led its companies in,
    /// out of `reports` (the latest first, as the Mac and the phone keep
    /// them), the latest first and at most `battlesRecalled`: what their
    /// counsel remembers.
    public func battles(ledBy commander: Commander, in reports: [BattleReport]) -> [BattleReport] {
        Array(reports.filter { $0.outcome != .scouted && $0.led.contains(commander.name) }.prefix(GameState.battlesRecalled))
    }

    /// The most battles a commander's counsel remembers.
    public static let battlesRecalled = 3

    /// The House's commander who led its companies in a battle and may be
    /// asked of it in counsel, on the Mac and the phone alike: the first
    /// its report names who is the House's own and not held prisoner; nil
    /// for none.
    public func askable(of report: BattleReport, by house: Int) -> Commander? {
        guard report.outcome != .scouted else { return nil }
        return commanders(of: house).first { report.led.contains($0.name) && $0.captive == nil }
    }
}

extension GameState {
    /// The reports a House is filed from the events of a turn, a pace or an
    /// order, read against this world as it stands after them, on the Mac
    /// and the phone alike: each battle and hunt the House had a part in,
    /// each field of battle as it ends (a blow struck within one is told in
    /// the field's report), each hold its Lanterns scouted and each lair it
    /// assaulted; numbered on from `after`, in the order they came.
    public func reports(of events: [GameEvent], for viewer: Int, after: Int = 0) -> [BattleReport] {
        var filed: [BattleReport] = []
        for event in events {
            let id = after + filed.count + 1
            let report: BattleReport?
            switch event {
            case .battle(let battle) where battle.field == nil: report = self.report(of: battle, id: id, for: viewer)
            case .fieldEnded(let field): report = self.report(of: field, id: id, for: viewer)
            case .hunted(let hunt): report = self.report(of: hunt, id: id, for: viewer)
            case .holdScouted(let scouting): report = self.report(of: scouting, id: id, for: viewer)
            case .lairAssaulted(let assault): report = self.report(of: assault, id: id, for: viewer)
            default: report = nil
            }
            if let report { filed.append(report) }
        }
        return filed
    }
}
