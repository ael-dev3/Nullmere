/// What an attack would most likely do, before chance has its say: the
/// least and most damage each side can suffer.
public struct Forecast: Equatable, Sendable {
    public enum Target: Equatable, Sendable {
        case unit(UnitKind)
        case hold(Int)
    }

    public let target: Target
    /// Damage to the defending unit's health, or to the hold's ward.
    public let dealt: ClosedRange<Int>
    /// Damage the attacker takes in return; nothing when striking from afar.
    public let taken: ClosedRange<Int>
    /// The defender's health, or the hold's ward, before the blow.
    public let defenderHealth: Int
    public let attackerHealth: Int
    /// Whether the hold falls to this attacker when its ward breaks, or
    /// when the garrison falls with the ward down: only a company that can
    /// take holds, striking close, and sure to live through the blow it
    /// takes in return.
    public let couldCapture: Bool
    /// Whether the attacker steps onto the fallen's ground when they fall:
    /// a close blow struck out in the field, never from within a hold, by
    /// a company sure to live through it.
    public var takesTheField = false

    /// Whether the blow can finish the defender (or break the ward).
    public var mayFinish: Bool { dealt.upperBound >= defenderHealth }
    public var surelyFinishes: Bool { dealt.lowerBound >= defenderHealth }
    public var mayFall: Bool { taken.upperBound >= attackerHealth }
}

extension GameState {
    /// What the unit's attack on a hex would do, or nil when it can't attack
    /// there now.
    public func forecast(unit unitID: Int, at target: Hex) -> Forecast? {
        guard let attacker = unit(unitID), attacker.kind.isMilitary, attacker.movesLeft > 0,
              attacker.position.distance(to: target) <= attacker.kind.range,
              let foe = foe(at: target, for: attacker.owner), isAtWar(attacker.owner, foe.owner)
        else { return nil }
        let ranged = attacker.position.distance(to: target) > 1

        if let defenderID = foe.unit, let defender = unit(defenderID) {
            let (attack, defense) = strengths(of: attacker, against: defender, at: target)
            let dealt = 70 * attack / (attack + defense)
            let taken = ranged ? 0 : 70 * defense / (attack + defense)
            let stands = taken * 120 / 100 < attacker.health
            let wardDown = hold(at: target).map { $0.ward == 0 } ?? false
            return Forecast(
                target: .unit(defender.kind),
                dealt: max(5, dealt * 80 / 100)...max(5, dealt * 120 / 100),
                taken: (taken * 80 / 100)...(taken * 120 / 100),
                defenderHealth: defender.health,
                attackerHealth: attacker.health,
                couldCapture: !ranged && attacker.kind.canCapture && wardDown && stands,
                takesTheField: takesTheField(attacker, at: target) && stands
            )
        }
        guard let holdID = foe.hold, let hold = hold(holdID) else { return nil }
        let damage = Hold.strikeDamage(attack: attacker.kind.attack, health: attacker.health)
        let returned = ranged ? 0 : 5 + 4 * hold.level(.walls)
        return Forecast(
            target: .hold(holdID),
            dealt: (damage * 80 / 100)...(damage * 120 / 100),
            taken: returned...returned,
            defenderHealth: hold.ward,
            attackerHealth: attacker.health,
            couldCapture: !ranged && attacker.kind.canCapture && returned < attacker.health
        )
    }
}
