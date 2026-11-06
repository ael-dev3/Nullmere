/// The pages of the realm every keeper is told alike, just as a keeper of
/// no House is told them (every House's strength and might, the lake as
/// one who has explored none of it knows it, the dealings between Houses):
/// kept on the server once, as no keeper's parts, rather than once in every
/// keeper's view, and named by each view that has them. At ninety-six
/// keepers that is most of every view, and most of what a watch's turn
/// would write again for each of them.
///
/// A page told alike is kept under the name of its row, "~", the page's
/// own name, "#" and the mark of its text, so a page rewritten is a new row
/// and a view that named the old one can still be read until it is written
/// anew; the steward lets go of the rows no view names.
public enum AlikePages {
    /// The keeper their rows are kept as: no one.
    public static let keeper = ""

    /// The row a page told alike is kept under.
    public static func row(_ page: String, _ text: String) -> String {
        // FNV-1a over the text's bytes, as sixteen hex digits.
        var mark: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            mark ^= UInt64(byte)
            mark = mark &* 0x0000_0100_0000_01b3
        }
        let hex = String(mark, radix: 16)
        return "~" + page + "#" + String(repeating: "0", count: 16 - hex.count) + hex
    }

    /// Whether a part a view names is a page told alike.
    public static func isAlike(_ name: String) -> Bool { name.hasPrefix("~") }

    /// The page a part a view names is: its own name, or the page a row
    /// told alike holds.
    public static func page(of name: String) -> String {
        guard isAlike(name), let mark = name.lastIndex(of: "#") else { return name }
        return String(name[name.index(after: name.startIndex)..<mark])
    }

    /// A view's parts by the names its row gives them: each its own, or,
    /// told just as `alike` tells it, the row of the page told alike.
    public static func named(_ parts: [String: String], alike: [String: String]) -> [String: String] {
        var named: [String: String] = [:]
        named.reserveCapacity(parts.count)
        for (page, text) in parts {
            named[alike[page] == text ? row(page, text) : page] = text
        }
        return named
    }
}
