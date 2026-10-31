# Nullmere Online against Rise of Kingdoms: the gap list

The bar, set by ael on October 30: Nullmere Online is to be a complete game
on the level of Rise of Kingdoms or better, native to the Mac. Everything
below is scored against Rise of Kingdoms, honestly: anything 2D, a
placeholder, stubbed or simulated scores under ten. The rules hold
throughout: one shared realm and nothing played alone, the launcher titled
exactly Nullmere Online, and every asset original. This list is kept
current as the work goes; each line says what is there now, not what is
planned, and what CI has shown of it.

## Where it stands

| | Requirement | Score now | What is there | What Rise of Kingdoms has that this lacks |
|---|---|---|---|---|
| 1 | Live realm, real multiplayer | 5 | A SpacetimeDB module and a steward that runs the rules; keepers' Macs hear the realm's changes pushed over SpacetimeDB's WebSocket subscription, the reads kept as a fallback. CI raises a real SpacetimeDB server where two keepers' clients meet, give orders and turn the watch, trade through an envoy, ally, speak to the realm and to their alliance, go to war, and march one on the other's seat over thirty watches and strike it, both seeing every step. A realm's watch passes in twelve paces: marches step through it, hosts strike the moment they arrive, and stewards give their orders at paces spread through it, nothing saved for a burst at the turn; battles are fought as fields of whole armies, every company near striking and struck pace by pace, told as one battle; armies drilled at the Muster Halls come to hundreds of thousands of troops a realm | A realm that is up for everyone (it waits on the maintainer's maincloud sign-in); battles of hundreds of thousands; kingdoms of thousands |
| 2 | 3D world in Metal | 5 | Terrain as a 3D mesh with relief and its own grain of earth and moss; every hold a town of lanes, homes lit at night, a well, fields and a seat's market, growing with its works; stone, timber, thatch, slate and earth drawn with their grain on every model; each omen's weather, rain or mist, over the world; the still lake mirroring the stars and the moon; a camera that pans, zooms, tilts and turns; picking and VoiceOver through it; original models built from code for every company in five tiers, every hold, work and wall at every level, the wilds, the sites of the land and the commanders, with fine work drawn near (quoins, framed windows, roof courses, arrow loops, wall-walks); four lights of the world's own with the moon's; a city view, close over the keeper's seat with its works named where they stand and chosen there; rendered on the GPU in CI | Hand-modelled detail at RoK's density |
| 3 | Animation | 6 | Companies idle, march, strike, gather and fall, easing from one clip to the next; works rise from scaffolds and finish in dust; blows land with sparks, a flash and light on the ground, the struck reel, arrows arc and kick up dust, wards splinter, the fallen raise dust; dust hangs over a field of battle; a commander's skill fires in its archetype's own look (a ward of light, fire, falling light, a ring of gold, the ground breaking); broken holds burn and smoke; townsfolk go about every hold's works and carts go between a House's holds; fireflies, birds, banners and hearth smoke | Spell-like effects at RoK's scale; a RoK city's crowds |
| 4 | Sound and music | 6 | A synthesised night, a score written as it plays that turns to war, and twenty-seven cues made as they play, a sound for every order and every event that concerns the keeper, each held by tests above the night and all at once under clipping; every sound heard from where it happened, left or right of the view and fainter far off; the din of every field of battle in sight, voices, feet and steel, as loud as the troops fighting there | Recorded orchestral music and foley |
| 5 | Depth of systems | 5 | The Frontier, where the kingdoms of several realms meet for seasons, each a database of its own; drill at the Muster Halls, companies taking on troops by the thousand up to what their hall and commander can lead; studies (28 in four branches, an Archive's circles), troop tiers I to V, commanders (five archetypes, twenty skills, thirty levels, fury, three talent trees, gear in three slots), the wilds at levels I to X, gathering at the land's sites, alliances with help and their own words, rallies, marches that take watches and say when they arrive, happenings with marks and honours, deeds, charges, might and renown across ages; holy sites held for their gifts; an Infirmary whose beds keep the fallen to be healed; scouting reports from Lanterns; lairs of the wilds broken by rallies; alliance land under standards; an alliance's hall, its fortress, raised on its land; a satchel of hourglasses, caches, ward stones and draughts; six heritages, each with its strengths and a company of its own; alliance studies paid for together; a Forge that works makings from the wilds and the land's sites into three sets of gear; alliance coffers, yards and a storehouse; a keeper's favour (VIP) by levels; companies and battles counted in troops; the Sundering, kingdom against kingdom between the lake's shores; every rule tested on Linux and played by the stewards | Kingdoms of thousands of keepers, and a Frontier map of its own making |
| 6 | Interface and onboarding | 5 | A screen for every system: the Archive (3), Commanders (4), Alliance (5), the Realm (6) and Words (7), on keys, in the menu and on a row of buttons; a small map of the whole lake; battle reports in the Chronicle; tiers chosen in training; a site gathered by a right-click; a rally called from an enemy hold; the wilds and the sites named on hover and read to VoiceOver; portraits of every commander, company and work, and a vista of every hold, drawn from the world's own models and painted as they are drawn, in strokes that keep to the forms, inked edges and a canvas's weave; every screen through the Mac's accessibility audit in CI. The first hour taught in play: a briefing, three first steps, then eleven charges one after another, the last drilling a company, each saying how, with Show me ringing the very control that keeps it, and a reward, each read aloud by the advisor as it comes; a Guide for every system | RoK's painted, illustrated interface |

Overall against Rise of Kingdoms: **5 of 10**.

## What closes each gap

Each item is done when it is real, in the shipped app, tested, and shown in
CI (a test, a figure, or a screenshot). Ticked items are done.

### 1. Live realm, real multiplayer
- [x] Several keepers' clients, as shipped, play together in CI against a real SpacetimeDB server: they arrive, see each other, trade, ally, speak, march on each other and fight
- [x] A live connection: the realm's updates pushed to the client over SpacetimeDB's WebSocket subscription, the reads once a second kept only as a fallback
- [x] Words between keepers: a realm channel and an alliance channel
- [x] One workflow that publishes the realm to maincloud once the maintainer adds the token (the sign-in, and the machine the steward runs on, are the maintainer's)
- [x] Marches and battles that play out across the watch, not resolved at its turn: twelve paces a watch, a host striking as it arrives, stewards acting through it
- [x] Battles that last: in the realm, companies in battle exchange blows again at the paces after the first, until one side falls or draws off
- [x] Armies counted in troops: every company so many at its first muster by kind and tier (Spears 1,200 to 2,400), and those drilled into it since, as many standing as its health allows; battles told in the troops each side slew and lost; a House's army totalled
- [x] Battles of whole armies: fields of battle in which every company near strikes and is struck pace by pace, whole armies drawn in, allies fighting on the side they strike for, each side's companies and troops reported as one battle, shown on the map with each side's troops standing
- [x] Armies by the hundred thousand: companies of war drilled at the Muster Halls, troops taken on watch by watch for grain up to as many as the House's best hall and the company's commander can lead (Spears V with a hall V and a commander of the thirtieth level lead 74,400), every troop counted in battle as the square root of the muster, in its hunger and in its House's strength; in 32 ages of eight stewards a realm's armies came to 770,000 troops at the median as the age ended, against 209,000 before drill
- [ ] Battles of hundreds of thousands: a realm's greatest battle came to 26,000 troops at the median and 55,000 at the most in 32 ages of eight stewards, against 10,000 and 18,000 before drill; RoK's reach hundreds of thousands in one battle
- [ ] The realm up for everyone on maincloud

### 2. 3D world in Metal
- [x] A model library of original procedural meshes, built and tested on Linux, previewed as images
- [x] Terrain as a 3D mesh with relief: still water, shallows, strand, salt flats, greyfields, blackwood, barrows and the spine, each with its own form
- [x] The lake as a 3D surface that mirrors the moon and the stars, black and still
- [x] A camera that pans, zooms, tilts and turns, with the map's picking and VoiceOver's elements through it
- [x] A model for every company kind and tier, every work at every level, every hold, and every feature of the land
- [x] Moonlight, firelight and the world's own lights; the render's frame times measured in CI and held there: the world at three zooms, panning, staging and the marks, each within half again CI's own figures
- [x] Textured detail: every model's stone, timber, thatch, slate and earth drawn with its grain in the shader, fading to its mean with distance; the ground's own grain
- [x] Weather: each omen's own over the world, rain and dimmed moon, banks of mist and thick haze, a clearer still night
- [x] Each heritage's own architecture: a keep for each people, its walls, roof and crown its own; every work and wall of its holds in its people's slates, stone and timber; and a company of its own at the fifth tier in its people's gear
- [x] A city view inside the world: C, or Watch ▸ View the Seat Close, takes the view low over the keeper's seat, leaning in, each work named over its roof and chosen there, its row opened in the hold's panel; Back to the lake returns
- [x] Every hold a town: lanes from the keep's door through the gate and to every work, a ring lane outside the walls; homes of four kinds (cottages, longhouses, roundhouses, townhouses) lit at night with doors in the House's colour, built their people's way, a few about a bare keep and up to 44 (a seat's 64) as its works rise, each facing its lane and never on a lane, a work's ground, the walls' or a company's; a well, a seat's market, a granary's fields; the townsfolk keep to the lanes
- [x] The land's undergrowth: heather on the greyfields, the barrows and the Spine; ferns and birches in the blackwood, and birches out on the greyfields; pebbles on the strand and the flats; among the firs, grass, reeds, crags and stones, every piece within its hex and clear of hearts, previewed
- [x] Fine work near, left off afar: a keep's quoins, framed and shuttered windows, roof ribs and courses, a half-timbered hall with a capped chimney, logs and a handcart (a seat's keep 2,728 triangles, from 778); the walls' arrow loops, string courses, wall-walks, tower slits, finials and gate bands; courses, gable boards, vents, hoops and finials on every hall and round house of the works; the renderer draws it only with the camera near, as close as twice the lake's opening view or closer, so the lake's view costs no more
- [ ] Hand-modelled detail at RoK's density

### 3. Animation
- [x] Companies: idle, march, attack, gather and death, eased from clip to clip
- [x] Works: construction from scaffold to finish, and each upgrade
- [x] Combat: arrows, clashes, sparks, the flash and its light, splinters, the fallen
- [x] Ambience: smoke, embers, fireflies, banners, torches, birds and the drift of mist
- [x] City life: townsfolk at every hold's works, the folk of each work's kind (farmhands, carters of timber and stone, salters, porters), walking out from the keep through the gate and back
- [x] Traffic between holds: a cart on the way between each hold and the nearest other of its House within seven hexes, where unbroken land runs between, timber one way and stone the next
- [x] Skill effects for commanders' fury, each archetype's its own: a ward of pale light over a warden's company, fire thrown out from a vanguard's, shafts of light falling about an outrider's, a ring of gold round a gleaner's, the ground breaking in a ring under a wallbreaker's

### 4. Sound and music
- [x] A sound for every order and every event, checked by a test that none is silent
- [x] Music that follows peace and war
- [x] Sound placed in the world: each cue panned by where it happened across the view, quieter far off
- [ ] Recorded music and foley

### 5. Depth of systems
- [x] Research: a tree of studies with prerequisites, costs and time, each changing the rules it names
- [x] Troop tiers, unlocked by research and the Muster Hall
- [x] Commanders: heroes with skills, experience and levels, who lead companies
- [x] Gathering: stores in the land, worked by companies sent to them
- [x] Alliances of many Houses, with help and words of their own
- [x] Rallies: several Houses' companies joined against one target
- [x] Marches across the map that take time to arrive
- [x] Events: realm-wide happenings with their own goals and rewards
- [x] Progress: a keeper's renown and rewards that carry across ages
- [x] VIP: a keeper's favour with the lake, won each watch they keep in the realm and more for every watch kept unbroken, raising their House by levels I to X (more gathered, works, studies and musters sooner) and bringing a favour chest every tenth watch kept unbroken; carried across ages, shown on the Realm screen
- [x] Talent trees for commanders: three trees of five, a point a level, learned a rank at a time, forgotten for moonsalt
- [x] Equipment: gear left by the wilds in four qualities, worn in three slots, kept in an armoury, broken up for moonsalt
- [x] Holy sites: shrines held by standing on them, each giving its gift to the holder's whole alliance, contested by foes beside them
- [x] Hospitals and healing: an Infirmary at every hold whose beds keep the House's fallen companies of war, healed for half their muster's cost and rising whole as the watch turns, lost with a hold taken
- [x] Scouting: Lanterns near another's hold bring back its garrison and commanders, ward, works and musters under way, the spoils of its taking and its wounded, filed in the Chronicle's Reports; its House sees them watch
- [x] Barbarian forts: lairs of the wilds, levels I to V, that only a rally's host breaks, their spoils shared by the companies each House brought and gear for the caller; modelled, drawn, rallied on from their ground, played by the stewards
- [x] Alliance territory: standards raised by an alliance's Houses whose land gives its companies defence, mending and gathering, struck down by foes at war, drawn in the alliance's colour
- [x] Items and speedups: a satchel of Salt Hourglasses that bring a hold's work and muster or the House's study a watch nearer, caches of stores, ward stones and mending draughts, given by the charges, a happening's marks and honours and lairs broken; used from the Realm screen and a hold's own panel; played by the stewards; the hourglass with a sound of its own
- [x] Civilizations: six heritages of the lake's peoples, dealt round the lake, each with two strengths in the rules and a company of its own at the fifth tier with its own model and name; taken up by keepers from the Realm screen, the first time freely; told in the seat briefing and on the Houses screen; played by the stewards
- [x] Alliance technology: six studies of three grades its leader chooses and its Houses pay for together, each grade raising every House of the alliance; gifts rewarded with hourglasses; played by the stewards
- [x] An alliance fortress: a hall its leader raises on the alliance's land over four watches, widening its land, giving its rallies room and its standards number, its keepers a quarter firmer; only its companies enter; struck down by foes at war, ruined when its alliance is gone; modelled, rising in its scaffold, burning when struck low; played by the stewards
- [x] Crafted equipment and sets: a Forge of five levels, modelled, that works hide, iron, heartwood and moonglass from the wilds, the lairs and the land's sites into three sets of gear, finer the higher it stands, two pieces of a set and all three giving more; forged from the Commanders screen with the anvil's ring; played by the stewards
- [x] Alliance resources: coffers filled by the alliance's land each watch and a tithe of its yards, paying first for what its Houses raise for it; yards (its resource points) of each store that its companies alone work, faster; a storehouse where its Houses lay up their stores out of any taker's reach, torn down and plundered by foes at war; modelled with working hoists, derricks and windlasses; played by the stewards
- [x] Kingdom against kingdom, within the realm: the Sundering, a season from the fifty-fifth watch and every ninety after in which the lake's Houses stand as two kingdoms by the shore their seats stand on; troops slain, holds taken and alliances' works torn down across the shores score for each kingdom; the kingdom that prevails shares its spoils and its foremost House is hailed; told, heard, shown on the Realm screen
- [x] Kingdom against kingdom across realms: the Frontier, a realm and database of its own whose seasons of 24 watches seat only keepers crossing from the realms that border it, each House for its realm's kingdom with a levy of its strongest companies, at war with every other realm's; strikes across kingdoms scored; the season's end told home by the realms' stewards, which read each other's status, the prevailing kingdom's Houses given its spoils; crossed and come home from the Realm screen by the same identity on the same server; played through a real SpacetimeDB server in CI with two realms and the Frontier as three databases, once by the stewards' steps and once by two keepers' own clients with the stewards on their own clocks, a season of watches kept there and told home

### 6. Interface and onboarding
- [x] A screen for every system above, keyboard and VoiceOver included
- [x] An onboarding that teaches the first hour in play
- [x] A voiced advisor: each new charge read aloud as it comes, silent under VoiceOver, with its own setting
- [x] Portraits in the panels: every commander, company and work drawn by the world's own renderer, in its House's colours
- [x] Vistas: each of the keeper's holds drawn whole by the world's renderer at the head of its panel, its keep in its people's way, its walls and works as they stand
- [x] The interface's pictures painted: every portrait and hold vista laid on in strokes that keep to the forms (a Kuwahara filter, a pixel's reach for a portrait, two for a vista), inked along its edges, on the weave of a canvas with its corners in shadow; tested on Linux, applied as each is drawn
- [ ] Painted illustration for the interface at RoK's richness

## The order of the work

1. The 3D world: the model library, then the Metal renderer for terrain, lake and models, then the camera, picking and VoiceOver through it.
2. The depth of systems, rules first (tested on Linux), then the realm and the interface for each.
3. Animation, on the models as they land.
4. The live connection and the multiplayer test.
5. Sound for every action, and music by the state of the realm.
6. The onboarding over all of it.
7. Realms meeting across their borders: the Frontier.
8. Armies by the hundred thousand: drill at the Muster Halls.
9. The land's undergrowth, and fine work on the keeps, walls and works, drawn near.
10. Next: battles of hundreds of thousands; hand-modelled detail at RoK's density.

What only a person can do stays as it was: raising the realm on maincloud
with the maintainer's account, signing and notarizing the release, and
playing it by ear with VoiceOver on a real Mac.
