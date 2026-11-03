/// The Pedlar of the Still (after Rise of Kingdoms' mysterious merchant):
/// a pedlar poles his skiff across the black lake to a keeper's House's
/// hold by the water every so many watches, and lies off it two watches
/// with three wares: stores of one kind for another, an item of use, or
/// sculptures for its commanders' stars. Each ware is sold once, for what
/// he asks; then he is gone until his next coming. His coming and his
/// wares are known to that House alone.
public struct Pedlar: Codable, Equatable, Sendable {
    /// What a ware is.
    public enum Goods: Codable, Equatable, Sendable {
        case stores(Stock)
        case item(ItemKind, Int)
        case sculptures(Int)
    }

    public struct Ware: Codable, Equatable, Sendable, Identifiable {
        public let id: Int
        public let goods: Goods
        public let price: Stock
        public internal(set) var sold: Bool
    }

    public let house: Int
    /// The hold he lies off.
    public let hold: Int
    /// The water where his skiff lies.
    public let at: Hex
    public let came: Int
    public internal(set) var wares: [Ware]

    /// The watches he lies off a hold.
    public static let stays = 2
    /// The watches between his comings to a House.
    public static let round = 8
}

extension Pedlar.Goods {
    /// What a ware is, as a keeper reads it.
    public var title: String {
        switch self {
        case .stores(let stock): return "\(stock)"
        case .item(let kind, let count): return kind.counted(count)
        case .sculptures(let count): return "\(count) sculpture\(count == 1 ? "" : "s")"
        }
    }
}

extension GameState {
    /// The pedlars lying off holds now.
    public var pedlarsHere: [Pedlar] { pedlars ?? [] }

    /// The pedlar lying off a House's hold, if one is.
    public func pedlar(for house: Int) -> Pedlar? {
        pedlarsHere.first { $0.house == house }
    }

    /// The watch a House's pedlar next comes, from this one on.
    public static func pedlarComes(to house: Int, from watch: Int) -> Int {
        var next = watch
        while (next + house * 3) % Pedlar.round != 0 { next += 1 }
        return next
    }

    /// The pedlar's three wares for a House at a watch: always the same
    /// for the same House and watch, so the realm needs no chance for them.
    static func pedlarWares(for house: Int, at watch: Int, firstID: Int) -> [Pedlar.Ware] {
        let roll = (watch * 31 + house * 17) % 6
        let stores: [(Stock, Stock)] = [
            (Stock(timber: 160), Stock(grain: 120)), (Stock(stone: 160), Stock(timber: 120)),
            (Stock(grain: 200), Stock(stone: 110)), (Stock(moonsalt: 12), Stock(grain: 150, timber: 60)),
            (Stock(timber: 120, stone: 120), Stock(grain: 160)), (Stock(grain: 160), Stock(moonsalt: 6)),
        ]
        let items: [ItemKind] = [.hourglass, .mendingDraught, .wardStone, .hourglass, .moonsaltCache, .mendingDraught]
        let trade = stores[roll]
        return [
            Pedlar.Ware(id: firstID, goods: .stores(trade.0), price: trade.1, sold: false),
            Pedlar.Ware(id: firstID + 1, goods: .item(items[roll], roll % 3 == 0 ? 2 : 1), price: Stock(grain: 60, moonsalt: 4), sold: false),
            Pedlar.Ware(id: firstID + 2, goods: .sculptures(3 + roll % 3), price: Stock(stone: 80, moonsalt: 8), sold: false),
        ]
    }

    /// As the watch turns: a pedlar whose stay is done leaves; to each
    /// keeper's House whose round it is, he comes to its first hold by the
    /// lake, if it has one.
    mutating func turnThePedlars() -> [GameEvent] {
        var events: [GameEvent] = []
        var here = pedlarsHere
        here.removeAll { pedlar in
            let leaves = watch - pedlar.came >= Pedlar.stays || hold(pedlar.hold)?.owner != pedlar.house
            if leaves { events.append(.pedlarLeft(house: pedlar.house)) }
            return leaves
        }
        for house in houses.indices where houses[house].isPlayer && !houses[house].isEliminated
            && GameState.pedlarComes(to: house, from: watch) == watch && !here.contains(where: { $0.house == house }) {
            let holds = holds(of: house).sorted { ($0.isSeat ? 0 : 1, $0.id) < ($1.isSeat ? 0 : 1, $1.id) }
            guard let hold = holds.first(where: { stoneWater(before: $0) != nil }), let at = stoneWater(before: hold) else { continue }
            let first = takeID()
            _ = takeID(); _ = takeID()
            here.append(Pedlar(house: house, hold: hold.id, at: at, came: watch,
                               wares: GameState.pedlarWares(for: house, at: watch, firstID: first)))
            events.append(.pedlarCame(house: house, hold: hold.id))
        }
        pedlars = here.isEmpty ? nil : here
        return events
    }

    /// Why a House can't buy a ware now, if it can't.
    public func buyRefusal(_ wareID: Int, as house: Int) -> RuleError? {
        guard let pedlar = pedlar(for: house), let ware = pedlar.wares.first(where: { $0.id == wareID }) else { return .noPedlar }
        guard !ware.sold else { return .wareSold }
        guard houses[house].stock.covers(ware.price) else { return .shortOf(houses[house].stock.shortfall(for: ware.price)) }
        return nil
    }

    mutating func buy(_ wareID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = buyRefusal(wareID, as: house) { throw refusal }
        let index = pedlars!.firstIndex { $0.house == house }!
        let at = pedlars![index].wares.firstIndex { $0.id == wareID }!
        let ware = pedlars![index].wares[at]
        houses[house].stock.debit(ware.price)
        pedlars![index].wares[at].sold = true
        var events: [GameEvent] = [.pedlarSold(house: house, ware: wareID)]
        switch ware.goods {
        case .stores(let stock): store(stock, for: house)
        case .item(let kind, let count): events += give(kind, count, to: house)
        case .sculptures(let count): events += giveSculptures(count, to: house)
        }
        return events
    }
}
