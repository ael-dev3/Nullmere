/// Sixteen words a keeper writes down to carry their identity to another
/// Mac. Their Mac makes them, shows them once and sends the realm only
/// their digest; the realm keeps only the digest of that. Brought again on
/// another Mac, the same words make the same digest, and the realm takes
/// up the keeper they seal there. Each word is one of 256, so sixteen hold
/// 128 bits: no one guesses them, and no two of the words begin with the
/// same four letters.
public enum KeeperWords {
    /// How many words a keeper writes down.
    public static let count = 16

    /// The words they are made of: plain things of the lake and its shores.
    public static let list: [String] = [
        "acorn", "alder", "amber", "anchor", "anvil", "apple", "arch", "arrow", "ash", "aspen", "autumn", "axe", "badger", "bank", "barley", "barn",
        "barrow", "basin", "bay", "beacon", "bean", "bear", "beech", "bell", "berry", "birch", "blade", "bloom", "boar", "boat", "bone", "bough",
        "bramble", "bread", "breeze", "brick", "bridge", "brook", "bucket", "burrow", "butter", "cairn", "candle", "canoe", "cape", "cart", "castle", "cedar",
        "chalk", "chapel", "cherry", "chimney", "cinder", "clay", "cliff", "cloak", "clover", "coal", "comb", "copper", "coral", "corn", "cotton", "cove",
        "crane", "creek", "crow", "cup", "dagger", "daisy", "dawn", "deer", "dew", "dove", "drift", "drum", "dune", "dusk", "eagle", "earth",
        "echo", "eel", "elder", "elm", "ember", "fable", "falcon", "fawn", "feather", "fen", "fern", "ferry", "field", "finch", "fir", "flame",
        "flax", "flint", "flute", "foal", "fog", "ford", "forest", "forge", "fox", "frost", "gale", "garnet", "gate", "glade", "glass", "glen",
        "goat", "goose", "grain", "granite", "grass", "gravel", "grove", "gull", "hail", "hare", "harp", "harvest", "hawk", "hay", "hazel", "heath",
        "hedge", "helm", "hen", "heron", "hill", "hive", "holly", "honey", "hoof", "horn", "horse", "hut", "ice", "inlet", "iron", "isle",
        "ivy", "jay", "jetty", "juniper", "kestrel", "kettle", "key", "kite", "lamb", "lamp", "lantern", "lark", "leaf", "ledge", "lily", "linen",
        "loom", "lynx", "maple", "marsh", "mast", "meadow", "mill", "mint", "mist", "moor", "moss", "moth", "mound", "mule", "nettle", "nest",
        "night", "oak", "oar", "oat", "orchard", "otter", "owl", "oxen", "paddle", "pail", "pebble", "pepper", "pike", "pine", "plough", "plum",
        "pond", "poppy", "quail", "quarry", "quill", "rain", "raven", "reed", "ridge", "river", "robin", "rope", "rowan", "rye", "saddle", "sage",
        "salt", "sand", "sapling", "shell", "shore", "sickle", "silver", "slate", "snow", "sparrow", "spring", "spruce", "star", "stone", "stork", "straw",
        "stream", "swallow", "swan", "thatch", "thistle", "thorn", "thrush", "tide", "timber", "torch", "tower", "trout", "tulip", "turnip", "vale", "velvet",
        "vine", "violet", "wagon", "walnut", "wand", "water", "well", "whale", "wheat", "wheel", "willow", "wind", "wolf", "wool", "wren", "yew",
    ]

    /// New words, from `generator`.
    public static func make<G: RandomNumberGenerator>(using generator: inout G) -> [String] {
        (0..<count).map { _ in list[Int(generator.next() % UInt64(list.count))] }
    }

    /// New words, from the system's own randomness.
    public static func make() -> [String] {
        var generator = SystemRandomNumberGenerator()
        return make(using: &generator)
    }

    /// The words as a keeper wrote them, read back: any case, any spaces,
    /// commas, numbers or lines between; nil unless there are sixteen, each
    /// one of the list.
    public static func read(_ text: String) -> [String]? {
        let words = text.lowercased().split { !$0.isLetter }.map(String.init)
        guard words.count == count, words.allSatisfy(known.contains) else { return nil }
        return words
    }

    /// What is wrong with words written so far, in a few words; nil when
    /// they will do, or when nothing is written yet.
    public static func problem(_ text: String) -> String? {
        let words = text.lowercased().split { !$0.isLetter }.map(String.init)
        if words.isEmpty { return nil }
        if let stranger = words.first(where: { !known.contains($0) }) { return "\"\(stranger)\" is not one of the words." }
        if words.count < count { return "\(words.count) of \(count) words." }
        if words.count > count { return "\(words.count) words: there are \(count)." }
        return nil
    }

    /// What a keeper's Mac sends the realm: the words' digest, never the words.
    public static func proof(of words: [String]) -> String {
        SHA256.hex("nullmere keeper words: " + words.joined(separator: " "))
    }

    /// What the realm keeps of a proof: its own digest, so that what the
    /// realm keeps can't be sent back to it to take up the keeper.
    public static func seal(of proof: String) -> String {
        SHA256.hex("nullmere seal: " + proof)
    }

    /// Whether a text could be a proof: 64 lower-case hexadecimal digits.
    public static func isProof(_ text: String) -> Bool {
        text.utf8.count == 64 && text.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }

    private static let known = Set(list)
}
