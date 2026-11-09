import Foundation
import XCTest
@testable import NullmereCore

/// Counsel taken of a commander: grounded in the keeper's own view, never
/// the whole world; looks that tell only what the House sees; orders only
/// ever proposed, and weighed as the realm would weigh them; a memory of
/// the last few exchanges within a budget; and the keeper told honestly why
/// no counsel came.
final class CommanderCounselTests: XCTestCase {
    /// A keeper's House with its first commander leading a spear at its
    /// seat, as the keeper's own view holds it.
    private func counsel(_ seed: String = "counsel") throws -> (CommanderCounsel, world: GameState) {
        var world = Scene.world(seed)
        let me = world.player
        let commander = try XCTUnwrap(world.commanders(of: me).first).id
        let seat = try XCTUnwrap(world.seat(of: me))
        let spear = try XCTUnwrap(world.units(of: me).first { $0.kind == .spear })
        if let there = world.unit(at: seat.position), let other = world.unitIndex(there.id) {
            world.units[other].position = spear.position
        }
        world.units[try XCTUnwrap(world.unitIndex(spear.id))].position = seat.position
        try world.perform(.assign(commander: commander, unit: spear.id), as: me)
        let view = world.view(for: me)
        return (try XCTUnwrap(CommanderCounsel(state: view, player: me, commander: commander)), world)
    }

    /// The commander is who the instructions say, of their own kind, and
    /// held to the facts; the briefing names their company by its handle.
    func testTheCommanderSpeaksAsThemselfFromTheBriefing() throws {
        let (counsel, _) = try counsel()
        let commander = counsel.commander
        XCTAssertTrue(counsel.instructions.contains(commander.name))
        XCTAssertTrue(counsel.instructions.contains(commander.archetype.named))
        XCTAssertTrue(counsel.instructions.contains("never invent"))
        XCTAssertTrue(counsel.instructions.contains("only by proposing it"))
        let company = try XCTUnwrap(counsel.company)
        let handle = try XCTUnwrap(counsel.handle(of: company))
        XCTAssertTrue(counsel.briefing.contains("You lead \(handle), \(SpokenOrders.named(company, in: counsel.state))"))
        // Its march as its keeper is told it, which way and how far, never
        // "marching to on" the ground.
        var marching = counsel.state
        let index = try XCTUnwrap(marching.unitIndex(company.id))
        let ground = try XCTUnwrap(company.position.neighbors.first { marching.map[$0] != nil && marching.hold(at: $0) == nil })
        marching.units[index].destination = ground
        let told = try XCTUnwrap(CommanderCounsel(state: marching, player: counsel.player, commander: commander.id)).briefing
        let terrain = try XCTUnwrap(marching.map[ground]?.terrain)
        XCTAssertTrue(told.contains("marching to \(terrain.ground), 1 tile \(GameState.direction(of: ground, from: company.position))"), told)
        XCTAssertFalse(told.contains("marching to on") || told.contains("marching to at"), told)
        XCTAssertTrue(counsel.briefing.contains("It is watch \(counsel.state.watch)."))
        XCTAssertTrue(counsel.briefing.contains("Its stores:"))
        for skill in commander.skills { XCTAssertTrue(counsel.briefing.contains(skill.title)) }
        // Each kind counsels its own way.
        XCTAssertEqual(Set(Archetype.allCases.map { kind -> String in
            var other = counsel.state
            let old = other.commanders![commander.id - 1]
            other.commanders![commander.id - 1] = Commander(id: old.id, name: old.name, archetype: kind, owner: old.owner)
            return CommanderCounsel(state: other, player: counsel.player, commander: commander.id)!.bent
        }).count, Archetype.allCases.count)
    }

    /// Only the keeper's own commanders give counsel.
    func testOnlyTheKeepersOwnCommandersCounsel() throws {
        let (counsel, world) = try counsel()
        let theirs = try XCTUnwrap(world.commanders(of: 1).first)
        XCTAssertNil(CommanderCounsel(state: counsel.state, player: counsel.player, commander: theirs.id))
        XCTAssertNil(CommanderCounsel(state: counsel.state, player: counsel.player, commander: 9_999))
    }

