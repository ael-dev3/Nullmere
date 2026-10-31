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
            "The watch turns when every keeper there is ready, or when its time runs out; while any keeper whose House stands is away, it lasts at least a third of its time. Your orders take effect as you give them. Through the watch, companies on the march walk on, a step at a time, a battle goes on blow after blow until a side falls or draws off, hosts strike the moment they are there, and the stewards play the seats no keeper holds, each at its own moment; when it turns, holds yield, works rise and companies are fresh again.",
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
            "A company is so many troops at its first muster, by its kind and tier: Spears 1,200 at I to 2,400 at V, Bows 1,000 to 2,000, Riders 800 to 1,600. As many stand as its health is a share of, and every battle is told in the troops each side slew and lost. Your army, all your companies of war, is counted in the Realm (6).",
            "Drill a company of war at or beside one of your holds with a Muster Hall and it takes on troops as each watch turns while it stays there, half its first muster for each of the hall's levels, for grain: up to as many as it may lead, once its first muster, eight times more for each level of your best Muster Hall, and once more for every three levels of its commander. No hall drills troops your grain can't feed. Every troop counts, each the less the more there are: a company drilled to nine times its first muster fights others three times as hard and eats three times as much; walls, wards and the wilds are struck as before.",
            "Lanterns within two tiles of another House's hold can scout it from its panel, for all their moves: their report, in the Chronicle's Reports and on the hold's panel, tells the companies at its gates and who leads them, its ward, what it raises and musters, the stores its taking would carry off, and how many lie in its Infirmary. Its House sees them watching.",
            "Select a company, then right-click to march, or to strike an enemy within reach. Hovering an enemy shows the battle's odds first.",
            "A company that wins a close fight steps onto the fallen's ground, but never out of a hold, for a garrison holds its ground, nor into a hold it can't take.",
            "A strike on another House's company joins battle there: a field of battle that goes on through the watch. At every pace each company in it strikes a foe within its reach, so the struck strike back, and your companies standing near it with no march or errand join in. Strike, or be struck, near it and you are in it on your House's side. It ends when a pace passes without a blow or one side has none left in it; march a company away to draw it off. Your report tells each side's companies and troops, the slain and the fallen, and who held the field.",
            "Every company but Lanterns eats a grain each watch. Those that live through battles rise in rank.",
            "A company trained with no free tile within three of its hold waits, trained, and the hold trains no other until it has room to stand.",
            "To take a hold, break its ward, then march Spears or Riders in; one that falls to the walls' blow back takes nothing. You carry off its share of their stores; a seat holds half.",
            "Raise an Infirmary, and your companies of war that fall are carried to the nearest hold with a bed free, two beds at I and one more at each level, rather than lost. Heal them from the hold's panel for half what mustering them anew costs: they rise whole, their rank kept, as the watch turns. A hold taken loses those in its beds.",
        ]),
        Section(title: "Tiers and studies", lines: [
            "Spears, Bows and Riders muster in five tiers, each stronger and dearer than the last: a tier needs its study (Close Order for II, Iron Ranks for III, Grey Companies for IV, Moonsteel for V) and a Muster Hall as high as the tier. Choose the tier as you train.",
            "Build an Archive to study, one study at a time, in four branches: Husbandry, Arms, Masonry and Lore. A study of the second circle needs an Archive of II, and so on, and the studies it builds on. The Archive (3) shows the whole tree: what each grade does, costs and takes.",
        ]),
        Section(title: "Commanders", lines: [
            "Your House keeps up to five commanders: one at the start, another with each Muster Hall of III and V, and with Banner Lore. Set one at the head of a company of war in Commanders (4); it leads it in every battle.",
            "A commander learns from every battle and every company of the wilds struck down, and rises in level; at levels V, X and XX its skills come to it. Its second skill fires in battle once its fury has risen. A commander whose company falls is carried home wounded, and mends in four watches.",
            "At each level past the first a commander gains a talent point, to spend in Commanders (4) a rank at a time in three trees of five: Steel for the blow, Ward for the guard, Road for the way and the sites. Each talent is opened by the one before it in its tree. Forget them all for 20 moonsalt, to learn anew.",
            "Companies of the wilds struck down may leave gear: weapons, armour and charms, each kind of the wilds its own, finer from the higher levels. Arm a commander with a piece from the armoury in Commanders (4); it wears one of each, and its company gains what each gives. Break up what you don't need for moonsalt.",
            "A Forge works makings into gear of three sets: the Warden's Harness, the Raider's Kit and the Pathfinder's Gear. The wilds leave makings as they fall, a lair broken leaves more, and companies bring them in with what they gather: hide with grain, heartwood with timber, iron with stone, moonglass with moonsalt. Forge a piece in Commanders (4), as fine as your highest Forge allows: plain at level I, fine at II, masterwork at IV, fabled at V. Two pieces of a set worn by one commander give its company more, all three more still.",
        ]),
        Section(title: "The wilds and the sites", lines: [
            "Companies of the wilds rise in the far country: every House's foe. Strike them for their spoils and for your commanders' learning; the higher their level, the richer and the harder.",
            "Holy sites (Moonwells, Still Stones and Salt Altars) stand far out on the land. A company of war standing on one as the watch turns, with no foe beside it, takes it for your House: its gift is your whole alliance's while you hold it. The Realm (6) lists those you have found.",
            "From the twelfth watch the wilds raise lairs far out in the country: a Salt Hollow, a Reavers' Stockade, a Barrow Hall, a Hunters' Eyrie or a Drowned Chapel, of levels I to V. No company alone can strike one. Select its ground and call a rally against it; your alliance's host strikes it together, and broken, its spoils are shared by the companies each House brought, with gear for the rally's caller. A lair that holds mends a little each watch.",
            "Sites of the land (fallow fields, deadfalls, screes and salt pans) hold stores to gather. Choose a company of war and right-click a site: it works it until it carries all it can, then brings the stores home to your nearest hold.",
        ]),
        Section(title: "Houses", lines: [
            "Other Houses are held by keepers, or by stewards until a keeper claims them. Stewards are ambitious, steadfast, wary or cunning, and remember who wronged them.",
            "Every House comes of one of the lake's six peoples, dealt round the lake as the age begins: the Saltborn, the Fenfolk, the Blackwood Kin, the Spinewardens, the Mound Clans and the Strandfolk. Each has two strengths and a company of its own at the fifth tier, a twentieth stronger and firmer than others of its kind. Take up another in the Realm (6): the first time freely, then for \(Heritage.changeCost).",
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
            "Raise standards of your alliance on open ground near its holds, from that ground's panel, for timber, stone and moonsalt: the land two tiles about each is the alliance's, where its companies stand a tenth firmer, mend sooner and gather a fifth more. An alliance keeps one standard, and one more for each of its Houses. A House at war with the one that raised it can strike a standard down.",
            "An alliance's leader begins its hall on the alliance's land, from that ground's panel, for great stores; it rises over four watches. Whole, the land three tiles about it is the alliance's, its companies keeping it stand a quarter firmer, the rallies its Houses call take two more companies and it may keep two more standards. Only its companies enter it; a House at war with one of its Houses can strike it down when none keeps it.",
            "An alliance keeps coffers of its own: each standard's land and its hall, whole, fill them every watch, and they pay first for whatever its Houses raise for it. Its leader raises its storehouse on its land, from that ground's panel; whole, each House may lay up stores there from Alliance (5), beyond its own storage and out of any taker's reach, and take them back when it will. A House at war with the alliance that tears the storehouse down carries off what was laid up in it.",
            "Its leader raises yards on its land too, one of each store: a Tilled Acre, a Timber Yard, a Quarry and Salt Works. Its companies alone work them, a quarter faster than anywhere else, and the coffers take a tithe of what they gather.",
            "An alliance studies together: its leader chooses a study in Alliance (5), and every House of it gives stores toward each grade. A grade learned raises every House of the alliance at once, three grades a study; every \(GameState.givenPerHourglass) given, in barter worth, brings the giver a Salt Hourglass.",
            "Call a rally from an enemy hold's panel: your alliance's companies gather at your hold with a Muster Hall for one to four watches, then march together at the slowest's pace and strike together the moment all are there. Send a company to keep an ally's gates, and it strikes back at those who strike them.",
        ]),
        Section(title: "Happenings and charges", lines: [
            "From the tenth watch, a happening comes round every thirty, for ten watches: the Long Hunt, the Harvest Fair, the Raising, the Great Muster and the Learned Season. Points bring stores and items at 10, 25 and 50, and the three foremost are honoured as it ends. The Realm (6) shows it.",
            "Each watch you keep in the realm, there as it turns, wins you favour with the lake, the more for every watch kept unbroken. Favour raises your House by levels, I to X: more gathered at the land's sites, works and studies sooner, companies mustered sooner; every tenth watch kept unbroken brings a favour chest, the richer the higher you stand. It is yours across ages; the Realm (6) shows it.",
            "From the fifty-fifth watch, and every ninety after, comes the Sundering: for twelve watches the lake's Houses stand as two kingdoms, the Eastern and the Western Shore, each by where its seat stands, and every House is at war with each of the other shore it was at peace with, but its alliance's and its liege's, the wars laid down as it ends. Troops of the other shore slain, its holds taken and its alliances' works torn down count for your kingdom; every House of the kingdom that prevails shares its spoils, and its foremost is hailed its sword. The Realm (6) shows how the shores stand.",
            "Beyond the lake lies the Frontier, a realm of its own where the kingdoms of several realms meet, a season of twenty-four watches at a time. While a season is open, Cross to the Frontier on the Realm (6) sends you there with your House's strongest companies of war, up to six, while a caretaker keeps your House at home; you stand there for your realm's kingdom, at war with every other realm's. Troops of their kingdoms slain, their companies felled and their holds taken count for yours; as the season ends it is told home, and every House of the kingdom that prevails shares its spoils. Return Home brings you back.",
            "Charges set your House one thing at a time, each rewarded: the card in the corner names it, More says how, and Show me takes you there. Deeds are remembered across ages, and win the keeper renown.",
            "Charges, a happening's marks and lairs broken fill your satchel, shown in the Realm (6). A Salt Hourglass brings a hold's work and muster a watch nearer, from the hold's panel, or your study; caches open into your stores; a Ward Stone makes a hold's ward whole; a Mending Draught mends every hurt company of yours by 30.",
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
            "Tab or .: the next company waiting · ] and [: every company in turn, marching or fortified too · H: your holds in turn, the seat first · C: your seat close, its works named where they stand, and back out to the lake",
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
