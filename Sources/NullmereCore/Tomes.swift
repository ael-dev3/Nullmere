/// Tomes of old campaigns (Rise of Kingdoms' tomes of knowledge): read by a
/// commander of the House, a tome gives them experience as battles do,
/// with no battle fought. A House gains one for every lair its companies
/// help break. A commander held prisoner reads none, nor one risen as high
/// as any may. Stewards keep any they win unread, so their ages play as
/// they did.
extension GameState {
    /// Experience a tome gives the commander who reads it.
    public static let tomeExperience = 300

    /// Why a House's commander can't read a tome now, if they can't: the
    /// House keeps none, the commander isn't the House's or is held
    /// prisoner, or has risen as high as any may.
    public func tomeRefusal(for commanderID: Int, as house: Int) -> RuleError? {
        guard items(.tome, of: house) > 0 else { return .noItem }
        guard let commander = commander(commanderID), commander.owner == house else { return .unknownCommander }
        guard commander.captive == nil else { return .commanderCaptive }
        guard commander.level < Commander.highestLevel else { return .maxLevel }
        return nil
    }

    /// What reading a tome would bring a commander, as their line on the
    /// Mac and the phone offers it: "Read a Tome of Old Campaigns: 300
    /// experience, to level 5".
    public func tomeSaid(for commanderID: Int) -> String {
        let read = "Read a \(ItemKind.tome.title): \(GameState.tomeExperience) experience"
        guard let commander = commander(commanderID) else { return read }
        let after = Commander.level(forExperience: commander.experience + GameState.tomeExperience)
        return after > commander.level ? "\(read), to level \(after)" : read
    }

    /// A House's commander reads one of its tomes: its experience rises,
    /// and with it, perhaps, its level.
    mutating func readTome(by commanderID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = tomeRefusal(for: commanderID, as: house) { throw refusal }
        let index = commanderIndex(commanderID)!
        let before = commanders![index].level
        commanders![index].experience = min(commanders![index].experience + GameState.tomeExperience,
                                            Commander.experience(forLevel: Commander.highestLevel))
        spend(.tome, of: house)
        var events: [GameEvent] = [.tomeRead(commander: commanderID, house: house)]
        let after = commanders![index].level
        if after > before {
            events.append(.commanderRose(commander: commanderID, house: house, level: after))
        }
        return events
    }
}