    /// A company is told by its handle; one the House hasn't is said to be
    /// none of its own.
    func testACompanyIsToldByItsHandle() throws {
        let (counsel, _) = try counsel()
        let company = try XCTUnwrap(counsel.company)
        let handle = try XCTUnwrap(counsel.handle(of: company))
        let told = counsel.report(on: handle)
        XCTAssertTrue(told.hasPrefix("\(handle): \(SpokenOrders.named(company, in: counsel.state))"))
        XCTAssertTrue(told.contains("\(counsel.commander.name) leads it."))
        XCTAssertEqual(counsel.report(on: "C99"), "Your House has no company C99.")
        XCTAssertEqual(counsel.report(on: " C99 "), "Your House has no company C99.")
    }

    /// A look about the commander's company tells what lies within reach,
    /// the nearest first, and only what the House sees: a company of
    /// another House out of its sight is none of the commander's knowing.
    func testALookTellsOnlyWhatTheHouseSees() throws {
        var (counsel, world) = try counsel()
        let me = counsel.player
        let here = try XCTUnwrap(counsel.company).position
        // Another House's spear set three tiles off, where the House sees,
        // and another far beyond its sight.
        let theirs = try XCTUnwrap(world.units(of: 1).first { $0.kind == .spear || $0.kind == .bow })
        func land(_ hex: Hex) -> Bool { world.map[hex].map { !$0.terrain.isWater } ?? false }
        let visible = world.visibility(for: me)
        func seen(_ hex: Hex) -> Bool { world.map.index(of: hex).map { visible[$0] } ?? false }
        let near = try XCTUnwrap(world.map.hexes.filter { (2...3).contains($0.distance(to: here)) && land($0) && seen($0) && world.unit(at: $0) == nil }
            .min { ($0.distance(to: here), $0.q, $0.r) < ($1.distance(to: here), $1.q, $1.r) })
        world.units[try XCTUnwrap(world.unitIndex(theirs.id))].position = near
        let far = try XCTUnwrap(world.map.hexes.first {
            $0.distance(to: here) > 12 && land($0) && !(world.map.index(of: $0).map { visible[$0] } ?? true) && world.unit(at: $0) == nil
        })
        let hidden = try XCTUnwrap(world.units(of: 2).first)
        world.units[try XCTUnwrap(world.unitIndex(hidden.id))].position = far
        counsel = try XCTUnwrap(CommanderCounsel(state: world.view(for: me), player: me, commander: counsel.commander.id))
        let look = counsel.lookAround(within: 4)
        XCTAssertTrue(look.hasPrefix("Within 4 tiles of your company, \(counsel.state.placeName(of: here)), your House sees:"), look)
        XCTAssertTrue(look.contains("\(world.houses[1].title)'s"), look)
        // Which way and how far, as every line says it: never "1 tiles off".
        let way = GameState.waySaid(to: near, from: here)
        XCTAssertTrue(look.contains("\(way), at war") || look.contains("\(way), at peace"), look)
        XCTAssertFalse(look.contains("tiles off"), look)
        XCTAssertFalse(look.contains(world.houses[2].title + "'s"), "Out of sight, out of counsel: \(look)")
        // The widest look is eight tiles, the narrowest one.
        XCTAssertTrue(counsel.lookAround(within: 40).hasPrefix("Within 8 tiles"))
        XCTAssertTrue(counsel.lookAround(within: 0).hasPrefix("Within 1 tile of"))
        // A commander leading no company has nothing to look out from.
        var idle = counsel.state
        if let index = idle.units.firstIndex(where: { $0.leader == counsel.commander.id }) { idle.units[index].leader = nil }
        let unled = try XCTUnwrap(CommanderCounsel(state: idle, player: me, commander: counsel.commander.id))
        XCTAssertEqual(unled.lookAround(within: 4), "You lead no company to look out from.")
        XCTAssertTrue(unled.briefing.contains("You lead no company now."))
    }

