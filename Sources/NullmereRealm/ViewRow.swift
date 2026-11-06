/// A keeper's view as its row names it: the parts that are theirs alone,
/// each with the version it was written at; the list of the pages told
/// alike that the view takes, itself a page told alike, kept under "~#" and
/// the mark of its text; and the pages of that list the view hasn't. The
/// view has every page of the list but those it has its own of and those
/// it hasn't, each as every keeper is told it: so a keeper's row names the
/// dozen parts that are theirs, not every page of the realm, and a page
/// told alike written anew writes their row anew only to name a new list.
///
///     "-sites.3:0,head:12,own:12,units.0:11,~#0123456789abcdef:0"
public struct ViewRow: Equatable, Sendable {
    /// The parts the row names itself, and the version each was written
    /// at: the view's own, and any page told alike it names outright (at 0).
    public var own: [String: UInt64]
    /// The list of the pages told alike the view takes, by the name of its
    /// row; none, and it takes only those it names outright.
    public var told: String?
    /// The pages of the list the view hasn't.
    public var without: Set<String>

    public init(own: [String: UInt64], told: String? = nil, without: Set<String> = []) {
        self.own = own
        self.told = told
        self.without = without
    }

    /// The row a text names: every entry "name:version", comma by comma, a
    /// page of the list the view hasn't under "-", and one list at most.
    /// Nothing if the text says otherwise.
    public init?(_ text: String) {
        var own: [String: UInt64] = [:], told: String?, without: Set<String> = []
        for entry in text.split(separator: ",") {
            guard let colon = entry.lastIndex(of: ":"), let version = UInt64(entry[entry.index(after: colon)...]) else { return nil }
            let name = String(entry[..<colon])
            if name.hasPrefix("-") {
                without.insert(String(name.dropFirst()))
            } else if ViewRow.isList(name) {
                guard told == nil else { return nil }
                told = name
            } else {
                own[name] = version
            }
        }
        guard !own.isEmpty || told != nil else { return nil }
        self.init(own: own, told: told, without: without)
    }

    /// As its row carries it, its entries in order.
    public var text: String {
        var entries = own.map { (name: $0.key, version: $0.value) }
        if let told { entries.append((told, 0)) }
        entries += without.map { ("-" + $0, 0) }
        return entries.sorted { $0.name < $1.name }.map { "\($0.name):\($0.version)" }.joined(separator: ",")
    }

    /// Whether a part a row names is a list of pages told alike.
    public static func isList(_ name: String) -> Bool { name.hasPrefix("~#") }

    /// The list of these pages told alike, by their rows' names, as its row
    /// keeps it; and that row's name.
    public static func list(of rows: some Sequence<String>) -> (name: String, text: String) {
        let text = rows.sorted().joined(separator: ",")
        return (AlikePages.row("", text), text)
    }

    /// Every part the view has, by the name each is kept under, with the
    /// version its row gives it (0 for a page told alike): those the row
    /// names itself, its list, and each page of the list, as `list` reads,
    /// that the view has and has none of its own of. Nothing if the row
    /// names a list and `list` is none.
    public func parts(told list: String?) -> [String: UInt64]? {
        guard let told else { return own }
        guard let list else { return nil }
        var parts = own
        let pages = Set(own.keys.lazy.map(AlikePages.page(of:)))
        for entry in list.split(separator: ",") {
            let name = String(entry), page = AlikePages.page(of: name)
            guard AlikePages.isAlike(name), !pages.contains(page), !without.contains(page) else { continue }
            parts[name] = 0
        }
        parts[told] = 0
        return parts
    }
}
