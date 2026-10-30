/// A company's figures as the rules reckon them: its kind's, raised by its
/// tier. Every rule that weighs a company asks here, so what raises one
/// raises it everywhere: in battle, on the march, in the forecast, and in
/// its House's strength.
extension GameState {
    /// A company's attack, in percent of its kind's at the first tier.
    public func attackPercent(of unit: Unit) -> Int {
        Unit.tierMight[Unit.tierIndex(unit.tier, of: unit.kind)]
    }

    /// A company's defence, in percent of its kind's at the first tier.
    public func defensePercent(of unit: Unit) -> Int {
        Unit.tierMight[Unit.tierIndex(unit.tier, of: unit.kind)]
    }

    /// A company's body, in percent of the first tier's: a blow takes that
    /// much less of its health.
    public func bodyPercent(of unit: Unit) -> Int {
        Unit.tierBody[Unit.tierIndex(unit.tier, of: unit.kind)]
    }

    /// Moves a company has in a watch.
    public func movement(of unit: Unit) -> Int {
        unit.kind.movement
    }

    /// Grain a company eats each watch.
    public func upkeep(of unit: Unit) -> Int {
        unit.kind.upkeep(tier: unit.tier)
    }

    /// A company's weight in its House's strength: its attack and defence,
    /// its body, and how whole it is.
    public func strength(of unit: Unit) -> Int {
        let might = unit.kind.attack * attackPercent(of: unit) + unit.kind.defense * defensePercent(of: unit)
        return might * bodyPercent(of: unit) / 100 * unit.health / 1000
    }

    /// A blow's damage as the company struck takes it: lessened by its body.
    func bodily(_ damage: Int, on unit: Unit) -> Int {
        damage * 100 / max(bodyPercent(of: unit), 1)
    }

    /// What a company's blow takes from a ward, before chance.
    public func wardDamage(by unit: Unit) -> Int {
        12 + unit.kind.attack * 4 * unit.health * attackPercent(of: unit) / 10_000
    }

    /// The highest tier of a kind a House may muster at a hold now: as high
    /// as the hold's Muster Hall allows.
    public func highestTier(of kind: UnitKind, at hold: Hold, for house: Int) -> Int {
        guard kind.hasTiers else { return 1 }
        let muster = hold.level(.musterHall)
        return (1...kind.highestTier).last { muster >= kind.requiredMuster(tier: $0) } ?? 1
    }

    /// Why a House can't muster a tier of a kind at a hold, if it can't.
    public func tierRefusal(of kind: UnitKind, tier: Int, at hold: Hold, for house: Int) -> RuleError? {
        guard (1...Unit.highestTier).contains(tier) else { return .noSuchTier }
        guard tier <= kind.highestTier else { return .oneTierOnly(kind) }
        let muster = kind.requiredMuster(tier: tier)
        guard hold.level(.musterHall) >= muster else { return .needsMusterHall(muster) }
        return nil
    }
}