    /// The House's affairs: holds and companies, every store, its wars.
    func testTheHousesAffairsAreTold() throws {
        var (counsel, world) = try counsel()
        let me = counsel.player
        XCTAssertTrue(counsel.affairs.contains("It is at war with no House."))
        // Counted as a keeper would say it: "1 hold", never "1 holds".
        let holds = world.holds(of: me).count, companies = world.units(of: me).count
        XCTAssertTrue(counsel.affairs.hasPrefix("Your House holds \(holds == 1 ? "1 hold" : "\(holds) holds") and \(GameState.companies(companies))."),
                      counsel.affairs)
        for resource in Resource.allCases { XCTAssertTrue(counsel.affairs.contains(resource.title.lowercased())) }
        try world.perform(.declareWar(on: 1), as: me)
        counsel = try XCTUnwrap(CommanderCounsel(state: world.view(for: me), player: me, commander: counsel.commander.id))
        XCTAssertTrue(counsel.affairs.contains("It is at war with \(world.houses[1].title)."), counsel.affairs)
    }

    /// An order is only ever proposed, read as the order book reads it: a
    /// march to a place the House knows is put forward as the realm would
    /// take it; one the realm wouldn't is told why, and nothing else is a
    /// commander's to propose.
    func testOrdersAreProposedAndWeighedAsTheRealmWeighsThem() throws {
        let (counsel, _) = try counsel()
        let company = try XCTUnwrap(counsel.company)
        let handle = try XCTUnwrap(counsel.handle(of: company))
        let place = try XCTUnwrap(counsel.state.holds.first { $0.owner != counsel.player })
        let march = counsel.propose("march", company: handle, place: place.name)
        XCTAssertEqual(march.line, "MARCH \(handle) TO \(place.name)")
        XCTAssertTrue(march.isGiven, march.why ?? "")
        XCTAssertEqual(march.command, .move(unit: company.id, to: place.position))
        XCTAssertTrue(march.answer.hasPrefix("Put forward to your keeper:"))
        XCTAssertTrue(march.answer.hasSuffix("The keeper decides."))

        let dig = counsel.propose(" Fortify ", company: handle, place: "")
        XCTAssertEqual(dig.command, .fortify(unit: company.id))

        let nowhere = counsel.propose("march", company: handle, place: "Nowhere At All")
        XCTAssertFalse(nowhere.isGiven)
        XCTAssertEqual(nowhere.why, "Your House knows no place by the name Nowhere At All.")
        XCTAssertTrue(nowhere.answer.hasPrefix("That cannot be ordered:"))

        XCTAssertEqual(counsel.propose("march", company: handle, place: "").why, "A march or a strike wants a place to go to.")
        XCTAssertEqual(counsel.propose("march", company: "C99", place: place.name).why, "Your House has no company C99.")
        let burn = counsel.propose("burn", company: handle, place: place.name)
        XCTAssertNil(burn.command)
        XCTAssertEqual(burn.why, "A commander may propose only that a company march, strike, fortify, halt, drill, kindle (set the wood alight), "
                       + "douse (its torches, to march dark), light (its torches again) or wait (lie in wait in the blackwood, marching dark).")
        XCTAssertEqual(CommanderCounsel.actions, ["march", "strike", "fortify", "halt", "drill", "kindle", "douse", "light", "wait"])
        // A company at the seat can set nothing alight: put forward as a
        // line, and told why in the realm's own words.
        let kindle = counsel.propose("kindle", company: handle, place: "")
        XCTAssertEqual(kindle.line, "KINDLE \(handle)")
        XCTAssertEqual(kindle.command, .kindle(unit: company.id))
        XCTAssertEqual(kindle.why, counsel.state.kindleRefusal(company.id, as: counsel.player)?.description)
        XCTAssertFalse(kindle.isGiven)
    }

