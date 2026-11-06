import Foundation

/// The models made in Blender (each by its script in Art/blender), written
/// into the package by Art/embed.py, and read by Asset as the world asks for
/// them.
enum Art {
    /// The bones of every figure on foot after its root, in the order the
    /// rig keeps them (Limb), so a figure made in Blender is moved, put
    /// away and drawn as the figures built in code are.
    static let limbs = ["hips", "torso", "head", "armL", "forearmL", "armR", "forearmR", "thighL", "shinL", "thighR", "shinR",
                        "heldR", "heldL", "cloak", "tool", "extra"]
    /// Figures are made 1.8 tall and drawn as tall as those built in code.
    static let figureScale: Float = 0.3 / 1.8
    /// Archers are drawn a twentieth taller: lean and tall, as their kind is.
    static let archerScale: Float = 0.315 / 1.8
    /// Lantern-bearers a thirtieth shorter: slight and wiry.
    static let lanternScale: Float = 0.29 / 1.8
    /// A Mangonel's crewman and a founder a fifteenth shorter: short and
    /// stocky, the engine and the handcart made at their measure
    /// (Art/blender/carts.py).
    static let stockyScale: Float = 0.28 / 1.8
    /// The bones of a horse and its rider after its root, in the order the
    /// rig every horse and rider keeps them (Steed): the horse's, then the
    /// rider's astride.
    static let steed = ["body", "neck", "horseHead", "tail", "foreLegL", "foreShinL", "foreLegR", "foreShinR", "hindLegL", "hindShinL",
                        "hindLegR", "hindShinR", "hips", "torso", "head", "armL", "forearmL", "armR", "forearmR", "heldR", "heldL", "cloak",
                        "tool"]
    /// A rider is made seated at a man's height, his horse's hooves this far
    /// below the ground (GROUND in Art/blender/horse.py), and lifted as he
    /// is read till they stand on it.
    static let hooves: Float = 0.56
    /// Commanders are drawn a ninth larger than a company's riders: tall and
    /// broad, on great horses.
    static let commanderScale: Float = figureScale * 1.12
    /// The six commanders, as their file names them, in the order the game
    /// numbers them.
    static let commanders = ["warden", "lamplighter", "saltCrown", "hornedAxe", "standard", "tideHeir"]

    /// A company's figure made in Blender, at its tier, or as a heritage's
    /// own company (its variant) in place of a tier; `more`, the bones of
    /// its own kind it keeps next after the limbs (the archer's string).
    static func figure(_ base64: String, tier: Int, variant: String? = nil, name: String, more: [String] = [],
                       scale: Float = figureScale) -> Model {
        model(base64, tier: tier, variant: variant, name: name, order: limbs + more, scale: scale)
    }

    /// A rider and his horse made in Blender, at the rider's tier or as a
    /// heritage's own riders (its variant), the horse's coat, socks and mane
    /// the colours of `mount`'s.
    static func rider(tier: Int, variant: String? = nil, name: String, mount: Mount) -> Model {
        model(horseman, tier: tier, variant: variant, name: name, order: steed, lift: hooves * figureScale, colours: colours(of: mount))
    }

    /// One of the six commanders made in Blender, on a horse coloured as
    /// `mount` is. The last of their bones is where a rider's mattock
    /// hangs: no commander digs, and the Lamplighter's light rides it.
    static func commander(_ variant: Int, name: String, mount: Mount) -> Model {
        model(heroes, tier: 1, variant: commanders[variant], name: name, order: steed, scale: commanderScale,
              lift: hooves * commanderScale, colours: colours(of: mount))
    }

    /// A horse's coat, socks and mane, by the names of the materials they
    /// are made in.
    static func colours(of mount: Mount) -> [String: Vec3] {
        ["plain_coat": mount.coat, "plain_socks": mount.socks ?? mount.coat, "plain_mane": mount.mane]
    }

    /// A Mangonel and its crewman made in Blender, at its tier: his limbs,
    /// then the engine's wheels, arm and stone (Engine), in the order the
    /// game names them.
    static func mangonel(tier: Int, name: String) -> Model {
        model(engine, tier: tier, name: name, order: limbs + ["wheelL", "wheelR", "arm", "stone"], scale: stockyScale)
    }

