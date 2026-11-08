/// What every voice of the realm keeps to when a device's own model gives
/// it words, on the Mac and the phone alike.
public enum Voicing {
    /// The voices' instructions, given the model with every moment.
    public static let instructions = """
    You give voice to characters in Nullmere Online, a game of great Houses around a vast \
    black lake of dead, perfectly still water under a full moon. The tone is grave, \
    spare and formal, like an old chronicle: quiet, never cheerful, no modern words, no \
    exclamation marks. Use only the facts you are given. Never invent numbers, places, \
    names, promises or events, and never mention games, players, turns or rules. Reply \
    with the spoken words alone, without quotation marks or a speaker's name.
    """

    /// A moment as a voice is asked to speak it: what to say, then what is
    /// known, a fact to a line.
    public static func asking(_ task: String, facts: [String]) -> String {
        task + "\n\nWhat is known:\n" + facts.map { "- \($0)" }.joined(separator: "\n")
    }
}