    /// A commander whose company stands in blackwood it may set alight is
    /// told so, and which way the wind blows, and may put the fire to the
    /// keeper as the realm would take it.
    func testACommanderInTheBlackwoodMayPutTheFireForward() throws {
        var (counsel, world) = try counsel()
        let me = counsel.player
        let company = try XCTUnwrap(counsel.company)
        let seat = try XCTUnwrap(world.seat(of: me)).position
        let sites = Set(world.sitesInLand.map(\.position))
        let owners = world.territory()
        let wood = try XCTUnwrap(world.map.hexes.filter { hex in
            world.isBlackwood(hex) && world.hold(at: hex) == nil && !sites.contains(hex) && world.unit(at: hex) == nil
                && (world.territoryOwner(of: hex, in: owners) ?? me) == me
        }.min { ($0.distance(to: seat), $0.q, $0.r) < ($1.distance(to: seat), $1.q, $1.r) })
        world.units[try XCTUnwrap(world.unitIndex(company.id))].position = wood
        counsel = try XCTUnwrap(CommanderCounsel(state: world.view(for: me), player: me, commander: counsel.commander.id))
        let handle = try XCTUnwrap(counsel.handle(of: try XCTUnwrap(counsel.company)))
        XCTAssertNil(counsel.state.kindleRefusal(company.id, as: me))
        XCTAssertTrue(counsel.briefing.contains(", standing in blackwood it may set alight (\(counsel.state.windSaid))."), counsel.briefing)
        XCTAssertTrue(counsel.report(on: handle).contains("standing in blackwood it may set alight"))
        let fire = counsel.propose("Kindle", company: handle, place: "")
        XCTAssertTrue(fire.isGiven, fire.why ?? "")
        XCTAssertEqual(fire.command, .kindle(unit: company.id))
        XCTAssertEqual(fire.told, "Your \(SpokenOrders.named(try XCTUnwrap(counsel.company), in: counsel.state)) set the wood alight.")
        // Set alight, it is told so no longer.
        try world.perform(.kindle(unit: company.id), as: me)
        let after = try XCTUnwrap(CommanderCounsel(state: world.view(for: me), player: me, commander: counsel.commander.id))
        XCTAssertFalse(after.briefing.contains("standing in blackwood it may set alight"), after.briefing)
    }

    /// A commander may put it to the keeper that its company douse its
    /// torches and march dark, and once it does is told it marches dark and
    /// may put it that the company light them again, each as the realm
    /// would take it.
    func testACommanderMayPutTheMarchInTheDarkForward() throws {
        var (counsel, world) = try counsel()
        let me = counsel.player
        let company = try XCTUnwrap(counsel.company)
        let handle = try XCTUnwrap(counsel.handle(of: company))
        XCTAssertFalse(counsel.briefing.contains("marching dark"), counsel.briefing)
        let douse = counsel.propose(" Douse ", company: handle, place: "")
        XCTAssertEqual(douse.line, "DOUSE \(handle)")
        XCTAssertTrue(douse.isGiven, douse.why ?? "")
        XCTAssertEqual(douse.command, .torches(unit: company.id, lit: false))
        XCTAssertEqual(douse.told, "Your \(SpokenOrders.named(company, in: counsel.state)) douse their torches and march dark.")
        // Lit already: told why in the realm's own words.
        let lit = counsel.propose("light", company: handle, place: "")
        XCTAssertFalse(lit.isGiven)
        XCTAssertEqual(lit.why, counsel.state.torchRefusal(company.id, lit: true, as: me)?.description)
        // Doused, it is told it marches dark, and may be lit again.
        try world.perform(.torches(unit: company.id, lit: false), as: me)
        let dark = try XCTUnwrap(CommanderCounsel(state: world.view(for: me), player: me, commander: counsel.commander.id))
        XCTAssertTrue(dark.briefing.contains(", marching dark, its torches doused"), dark.briefing)
        XCTAssertTrue(dark.report(on: handle).contains("marching dark, its torches doused"))
        let light = dark.propose("light", company: handle, place: "")
        XCTAssertTrue(light.isGiven, light.why ?? "")
        XCTAssertEqual(light.command, .torches(unit: company.id, lit: true))
        XCTAssertFalse(dark.propose("douse", company: handle, place: "").isGiven, "Dark already")
    }

