# Nullmere Online against Rise of Kingdoms: the gap list

The bar, set by ael on October 30: Nullmere Online is to be a complete game
on the level of Rise of Kingdoms or better, native to the Mac. Everything
below is scored against Rise of Kingdoms, honestly: anything 2D, a
placeholder, stubbed or simulated scores under ten. The rules hold
throughout: one shared realm and nothing played alone, the launcher titled
exactly Nullmere Online, and every asset original. This list is kept
current as the work goes; each line says what is there now, not what is
planned, and what CI has shown of it. The rules of every system are in
[PLAYING.md](PLAYING.md).

## Where it stands

| | Requirement | Score now | What is there | What Rise of Kingdoms has that this lacks |
|---|---|---|---|---|
| 1 | Live realm, real multiplayer | 5 | A SpacetimeDB realm whose steward runs the rules, keepers' Macs hearing its changes over a live subscription; several shipped clients playing together on a real server in CI (trading, allying, speaking, marching and fighting); watches played in twelve paces; battles of whole armies; armies of hundreds of thousands of troops; realms of up to ninety-six seats; keepers' views sent in parts | A realm up for everyone (it waits on the maintainer's maincloud sign-in); battles of hundreds of thousands; kingdoms of thousands |
| 2 | 3D world in Metal | 5 | Terrain with relief and grain; every hold a town lit at night; stone, timber, thatch, slate and earth drawn with their grain; each omen's weather; the still lake mirroring the moon and stars; a camera that pans, zooms, tilts and turns, with picking and VoiceOver through it; original models built in code for every company, work, wall, hold, wild and site, with fine work drawn near; a city view; rendered on the GPU in CI | Hand-modelled detail at RoK's density |
| 3 | Animation | 6 | Companies idle, march, strike, gather and fall, eased from clip to clip; works rise from scaffolds; blows, arrows, sparks and splinters; commanders' skills across their companies' ground; burning holds; townsfolk at work and carts between holds; fireflies, birds, banners and hearth smoke | Spell effects made of more than lights and motes; streets as thronged as a RoK city's |
| 4 | Sound and music | 6 | A synthesised night; a score written as it plays by modelled strings, harp, glass bells and drums, turning to war, in a stereo hall; thirty-one cues coloured by their material, one for every order and every event that concerns the keeper; every sound placed where it happened; the din of battles and the talk of towns near the view | Recorded orchestral music and foley |
| 5 | Depth of systems | 5 | Studies, troop tiers I to V, commanders with skills, talents and gear, gathering, alliances, rallies, marches, happenings, deeds and renown; holy sites, an Infirmary, scouting, lairs, alliance land, halls, studies, coffers and storehouses; six heritages; a Forge; favour (VIP); the Sundering and the Frontier, kingdom against kingdom; titles, peace shields, seats raised anew, the Ring and siege engines; every rule tested on Linux and played by the stewards | Kingdoms of thousands of keepers |
| 6 | Interface and onboarding | 5 | The world first: a top bar of three small islands, every panel on one rail, notices that fade; a screen for every system; portraits and hold vistas drawn from the world's own models and painted; every screen through the Mac's accessibility audit in CI; the first hour taught in play, eleven charges read aloud by the advisor; a Guide for every system | RoK's painted, illustrated interface |

Overall against Rise of Kingdoms: **5 of 10**.

## What closes each gap

Each item is done when it is real, in the shipped app, tested, and shown in
CI (a test, a figure, or a screenshot). Ticked items are done.

### 1. Live realm, real multiplayer
- [x] Several keepers' clients, as shipped, play together in CI against a real SpacetimeDB server: they arrive, see each other, trade, ally, speak, march on each other and fight
- [x] A keeper's client on a real SpacetimeDB server in CI sees its hold in the world's 3D models as the realm keeps it: a sawpit ordered raised rises in its scaffold, the sawyers' rig at work beside it, every piece drawn within its budget (and the same played through the fake server on Linux)
- [x] A live connection: the realm's updates pushed to the client over SpacetimeDB's WebSocket subscription, the reads once a second kept only as a fallback
- [x] Words between keepers: a realm channel and an alliance channel
- [x] One workflow that publishes the realm to maincloud once the maintainer adds the token (the sign-in, and the machine the steward runs on, are the maintainer's)
- [x] Marches and battles that play out across the watch, not resolved at its turn: twelve paces a watch, a host striking as it arrives, stewards acting through it
- [x] Battles that last: in the realm, companies in battle exchange blows again at the paces after the first, until one side falls or draws off
- [x] Armies counted in troops: every company so many at its first muster by kind and tier (Spears 1,200 to 2,400), and those drilled into it since, as many standing as its health allows; battles told in the troops each side slew and lost; a House's army totalled
- [x] Battles of whole armies: fields of battle in which every company near strikes and is struck pace by pace, whole armies drawn in, allies fighting on the side they strike for, each side's companies and troops reported as one battle, shown on the map with each side's troops standing; both sides' war banners at each field's heart, leaning as each gives ground and laid flat when it breaks
- [x] Armies by the hundred thousand: companies of war drilled at the Muster Halls take on troops watch by watch for grain, up to what the House's best hall and the company's commander can lead (Spears V with a hall of V and a commander of the thirtieth level lead 218,400); in 96 ages of twelve seats a realm's armies came to 3,190,000 troops at the median as the age ended
- [ ] Battles of hundreds of thousands. In 96 ages of twelve seats, a realm's greatest battle comes to 144,300 troops at the median and 387,600 at the most, over 100,000 in 81 of the ages and over 200,000 in 13; in 8 ages of forty-eight seats, to 166,000 and 248,300. The rules hold such battles (a test meets two armies of eight companies of 25,000 as one field of 400,000), but the stewards' armies never meet whole: a battle takes in about a fifth of its two sides' armies, the rest standing in their holds or marching elsewhere. Wider fields of battle, and a dozen ways for stewards to gather before a siege or come to their allies' battles, were tried and measured over whole ages; none was kept, each leaving the battles no larger or tilting which tempers win. Tried again (November 2): siege rallies called by any House of an alliance at war, allies sending twice the companies, and a House drawing up to six free companies to its own threatened gates; over 32 ages against 32 without it, the greatest battle fell (median 122,725 troops against 135,142; over 100,000 in 25 ages against 30) and the steadfast won 11 to 6, so it stays behind its switch, off. The rule it needed stays: a House may keep its own gates as well as an ally's. RoK's battles reach hundreds of thousands
- [x] Realms of many Houses: a realm raised with up to ninety-six seats, its lake as much wider as keeps each seat its country (a radius of 72 hexes for forty-eight seats, 102 for ninety-six, against 36 for twelve), its seats a walk from the shore that lengthens with the lake so they keep their room (eight hexes or more apart at forty-eight, seven at ninety-six, on every lake's shape); the twelve elder Houses and eighty-four younger ones, each with an original name and a colour of its own that reads as words, each House's land washed in its colour on the map; a lake of twelve seats or fewer made exactly as before
- [ ] Kingdoms of thousands. A realm's watch grows with its seats and its age, still a little faster than its seats. Every seat a keeper's, in an optimised build on a four-core Linux machine, its rules and stewards take 2, 7 and 16 ms a watch at the tenth, fiftieth and ninetieth watch for twelve seats, 7, 44 and 87 ms for forty-eight, and 20, 91 and 219 ms for ninety-six (1.0 s at the ninetieth for ninety-six when first measured); a company in a realm of ninety-six seats costs the watch about twice what one in a realm of twelve does (0.11 ms against 0.05), where it cost five times as much. Every keeper's view is worked out side by side, one to a core: forty-eight views in 0.2 s a publication on four cores. Each cut that got it here kept the same worlds byte for byte; the commits tell them. RoK's kingdoms hold thousands of governors
- [ ] The realm up for everyone on maincloud. Everything is ready but what only the maintainer can give:
  1. `spacetime login` on the maintainer's machine, then the token from `spacetime login show --token` saved as the repository secret `SPACETIME_TOKEN`;
  2. Actions → Publish the realm → Run workflow (database `nullmere`), which publishes the module to https://maincloud.spacetimedb.com/nullmere;
  3. the steward started as the same identity on a machine that stays up: `scripts/raise-realm.sh maincloud` (or the `Dockerfile.steward` image), as docs/GO-LIVE.md step 1 says;
  4. then Actions → Live realm smoke (also run each day) joins two keepers' clients to the live realm and checks each sees the other's House and hears the other speak. Until the realm answers it warns and passes.
  The same two-client smoke runs on every push against a standalone realm raised by the same one command with its steward in the background. From this agent's container maincloud can't be reached at all (the proxy refuses the connection with 403), so the live realm hasn't been seen from here.

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
- [x] Fine work near, left off afar: a keep's quoins, shuttered windows, half-timbered hall, arms and ivy (a seat's keep 3,768 triangles, from 778); the walls' loops, wall-walks and patched stones; homes with flowers, steps and firewood; every work's hall coursed and its yard furnished; all drawn only with the camera near, so the lake's view costs no more. [DESIGN.md](DESIGN.md#every-model-built-from-code) lists it
- [x] A wide realm drawn only where the view reaches: the land's furniture kept in regions of eight hexes a side, each frame drawing only the regions in its view, and the holds, towns and companies out of view not staged. Near, a forty-eight-seat lake draws 10,500 of its 76,000 pieces (12.4 ms of CI's GPU, against 23.1 ms drawing it all), and a realm of ninety-six seats, the widest, costs about what one of forty-eight does, both held by CI: what a frame costs is what is in view, not how wide the realm is
- [x] The Moonspire as the age's wonder: a colonnade, banners and a balustrade past its third stage, moonsalt and a turning halo of shards at its fifth, and a treadwheel crane at work on every stage until it is crowned (808 to 2,528 triangles); and every work, holy site, lair, gate of the Crown, standard, site of the land and alliance hall given the gear of its trade drawn near
- [ ] Hand-modelled detail at RoK's density. Every work but the walls now raises an estate about itself level by level, in its family's own stone, timber, roofs and trade colour: a fenced yard and woodstack at the first level, a lean-to store at the second, a dressed kerb and lit lamp posts at the third, a dormered second house with its chimney and two banners of the House at the fourth, a corner tower and a gate at the fifth, each part laid only while the whole keeps within 2,950 triangles; the greatest levels now stand at 2,668 to 2,944 (the beacon, of three levels, 1,736), the first at 1,244 to 1,556. The walls' first two levels have work of their own: the palisade a walkway on posts behind its stakes, two thatched watch platforms and a gate of two leaves strapped in iron (1,226 to 2,424 triangles); the low stone wall its coping, buttresses and a roofed gatehouse with torches lit (1,384 to 2,280). The Masons' Lodge is modelled whole at each level, with no shared estate: an open thatched shed over a banker, then walled in planks under slate, then a hall of white stone dressed in ashlar before a tracing floor, a treadwheel crane turning at the fourth and a carved arch, dormers and a moonsalt finial at the fifth (1,296 to 2,800 triangles), its jib slewing at every level and its masons' chisels heard in the town; the Beacon too, at its three levels: a braced timber tower with its fire basket, then taller on stone under a slate lookout with the keeper's hut, then a round stone tower with a stair winding round it and a great brazier on its crown (1,452 to 2,830), its fire leaping and its crackle heard; the Sawpit is now modelled whole too, with no shared estate: a pit in the clearing with a log on trestles and the pit-saw rocking through it, then an open shed of planks over the pit and boards stacked on their sticks, a saw-house under thatch whose frame saw a horse drives walking its gin, then on a stone footing under slate with a drying shed, a timber wain and the saw-doctor's bench, and at the fifth a two-storeyed sawmill with its louvre and a board swaying on the hoist beam over a log pond, a fence of posts and rails about the yard (544 to over 2,500), its rasp heard. The Granary as well: a wattle granary on staddle stones under thatch, then a timber barn with its loft door and a threshing floor, then the barn in stone with round grain bins, then iron-hooped silos, drying racks and a wain, then a buttressed tithe barn with its louvre and a dovecote (1,378 to 2,880), its sack hoist swinging at the loft door and its flails heard; the Quarry, its rock face cut in benches deeper at each level, a windlass, then shear legs, a boom derrick, a treadwheel crane and at the fifth a great gantry over the pit, the stone-cutters' shed and the quarry-master's house (1,036 to 2,628), what lifts its stone always at work and its picks heard; the Saltworks, from pans in the shore mud with a shaduf and a thatched hut, to pans in a grid on walkways, a stone boiling house smoking, a brine wheel turning, and at the fifth a refinery tower of white stone with its moonsalt crystals lit (1,282 to 2,626), a dyke rising round the pans with each level, its rakes heard hissing through the crust; the Muster Hall, from a staked drill yard with pells, a spear rack and the drill-master's tent, to a timber barracks with archery butts, stone barracks and an armoury, a drill tower over a flagged parade ground, and at the fifth a gatehouse of two towers with the war drum (1,214 at the first level to its fifth near its budget), a quintain spinning at every level, its drum heard beating the step and its roof truss swung up between shear legs as it rises; the Infirmary, from a canvas tent of cots by the healers' open fire, to a timber ward under thatch with raised herb beds, a ward of white stone with a bath-house and a lantern walk, a cloister about a physic garden, and at the fifth a great hospice crowned with a dome and a moonsalt lantern beside its bell cote, its well's windlass turning and its pestle heard grinding herbs; the Archive, from a scholar's cell with a lectern, scroll chests and a sundial, to a long library with writing desks under an awning, a stone archive and scriptorium about an armillary sphere, an observatory tower under a dome, and at the fifth a domed reading hall with a columned portico beside the observatory crowned with the great armillary, its vane or armillary turning, its pages and quills heard, and a crane and ladder at work as it rises. The Moonspire stands in a court of its own: a processional way of pale flags to its door, obelisks of black stone more with each stage, moonsalt braziers from the third and a gate arch with banners at the fifth (896 to 2,528). The Forge, from a clay bloomery smoking in a ring of stones beside an anvil under a thatched lean-to, to a timber smithy with its stone chimney and glowing hearth, a stone smithy with a trip hammer, an armourer's shop, a grindstone and an ore cart, and at the fifth a buttressed forge hall of three hearths under its tall bannered chimney before a furnace of moonglass (734 to 2,690), its bellows or hammer always at work and the smith's tap, tap, blow heard ringing on the anvil. The Wayhouse, from a thatched waystation with a horse tethered at its post and a signpost at the road, to a timber inn with a stable range and a hay rick, an inn of pale stone of two storeys with its cote for the post-birds, a gate over the cobbled road with its lantern and a post-coach in the yard, and at the fifth a three-bay stable range, two coaches, a team in harness and a waymark pillar crowned with a moonsalt lamp (674 to over 2,500), its inn sign swinging and the cote's vane turning, a horse heard led across the yard with its harness bells. While a work rises, its builders' own rig works beside the scaffold on the side away from the keep: shear legs swinging a log over the sawpit, a treadwheel crane slewing a block for the lodge and the archive (its masons' ladder too), a gin pole hauling up the beacon's fire basket, a roof truss swung up for the muster hall, a thatchers' derrick swinging a bundle of straw to the granary's roof, a tripod and windlass lowering a stone on its lewis into the quarry's footings, and a beam pile-engine driving the saltworks' piles into the shore mud. Still open: the other works' estates are a shared kit placed about each work rather than modelled into it, no work has new animation or sound of its own, and the gathering sites are now modelled at the works' density: the outcrop a ridge of three rock masses in bands of strata with its stepped faces, stacked blocks, sheerlegs over the cut, the quarrymen's lean-to and scree with heather (2,243 triangles, from 531); the stand of firs tall tiered firs on spread roots with young firs, birches, ferns, the woodcutters' bark shelter, a log sledge and a charcoal clamp (2,851, from 578); the grain field its ears standing thick, a row of stooks, a thorn hedge with its gate, an oak at the corner and a field shelter (2,833, from 1,036); the salt pan walkways, the rakers' hut, a barrow, sluice boards and reeds (1,958, from 1,132). The alliance yards now carry their store away on a loaded wain with its horse in the shafts, a trough and a tally board (1,612 to 2,024, from 880 to 1,340); each lair has the ground its wilds have made their own (the saltwights' crystal ring and pale cairns, the reavers' tents, beached boat and loot, the barrowkin's cairns and crooked headstones, the spine hunters' hide racks and bone totems, the drowned's weed-hung columns and pools) and the gatehold coursed towers, wing walls into the peaks, stairs, shields and a hunters' tent (1,418 to 2,416, from 764 to 1,558). The holy sites now stand in a court of their own (lintels across the ring's stones, the way in between lines of lesser stones, braziers burning at its gap) and each heart is alive, motes of moonlight, black water-drops, salt crystals, the broken crown's shards or the heartstone's halo turning about it (1,490 to 2,176); the rally camp a ring of six war tents with their pennons, horse lines, a rack of spears, the drum's beaters rising and falling and its fire leaping (1,278, from 626); the alliance standard a stepped plinth carved with the alliance's shield, guard posts, a ring of lesser banners and braziers flickering (914, from 468); each set working on the stage. The plainest pieces left are the drowned crown (642), a single relic, and the standard, still under a thousand

### 3. Animation
- [x] Companies: idle, march, attack, gather and death, eased from clip to clip
- [x] Works: construction from scaffold to finish, and each upgrade
- [x] Combat: arrows, clashes, sparks, the flash and its light, splinters, the fallen
- [x] Ambience: smoke, embers, fireflies, banners, torches, birds and the drift of mist
- [x] City life: townsfolk at every hold's works, the folk of each work's kind (farmhands, carters of timber and stone, salters, porters), walking out from the keep through the gate and back; close up, the rest of the town's folk out about its lanes, one for every three homes (up to 10, a seat's 16): householders, water-carriers, elders and children, each keeping to one side of the lane
- [x] Traffic between holds: a cart on the way between each hold and the nearest other of its House within seven hexes, where unbroken land runs between, timber one way and stone the next
- [x] Skill effects for commanders' fury, each archetype's its own and as wide as the company's ground: its sigil laid about the company in its light (two rings and six spokes swelling out and turning as they fade), then a ward of pale light over a warden's company under a shaft of it, fire thrown out from a vanguard's with its embers flying, shafts of light falling about an outrider's, a ring of gold round a gleaner's under a shaft of gold, the ground breaking in a ring under a wallbreaker's; two hundred motes and more each, against some thirty before

### 4. Sound and music
- [x] A sound for every order and every event, checked by a test that none is silent
- [x] Music that follows peace and war
- [x] Sound placed in the world: each cue panned by where it happened across the view, quieter far off
- [x] Instruments modelled on real ones, in a hall: the score's strings bowed (three players to a note, sawtooths kept from aliasing, a slow vibrato each, a body's low-pass), a harp plucked (Karplus and Strong's string, in tune to four cents at any rate, every pluck carrying its note), glass bells and skin drums struck (each mode a resonator of its own, the drum's pitch falling back after the blow), the score and the cues ringing in a stereo hall (a feedback delay network of eight lines, a 2.6-second tail, its highs dying first), the night dry; all of it rendered and measured on Linux, and kept by CI as sound files to listen to
- [x] Foley coloured by its material: each cue's noise through its own band, a page high and soft, hooves, skins and earth low, grit and dust about the middle, steel bright and salt brighter, as loud at any rate; tested by where each sits in the spectrum
- [x] The eaten moon's own music: while the drowned age walks, chords of stacked minor thirds and tritones, low and slow, a line from the scale of tones and half tones on glass bells far apart, each answered on the harp a tritone above; no chord rolled and no drum
- [x] The towns near the view heard: as the view comes down close to a hold, two murmurs of talk through a voice's formants, rising and falling syllable by syllable, and a hammer's blow now and then, about as loud as the night, the louder the more the hold has raised, from where it lies across the view, eased in and out as the view moves; still under the stillest motion
- [ ] Recorded music and foley: a score played by musicians, and foley recorded for every cue