    /// The things of the far country made in Blender, each its own file and
    /// drawn at its own height: the hollow, the thornwight, the colossus.
    static func wild(tier: Int, name: String) -> Model {
        let (base64, height): (String, Float) = switch tier {
        case 1: (hollow, 0.34)
        case 2: (thornwight, 0.37)
        default: (colossus, 0.56)
        }
        return model(base64, tier: 1, name: name, order: limbs, scale: height / 1.8)
    }

    /// The founder and his handcart made in Blender: his limbs, then the
    /// cart's wheels (Cart), in the order the game names them.
    static func founder(name: String) -> Model {
        model(settler, tier: 1, name: name, order: limbs + ["wheelL", "wheelR"], scale: stockyScale)
    }

    /// One of the townsfolk made in Blender, by the name its file gives
    /// them (Folk.names), drawn `height` tall.
    static func folk(_ variant: String, name: String, height: Float) -> Model {
        model(townsfolk, tier: 1, variant: variant, name: name, order: limbs, scale: height / 1.8)
    }

    /// A carter and their handcart made in Blender, hauling timber or stone:
    /// their limbs, then the cart's wheels (Cart), in the order the game
    /// names them, drawn as tall as the townsfolk.
    static func carter(stone: Bool, name: String) -> Model {
        model(carters, tier: 1, variant: stone ? "stone" : "timber", name: name, order: limbs + ["wheelL", "wheelR"],
              scale: Folk.size / 1.8)
    }

    /// Buildings are made at ten times the world's measure.
    static let buildingScale: Float = 0.1

    /// A keep made in Blender, a seat's or a hold's, built as a people
    /// builds it (`people`, the name its file gives their pieces: the pitch
    /// of their roof and their crown): its walls, dark courses, trim and roof
    /// in `style`'s colours and grains.
    static func keep(seat: Bool, style: KeepStyle, people: String, name: String) -> Model {
        let roofGrain = style.roofGrain ?? Surface.of(style.roof)
        let colours: [String: Vec3] = [
            "plain_stone_wall": style.wall, "plain_stone_dark": style.dark, "plain_stone_trim": style.trim, "plain_slate_roof": style.roof,
            "plain_slate_rib": style.roof * 0.7, "plain_timber_dark": Palette.timberDark, "plain_timber": Palette.timber,
            "plain_timber_pale": Palette.timberPale, "plain_timber_grey": Palette.timberGrey, "house_roof": Palette.house,
            "house_dark": Palette.houseDark, "cloth_banner": Palette.house, "glow_candle": Palette.candle, "glow_fire": Palette.fire,
            "metal_iron": Palette.iron, "metal_gold": Palette.gold, "crystal_moonsalt": Palette.moonsalt, "plain_earth": Palette.earth,
            "foliage_ivy": Palette.leaf,
        ]
        let grains: [String: Surface] = [
            "plain_stone_wall": style.wallGrain ?? Surface.of(style.wall), "plain_stone_dark": Surface.of(style.dark),
            "plain_stone_trim": Surface.of(style.trim), "plain_slate_roof": roofGrain, "plain_slate_rib": roofGrain,
        ]
        return model(seat ? seatKeep : holdKeep, tier: 1, variant: people, name: name, order: [], scale: buildingScale, colours: colours,
                     grains: grains)
    }

    /// A hold's walls made in Blender at their level, each level its tier of
    /// one file: from a palisade of stakes to high walls with round towers
    /// under the House's cones and a gatehouse flying its banner.
    static func walls(level: Int, name: String) -> Model {
        let colours: [String: Vec3] = [
            "plain_stone_patched": Palette.stonePale.mix(Palette.stone, 0.4), "plain_rope": Palette.leatherDark,
            "plain_hole": Palette.barkBlack,
        ]
        return work(wallsFile, level: level, name: name, colours: colours)
    }

