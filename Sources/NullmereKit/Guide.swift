/// The game's rules, in a few short sections, for the Guide panel.
enum Guide {
    struct Section: Identifiable, Equatable {
        let title: String
        let lines: [String]
        var id: String { title }
    }

    static let sections: [Section] = [
        Section(title: "The watch", lines: [
            "The lake is one world, shared by every keeper in the realm. Each turn is a watch: give your orders, then say you're ready with ⌘↩.",
            "The watch turns when every keeper there is ready, or when its time runs out. Then the stewards play the seats no keeper holds, holds yield, works rise and companies march on.",
            "The realm keeps the world. Leave, and your House stands as you left it; an empty realm sleeps until a keeper returns.",
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
            "To take a hold, break its ward, then march Spears or Riders in. You carry off its share of their stores; a seat holds half.",
        ]),
        Section(title: "Houses", lines: [
            "Other Houses are held by keepers, or by stewards until a keeper claims them. Stewards are ambitious, steadfast, wary or cunning, and remember who wronged them.",
            "Proposals to a keeper wait as envoys for their answer, as theirs wait for yours.",
            "Declare war, offer peace or a pact, and answer their envoys. A pact shares sight; breaking one is not forgotten.",
            "Send a gift to a House you aren't at war with. Stewards remember gifts for twenty watches: a war seems older to them, and enough goodwill wins a pact.",
            "Offer a trade to any House you aren't at war with: so much of one store for so much of another. Stewards weigh it by barter worth, the cunning asking most; allies and givers of gifts ask less, and a House takes less for what it lacks. A keeper answers by envoy. Stewards trade among themselves, too, before bartering at three to one.",
            "A far stronger rival may demand tribute, a fifth of your stores: pay, and it keeps the peace for twenty watches; refuse, or let its envoy wait out, and it marches. You may demand tribute of the weak, too.",
            "Envoys and the chronicle speak in words written on your Mac by Apple's on-device model. They only speak; the rules decide.",
        ]),
        Section(title: "Omens", lines: [
            "Now and then the lake turns, for every House at once, for three to five watches: Moonsalt Bloom doubles salt, Rising Mist shortens every sight by a hex, a Lean Watch takes a third of the grain, and a Still Night mends wards twice as fast.",
            "The omen on the realm is shown under the top bar, with the watches it has left.",
        ]),
        Section(title: "Winning", lines: [
            "Raise the five stages of the Moonspire at your seat (ascendancy), or rule the lake (dominion): nine of every twenty holds and at least ten, your vassals' counted with your own, or be the last House standing.",
            "Take a rival's seat while it has four holds or fewer left and it swears you fealty; beaten Houses may offer it too. A vassal's holds join your realm, and it can never turn on you. Turn on it, and it is free.",
            "Rivals fear a rising Moonspire, and will march on it.",
            "The Houses panel shows the race: each House's holds toward dominion and its Moonspire's stages. You are warned when anyone nears the end of either road, and counsel says what to do.",
        ]),
        Section(title: "Keys", lines: [
            "Tab: the next company waiting · H: your seat · F: fortify · B: found a hold",
            "Arrows or WASD: pan · + and −: zoom · Esc: close, then clear the selection",
            "Without a pointer: choose a company, pan until where it should go is in the middle of the view, then M to march there, or strike",
            "1: Houses · 2: Chronicle · ?: this guide · ⇧⌘W: leave the world · ⌘,: settings",
            "⌘↩: ready · ⇧⌘↩: stay ready until something needs you, up to ten watches",
        ]),
    ]
}
