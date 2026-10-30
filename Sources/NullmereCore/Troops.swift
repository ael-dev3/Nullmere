/// A company's troops: so many soldiers, riders or scouts at full muster,
/// by its kind and tier, as many of them standing as its health is a share
/// of; a House's army is all its companies of war's troops together. A
/// battle is told in the troops each side slew and lost.
extension UnitKind {
    /// How many a company of this kind musters whole, at a tier.
    public func troops(tier: Int) -> Int {
        let above = min(max(tier, 1), 5) - 1
        switch self {
        case .spear: return 1_200 + 300 * above
        case .bow: return 1_000 + 250 * above
        case .rider: return 800 + 200 * above
        case .lantern: return 60
        case .founder: return 250
        }
    }
}

extension GameState {
    /// The troops a company stands with.
    public func troops(of unit: Unit) -> Int {
        unit.kind.troops(tier: unit.tier) * min(max(unit.health, 0), 100) / 100
    }

    /// A House's army: the troops of all its companies of war.
    public func army(of house: Int) -> Int {
        units.reduce(0) { $1.owner == house && $1.kind.isMilitary ? $0 + troops(of: $1) : $0 }
    }

    /// A count as the realm writes it, its thousands set apart: 12,400.
    public static func counted(_ number: Int) -> String {
        let digits = String(abs(number))
        var grouped = ""
        for (index, digit) in digits.enumerated() {
            if index > 0, (digits.count - index) % 3 == 0 { grouped.append(",") }
            grouped.append(digit)
        }
        return number < 0 ? "-" + grouped : grouped
    }
}
