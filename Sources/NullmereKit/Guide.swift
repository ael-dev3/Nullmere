import NullmereCore

/// The game's rules, in a few short sections, for the Guide panel.
enum Guide {
    struct Section: Identifiable, Equatable {
        let title: String
        let lines: [String]
        var id: String { title }
    }

    /// The fewest holds whose storage holds the stone for the Moonspire's
    /// last stage.
    static var holdsForTheLastSpire: Int {
        let stone = BuildingKind.moonspire.cost(toLevel: BuildingKind.moonspire.maxLevel).stone
        return (1...).first { GameState.baseStorage + GameState.storagePerHold * $0 >= stone } ?? 1
    }

    static let sections: [Section] = [
        Section(title: "The watch", lines: [
            "The lake is one world, shared by every keeper in the realm. Each turn is a watch: give your orders, then say you're ready with ⌘↩.",
            "The watch turns when every keeper there is ready, or when its time runs out; while any keeper whose House stands is away, it lasts at least a third of its time. Your orders take effect as you give them. Through the watch, companies on the march walk on, a step at a time, hosts strike the moment they are there, and the stewards play the seats no keeper holds, each at its own moment; when it turns, holds yield, works rise and companies are fresh again.",
            "The realm keeps the world. Leave, or leave the game open with no one at your Mac for five minutes, and after two watches away a caretaker keeps your House for you: it answers envoys, builds and trains, guards your holds, fights on in wars already begun and sues for peace in one going badly, but begins no war, demand or pact. It takes the peace a steward would take to end a war, but swears you no pact, which would lend your sight to another, and never bends the knee for you, though it takes a House offering fealty as your vassal. An empty realm sleeps until a keeper returns.",
        ]),
        Section(title: "The land", lines: [
            "Strand, salt flats, greyfields, blackwood and barrows ring the lake.",
            "Each yields grain, timber, stone or moonsalt to the hold whose land it lies in.",
            "Groves, seams, loam and moonsalt beds yield more. Drowned ruins hide something for the first to search them.",
            "The Still, the lake's deep water, yields nothing and can't be crossed; the shallows can. The Spine walls the world.",
            "Point at any tile to see what it is, what it yields, whose it is and what it costs to cross.",
        ]),
        Section(title: "Holds", lines: [
            "Holds gather what their land yields and store it, up to a limit that grows with every hold.",
            "Build works: a Granary, Sawpit, Quarry or Saltworks to yield more of one store, Walls for a thicker ward, a Beacon to see further (at II, its land reaches a tile further too), and a Muster Hall for stronger companies, all but Lanterns trained a watch sooner at III.",
            "Short of something? Barter a surplus for it, three to one. Moonsalt counts as three of any other store, so one costs nine of them, and fetches one.",
        ]),
        Section(title: "Companies", lines: [
            "Lanterns scout. Spears hold the line and take holds. Bows strike from two tiles. Riders are fast. Founders found new holds.",
            "Select a company, then right-click to march, or to strike an enemy within reach. Hovering an enemy shows the battle's odds first.",
            "A company that wins a close fight steps onto the fallen's ground, but never out of a hold, for a garrison holds its ground, nor into a hold it can't take.",
            "Every company but Lanterns eats a grain each watch. Those that live through battles rise in rank.",
            "A company trained with no free tile within three of its hold waits, trained, and the hold trains no other until it has room to stand.",
            "To take a hold, break its ward, then march Spears or Riders in; one that falls to the walls' blow back takes nothing. You carry off its share of their stores; a seat holds half.",
        ]),
        Section(title: "Tiers and studies", lines: [
            "Spears, Bows and Riders muster in five tiers, each stronger and dearer than the last: a tier needs its study (Drill for II, Iron Ranks for III, Grey Companies for IV, Moonsteel for V) and a Muster Hall as high as the tier. Choose the tier as you train.",
            "Build an Archive to study, one study at a time, in four branches: Husbandry, Arms, Masonry and Lore. A study of the second circle needs an Archive of II, and so on, and the studies it builds on. The Archive (3) shows the whole tree: what each grade does, costs and takes.",
        ]),
        Section(title: "Commanders", lines: [
            "Your House keeps up to five commanders: one at the start, another with each Muster Hall of III and V, and with Banner Lore. Set one at the head of a company of war in Commanders (4); it leads it in every battle.",
            "A commander learns from every battle and every company of the wilds struck down, and rises in level; at levels V, X and XX its skills come to it. Its second skill fires in battle once its fury has risen. A commander whose company falls is carried home wounded, and mends in four watches.",
        ]),
        Section(title: "The wilds and the sites", lines: [
            "Companies of the wilds rise in the far country: every House's foe. Strike them for their spoils and for your commanders' learning; the higher their level, the richer and the harder.",
            "Sites of the land (fallow fields, deadfalls, screes and salt pans) hold stores to gather. Choose a company of war and right-click a site: it works it until it carries all it can, then brings the stores home to your nearest hold.",
        ]),
        Section(title: "Houses", lines: [
            "Other Houses are held by keepers, or by stewards until a keeper claims them. Stewards are ambitious, steadfast, wary or cunning, and remember who wronged them.",
            "Offers to a keeper wait as envoys for their answer, as theirs wait for yours.",
            "Declare war, offer peace or a pact, and answer their envoys. A pact shares sight; breaking one is not forgotten. A steward makes no peace before it has had a watch of its own at war, and one far the stronger none until the war has run past thirty watches.",
            "Send a gift to a House you aren't at war with. Stewards remember gifts for twenty watches: a war seems older to them, and enough goodwill wins a pact, unless you once made war on them or a pact between you was broken. War on a House throws away the goodwill your gifts bought, and no gift moves a steward that fears your rising Moonspire.",
            "A House takes in gifts worth \(GameState.giftsTakenPerWatch) a watch at most, from every giver together, moonsalt counting four: enough to help an ally, never enough for Houses one keeper holds under other names to pour their stores into one. Between keepers, what a trade gives one side beyond what it takes back is a gift, and counts as one.",
            "Offer a trade to any House you aren't at war with: so much of one store for so much of another. Stewards weigh it by barter worth, the cunning asking most; allies and givers of gifts ask less, and a House takes less for what it lacks. A keeper answers by envoy. Stewards trade among themselves, too, before they barter.",
            "From watch twenty, an ambitious or cunning steward a quarter stronger than you may demand tribute, a fifth of your stores: pay, and it keeps the peace for twenty watches, unless your Moonspire rises; refuse, or let its envoy wait out, and it marches. You may demand tribute too: a steward that refuses is at once at war with you, the war of your making; a keeper who refuses you owes you nothing more, and war is yours to choose.",
            "Envoys and the chronicle speak in words written on your Mac by Apple's on-device model. They only speak; the rules decide.",
        ]),
        Section(title: "Alliances and rallies", lines: [
            "Raise a banner in Alliance (5), or ask to join one; its leader invites and admits. An alliance takes a third of the lake's seats at most. Allies share their sight, can't make war on each other, and help each other's works, musters and studies: every second help takes a watch off.",
            "Words (7) carry a line to every keeper of the realm, or to your alliance alone: plain words, with no addresses.",
            "Call a rally from an enemy hold's panel: your alliance's companies gather at your hold with a Muster Hall for one to four watches, then march together at the slowest's pace and strike together the moment all are there. Send a company to keep an ally's gates, and it strikes back at those who strike them.",
        ]),
        Section(title: "Happenings and charges", lines: [
            "From the tenth watch, a happening comes round every thirty, for ten watches: the Long Hunt, the Harvest Fair, the Raising, the Great Muster and the Learned Season. Points bring stores at 10, 25 and 50, and the three foremost are honoured as it ends. The Realm (6) shows it.",
            "Charges set your House one thing at a time, each rewarded: the card in the corner says how, and Show me takes you there. Deeds are remembered across ages, and win the keeper renown.",
        ]),
        Section(title: "Omens", lines: [
            "Now and then the lake turns, for every House at once, for three to five watches: Moonsalt Bloom doubles moonsalt, Rising Mist shortens every sight by a tile, a Lean Watch takes a third of the grain, and a Still Night mends wards twice as fast.",
            "The omen on the realm is shown under the top bar, with the watches it has left.",
        ]),
        Section(title: "Winning", lines: [
            "Raise the five stages of the Moonspire at your seat (ascendancy), or rule the lake (dominion): five of every twenty holds and at least ten, your vassals' counted with your own, or be the last House standing.",
            "Take a steward's seat while it has four holds or fewer left and no vassals of its own, and, if you are sworn to no one, it swears you fealty; beaten Houses may offer it too. A vassal's holds count with yours, and it can never turn on you, nor win, nor raise its Moonspire while it serves: the works on it stop when it bends the knee. Turn on it, and it is free; it goes free, too, if you fall.",
            "Stewards fear a rising Moonspire, and will march on it.",
            "Each hold stores more: the Moonspire's last stage asks for \(BuildingKind.moonspire.cost(toLevel: BuildingKind.moonspire.maxLevel).stone) stone, more than a House of fewer than \(Guide.holdsForTheLastSpire) holds can keep.",
            "The Houses panel shows the race: each House's holds towards dominion and its Moonspire's stages. You are warned when anyone nears the end of either road, and counsel says what to do.",
        ]),
        Section(title: "Keys", lines: [
            "Tab or .: the next company waiting · ] and [: every company in turn, marching or fortified too · H: your holds in turn, the seat first",
            "F: fortify · B: found a hold, B again to be sure · Space or Return: choose whatever lies in the middle of the view",
            "Arrows or WASD: pan · + and −: zoom · Q and E: turn the view · R and T: look down more or toward the horizon · Page Up and Page Down: scroll the open panel · Esc: close, then clear the selection",
            "With the pointer: drag to pan, pinch or ⌘-scroll to zoom, twist two fingers or ⌥-drag to turn and lean the view",
            "With Keyboard navigation on in System Settings, Tab, the arrows, Space and Return move through and press the controls as everywhere on the Mac: . and WASD stay the game's, and the arrows pan once the map has the keyboard",
            "Without a pointer: choose a company, pan until where it should go is in the middle of the view, then M to march there; to strike, M shows the odds and M again strikes. VoiceOver says what lies in the middle as you pan, and how far it is from your company",
            "In Settings, Letter keys set to With ⌥ makes every letter, number and mark key need ⌥, so a stray key does nothing",
            "1: Houses · 2: Chronicle · 3: Archive · 4: Commanders · 5: Alliance · 6: the Realm · 7: Words · ? or ⌘?: this Guide · ⇧⌘W: leave the world · ⌘,: Settings",
            "⌘↩: ready · ⇧⌘↩: stay ready until something needs you, up to ten watches",
            "⇧⌘M: sound on or off · ⇧⌘U: the music · ⇧⌘+: larger text",
        ]),
    ]
}