    /// A piece of a hold's town made in Blender, each a variant of one file
    /// by the name the game gives it: its homes, well, fields, lanes and
    /// market stalls.
    static func town(_ piece: Town, name: String) -> Model {
        let colours = buildingColours.merging([
            "plain_thatch_cap": Palette.thatch.mix(Palette.bark, 0.3), "plain_water": Palette.loam,
            "plain_clay": Palette.madder.mix(Palette.earth, 0.4),
        ]) { _, own in own }
        return model(townFile, tier: 1, variant: piece.rawValue, name: name, order: [], scale: buildingScale, colours: colours)
    }

    /// The colours of the materials buildings made in Blender are made in,
    /// by their names: the palette's own, exactly.
    static let buildingColours: [String: Vec3] = [
        "plain_stone": Palette.stone, "plain_stone_dark": Palette.stoneDark, "plain_stone_pale": Palette.stonePale,
        "plain_stone_white": Palette.stoneWhite, "plain_slate": Palette.slate, "plain_timber": Palette.timber,
        "plain_timber_dark": Palette.timberDark, "plain_timber_pale": Palette.timberPale, "plain_timber_grey": Palette.timberGrey,
        "plain_timber_bark": Palette.bark, "plain_thatch": Palette.thatch, "plain_earth": Palette.earth, "plain_earth_yard": Palette.yard,
        "plain_earth_loam": Palette.loam, "plain_daub": Palette.linen.mix(Palette.thatch, 0.4), "plain_weld": Palette.weld,
        "plain_madder": Palette.madder, "plain_canvas": Palette.canvas, "plain_linen": Palette.linen, "plain_reed": Palette.reed,
        "metal_iron": Palette.iron, "metal_gold": Palette.gold, "house_roof": Palette.house, "house_door": Palette.house,
        "house_awning": Palette.house, "house_dark": Palette.houseDark, "cloth_banner": Palette.house, "glow_candle": Palette.candle,
        "glow_fire": Palette.fire, "crystal_moonsalt": Palette.moonsalt, "foliage_ivy": Palette.leaf, "foliage_grain": Palette.grain,
        "foliage_straw": Palette.straw, "plain_stone_rock": Palette.rock, "plain_bone": Palette.bone, "metal_bronze": Palette.bronze,
        "plain_thatch_straw": Palette.straw, "plain_soot": Palette.barkBlack, "plain_leather_dark": Palette.leatherDark,
        "metal_steel": Palette.steel, "metal_mail": Palette.mail, "plain_seawool": Palette.seaWool, "plain_moss": Palette.moss,
        "plain_saltcrust": Palette.saltCrust, "crystal_saltcrust": Palette.saltCrust, "glow_moonglow": Palette.moonGlow,
        "glow_moonsalt": Palette.moonsalt, "plain_earth_mud": Palette.loam.mix(Palette.yard, 0.4),
        "plain_earth_quarry": Palette.rock.mix(Palette.yard, 0.5), "plain_water": Palette.slate, "plain_horse_dun": Palette.horseDun,
        "plain_hair": Palette.hair, "plain_leather": Palette.leather, "plain_water_deep": Vec3(0.05, 0.07, 0.09),
        "plain_moss_weld": Palette.moss.mix(Palette.weld, 0.3), "cloth_linen": Palette.linen,
        "plain_stone_ashlar": Palette.stoneWhite * 0.96, "plain_horse_bay": Palette.horseBay, "plain_horse_grey": Palette.horseGrey,
        "plain_horse_black": Palette.horseBlack, "plain_wool": Palette.wool, "plain_ash": Palette.ash,
        "metal_moonsalt": Palette.moonsalt * 0.8, "glow_page": Palette.candle * 0.6,
    ]

    /// An alliance's hall, made in Blender (Art/blender/hall.py), its roof,
    /// shields and banners in the alliance's colour.
    static func hall(name: String) -> Model {
        model(hallFile, tier: 1, name: name, order: [], scale: buildingScale, colours: buildingColours)
    }

    /// The Lyceum's hall or the orrery over its dome, made in Blender
    /// (Art/blender/lyceum.py), each a variant of one file.
    static func lyceum(_ variant: String, name: String) -> Model {
        model(lyceumFile, tier: 1, variant: variant, name: name, order: [], scale: buildingScale, colours: buildingColours)
    }