    /// A commander whose company marches dark in the blackwood is told it
    /// may lie in wait there, and may put the ambush to the keeper as the
    /// realm would take it; once it waits, they are told so.
    func testACommanderMayPutAnAmbushForward() throws {
        var (counsel, world) = try counsel()
        let me = counsel.player
        let company = try XCTUnwrap(counsel.company)
        let handle = try XCTUnwrap(counsel.handle(of: company))
        // Its torches lit, out of the wood: nothing to put forward but why not.
        let early = counsel.propose("wait", company: handle, place: "")
        XCTAssertEqual(early.line, "WAIT \(handle)")
        XCTAssertFalse(early.isGiven)
        XCTAssertEqual(early.why, counsel.state.waitRefusal(company.id, waiting: true, as: me)?.description)
        // Marching dark in the blackwood the House knows, nearest its seat.
        let seat = try XCTUnwrap(world.seat(of: me)).position
        let seen = world.view(for: me)
        let wood = try XCTUnwrap(world.map.hexes.filter { hex in
            seen.isCover(hex) && world.hold(at: hex) == nil && world.unit(at: hex) == nil
        }.min { ($0.distance(to: seat), $0.q, $0.r) < ($1.distance(to: seat), $1.q, $1.r) })
        world.units[try XCTUnwrap(world.unitIndex(company.id))].position = wood
        try world.perform(.torches(unit: company.id, lit: false), as: me)
        let dark = try XCTUnwrap(CommanderCounsel(state: world.view(for: me), player: me, commander: counsel.commander.id))
        XCTAssertTrue(dark.briefing.contains(", in the blackwood where it may lie in wait, marching dark"), dark.briefing)
        let ambush = dark.propose(" Wait", company: handle, place: "")
        XCTAssertTrue(ambush.isGiven, ambush.why ?? "")
        XCTAssertEqual(ambush.command, .lieInWait(unit: company.id, waiting: true))
        XCTAssertEqual(ambush.told, "Your \(SpokenOrders.named(try XCTUnwrap(dark.company), in: dark.state)) lie in wait in the wood.")
        // Waiting, it is told so, and waits already.
        try world.perform(.lieInWait(unit: company.id, waiting: true), as: me)
        let waiting = try XCTUnwrap(CommanderCounsel(state: world.view(for: me), player: me, commander: counsel.commander.id))
        XCTAssertTrue(waiting.report(on: handle).contains("lying in wait in the wood"), waiting.report(on: handle))
        XCTAssertEqual(waiting.propose("wait", company: handle, place: "").why, RuleError.waitingAlready(true).description)
    }

