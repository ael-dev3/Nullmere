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
