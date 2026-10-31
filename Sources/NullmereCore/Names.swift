/// Original names for the Houses and their holds.
public enum Names {
    /// The great Houses that may sit around the lake: the twelve elder
    /// Houses, then the younger ones that take the seats of a wider lake.
    /// A House's place among them is its sigil, and so its colour.
    public static let houses = elder + younger

    /// The elder Houses, seated at every lake of twelve seats or fewer.
    public static let elder = [
        "Aurel", "Venn", "Morcant", "Seris", "Okon", "Thale", "Dravic", "Ysolde",
        "Lioth", "Quell", "Brannoch", "Sefa",
    ]

    /// The younger Houses, seated only where a lake seats more than twelve.
    public static let younger = [
        "Aelane", "Estoth", "Corar", "Lorond", "Wynith", "Varwen", "Ulfys", "Brelec", "Savric",
        "Rhunell", "Ardhane", "Ossoth", "Norar", "Maelond", "Heskith", "Kelwen", "Jorys", "Pyrec",
        "Halric", "Garell", "Fenane", "Toroth", "Dorar", "Caelond", "Iskith", "Estond", "Corith",
        "Varec", "Savane", "Rhunoth", "Ardhar", "Ossond", "Norith", "Maelwen", "Heskys", "Kelec",
        "Jorric", "Pyrell", "Halane", "Garoth", "Fenar", "Torond", "Dorith", "Caelwen", "Iskys",
        "Aelith", "Estwen", "Lorec", "Wynric", "Varell", "Ulfane", "Breloth", "Savar", "Rhunond",
        "Ardhith", "Osswen", "Norys", "Maelec", "Heskric", "Jorane", "Pyroth", "Halar", "Garond",
        "Fenith", "Torwen", "Caelec", "Iskric", "Aelys", "Estec", "Corric", "Lorell", "Wynane",
        "Varoth", "Ulfar", "Brelond", "Savith", "Rhunwen", "Ardhys", "Ossec", "Norric", "Maelell",
        "Heskane", "Keloth", "Pyrond",
    ]

    private static let heads = [
        "Vael", "Ost", "Mor", "Kael", "Sar", "Tir", "Ul", "Wen", "Har", "Ith",
        "Bel", "Cor", "Dun", "Esk", "Fal", "Gal", "Lun", "Myr", "Nar", "Rhos",
        "Sel", "Thal", "Vor", "Yr", "Ash", "Brae", "Cail", "Drem", "Orm", "Pell",
    ]

    private static let tails = [
        "watch", "holme", "fall", "stead", "march", "reach", "gate", "haven",
        "crag", "moor", "shade", "wick", "hollow", "spire", "ford", "cairn",
    ]

    /// A hold name not already in use.
    public static func hold(using random: inout SeededRandom, avoiding used: Set<String>) -> String {
        for _ in 0..<64 {
            let name = random.pick(heads) + random.pick(tails)
            if !used.contains(name) {
                return name
            }
        }
        var suffix = 2
        let base = random.pick(heads) + random.pick(tails)
        while used.contains("\(base) \(suffix)") {
            suffix += 1
        }
        return "\(base) \(suffix)"
    }
}