    /// A commander is told of the House's watchfires and of what their light
    /// lately made out marching dark, the latest first, so their counsel
    /// can weigh a foe moving by night.
    func testACommanderIsToldWhatTheHousesWatchfiresMadeOut() throws {
        var (counsel, world) = try counsel()
        let me = counsel.player
        XCTAssertFalse(counsel.affairs.contains("watchfire"), counsel.affairs)
        world.houses[me].stock.timber = 100
        let owners = world.territory()
        let at = try XCTUnwrap(world.map.hexes.first { hex in
            world.territoryOwner(of: hex, in: owners) == me && world.watchfireRefusal(at: hex, as: me) == nil
        })
        _ = try world.perform(.watchfire(at), as: me)
        let lit = try XCTUnwrap(CommanderCounsel(state: world.view(for: me), player: me, commander: counsel.commander.id))
        XCTAssertTrue(lit.affairs.contains("Its watchfires burn \(world.placeName(of: at))."), lit.affairs)
        XCTAssertFalse(lit.affairs.contains("made out"), lit.affairs)
        // A foe's company comes marching dark into its light.
        let foe = try XCTUnwrap(world.livingHouses.first { $0.id != me && !world.watchers(for: me).contains($0.id) }).id
        let spot = try XCTUnwrap(at.spiral(Watchfire.reach).first { hex in
            guard hex != at, let terrain = world.map[hex]?.terrain else { return false }
            return terrain.isPassable && !terrain.isWater && world.unit(at: hex) == nil && world.hold(at: hex) == nil
        })
        let company = try XCTUnwrap(world.placeUnit(.spear, tier: 1, for: foe, near: spot))
        world.units[try XCTUnwrap(world.unitIndex(company.id))].position = spot
        _ = try world.perform(.torches(unit: company.id, lit: false), as: foe)
        XCTAssertEqual(world.keepWatchByFire().count, 1)
        let told = try XCTUnwrap(CommanderCounsel(state: world.view(for: me), player: me, commander: counsel.commander.id))
        let sighting = try XCTUnwrap(world.watchfire(at: at)?.seen?.last)
        XCTAssertTrue(told.affairs.contains("In watch \(sighting.watch) its watchfire \(world.placeName(of: at)) made out "
                                            + "\(world.houses[foe].title)'s \(world.named(.spear, tier: 1, of: foe)), "
                                            + "\(GameState.counted(sighting.troops)) troops, marching dark \(world.placeName(of: spot))."), told.affairs)
        XCTAssertTrue(told.briefing.contains("made out"), "Briefed with it")
        XCTAssertEqual(CommanderCounsel.sightingsTold, 3)
    }

    /// The commander remembers the last few exchanges, the oldest let go,
    /// and recalls the latest within a budget.
    func testTheCommanderRemembersTheLatestWithinABudget() throws {
        var memory = CounselMemory(commander: 3, age: 2)
        XCTAssertNil(memory.recalled(within: 1_000))
        for watch in 1...(CounselMemory.kept + 3) {
            memory.remember("Question \(watch)?", "Answer \(watch).", at: watch)
        }
        XCTAssertEqual(memory.exchanges.count, CounselMemory.kept)
        XCTAssertEqual(memory.exchanges.first?.watch, 4)
        let all = try XCTUnwrap(memory.recalled(within: 100_000))
        XCTAssertTrue(all.hasPrefix("At watch 4 your keeper said: Question 4? You answered: Answer 4."))
        XCTAssertTrue(all.hasSuffix("Answer 15."))
        let short = try XCTUnwrap(memory.recalled(within: 130))
        XCTAssertFalse(short.contains("Question 14?"), "Only the latest within the budget")
        XCTAssertTrue(short.contains("Question 15?"))
        XCTAssertNil(memory.recalled(within: 10), "Nothing recalled that won't fit whole")
        // Kept as it was written.
        let data = try JSONEncoder().encode(memory)
        XCTAssertEqual(try JSONDecoder().decode(CounselMemory.self, from: data), memory)
        XCTAssertEqual(CounselMemory(commander: 1, age: 1, exchanges: memory.exchanges + memory.exchanges).exchanges.count, CounselMemory.kept)
    }

    /// The budget leaves room for the counsel itself.
    func testTheBudgetLeavesRoomForTheCounsel() throws {
        let (counsel, _) = try counsel()
        let room = CounselBudget.recall(context: 4_096, instructions: counsel.instructions, briefing: counsel.briefing)
        XCTAssertGreaterThan(room, 1_000)
        XCTAssertLessThan(Double(counsel.instructions.count + counsel.briefing.count + room),
                          4_096 * CounselBudget.broughtShare * CounselBudget.charactersPerToken + 1)
        XCTAssertEqual(CounselBudget.recall(context: 100, instructions: counsel.instructions, briefing: counsel.briefing), 0)
    }

