/// The colours things are made of, as they would look in plain daylight
/// (sRGB albedo): the night darkens and blues them. Grave and old: dark
/// timber, grey stone, pale moonsalt, House colours on cloth.
enum Palette {
    // Wood
    static let timber = Vec3(0.29, 0.21, 0.15)
    static let timberDark = Vec3(0.19, 0.14, 0.11)
    static let timberPale = Vec3(0.45, 0.37, 0.28)
    /// Old wood gone silver in the weather.
    static let timberGrey = Vec3(0.42, 0.39, 0.35)
    static let bark = Vec3(0.21, 0.17, 0.14)
    static let deadWood = Vec3(0.70, 0.67, 0.61)

    // Stone and earth
    static let stone = Vec3(0.52, 0.51, 0.49)
    static let stoneDark = Vec3(0.37, 0.37, 0.38)
    static let stonePale = Vec3(0.68, 0.67, 0.64)
    static let stoneWhite = Vec3(0.84, 0.84, 0.82)
    static let rock = Vec3(0.40, 0.40, 0.42)
    static let slate = Vec3(0.23, 0.24, 0.28)
    static let thatch = Vec3(0.47, 0.41, 0.29)
    static let earth = Vec3(0.24, 0.21, 0.18)
    /// Ground trodden hard round a work.
    static let yard = Vec3(0.31, 0.29, 0.25)
    static let loam = Vec3(0.15, 0.13, 0.11)
    static let moonsalt = Vec3(0.88, 0.91, 0.95)
    static let saltCrust = Vec3(0.80, 0.83, 0.86)

    // Metal
    static let iron = Vec3(0.36, 0.37, 0.40)
    static let steel = Vec3(0.62, 0.65, 0.70)
    static let mail = Vec3(0.47, 0.49, 0.52)
    static let bronze = Vec3(0.55, 0.43, 0.26)
    static let gold = Vec3(0.75, 0.62, 0.32)

    // Cloth and leather
    static let padded = Vec3(0.55, 0.50, 0.41)
    static let wool = Vec3(0.39, 0.37, 0.33)
    static let woolDark = Vec3(0.24, 0.24, 0.25)
    static let linen = Vec3(0.70, 0.67, 0.60)
    /// Grey-blue wool, dyed with the strand's sea-holly.
    static let seaWool = Vec3(0.27, 0.33, 0.38)
    static let leather = Vec3(0.36, 0.25, 0.17)
    static let leatherDark = Vec3(0.22, 0.16, 0.12)
    static let fur = Vec3(0.33, 0.29, 0.25)
    static let canvas = Vec3(0.62, 0.58, 0.49)

    // People and beasts
    static let skin = Vec3(0.74, 0.60, 0.50)
    static let hair = Vec3(0.21, 0.17, 0.14)
    static let horseBay = Vec3(0.36, 0.23, 0.15)
    static let horseDun = Vec3(0.52, 0.43, 0.31)
    static let horseGrey = Vec3(0.62, 0.62, 0.62)
    static let horseBlack = Vec3(0.13, 0.12, 0.12)
    static let horsePale = Vec3(0.82, 0.81, 0.78)
    static let hoof = Vec3(0.15, 0.13, 0.12)

    // The far country
    static let bone = Vec3(0.80, 0.78, 0.70)
    static let ash = Vec3(0.55, 0.56, 0.56)
    static let shroud = Vec3(0.68, 0.70, 0.70)
    static let barkBlack = Vec3(0.11, 0.10, 0.10)
    static let moss = Vec3(0.21, 0.26, 0.22)

    // Growing things
    static let fir = Vec3(0.11, 0.19, 0.15)
    static let firDark = Vec3(0.08, 0.14, 0.12)
    static let leaf = Vec3(0.16, 0.24, 0.17)
    static let grass = Vec3(0.37, 0.41, 0.31)
    static let reed = Vec3(0.47, 0.45, 0.33)
    static let grain = Vec3(0.66, 0.60, 0.40)
    static let straw = Vec3(0.62, 0.55, 0.36)
    static let smoke = Vec3(0.62, 0.63, 0.65)

    /// Tinted by the owning House's colour.
    static let house = Vec3(0.78, 0.78, 0.78)
    static let houseDark = Vec3(0.50, 0.50, 0.50)

    // Light
    static let fire = Vec3(1.0, 0.68, 0.32)
    static let candle = Vec3(1.0, 0.80, 0.52)
    static let moonGlow = Vec3(0.72, 0.86, 1.0)
    static let wildGlow = Vec3(0.55, 0.95, 0.88)
}
