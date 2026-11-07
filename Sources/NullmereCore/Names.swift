/// Original names for the Houses and their holds.
public enum Names {
    /// The great Houses that may sit around the lake: the twelve elder
    /// Houses, then the younger ones that take the seats of a wider lake,
    /// then those of the widest. A House's place among them is its sigil,
    /// and so its colour.
    public static let houses = elder + younger + widest

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

    /// The Houses of the widest lakes, seated only where a lake seats more
    /// than ninety-six, up to a thousand and twenty-four: each a root and an
    /// ending in the younger Houses' voice, none a word or a name already
    /// another's.
    public static let widest: [String] = [
        "Ardhaine", "Osseld", "Maelorn", "Heskuth", "Kelyrn", "Jorast", "Pyreon", "Halath", "Garivar", "Fenost",
        "Toremar", "Dorul", "Caelidd", "Iskavel", "Daeroth", "Fyrond", "Kastwen", "Morvec", "Nethric", "Quoraine",
        "Ryveld", "Seldiss", "Tavorn", "Threnast", "Gwyleon", "Sornath", "Aeloth", "Corond", "Lorith", "Ulfec",
        "Brelric", "Savell", "Rhunaine", "Ossiss", "Nororn", "Maeluth", "Heskyrn", "Kelast", "Joreon", "Pyrath",
        "Halivar", "Garost", "Fenemar", "Torul", "Doridd", "Caelavel", "Iskewyn", "Eldond", "Fyrith", "Haelwen",
        "Kastys", "Lythec", "Morvric", "Orlaine", "Quoreld", "Ryviss", "Seldorn", "Tavuth", "Ulthyrn", "Vyrast",
        "Threneon", "Gwylath", "Sornivar", "Lorwen", "Savaine", "Rhuneld", "Ardhiss", "Ossorn", "Noruth", "Maelyrn",
        "Heskast", "Keleon", "Jorath", "Pyrivar", "Halost", "Garemar", "Fenul", "Toridd", "Doravel", "Caelewyn",
        "Iskane", "Cethar", "Daerond", "Eldith", "Fyrwen", "Haelys", "Kastec", "Lythric", "Morvell", "Nethaine",
        "Orleld", "Quoriss", "Ryvorn", "Selduth", "Tavyrn", "Ulthast", "Vyreon", "Threnath", "Gwylivar", "Sornost",
        "Aelond", "Lorys", "Wynec", "Ulfell", "Brelaine", "Saveld", "Rhuniss", "Ardhorn", "Ossuth", "Noryrn",
        "Maelast", "Heskeon", "Kelath", "Jorivar", "Pyrost", "Halemar", "Garul", "Fenidd", "Toravel", "Dorewyn",
        "Caelane", "Iskoth", "Cethond", "Daerith", "Haelec", "Kastric", "Morvaine", "Orliss", "Quororn", "Ryvuth",
        "Seldyrn", "Tavast", "Ultheon", "Vyrath", "Threnivar", "Gwylost", "Sornemar", "Corys", "Ulfaine", "Breleld",
        "Saviss", "Rhunorn", "Ardhuth", "Ossyrn", "Norast", "Maeleon", "Heskath", "Kelivar", "Jorost", "Pyremar",
        "Garidd", "Fenavel", "Torewyn", "Dorane", "Caeloth", "Daerwen", "Eldys", "Fyrec", "Haelric", "Lythaine",
        "Morveld", "Nethiss", "Orlorn", "Quoruth", "Seldast", "Taveon", "Vyrivar", "Threnost", "Gwylemar", "Sornul",
        "Aelwen", "Estys", "Corec", "Wynell", "Varaine", "Ulfeld", "Breliss", "Savorn", "Rhunuth", "Ardhyrn",
        "Ossast", "Noreon", "Maelath", "Heskivar", "Kelost", "Joremar", "Pyrul", "Halidd", "Garavel", "Torane",
        "Iskond", "Cethwen", "Daerys", "Eldec", "Kastaine", "Morviss", "Nethorn", "Orluth", "Quoryrn", "Ryvast",
        "Seldeon", "Tavath", "Ulthivar", "Vyrost", "Threnemar", "Sornidd", "Wynaine", "Vareld", "Ulfiss", "Brelorn",
        "Savuth", "Rhunyrn", "Ardhast", "Osseon", "Maelivar", "Heskost", "Kelemar", "Jorul", "Pyridd", "Halavel",
        "Garewyn", "Brywen", "Cethys", "Daerec", "Fyrell", "Haelaine", "Kasteld", "Lythiss", "Morvorn", "Orlyrn",
        "Quorast", "Ryveon", "Seldath", "Tavivar", "Ulthost", "Vyremar", "Threnul", "Gwylidd", "Sornavel", "Aelec",
        "Estric", "Corell", "Wyneld", "Variss", "Ulforn", "Breluth", "Savyrn", "Rhunast", "Ardheon", "Ossath",
        "Norivar", "Maelost", "Heskemar", "Joridd", "Pyravel", "Halewyn", "Garane", "Fenoth", "Dorond", "Caelith",
        "Iskwen", "Cethec", "Eldell", "Fyraine", "Haeleld", "Kastiss", "Lythorn", "Morvuth", "Nethyrn", "Orlast",
        "Quoreon", "Ryvath", "Seldivar", "Tavost", "Ulthemar", "Vyrul", "Threnidd", "Gwylavel", "Aelric", "Coraine",
        "Loreld", "Wyniss", "Varorn", "Ulfuth", "Brelyrn", "Savast", "Rhuneon", "Ardhath", "Ossivar", "Norost",
        "Maelemar", "Heskul", "Kelidd", "Joravel", "Cethric", "Daerell", "Fyreld", "Haeliss", "Kastorn", "Morvyrn",
        "Nethast", "Orleon", "Quorath", "Ryvivar", "Seldost", "Tavemar", "Ulthul", "Vyridd", "Threnavel", "Sornane",
        "Estaine", "Coreld", "Loriss", "Wynorn", "Varuth", "Ulfyrn", "Brelast", "Saveon", "Rhunath", "Ardhivar",
        "Ossost", "Noremar", "Heskidd", "Kelavel", "Jorewyn", "Pyrane", "Haloth", "Fenond", "Torith", "Dorwen",
        "Caelys", "Iskec", "Bryric", "Daeraine", "Eldeld", "Fyriss", "Haelorn", "Kastuth", "Morvast", "Netheon",
        "Orlath", "Quorivar", "Ryvost", "Seldemar", "Tavul", "Ulthidd", "Vyravel", "Gwylane", "Sornoth", "Aelaine",
        "Esteld", "Coriss", "Lororn", "Wynuth", "Varyrn", "Ulfast", "Breleon", "Savath", "Rhunivar", "Ardhost",
        "Ossemar", "Norul", "Maelidd", "Heskavel", "Kelewyn", "Cethaine", "Daereld", "Eldiss", "Fyrorn", "Haeluth",
        "Kastyrn", "Lythast", "Morveon", "Orlivar", "Quorost", "Ryvemar", "Seldul", "Tavidd", "Ulthavel",
        "Threnane", "Gwyloth", "Sornar", "Aeleld", "Estiss", "Cororn", "Loruth", "Varast", "Ulfeon", "Brelath",
        "Savivar", "Rhunost", "Ardhemar", "Ossul", "Noridd", "Maelavel", "Heskewyn", "Kelane", "Joroth", "Halond",
        "Garith", "Dorec", "Caelric", "Iskell", "Daeriss", "Eldorn", "Fyruth", "Haelyrn", "Kastast", "Lytheon",
        "Morvath", "Nethivar", "Orlost", "Quoremar", "Ryvul", "Seldidd", "Tavavel", "Ulthewyn", "Vyrane",
        "Threnoth", "Gwylar", "Sornond", "Aeliss", "Estorn", "Coruth", "Loryrn", "Wynast", "Vareon", "Ulfath",
        "Brelivar", "Savost", "Rhunemar", "Ardhul", "Ossidd", "Noravel", "Maelewyn", "Halith", "Fenys", "Iskaine",
        "Cethiss", "Daerorn", "Elduth", "Haelast", "Kasteon", "Morvivar", "Nethost", "Orlemar", "Quorul", "Ryvidd",
        "Seldavel", "Tavewyn", "Ulthane", "Vyroth", "Threnar", "Gwylond", "Aelorn", "Estuth", "Coryrn", "Lorast",
        "Wyneon", "Varath", "Ulfivar", "Brelost", "Savemar", "Rhunul", "Ardhidd", "Ossavel", "Norewyn", "Maelane",
        "Heskoth", "Kelar", "Jorond", "Pyrith", "Halwen", "Fenec", "Dorell", "Caelaine", "Iskeld", "Cethorn",
        "Daeruth", "Eldyrn", "Fyrast", "Haeleon", "Kastath", "Lythivar", "Morvost", "Nethemar", "Quoridd",
        "Ryvavel", "Seldewyn", "Tavane", "Threnond", "Gwylith", "Aeluth", "Estyrn", "Corast", "Loreon", "Wynath",
        "Varivar", "Ulfost", "Brelemar", "Savul", "Rhunidd", "Ardhavel", "Ossewyn", "Norane", "Maeloth", "Heskar",
        "Kelond", "Jorith", "Pyrwen", "Garec", "Torell", "Doraine", "Caeleld", "Iskiss", "Daeryrn", "Eldast",
        "Fyreon", "Haelath", "Kastivar", "Lythost", "Morvemar", "Nethul", "Orlidd", "Quoravel", "Seldane", "Tavoth",
        "Vyrond", "Threnith", "Gwylwen", "Sornys", "Aelyrn", "Estast", "Coreon", "Wynivar", "Varost", "Ulfemar",
        "Savidd", "Rhunavel", "Ardhewyn", "Ossane", "Noroth", "Maelar", "Heskond", "Kelith", "Jorwen", "Halec",
        "Toraine", "Doreld", "Caeliss", "Iskorn", "Cethyrn", "Daerast", "Eldeon", "Fyrath", "Haelivar", "Kastost",
        "Lythemar", "Morvul", "Nethidd", "Orlavel", "Quorewyn", "Ryvane", "Seldoth", "Tavar", "Ulthond", "Vyrith",
        "Sornec", "Aelast", "Esteon", "Corath", "Lorivar", "Wynost", "Varemar", "Brelidd", "Savavel", "Fenaine",
        "Toreld", "Caelorn", "Iskuth", "Cethast", "Daereon", "Eldath", "Fyrivar", "Haelost", "Kastemar", "Lythul",
        "Morvidd", "Nethavel", "Orlewyn", "Quorane", "Ryvoth", "Seldar", "Tavond", "Vyrwen", "Threnys", "Gwylec",
        "Sornric", "Aeleon", "Estath", "Corivar", "Lorost", "Wynemar", "Varul", "Ulfidd", "Brelavel", "Savewyn",
        "Rhunane", "Ardhoth", "Ossar", "Norond", "Maelith", "Heskwen", "Kelys", "Jorec", "Garaine", "Feneld",
        "Toriss", "Dororn", "Caeluth", "Iskyrn", "Cetheon", "Daerath", "Eldivar", "Fyrost", "Haelemar", "Kastul",
        "Lythidd", "Morvavel", "Nethewyn", "Quoroth", "Ryvar", "Seldond", "Tavith", "Ulthwen", "Threnec", "Gwylric",
        "Sornell", "Aelath", "Estivar", "Corost", "Loremar", "Wynul", "Varidd", "Ulfavel", "Brelewyn", "Halaine",
        "Gareld", "Feniss", "Tororn", "Doruth", "Caelyrn", "Iskast", "Daerivar", "Eldost", "Fyremar", "Kastidd",
        "Lythavel", "Morvewyn", "Orloth", "Ryvond", "Seldith", "Tavwen", "Ulthys", "Vyrec", "Threnric", "Sornaine",
        "Aelivar", "Estost", "Coremar", "Lorul", "Wynidd", "Varavel", "Ulfewyn", "Brelane", "Savoth", "Rhunar",
        "Ardhond", "Ossith", "Norwen", "Maelys", "Heskec", "Kelric", "Jorell", "Pyraine", "Haleld", "Gariss",
        "Fenorn", "Toruth", "Doryrn", "Caelast", "Iskeon", "Cethivar", "Daerost", "Eldemar", "Fyrul", "Haelidd",
        "Kastavel", "Morvane", "Orlar", "Quorond", "Ryvith", "Seldwen", "Tavys", "Ulthec", "Threnell", "Gwylaine",
        "Sorneld", "Aelost", "Estemar", "Corul", "Loridd", "Wynavel", "Varewyn", "Joraine", "Pyreld", "Haliss",
        "Garorn", "Fenuth", "Toryrn", "Dorast", "Caeleon", "Iskath", "Cethost", "Daeremar", "Eldul", "Fyridd",
        "Haelavel", "Kastewyn", "Lythane", "Morvoth", "Nethar", "Orlond", "Quorith", "Ryvwen", "Seldys", "Tavec",
        "Ulthric", "Vyrell", "Threnaine", "Gwyleld", "Sorniss", "Aelemar", "Estul", "Coridd", "Loravel", "Ulfoth",
        "Brelar", "Savond", "Rhunith", "Ardhwen", "Ossys", "Norec", "Maelric", "Heskell", "Kelaine", "Joreld",
        "Pyriss", "Halorn", "Garuth", "Fenyrn", "Torast", "Doreon", "Caelath", "Iskivar", "Cethemar", "Daerul",
        "Eldidd", "Fyravel", "Haelewyn", "Kastane", "Morvar", "Nethond", "Orlith", "Quorwen", "Seldec", "Tavric",
        "Vyraine", "Threneld", "Gwyliss", "Sornorn", "Estidd", "Coravel", "Lorewyn", "Heskaine", "Keleld", "Joriss",
        "Pyrorn", "Haluth", "Garyrn", "Fenast", "Toreon", "Dorath", "Caelivar", "Iskost", "Cethul", "Daeridd",
        "Eldavel", "Haelane", "Kastoth", "Lythar", "Morvond", "Orlwen", "Quorys", "Ryvec", "Seldric", "Tavell",
        "Ulthaine", "Vyreld", "Threniss", "Gwylorn", "Sornuth", "Aelidd", "Estavel", "Corewyn", "Lorane", "Wynoth",
        "Ulfond", "Brelith", "Savwen", "Rhunys", "Ardhec", "Ossric", "Norell", "Maelaine", "Heskeld", "Keliss",
        "Jororn", "Pyruth", "Halyrn", "Garast", "Feneon", "Torath", "Dorivar", "Caelost", "Iskemar", "Cethidd",
        "Daeravel", "Eldewyn", "Fyrane", "Haeloth", "Kastar", "Lythond", "Morvith", "Nethwen", "Orlys", "Quorec",
        "Ryvric", "Seldell", "Tavaine", "Vyriss", "Threnorn", "Gwyluth", "Sornyrn", "Aelavel", "Estewyn", "Corane",
        "Loroth", "Wynar", "Varond", "Ulfith", "Brelwen", "Savys", "Rhunec", "Ardhric", "Ossell", "Noraine",
        "Maeleld", "Heskiss", "Kelorn", "Joruth", "Halast", "Gareon", "Fenath", "Torivar", "Dorost", "Caelemar",
        "Iskul", "Cethavel", "Daerewyn", "Eldane", "Fyroth", "Haelar", "Kastond", "Morvwen", "Nethys", "Orlec",
        "Ryvell", "Seldaine", "Taveld", "Ulthiss", "Vyrorn", "Threnuth", "Sornast", "Aelewyn", "Coroth", "Wynond",
        "Varith", "Ulfwen", "Brelys", "Savec", "Rhunric", "Ossaine", "Noreld", "Maeliss", "Heskorn", "Keluth",
        "Joryrn", "Pyrast", "Haleon", "Garath", "Fenivar", "Torost", "Doremar", "Iskidd", "Cethewyn", "Daerane",
        "Eldoth", "Haelond", "Lythwen", "Morvys", "Nethec", "Orlric", "Quorell", "Ryvaine", "Seldeld", "Taviss",
        "Ulthorn",
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