    /// Why no counsel came is told plainly, never answered for.
    func testTroubleIsToldPlainly() {
        let all: [CounselTrouble] = [.unavailable(.deviceNotEligible), .unavailable(.appleIntelligenceOff), .unavailable(.modelNotReady),
                                     .unavailable(.systemTooOld), .refused, .language, .busy, .tooLong, .garbled, .assetsMissing, .slow,
                                     .silent, .failed("the stars are wrong")]
        XCTAssertEqual(Set(all.map(\.said)).count, all.count)
        XCTAssertTrue(CounselTrouble.unavailable(.deviceNotEligible).said.contains("Everything else plays as ever"))
        XCTAssertTrue(CounselTrouble.unavailable(.appleIntelligenceOff).said.contains("System Settings"))
        XCTAssertTrue(CounselTrouble.failed("the stars are wrong").said.hasSuffix("the stars are wrong"))
    }

    /// The foot of the counsel sheet, on the Mac and the phone alike: who
    /// speaks and how long the last answer took; and where the model can't
    /// be asked, never that it speaks there, only that nothing answers in
    /// its place, whatever an earlier answer took.
    func testTheFootSaysWhoSpeaksAndNeverClaimsAVoiceThatCantSpeak() {
        XCTAssertEqual(CommanderCounsel.foot(on: "Mac", canAsk: true), "Spoken by Apple's on-device model on this Mac")
        XCTAssertEqual(CommanderCounsel.foot(on: "iPhone", canAsk: true, firstWords: 0.84, whole: 3.12),
                       "Spoken by Apple's on-device model on this iPhone · first words 0.8 s, all of it 3.1 s")
        XCTAssertEqual(CommanderCounsel.foot(on: "Mac", canAsk: true, firstWords: 0.84), "Spoken by Apple's on-device model on this Mac",
                       "No timing told until the whole answer is in")
        for device in ["Mac", "iPhone"] {
            let foot = CommanderCounsel.foot(on: device, canAsk: false, firstWords: 1.2, whole: 4.5)
            XCTAssertEqual(foot, "Only Apple's on-device model gives counsel, and nothing answers in its place")
            XCTAssertFalse(foot.contains("Spoken"), "Never a voice claimed where it can't speak")
        }
    }

    /// How the voices stand where Apple's model can't be asked, as the Mac's
    /// settings tell it: who falls silent and why, for every reason; and
    /// where it can be, who speaks through it.
    func testTheVoicesSayWhyTheyAreSilent() {
        let reasons: [CounselTrouble.Unavailability] = [.deviceNotEligible, .appleIntelligenceOff, .modelNotReady, .systemTooOld]
        for reason in reasons {
            XCTAssertTrue(reason.voicesSaid.contains("the envoys and the chronicle go unvoiced, your commanders give no counsel, "
                                                     + "and the order book reads your words as they are written"), reason.voicesSaid)
        }
        XCTAssertEqual(Set(reasons.map(\.voicesSaid)).count, reasons.count, "Each reason its own words")
        XCTAssertTrue(CounselTrouble.Unavailability.deviceNotEligible.voicesSaid.hasPrefix("This Mac can't run Apple's on-device model"))
        XCTAssertTrue(CounselTrouble.Unavailability.appleIntelligenceOff.voicesSaid.hasSuffix("until it is turned on."))
        XCTAssertTrue(CounselTrouble.voicesReady.hasSuffix("nothing they say leaves the Mac."))
    }

    /// What the system says of a failure is told where a keeper can read
    /// it; its stock words for an error it has nothing to say of, which
    /// name a type and a code, never are.
    func testTheSystemsStockWordsAreNeverShown() {
        let stock = ["The operation couldn’t be completed. (FoundationModels.LanguageModelSession.GenerationError error -1.)",
                     "The operation couldn't be completed. (FoundationModels.LanguageModelSession.GenerationError error -1.)", ""]
        for said in stock {
            XCTAssertEqual(CounselTrouble.told(said), .silent, said)
        }
        XCTAssertEqual(CounselTrouble.told("The stars are wrong."), .failed("The stars are wrong."))
        for told in [CounselTrouble.silent.said, CounselTrouble.silent.unreadOrders, CounselTrouble.silent.ordersReadAsWritten] {
            XCTAssertFalse(told.contains("error"), told)
            XCTAssertFalse(told.contains("("), told)
        }
    }
}
