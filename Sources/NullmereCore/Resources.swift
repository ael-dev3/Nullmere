/// The four resources of the shore. Grain, timber and stone are common;
/// moonsalt, the pale crust that forms where moonlight lies on the dead
/// water's edge, is rare and feeds every great work.
public enum Resource: String, CaseIterable, Codable, Sendable {
    case grain
    case timber
    case stone
    case moonsalt

    public var title: String {
        switch self {
        case .grain: return "Grain"
        case .timber: return "Timber"
        case .stone: return "Stone"
        case .moonsalt: return "Moonsalt"
        }
    }

    /// Worth in barter: moonsalt is three times dearer than the rest.
    public var worth: Int { self == .moonsalt ? 3 : 1 }

    /// What it costs in `give` to barter for `amount` of this resource:
    /// three times its worth, rounded up.
    public func barterCost(of amount: Int, paidIn give: Resource) -> Int {
        (amount * 3 * worth + give.worth - 1) / give.worth
    }
}

/// An amount of each resource. Arithmetic never goes below zero; storing
/// stops at `Stock.cap`.
public struct Stock: Codable, Equatable, Hashable, Sendable, CustomStringConvertible {
    public static let cap = 99_999

    public var grain: Int
    public var timber: Int
    public var stone: Int
    public var moonsalt: Int

    public init(grain: Int = 0, timber: Int = 0, stone: Int = 0, moonsalt: Int = 0) {
        self.grain = grain
        self.timber = timber
        self.stone = stone
        self.moonsalt = moonsalt
    }

    public static let zero = Stock()

    public subscript(resource: Resource) -> Int {
        get {
            switch resource {
            case .grain: return grain
            case .timber: return timber
            case .stone: return stone
            case .moonsalt: return moonsalt
            }
        }
        set {
            switch resource {
            case .grain: grain = newValue
            case .timber: timber = newValue
            case .stone: stone = newValue
            case .moonsalt: moonsalt = newValue
            }
        }
    }

    public var isZero: Bool { Resource.allCases.allSatisfy { self[$0] == 0 } }

    public func covers(_ cost: Stock) -> Bool {
        Resource.allCases.allSatisfy { self[$0] >= cost[$0] }
    }

    /// What is missing to pay `cost`.
    public func shortfall(for cost: Stock) -> Stock {
        var missing = Stock()
        for resource in Resource.allCases {
            missing[resource] = max(cost[resource] - self[resource], 0)
        }
        return missing
    }

    /// Adds income, stopping at the cap.
    public mutating func credit(_ income: Stock) {
        for resource in Resource.allCases {
            self[resource] = min(self[resource] + max(income[resource], 0), Stock.cap)
        }
    }

    /// Removes `cost`, which must be covered.
    public mutating func debit(_ cost: Stock) {
        precondition(covers(cost), "debit exceeds stock")
        for resource in Resource.allCases {
            self[resource] -= cost[resource]
        }
    }

    /// `parts` out of every `whole` of each resource, rounded down.
    public func share(_ parts: Int, of whole: Int) -> Stock {
        var result = Stock()
        for resource in Resource.allCases {
            result[resource] = self[resource] * parts / max(whole, 1)
        }
        return result
    }

    public static func + (lhs: Stock, rhs: Stock) -> Stock {
        var result = Stock()
        for resource in Resource.allCases {
            result[resource] = lhs[resource] + rhs[resource]
        }
        return result
    }

    public static func * (lhs: Stock, factor: Int) -> Stock {
        var result = Stock()
        for resource in Resource.allCases {
            result[resource] = lhs[resource] * factor
        }
        return result
    }

    /// Each amount scaled by `percent` / 100, rounded down.
    public func scaled(percent: Int) -> Stock {
        var result = Stock()
        for resource in Resource.allCases {
            result[resource] = self[resource] * percent / 100
        }
        return result
    }

    public var description: String {
        Resource.allCases
            .filter { self[$0] != 0 }
            .map { "\(self[$0]) \($0.title.lowercased())" }
            .joined(separator: ", ")
    }
}