    /// A holy site made in Blender (Art/blender/shrines.py), each kind a
    /// variant of one file by the kind's name: the ring of standing stones
    /// under their lintels about its heart, its motes turning and its fires
    /// leaping, the pennant in its holder's colour.
    static func shrine(_ kind: String, name: String) -> Model {
        let colours = buildingColours.merging([
            "plain_stone_floor": Palette.stonePale.mix(Palette.stone, 0.5), "plain_stone_bleached": Palette.stonePale.mix(Palette.stoneWhite, 0.35),
            "plain_stone_weathered": Palette.stonePale.mix(Palette.stone, 0.25), "plain_wooldark": Palette.woolDark,
            "crystal_moonglow": Palette.moonGlow, "crystal_slatedrop": Palette.slate, "crystal_stonepale": Palette.stonePale,
            "foliage_grass": Palette.grass, "foliage_thatch_reed": Palette.reed,
        ]) { _, own in own }
        return model(shrinesFile, tier: 1, variant: kind, name: name, order: [], scale: buildingScale, colours: colours)
    }

    /// An alliance's storehouse, or the yard of one of its stores, made in
    /// Blender (Art/blender/stores.py), each a variant of one file: the
    /// storehouse by that name, a yard by its store's.
    static func stores(_ variant: String, name: String) -> Model {
        let colours = buildingColours.merging(["plain_stone_saltearth": Palette.saltCrust.mix(Palette.earth, 0.55)]) { _, own in own }
        return model(storesFile, tier: 1, variant: variant, name: name, order: [], scale: buildingScale, colours: colours)
    }

    /// Where a company gathers, made in Blender (Art/blender/sites.py), each
    /// store's site a variant of one file by the store's name: a field of
    /// grain stooked in rows, a stand of firs part felled, a stone outcrop
    /// cut in faces, a moonsalt pan crusted white.
    static func site(_ store: String, name: String) -> Model {
        let colours = buildingColours.merging([
            "plain_timber_birchbark": Palette.birchBark, "plain_thatch_reed": Palette.reed, "plain_wooldark": Palette.woolDark,
            "plain_jug": Palette.earth.mix(Palette.madder, 0.3), "plain_earth_saltflat": Palette.saltCrust.mix(Palette.earth, 0.5),
            "foliage_fir": Palette.fir, "foliage_firdark": Palette.firDark, "foliage_birchleaf": Palette.birchLeaf,
            "foliage_fern": Palette.fern, "foliage_heather": Palette.heather, "foliage_heatherdark": Palette.heatherDark,
            "foliage_heatherbloom": Palette.heatherBloom, "foliage_reed": Palette.reed, "foliage_grass": Palette.grass,
        ]) { _, own in own }
        return model(sitesFile, tier: 1, variant: store, name: name, order: [], scale: buildingScale, colours: colours)
    }

    /// The land's furniture, made in Blender (Art/blender/furnishings.py),
    /// each kind a variant of one file by its name: the firs, birches and
    /// elder trees, the crags, boulders and cut faces, reeds, grass,
    /// heather and ferns, barrows, standing stones and ruins, driftwood,
    /// furrows, pebbles and stepping stones. Still, but for its foliage
    /// swaying in the wind by its height above the ground.
    static func furnishing(_ kind: String, name: String) -> Model {
        let colours = buildingColours.merging([
            "foliage_fir": Palette.fir, "foliage_firdark": Palette.firDark, "foliage_birchleaf": Palette.birchLeaf,
            "foliage_fern": Palette.fern, "foliage_heather": Palette.heather, "foliage_heatherdark": Palette.heatherDark,
            "foliage_heatherbloom": Palette.heatherBloom, "foliage_grass": Palette.grass, "foliage_thatch_reed": Palette.reed,
            "plain_timber_birchbark": Palette.birchBark, "plain_timber_deadwood": Palette.deadWood,
            "plain_barrowturf": Palette.grass.mix(Palette.earth, 0.3), "plain_ruinturf": Palette.grass.mix(Palette.earth, 0.4),
        ]) { _, own in own }
        return model(furnishingsFile, tier: 1, variant: kind, name: name, order: [], scale: buildingScale, colours: colours)
    }

