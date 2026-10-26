/// The game's rules, in a few short sections, for the Guide panel.
enum Guide {
    struct Section: Identifiable, Equatable {
        let title: String
        let lines: [String]
        var id: String { title }
    }

    static let sections: [Section] = [
        Section(title: "The watch", lines: [
            "Each turn is a watch. Give your orders, then end the watch with ⌘↩ or End Watch.",
            "Then the rival Houses move, holds yield, works rise and companies march on.",
            "The game saves after every watch, and whenever you leave it.",
        ]),
        Section(title: "The land", lines: [
            "Strand, salt flats, greyfields, blackwood and barrows ring the lake.",
            "Each yields grain, timber, stone or moonsalt to the hold whose land it lies in.",
            "Groves, seams, loam and moonsalt beds yield more. Drowned ruins hide something for the first to search them.",
            "The still water yields nothing and can't be crossed; the shallows can. The Spine walls the world.",
            "Point at any tile to see what it is, what it yields, whose it is and what it costs to cross.",
        ]),
        Section(title: "Holds", lines: [
            "Holds gather what their land yields and store it, up to a limit that grows with every hold.",
            "Raise works to yield more of one resource, Walls for a thicker ward, Beacons to see and claim further, and a Muster Hall for stronger companies.",
            "Short of something? Barter a surplus for it, three to one.",
        ]),
        Section(title: "Companies", lines: [
            "Lanterns scout. Spears hold the line and take holds. Bows strike from two tiles. Riders are fast. Founders raise new holds.",
            "Select a company, then right-click to march, or to strike an enemy within reach. Hovering an enemy shows the battle's odds first.",
            "Every company but the Lantern eats a grain each watch. Those that live through battles rise in rank.",
            "To take a hold, break its ward, then march Spears or Riders in.",
        ]),
        Section(title: "Houses", lines: [
            "Rival Houses are ambitious, steadfast, wary or cunning, and remember who wronged them.",
            "Declare war, offer peace or a pact, and answer their envoys. A pact shares sight; breaking one is not forgotten.",
            "Envoys and the chronicle speak in words written on your Mac by Apple's on-device model. They only speak; the rules decide.",
        ]),
        Section(title: "Winning", lines: [
            "Raise the five stages of the Moonspire at your seat, or be the last House standing.",
            "Rivals fear a rising Moonspire, and will march on it.",
        ]),
        Section(title: "Keys", lines: [
            "Tab: the next company waiting · H: your seat · F: fortify · B: found a hold",
            "Arrows or WASD: pan · + and −: zoom · Esc: close, then clear the selection",
            "1: Houses · 2: Chronicle · ?: this guide · ⌘Z: take back an order · ⌘S: save",
        ]),
    ]
}
