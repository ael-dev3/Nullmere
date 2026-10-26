/// Original names for the Houses and their holds.
public enum Names {
    /// The great Houses that may sit around the lake.
    public static let houses = [
        "Aurel", "Venn", "Morcant", "Seris", "Okon", "Thale", "Dravic", "Ysolde",
        "Lioth", "Quell", "Brannoch", "Sefa",
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