    /// The tokens the world sets over the land, and the scaffold round a
    /// rising work, made in Blender (Art/blender/tokens.py), each a variant
    /// of one file by its name: a talent's sigil by its tree's number, a
    /// crest's charge by its own, an ally's help light, a border stone, a
    /// crest's board, a barge of the Still and its ferryman, a commander's
    /// star. Still: the world moves each whole.
    static func token(_ variant: String, name: String) -> Model {
        let colours = buildingColours.merging([
            "glow_ember": Vec3(0.95, 0.42, 0.18), "glow_wardblue": Vec3(0.45, 0.68, 1.0), "glow_roadgreen": Vec3(0.55, 0.9, 0.62),
            "glow_helplight": Vec3(1.0, 0.86, 0.55), "glow_starlight": Palette.moonGlow.mix(Palette.gold, 0.35),
            "plain_timber_tar": Palette.timberDark.mix(Vec3(0.05, 0.05, 0.06), 0.55), "plain_hood": Palette.linen.mix(Palette.leather, 0.6),
        ]) { _, own in own }
        return model(tokensFile, tier: 1, variant: variant, name: name, order: [], scale: buildingScale, colours: colours)
    }

    /// The land's marks, made in Blender (Art/blender/marks.py), each a
    /// variant of one file by its name: an alliance's standard on its
    /// plinth, a rally's war camp, a host's banner, the Drowned Crown, a
    /// listening stone and the pedlar's skiff; their fires leaping, the
    /// camp's drum beaten, the crown's halo and the stone's rings turning,
    /// the crown's drips swinging and the pedlar rocking, each a bone of its
    /// skeleton, the host's banner still.
    static func mark(_ variant: String, name: String) -> Model {
        let weed = Vec3(0.13, 0.24, 0.17), crimson = Vec3(0.45, 0.16, 0.18)
        let colours = buildingColours.merging([
            "crystal_moonglow": Palette.moonGlow, "plain_moonsalt": Palette.moonsalt,
            "plain_guyrope": Palette.linen.mix(Palette.leather, 0.5), "plain_cowhorn": Palette.linen.mix(Palette.leather, 0.3),
            "plain_crowngold": Palette.gold.mix(Palette.bronze, 0.35), "plain_verdigris": Palette.bronze.mix(Vec3(0.24, 0.45, 0.38), 0.6),
            "foliage_lakeweed": weed, "foliage_mossweed": weed.mix(Palette.moss, 0.4),
            "plain_pearl": Palette.stoneWhite.mix(Palette.moonGlow, 0.2), "plain_velvet": Palette.madder.mix(Palette.barkBlack, 0.55),
            "crystal_drip": Palette.slate.mix(Palette.moonGlow, 0.4), "glow_ripple": Palette.moonGlow.mix(Palette.slate, 0.5),
            "plain_tar": Palette.timberDark.mix(Vec3(0.05, 0.05, 0.06), 0.6), "plain_awning": Palette.linen.mix(Palette.leather, 0.45),
            "plain_awningpatch": Palette.linen.mix(crimson, 0.35), "plain_timber_crate": Palette.timber.mix(Palette.timberDark, 0.4),
            "plain_crimson": crimson, "plain_bluecloth": Palette.moonGlow.mix(Palette.slate, 0.6),
            "glow_lantern": Palette.fire.mix(Palette.gold, 0.3), "plain_cloak": Vec3(0.12, 0.11, 0.14), "plain_hood": Vec3(0.1, 0.09, 0.12),
        ]) { _, own in own }
        return model(marksFile, tier: 1, variant: variant, name: name, order: [], scale: buildingScale, colours: colours)
    }