### 5. Depth of systems
- [x] Research: a tree of studies with prerequisites, costs and time, each changing the rules it names
- [x] Troop tiers, unlocked by research and the Muster Hall
- [x] Commanders: heroes with skills, experience and levels, who lead companies
- [x] Gathering: stores in the land, worked by companies sent to them
- [x] Alliances of many Houses, with help and words of their own; their help seen in the world, a light circling over a helped hold's keep for each ally that helped
- [x] Rallies: several Houses' companies joined against one target; while one gathers, its war camp stands in the world past its muster's walls, toward its march, in its caller's colour
- [x] Marches across the map that take time to arrive
- [x] Events: realm-wide happenings with their own goals and rewards
- [x] Progress: a keeper's renown and rewards that carry across ages
- [x] VIP: a keeper's favour with the lake, won each watch they keep in the realm and more for every watch kept unbroken, raising their House by levels I to X (more gathered, works, studies and musters sooner) and bringing a favour chest every tenth watch kept unbroken; carried across ages, shown on the Realm screen
- [x] Talent trees for commanders: three trees of five, a point a level, learned a rank at a time, forgotten for moonsalt; seen in the world, the leading tree's sigil glowing beneath a commander on the march, wider with its ranks
- [x] Equipment: gear left by the wilds in four qualities, worn in three slots, kept in an armoury, broken up for moonsalt
- [x] Holy sites: shrines held by standing on them, each giving its gift to the holder's whole alliance, contested by foes beside them
- [x] Hospitals and healing: an Infirmary at every hold whose beds keep the House's fallen companies of war, healed for half their muster's cost and rising whole as the watch turns, lost with a hold taken
- [x] Scouting: Lanterns near another's hold bring back its garrison and commanders, ward, works and musters under way, the spoils of its taking and its wounded, filed in the Chronicle's Reports; its House sees them watch
- [x] Barbarian forts: lairs of the wilds, levels I to V, that only a rally's host breaks, their spoils shared by the companies each House brought and gear for the caller; modelled, drawn, rallied on from their ground, played by the stewards
- [x] Alliance territory: standards raised by an alliance's Houses whose land gives its companies defence, mending and gathering, struck down by foes at war, drawn in the alliance's colour; its borders marked in the world by boundary stones capped in the alliance's colour wherever its land meets land not its own
- [x] Items and speedups: a satchel of Salt Hourglasses that bring a hold's work and muster or the House's study a watch nearer, caches of stores, ward stones and mending draughts, given by the charges, a happening's marks and honours and lairs broken; used from the Realm screen and a hold's own panel; played by the stewards; the hourglass with a sound of its own
- [x] Civilizations: six heritages of the lake's peoples, dealt round the lake, each with two strengths in the rules and a company of its own at the fifth tier with its own model and name; taken up by keepers from the Realm screen, the first time freely; told in the seat briefing and on the Houses screen; played by the stewards
- [x] Alliance technology: six studies of three grades its leader chooses and its Houses pay for together, each grade raising every House of the alliance; gifts rewarded with hourglasses; played by the stewards
- [x] An alliance fortress: a hall its leader raises on the alliance's land over four watches, widening its land, giving its rallies room and its standards number, its keepers a quarter firmer; only its companies enter; struck down by foes at war, ruined when its alliance is gone; modelled, rising in its scaffold, burning when struck low; played by the stewards
- [x] Crafted equipment and sets: a Forge of five levels, modelled, that works hide, iron, heartwood and moonglass from the wilds, the lairs and the land's sites into three sets of gear, finer the higher it stands, two pieces of a set and all three giving more; forged from the Commanders screen with the anvil's ring; played by the stewards
- [x] Alliance resources: coffers filled by the alliance's land each watch and a tithe of its yards, paying first for what its Houses raise for it; yards (its resource points) of each store that its companies alone work, faster; a storehouse where its Houses lay up their stores out of any taker's reach, torn down and plundered by foes at war; modelled with working hoists, derricks and windlasses; played by the stewards
- [x] Kingdom against kingdom, within the realm: the Sundering, a season from the fifty-fifth watch and every ninety after in which the lake's Houses stand as two kingdoms by the shore their seats stand on; troops slain, holds taken and alliances' works torn down across the shores score for each kingdom; the kingdom that prevails shares its spoils and its foremost House is hailed; told, heard, shown on the Realm screen
- [x] Kingdom against kingdom across realms: the Frontier, a realm and database of its own on a lake of its own (the Marches: four meres and open land between them), whose seasons of 24 watches seat keepers crossing from the realms that border it, each House for its realm's kingdom with a levy of its strongest companies; strikes across kingdoms scored, the season's end told home by the realms' stewards, which read each other's status; played through a real SpacetimeDB server in CI with two realms and the Frontier as three databases, by the stewards and by two keepers' own clients
- [x] Kingdom titles (RoK's king and his titles): the keeper whose House holds the broken Spire, the last age's Moonspire and the realm's Lost Temple, names other Houses to seven titles from the Realm screen, four boons (more gathered, works and studies sooner, harder blows) and three slights (less gathered, softer blows, less firm), each borne by one House at a time and named anew no sooner than three watches on; the realm is told each, the Houses' list shows it, and all lapse when the Spire passes; a steward holding it names none
- [x] Peace shields (RoK's peace shield): the veil of the Still, drawn by a keeper from their seat's record for 30 moonsalt; for eight watches no hold of the House may be struck, rallied on or scouted, a rally already called on one turning back, though its companies abroad may still be met; it lifts the moment the House strikes another House, calls or joins a rally on a hold, or scouts one, rests ten watches before it is drawn again, and is shown on the holds' records, under the pointer and in the world, a low mist lying about each of the House's holds; stewards draw none and let veiled holds be
- [x] Moving a city (RoK's territorial teleport): a keeper raises their seat anew on open ground of their House's own land, from that ground's panel, for 40 moonsalt, its works, walls, ward and wounded as they stood and the company at its gates with it; once in thirty watches, never while its ward is short of whole or a foe at war stands within three tiles of it; told to the House and to whoever sees either place. Anywhere on the lake, as RoK's advanced teleport goes, it does not go
- [x] Siege engines (RoK's siege units): Mangonels, a fourth kind of company of war mustered from a Muster Hall of IV in tiers I to V, hurling stones from two tiles away three times as hard as any other company on a ward, soft in the field and riders' prey; an original model in five tiers whose arm flies to its stop bar as it strikes; stewards at war muster them and stand them off at their reach at a siege
- [x] Passes that open the map zone by zone, about a prize at its heart (RoK's Lost Kingdom and its Ziggurat): on the Frontier's Marches the Crown, a ring of the Spine with a gate between each two meres, held by the wilds and broken by companies or rallies for the season, its spoils the breaker's; at its heart the Heartstone, a holy site counting for its holder's kingdom every watch; each gate and the Heartstone an original model; the stewards strike the gates and seek the Heartstone. In the realm proper the Spine and the streams' shoals shape the ways, but no zone is shut
- [x] An alliance battleground over a relic (RoK's Ark of Osiris): the Drowned Crown, which lies at the heart of the Moonford while it is bare; a company of war standing on it takes it up and bears it, its alliance (or its House alone) marked each watch it is borne, the crown let fall where its bearer is struck down; as the water comes back the side that bore it longest is given 20 moonsalt a House. Stewards go for it from their nearby holds and hold it once taken; drawn in 3D, a weed-hung crown of gold with seven moonsalt stones that turns on the shingle and rides high over its bearer; heard as a herald, a horn for the keeper's side and dread for another's; told in a band under the bar only while it lies on the ford
- [x] An arena of commanders (RoK's Sunset Canyon): the Ring, at the foot of the Commanders screen, where a keeper stands a line of up to three of their commanders, each weighing its level, its talents and its gear, and challenges other keepers' lines three times a watch; the heavier line wins, a fifth either way by the realm's chance, and takes standing from the loser, the more the higher the loser stood; at each full moon the three standing highest take 30, 20 and 10 moonsalt and every standing drifts halfway back to 1000; every line in the Ring is seen by every keeper, with what its commanders wear; no company fights and no commander is hurt; stewards stand no line

### 6. Interface and onboarding
- [x] A screen for every system above, keyboard and VoiceOver included
- [x] An onboarding that teaches the first hour in play
- [x] A voiced advisor: each new charge read aloud as it comes, silent under VoiceOver, with its own setting
- [x] Portraits in the panels: every commander, company and work drawn by the world's own renderer, in its House's colours
- [x] Vistas: each of the keeper's holds drawn whole by the world's renderer at the head of its panel, its keep in its people's way, its walls and works as they stand
- [x] The interface's pictures painted: every portrait and hold vista laid on in strokes that keep to the forms (a Kuwahara filter, a pixel's reach for a portrait, two for a vista), inked along its edges, on the weave of a canvas with its corners in shadow; tested on Linux, applied as each is drawn
- [ ] Painted illustration for the interface at RoK's richness
- [x] A cinematic trailer (direction of November 1): a minute and fifty-two seconds of the game's own world at night, with nothing of the interface or the rules, every camera low and slow near the water and the holds, every frame drawn by the game's own renderers and scored by its own synthesiser, ending on the title; 1920 by 1080 at sixty frames a second, rendered on CI's Mac and published by the Trailer workflow as the asset of the [`trailer` release](https://github.com/ael-dev3/Nullmere/releases/tag/trailer). After a review, none of the marks the game lays over its world for its keepers is drawn in it: no skill's ring, no lanes, no motes read as status dots
- [x] The trailer's rain an unbroken streak however near the lens, and the world's smoke, mist and fallen fading smoothly (each covering as many of a pixel's samples as it is opaque), not as a dotted patch
- [ ] More of the world's life in the trailer: a siege at a hold's walls and the Moonspire's crowning seen close
- [x] The world first (direction of October 31): the interface minimal, contextual and uncluttered, panels collapsed until wanted. The top bar three small islands; every panel on one rail; the small map of the lake hidden until asked for; notices that show for nine seconds and fade (VoiceOver says each, the Chronicle keeps the story); the charge a line until asked for more; envoys one at a time; the counsel and the charge giving way whenever a company, ground or a hold other than the seat is chosen, so the selection is the only card beside the world; a hold's record and the Houses each folded to a line until opened; the panels narrower (the rail 328 points, from 360). CI photographs the plain view and holds the world's share of a laptop's window to a budget

## Warpkeep parity

Direction of October 31: Nullmere is to have every feature of Warpkeep
(github.com/ael-dev3/Warpkeep), reimagined with its own assets. Warpkeep
shipped no companies, battles, alliances or ending of its own (its last
patch notes say so); Nullmere goes far past it there. What Warpkeep did
have, feature by feature, audited from its source:

Already in Nullmere, in its own way:
- [x] A title over a living backdrop (Warpkeep's stone wordmark over a galaxy; here NULLMERE ONLINE over the moonlit lake), a transition into the game, and a menu that the keyboard alone can drive
- [x] A build stamp and patch notes (the launcher's footer, News from the repository)
- [x] Plain notices when the realm can't be reached, a boot painting when the GPU can't draw
- [x] Sound and music settings, reduced motion, keyboard and screen-reader play, meaning beyond colour; settings inside the world
- [x] An identity kept on the device between sessions; open admission with a queue
- [x] New worlds by generation (ages on a fresh lake, Frontier seasons), honest outcomes for every order, the realm's state before entry
- [x] Four resources with yield, storage and their accounts; a daily reward (favour for each watch kept, with chests)
- [x] Sites of the land to gather from, sent from the map, full sites refused, journeys drawn and heard
- [x] Works at five levels with costs and times, yield works, one rising at a time, the catalogue with each level's gain, construction drawn rising, the seat entered close (the city view)
- [x] A seeded hex world with its terrain recorded, landmarks, a bounded edge
- [x] A camera that pans, zooms and turns, labels on every hold, records for holds and companies, selection and hover, one step back at a time, a steady world
- [x] A first journey taught in play, a guide, a reason on every refused button, a welcome back
- [x] A shared world, public standing, generated cues placed where they happen, a sound for the water
- [x] Original models, detail by distance, living land, towns at work, a lit sky
- [x] Drawing paused in the background

To build, reimagined:
- [x] Credits, rolled in the launcher, still under reduced motion
- [x] The founding watch on a hold's record ("raised in the 23rd watch", under its name)
- [x] Bring it home: a gatherer recalled with what it carries, and every gatherer at once (Bring home and All home on its record)
- [x] The watches left of a gathering and of the way home on a gatherer's record; a list of the House's gatherers (folded under a gatherer's record)
- [x] A gathering's length chosen as it is sent (a watch, three, until full)
- [x] The camera's buttons on screen (under the small map, while it is shown), and Reset View to the whole House (⌘0)
- [x] Sounds for the interface (a panel opening and closing, going back, an order refused), and the trackpad's taps where the Mac has them
- [x] A keeper's House hidden everywhere (its Words, its notices, its ballads, its envoys' words), not only an envoy's; an unread count on the rail's Words
- [x] Words made safe at the realm: a line reported, kept with what was said round it for the realm's steward; the realm able to remove a line and bar a keeper (the realm's whole record paged back is still the latest eighty lines)
- [x] The realm's compact: terms and privacy in plain words, read and accepted at the front door before first entry, asked again when they change; a keeper forgotten by the realm's steward when they ask
- [x] A keeper's identity carried to another Mac: sixteen words written down (the realm keeps a digest of their digest), and taken up on the other; leaving an identity, and taking up another
- [x] A newer build known: the launcher tells its build in its footer and the realm the tongue it speaks and the oldest it hears; a Mac too old for its realm is told so at the door, which won't open, and where to get the new one (and in the world, once, should the realm move on)
- [x] A House's crest (Warpkeep's profile and portrait): a shield of one of seven tinctures bearing one of ten charges in another, drawn in the interface; the lake gives every House its own, the same for the same realm, and a keeper takes their own once an age from the Realm panel, told to every House; borne on each House's line among the Houses and hung in the world at every hold's gate, a shield on its board in the field's tincture with its charge in relief in its own
- [x] Rivers: streams from the Spine to the lake, crossed only at their shoals (stepping stones across, two moves, a quarter less firm), named and followed (a stream under the pointer traced from spring to mouth); the shores' regions between them named, written over the land when the view is drawn back, under the pointer and in a tile's record, with a legend (The land, in the Realm panel: each region, the streams that bound it, whose holds stand in it). The realm's atlas, its streams, regions and the lake's crests, travels whole to every keeper's view in a part of its own, so the crests the lake gave are the realm's own in every view
- [x] Graphics chosen for the Mac: Detail (Auto, High, Medium, Low), Auto reading the memory the Mac's graphics may work in; Reset to the defaults in both Settings; when the GPU fails three frames, a step down, told, before the painting
- [x] Title and menu music in the launcher, a theme for each lake: the night beneath a title theme for the lake the keeper's realm last lay on, each lake in a mode of its own (the Twin Waters answering each note a fifth above, the Frontier's Marches in G mixolydian), and Music among the launcher's settings, one choice with the realm's
- [x] A work that hastens marches and one that hastens building (Warpkeep's Barracks and Cathedral): the Wayhouse, each level sending one more kind of the House's companies a step further every watch, and the Masons' Lodge, each level raising every work 6% sooner; each modelled in five levels, given its own place in a hold, raised by keepers alone so the stewards' worlds stay exactly as they were
- [x] Works placed by the keeper within a hold (Warpkeep's free placement): in the city view a work chosen may be set in any of the eighteen places round the keep whose ground is the hold's, trading places with a work that stands there; kept with the hold, honoured by the hold's layout and its town, every other work standing where its ground suits it
- [x] A crash met by a page that says what happened and opens the world again: a fault caught as it strikes, and the next launch opening on where the keeper was, when, and what stopped it, with Open the world again, Report it (a new issue, written out) and Back

Left out by design, with what stands in their place:
- Play in a browser, on phones and tablets, and as a Farcaster Mini App: Nullmere Online is a native Mac game on Apple silicon (the on-device model is part of it); Sign In With Farcaster becomes the keychain identity and its recovery phrase
- One keep for good: a seat lasts an age, and renown, favour, titles and deeds carry across ages
- Hand-curated admission: admission is open, with a queue
- Time passing with nobody in the realm: an empty realm sleeps, and a caretaker keeps an absent keeper's House
- A lyric film and moving water: the lake is still by design, under a night that never ends

## Beyond Rise of Kingdoms: what nobody has shipped

Direction of October 31: cover Rise of Kingdoms whole, then go past it with
mechanics of Nullmere's own, from what no other game of its kind has: a still
lake under a moon, an on-device model on every keeper's Mac, and a realm that
persists, age after age. Each is ticked when it is real, tested and shown in
CI; [PLAYING.md](PLAYING.md#what-only-nullmere-has) has the rules of each.

- [x] **Ferries of the Still.** Companies poled across the lake between a
  House's own shore holds in one watch, for timber: barges seen on the water
  by whoever sees either shore, turned back if the landing falls meanwhile.
  Rules, realm, a contextual line in the selection panel and the barge drawn
  in 3D with its ferryman and lantern.
- [x] **The Moonford.** The moon keeps a calendar of thirty watches, and about
  each full moon from the fifty-fifth watch the tide lays bare a ford of
  shingle across the lake for ten watches, where the two kingdoms of a
  Sundering meet; the water takes back whoever still stands on it as the
  moon wanes. Over 48 ages it leaves how ages end where it was and makes
  battles a little larger (median 85,020 troops against 79,206).
- [x] **Edicts of the realm.** Laws a realm votes for itself (the Moon's
  Peace, the Harvest Truce, Safe Conduct, Holy Ground), every House voting
  by its might, and kept by the server for twenty watches: politics held by
  the rules, not by players' good faith.
- [x] **Ballads.** Verse of a House's own deeds, written on its keeper's Mac
  by its on-device model and sung to the realm's songbook: verse no server
  wrote and no other keeper's Mac made.
- [x] **Bottles on the lake.** Words set adrift from the shore, carried by
  the lake's current to whoever finds them: anonymous or signed, offers,
  warnings and lies, a way to speak to strangers that no chat has.
- [x] **Drowned ages.** The holds of the age before lie drowned in the new
  lake as named ruins, searched for what their works held: the realm's
  history is its map.
- [x] **The broken Spire.** The Moonspire an age raised highest stands broken
  in the next, a holy site whose holders build for less and sooner, and
  whose keeper names the realm's titles.
- [x] **Dreams of the Still.** At the dark of each moon, each keeper's House
  is shown one true thing it cannot see, chosen by the realm and told in the
  Still's voice by the keeper's own Mac: intelligence no spy brings, from a
  model no server runs.
- [x] **The Augury.** A market in foresight kept by the realm: keepers
  foretell the realm's course and stake moonsalt on it, others back or stand
  against them, and the realm judges by what comes to pass. No odds are set
  and no player judges.
- [x] **Whispers on the water.** Unsigned rumours whose truth the realm alone
  knows until a keeper's Lanterns find it out; a false one names its teller
  to the whole realm. Deception and reputation with no game master.
- [x] **The Remembering.** At each half moon, a riddle of the realm's own
  past, set in the Still's voice by the keeper's Mac: the realm's history
  made into play, age after age.
- [x] **The Eclipse.** At the eaten moon the drowned age walks again, its
  greatest holds rising as companies that bear their keepsakes: what keepers
  built in one age comes back to be fought for in the next.
- [x] **Orders in your own words.** A keeper writes what they would have
  done as they would say it, and their Mac's model, as the House's clerk,
  reads it into the order book, each line checked against the keeper's own
  view and given only when the keeper gives it. The model only reads; the
  realm judges.
- [x] **Letters to the age to come.** Sealed under a hold's stones, found in
  its drowned ruin in the next age and read to every House: the realm's past
  speaking to its present in its own keepers' words.
- [x] **Standing orders in your own words.** What a House should do while
  its keeper is away, told in plain words and followed by the realm's
  caretaker: the House played as its keeper would have it while their Mac is
  shut. In Rise of Kingdoms an absent player's troops stand idle.
- [x] **Prisoners who talk.** A commander felled by a keeper's company is
  taken prisoner, questioned for true things of their own House, worked out
  by the realm and spoken in the prisoner's voice by the captor's Mac, and
  ransomed or let go.
- [x] **Oaths the realm keeps.** A keeper swears in their own words to keep
  the peace with a House or send it goods, and the server holds their House
  to it: a promise between players made a binding contract of the world.

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
10. Realms of many Houses: up to ninety-six seats round a wider lake.
11. A wide realm drawn only where the view reaches.
12. A wide realm's watch: the stewards' work done over and over cut; the Sundering's shores at war; keepers' views sent in parts and worked out with each march's way found once.
13. The trailer, filmed in the game's own renderers.
14. Next: battles of hundreds of thousands, by armies that meet whole; kingdoms of thousands; hand-modelled detail at RoK's density.

What only a person can do stays as it was: raising the realm on maincloud
with the maintainer's account, signing and notarizing the release, and
playing it by ear with VoiceOver on a real Mac.
