import Foundation
import NullmereLive

/// What the screen says of what the player has chosen: a name, a few
/// lines, and what can be done about it, each with why not where it
/// can't be done now. Plain words, read from the realm's rows; the
/// screen only draws it.
public struct LiveCard: Equatable, Sendable {
    public enum Act: Equatable, Sendable {
        /// Open the city's buildings, or its troops.
        case city
        case troops
        /// Send everyone ready to what is chosen.
        case send
        /// Call an army home.
        case recall(UInt64)
    }

    public struct Button: Equatable, Sendable {
        public let title: String
        public let act: Act
        /// Why it can't be pressed now; nil where it can.
        public let why: String?
    }

    public let title: String
    public let lines: [String]
    public let buttons: [Button]
}

extension LiveSession {
    /// The grounds, as the module numbers them, in a player's words.
    static let grounds = ["Deep water", "Shallows", "Strand", "Salt flat", "Plain", "Wood", "Heath", "Mountains"]
    /// The goods a site holds, by its kind.
    static let goods = ["Grain", "Timber", "Stone", "Moonsalt"]

    private func soldiers(_ count: UInt64) -> String { "\(LiveWords.grouped(count)) \(count == 1 ? "soldier" : "soldiers")" }

    /// Who would lead an army sent now, in a line; nil where no commander
    /// is in the city.
    private var leaderLine: String? {
        world.freeLeader.map { "\($0.name), \($0.wayName.lowercased()) of level \($0.level), will lead it." }
    }

    /// Why no army can be sent now, whatever it is sent for: no one ready,
    /// or every army the city may send already out.
    private var cannotSend: String? {
        let ready = world.troops.reduce(0) { $0 + $1.ready }
        if ready == 0 { return "No soldiers stand ready in your city." }
        let most = LiveWorld.marches(keep: world.city?.keep ?? 1)
        if world.myMarches.count >= most {
            return most == 1 ? "Your one army is out. Raise your Keep to send more." : "All \(most) of your armies are out."
        }
        return nil
    }

    /// The card for what lies at a chosen hex.
    public func card(for selection: LiveSelection) -> LiveCard {
        let seconds = now
        let ready = world.troops.reduce(0) { $0 + $1.ready }
        switch selection {
        case .home(let city):
            var lines = ["Your city. Keep level \(city.keep), power \(LiveWords.grouped(city.power))."]
            if city.peace(at: seconds) > 0 {
                lines.append("At peace for another \(LiveWords.spoken(city.peace(at: seconds))): no army may attack it.")
            }
            if let job = world.jobs.first(where: { $0.kind == LiveJob.raise }),
               let name = world.buildings.first(where: { $0.id == job.subject }).flatMap({ world.blueprint($0.kind, level: 1)?.name }) {
                lines.append("\(name) to level \(job.level): \(LiveWords.clock(Int(job.left(at: seconds).rounded(.up))))")
            }
            return LiveCard(title: city.name, lines: lines, buttons: [.init(title: "Buildings", act: .city, why: nil), .init(title: "Troops", act: .troops, why: nil)])

        case .city(let city, let owner):
            let here = world.players[city.owner]?.online == true ? " They are here now." : ""
            var lines = ["\(owner)'s city. Keep level \(city.keep), power \(LiveWords.grouped(city.power)).\(here)"]
            var why = cannotSend
            if let mine = world.city, mine.peace(at: seconds) > 0 {
                lines.append("Attacking ends your own city's peace.")
            }
            if city.peace(at: seconds) > 0 {
                why = "That city is at peace for another \(LiveWords.spoken(city.peace(at: seconds)))."
            }
            // An ally's city is never attacked, and nothing else can be
            // sent to it yet.
            if world.isAlly(city.owner) {
                return LiveCard(title: city.name, lines: [lines[0], "Your ally."], buttons: [])
            }
            if why == nil, let leaderLine { lines.append(leaderLine) }
            return LiveCard(title: city.name, lines: lines,
                            buttons: [.init(title: ready > 0 ? "Attack with \(soldiers(ready))" : "Attack", act: .send, why: why)])

        case .site(let site):
            let good = LiveSession.goods.indices.contains(site.kind - 1) ? LiveSession.goods[site.kind - 1] : "Goods"
            var lines = ["\(LiveWords.grouped(site.left)) left to gather."]
            var why = cannotSend
            if site.gatherer != 0 {
                let mine = world.myMarches.contains { $0.id == site.gatherer }
                lines.append(mine ? "Your army is gathering here." : "Another army is gathering here.")
                why = "Another army is gathering there."
            }
            if why == nil, let leaderLine { lines.append(leaderLine) }
            return LiveCard(title: "\(good), level \(site.level)", lines: lines,
                            buttons: [.init(title: ready > 0 ? "Gather with \(soldiers(ready))" : "Gather", act: .send, why: why)])

        case .barrow(let barrow):
            var lines = ["The Unquiet hold it. An attack takes \(LiveWorld.energyAnAttack) energy."]
            var why = cannotSend
            let energy = world.hunt?.energy(at: seconds) ?? 0
            if energy < LiveWorld.energyAnAttack { why = "An attack takes \(LiveWorld.energyAnAttack) energy. You have \(energy)." }
            if barrow.level > (world.hunt?.mayAttack ?? 1) { why = "Clear a level \(barrow.level - 1) barrow first." }
            if barrow.fighter != 0 {
                let mine = world.myMarches.contains { $0.id == barrow.fighter }
                lines.append(mine ? "Your army is fighting here." : "Another army is fighting here.")
                why = "Another army is fighting there."
            }
            if why == nil, let leaderLine { lines.append(leaderLine) }
            return LiveCard(title: "Barrow, level \(barrow.level)", lines: lines,
                            buttons: [.init(title: ready > 0 ? "Attack with \(soldiers(ready))" : "Attack", act: .send, why: why)])

        case .army(let march, let own):
            guard own, let line = world.marchLines().first(where: { $0.id == march.id }) else {
                let owner = world.shownName(of: march.owner) ?? "Another player"
                return LiveCard(title: "\(owner)'s army", lines: [soldiers(march.soldiers)], buttons: [])
            }
            var lines = ["\(line.doing): \(LiveWords.clock(march.arrives - Int(seconds)))"]
            if let leader = world.commanders.first(where: { $0.id == march.leader }) {
                lines.append("Led by \(leader.name).")
            }
            lines.append(line.wounded > 0 ? "\(soldiers(line.soldiers)), and \(LiveWords.grouped(line.wounded)) wounded." : "\(soldiers(line.soldiers)).")
            let why = line.canRecall ? nil : (march.state == LiveMarch.fighting ? "That army is fighting. Wait for the fight to end." : "That army is already on its way home.")
            return LiveCard(title: "Your army", lines: lines, buttons: [.init(title: "Call home", act: .recall(march.id), why: why)])

        case .land(_, let ground):
            let name = ground.flatMap { LiveSession.grounds.indices.contains(Int($0)) ? LiveSession.grounds[Int($0)] : nil }
            return LiveCard(title: name ?? "Unknown land", lines: [], buttons: [])
        }
    }

    /// Does what a card's button says.
    public func press(_ button: LiveCard.Button) async {
        guard button.why == nil else {
            said = button.why
            return
        }
        switch button.act {
        case .send:
            if let selected { await send(everyoneReady, to: selected) }
        case .recall(let march): await recall(march: march)
        case .city, .troops: break
        }
    }
}