    /// A lair of the wilds or a gatehold of the Crown, made in Blender
    /// (Art/blender/lairs.py), each a variant of one file by its kind's
    /// name or "gatehold": still, its fires and wild lights glowing.
    static func lair(_ kind: String, name: String) -> Model {
        let colours = buildingColours.merging([
            "plain_fur": Palette.fur, "plain_timber_deadwood": Palette.deadWood, "glow_wildglow": Palette.wildGlow,
            "foliage_grass": Palette.grass, "foliage_thatch_reed": Palette.reed, "plain_hide": Palette.canvas.mix(Palette.leather, 0.4),
            "plain_stone_mossy": Palette.stonePale.mix(Palette.moss, 0.3), "plain_lichen": Palette.moss.mix(Palette.grass, 0.4),
            "plain_saltbone": Palette.bone.mix(Palette.saltCrust, 0.35), "plain_horn_dark": Palette.bone.mix(Palette.barkBlack, 0.35),
            "plain_horn": Palette.bone.mix(Palette.barkBlack, 0.3), "plain_husk": Palette.bone.mix(Palette.shroud, 0.5),
            "plain_saltwood": Palette.timberGrey.mix(Palette.saltCrust, 0.4), "plain_saltiron": Palette.iron.mix(Palette.saltCrust, 0.5),
            "plain_saltmadder": Palette.madder.mix(Palette.saltCrust, 0.6), "plain_roast": Palette.madder.mix(Palette.leatherDark, 0.55),
            "plain_drumhide": Palette.leather.mix(Palette.linen, 0.4), "plain_urn": Palette.earth.mix(Palette.madder, 0.35),
            "metal_rust": Palette.iron.mix(Palette.madder, 0.3), "plain_antler": Palette.bone.mix(Palette.timber, 0.4),
            "plain_rawhide": Palette.leather.mix(Palette.linen, 0.3), "plain_timber_wet": Palette.timberDark.mix(Palette.barkBlack, 0.45),
            "plain_stone_altar": Palette.stonePale.mix(Palette.moss, 0.25), "metal_mossbronze": Palette.bronze.mix(Palette.moss, 0.35),
            "plain_lilypad": Palette.moss.mix(Palette.leaf, 0.5), "plain_water_black": Vec3(0.03, 0.04, 0.05),
        ]) { _, own in own }
        return model(lairsFile, tier: 1, variant: kind, name: name, order: [], scale: buildingScale, colours: colours)
    }

    /// The rig a family's builders work beside a rising work, made in
    /// Blender (Art/blender/raising.py), each family's a variant of one file
    /// by the family's name, its moving parts the bones tagged for it.
    static func raising(_ family: String, name: String) -> Model {
        model(raisingFile, tier: 1, variant: family, name: name, order: [], scale: buildingScale, colours: buildingColours)
    }

    /// What moves through the world apart from companies, made in Blender
    /// (Art/blender/props.py), each a variant of one file by its name: an
    /// arrow or a stone in flight, a banner, a bird, a cart, a brazier, a
    /// puff of smoke, a fisher's boat, a builder's stores, a waystone.
    static func prop(_ prop: String, name: String) -> Model {
        let colours = buildingColours.merging([
            "plain_feather": Vec3(0.12, 0.12, 0.13), "plain_smoke": Palette.smoke, "plain_wooldark": Palette.woolDark,
            "plain_skin": Palette.skin, "plain_net": Palette.linen * 0.6, "plain_saltcrust_dim": Palette.saltCrust * 0.4,
        ]) { _, own in own }
        return model(propsFile, tier: 1, variant: prop, name: name, order: [], scale: buildingScale, colours: colours)
    }

    /// A work made in Blender at its level, each level its tier of the
    /// family's one file, its moving parts the bones tagged for that level.
    static func work(_ base64: String, level: Int, name: String, colours: [String: Vec3] = [:]) -> Model {
        model(base64, tier: level, name: name, order: [], scale: buildingScale, colours: buildingColours.merging(colours) { _, own in own })
    }

    /// A model made in Blender, its bones in `order` after its root.
    static func model(_ base64: String, tier: Int, variant: String? = nil, name: String, order: [String], scale: Float = figureScale,
                      lift: Float = 0, colours: [String: Vec3] = [:], grains: [String: Surface] = [:]) -> Model {
        do {
            return try Asset.model(name: name, glb: try Asset.bytes(base64: base64), scale: scale, lift: lift, order: order, tier: tier,
                                   variant: variant, colours: colours, grains: grains)
        } catch {
            // Written into the package and read by its tests: never a keeper's to meet.
            preconditionFailure("\(name), made in Blender, can't be read: \(error)")
        }
    }
}
