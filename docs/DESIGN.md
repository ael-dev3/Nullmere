# Design

How Nullmere Online looks, and the direction it keeps.

- [The launcher](#the-launcher)
- [The world in three dimensions](#the-world-in-three-dimensions)
- [Direction](#direction)

## The launcher

A full moon hangs over a great black lake. The water below gives it back
whole, still as black glass. Pale, thin type rests above the far shore. The mood is
vast, quiet and monumental, after the grand, minimal look of the Dune films.
Over it the night's drone and wind play beneath the title theme of the lake
the keeper's realm last lay on, made as it plays.

- **The moon** is a large, cold full moon at the top of the sky, the same
  view as the app icon. Its halo swells and settles very slowly, and thin
  haze drifting past catches its light.
- **The stars** flicker, each at its own pace, warm or cold. They flicker
  more near the horizon, as they do through deeper air. Now and then a star
  falls: the first a few seconds after the lake appears, then at random,
  about once in a minute and a half, drawing a fading trail away from the
  moon.
- **The lake is dead, deep and still.** Nothing stirs it: it gives back the
  sky exactly, the moon whole with its rim as clean as above, and every
  star where it stands, falling stars too. It shows itself only by giving
  back a little less light as it nears, and by the mist and the hairline of
  light where it meets the far shore.
- **The title** is NULLMERE ONLINE on a single line, set in SF Pro Thin
  with wide tracking, and nothing else. The letters settle together as it
  appears. The menu is a single row of
  light, spaced capitals on the water, and the chosen word glows faintly
  over a hairline. Panels darken the water beneath them so their text stays
  legible over the reflection, and the moon's image dims under them to a
  ghost of itself, never gone, brightening again as they are put away.
- **Rendering.** One fragment shader draws the whole scene procedurally. It
  is compiled at runtime from
  [`LakeShader.swift`](../Sources/LauncherKit/Backdrop/LakeShader.swift), so plain
  `swift build` works. Stars are sized in points, so they stay crisp at any
  window size or backing scale, and the output is dithered so the dark
  gradients don't band.
- **Cost.** The lake renders only while the window is visible and motion is
  allowed, at the chosen frame rate and resolution. It drops to 30 frames a
  second while another app is in front, in Low Power Mode, and when the Mac
  runs hot. If the shader fails, a still SwiftUI painting of the scene
  replaces it.
- **Accessibility.** The launcher honours Reduce Motion and Increase
  Contrast, reads its type at the game's Larger Text, has VoiceOver labels
  and selection traits, and works fully from the keyboard.

## The world in three dimensions

- **The land** is a mesh with relief, drawn by Metal from
  [`WorldShaders.swift`](../Sources/NullmereWorld/WorldShaders.swift): the Spine's
  ridges, the barrows' mounds, the strand and the flats, and the still
  lake laid over it as a mirror of the stars and the moon. What the keeper
  has never seen lies under mist; what they saw once and see no longer,
  greyed as memory.

### Every model, made in Blender or built from code

Every model is original. Every company of war (the spearman, the archer,
the lantern-bearer, the rider on his horse and the Mangonel with its crewman)
and the six commanders are made in Blender, each by a script
([`Art/blender/spearman.py`](../Art/blender/spearman.py),
[`archer.py`](../Art/blender/archer.py), [`lantern.py`](../Art/blender/lantern.py),
[`rider.py`](../Art/blender/rider.py), [`commanders.py`](../Art/blender/commanders.py),
[`mangonel.py`](../Art/blender/mangonel.py))
that builds the body, gear and
skeleton and keys the actions, on one body every person shares
([`person.py`](../Art/blender/person.py)): the skin is weighted to the
bones each side of a joint, so it bends there rather than breaking, and
each tier and heritage is a set of tagged pieces in one file. The
archer's draw is worked out where his hands must be, the bow arm laid at
the foe and the drawing hand at his cheek, the string and the arrow on it
weighted to the bow at one end and to the hand at the other. The horse is
a skinned body of its own under the rider, on the twelve bones every horse
in the game moves on, its coat, socks and mane made in materials the game
colours as each tier's horse is; the rider's legs, round its barrel, are
carried by his seat, so horse and rider keep to the 24 parts every
figure's rig is held to; the commanders ride the same horse
([`horse.py`](../Art/blender/horse.py)), each his own variant of one file
and each striking his own way, an action tagged for the variants that
strike so. The
file is glTF binary, written in one fixed order so the same script always
makes the same bytes, and the game carries it and reads it with an
importer of its own ([`Asset.swift`](../Sources/NullmereModels/Asset.swift)):
each vertex moves with its two heaviest bones, by its weight between them,
and each action plays bone by bone. Every other model is still built from
code ([`Sources/NullmereModels`](../Sources/NullmereModels)), and moves to
Blender the same way: the founder's handcart, the townsfolk, the wilds,
keeps, walls and every work at every level, the land's
firs, birches, heather, ferns, crags, reeds, pebbles, mounds and ruins, and
what moves through the world.
Companies stand in formation, fewer as they are worn down and more as they
are drilled; holds lay out their works on the land around the keep. Near,
the models show fine work that is left off from afar, where it is too small
to see. The tests hold every model under a budget of triangles (700 for a
figure, 3,000 for a work, 4,500 for a keep or an alliance's hall);
[GAPS.md](GAPS.md#2-3d-world-in-metal) says where they stand.

- **The keep.** A keep's quoins, framed windows with shutters in its House's
  colour, roof ribs, a half-timbered hall with a capped chimney, a log pile
  and a handcart, and nearest the hall's gable plastered between bargeboards
  under the House's arms and a bell-cote, flowers under its windows, a bench
  and potted shrubs by its steps, spouts at the tower's corners and ivy up
  its flank.
- **The walls.** The walls' arrow loops, string courses, wall-walks, tower
  slits and finials, and iron bands on the gate, and on the low stone walls
  the putlog holes their scaffolds left, patched stones and ivy up the
  gate's flanks.
- **The scaffold.** The scaffold round a rising work lashed at every joint,
  railed, laddered and with a hoist.
- **The town.** The town's homes shuttered, with flowers under their
  windows, steps at their doors, pots on their chimneys and firewood
  stacked, a townhouse's sign hung out over the lane in its House's colour.
- **The works.** On every hall and round house of the works, courses across
  the roofs, boards and vents in the gables, the rafters' ends under the
  eaves, hoops and finials.
- **Their yards.** In every work's yard but the Moonspire's, its odds and
  ends, barrels, crates, sacks, a bucket, a bench and stacks of logs, set
  down where nothing of the work stands and clear of the way to its door.
- **The Moonspire.** The Moonspire rises past its third stage as the age's
  wonder: a colonnade of white columns about its drum under a ring of stone,
  a string course, the House's banners hung between its buttresses and a
  balustrade round its top; at its fifth, moonsalt grown out of its plinth
  and a halo of shards turning below its crown the other way. Until its
  spire is crowned a treadwheel crane works from the top of the stage last
  raised, slewing a white block out over its edge and back: at its
  foundations the drum's first courses are laid round, open at its door and
  each shorter than the one below, with a banker where a block is dressed
  and a coil of rope by the crane; once its drum stands, an arch of
  voussoirs frames its door with a keystone and a step before it, braziers
  burn at either hand, spouts jut under its parapet, moons are carved in
  moonsalt between its buttresses until banners hang there, and from its
  third stage a balustrade runs round its gallery.
- **The great works.** A Muster Hall of the fourth level and the fifth has
  buttresses along its front, shields in the House's colours under its
  eaves, and more pells armed in its yard; a quarry of those levels a ladder
  up its cut terraces, the rubble of its face, a mason's bench with a block
  half dressed, and at its fifth shear legs on its top terrace; a sawpit of
  those levels its saw-house's front braced and half-timbered, its sawdust
  heaped by the door, and at its fifth a hoist beam out of the gable with
  its rope and hook; a beacon at its third, courses round its tower, slits
  lit up it, corbels under its lantern and the fire's wood stacked at its
  foot; and a forge at every level its chimney coursed and sooted, tongs and
  a hammer on its hearth's lip and tongs against the anvil's stump,
  horseshoes hung on a post, its barrel hooped and its charcoal heaped, then
  tools hung by the smithy door and bar iron stood by it, the bellows'
  boards and nozzle and a blade cooling on the trough, and a helm and a
  shield on the stand of mail.
- **The Masons' Lodge, the Study and the saltworks.** A Masons' Lodge's jib
  slews its stone round and back on its mast and, from the fourth level, its
  great treadwheel turns in a braced frame; near, a mallet and a chisel lie
  on its banker with the chips at its foot, a rough block is split with
  wedges at its first levels, a square, dividers and a template lie on its
  tracing floor and templates stand against its hall from the third, and at
  the fifth its arch has capitals and a keystone standing proud. A Study has
  a sundial in its court at every level, a lectern with a book open on it by
  the scriptorium's door, a lantern on the library's dome and doors where
  its library and its hall had none, courses round its tower, a chest of
  scrolls at the tower's foot and benches with books on them; and a
  saltworks a rake laid in its pans, a shovel standing in its heap and
  baskets of salt by it, a bucket on its brine sweep's rope, its furnace's
  mouth framed in stone and its chimney coursed, capped and sooted, its
  pans' crust standing proud enough that the yard's odds and ends are never
  set down in the brine.
- **The granary, the wayhouse and the Infirmary.** A granary has a bushel of
  grain heaped by it and its cat sitting watch for rats, a broom by the door
  from the second level and from the third a steelyard on its tripod, a sack
  hung from its beam against the weight; and a wayhouse saddles on a rail by
  its door, the post's bags against its wall with a spare wheel leaning by
  them, a bucket at its trough and a milestone by the road, and from the
  third its post-birds down from the cote, pecking. An Infirmary has the
  litter on which the fallen were carried home leaning by its door and a
  basket of herbs cut from its garden; from the second level bundles of
  herbs hung to dry under its eaves and a bench for those mending; from the
  third a table of the healers' jars and a bucket on the well's rim.
- **The first levels.** The works plainest at their first levels have their
  gear too: a sawpit's pit-saw standing through its log, its tiller above
  and wedges in the kerf, and at every level a chopping block with an axe
  bitten into it and a grindstone on its frame, and at its first two the
  bark of its logs strewn about, boards leaning by its shelter and a bow saw
  hung on its post; a quarry's rubble, a pick leaning on its rock, an iron
  bar and a coil of rope on its sledge, a block split along a line of wedges
  with the maul against it, a barrow of rubble and its chips heaped, at
  every level; a Muster Hall's spears given their iron heads, shields in the
  House's colours leaning on their rack, its pell armed with a crossbar and
  a sack of straw and wooden swords against it, and at its first two a ring
  for sparring, the drill's drum on its stand, helms on a bench and a barrel
  of water; a first Masons' Lodge's dressed stones stacked under its shed, a
  tub of mortar with its trowel, the masons' level and templates; a first
  saltworks' brine well under its sweep, a trough to its pans, a board
  between them and cakes of salt drying; and a beacon a ladder up its first
  tower and a torch by its second's door, the fire's wood stacked at the
  foot of both, and at the first its brushwood bound in faggots, a rope to a
  basket of them, jars of oil and a horn to cry the alarm, at the second its
  faggots against the tower's foot, a barrel of water by its door and
  leather buckets hung beside it.
- **The holy sites.** The holy sites have their floors flagged and worn,
  here a flag lifted long ago and grass come up where it lay, their poles
  set in sockets of stone and grass at their stones' feet; the Moonwell a
  coping with lamps burning on it, an arch over it crowned with the
  crescent, a silver bowl hung from it on a chain and stones to kneel on
  before it; the Still Stone its ring tied with pilgrims' ribbons that stir
  in the wind about the stone that never does, a kerb about it and cairns of
  flat stones its pilgrims left; the Salt Altar a step under it and a slab
  over it, a crescent cut in its face, bowls of salt and a salt-knife on it,
  candles either side, sacks of moonsalt brought to it and moonsalt grown up
  behind it; the Broken Spire carved bands about its shaft and moonsalt in
  its seams, its head fallen out between two stones of the ring with its
  crown of moonsalt in the grass; and the Heartstone braziers burning at its
  quarters, swords offered point down about its plinth, shields of fallen
  Houses laid against it and runes glowing in it.
- **The lairs of the wilds.** The lairs of the wilds have theirs: the
  Saltwights' hollow a great beast's bones where it slid in head first, the
  pale husks the wights crawl out of, moonsalt grown on its floor, skulls by
  its cold heart and the arms of those who came for them crusted white; the
  Reavers' stockade a beast on a spit over its fire, bedrolls about it, a
  rack of spears, the holds' plunder heaped between the tents, a war drum, a
  chopping block and its axe, skulls on the stakes by the gate and the
  gate's posts and lintel under a horned skull; the Barrowkin's hall urns, a
  shield and a sword at its door, a skull in its passage, a rune glowing on
  its lintel, a dead tree on its mound with a raven in it and another on the
  lintel, headstones and a cairn; the Spine Hunters' eyrie its deck's planks
  and rails, a stag's antlers on its windbreak, a bow, a quiver, furs, a
  horn, a basket on a rope over the edge and a hide stretched on its frame;
  and the drowned chapel its pews drowned in rows, its altar sunk at their
  head, its bell fallen in the shallows, a font, steps going down into the
  water, lilies and its yard's graves.
- **The Crown's gates and the alliances' standards.** A gate of the Crown
  has slits in its towers, fires in their tops, a ladder up one and the
  hunters' hide banner and antlers over the other, a horned skull over its
  gate and wood by the fire; an alliance's standard guy ropes, its banner
  bound to its crossbar, shields in the alliance's colour against its cairn
  and spears crossed behind it.
- **The land's sites.** The land's sites where companies gather: the grain
  field a scarecrow between its rows, a handcart of sheaves with a jug by
  it, a scythe against a stook and crows come for the grain; the stand of
  firs the stubs of the branches lopped from its felled trunk and their
  greenery heaped, chips about its stumps, a sawhorse with a log in it and a
  saw in its cut over the sawdust, and a maul by the pile; the outcrop the
  chisel's marks down its cut faces, wedges along a split with the hammer
  that drove them, a pick, rubble, a bucket, and a rope and a bar on its
  sledge; and the moonsalt pans baskets of salt, a wheelbarrow, a shovel
  standing in a heap, sacks and a pusher laid across a pan.
- **An alliance's hall.** An alliance's hall has a crenellated parapet round
  its platform, open where its steps come up between the braziers; iron
  bands and a ring on its great door and lanterns under its porch; a rack of
  spears in its court with shields in the alliance's colour against its
  foot, the alliance's barrels, crates and a sack stacked across from it,
  and a well behind; and a door, slits and a string course on its tower .

### Drawing the world

- **Only what the view reaches is drawn.** The land's furniture is kept
  on the GPU in square regions eight hexes on a side, each with the bounds
  of all it holds; each frame finds the regions inside the camera's view
  and draws just their runs of each kind. Near, over the realm proper's
  lake, a frame draws 7,600 of its 19,300 pieces; over a lake of
  forty-eight seats, 10,500 of 76,000, so a wider realm costs a near view
  little more than the realm proper's: on CI's Mac, 12.4 ms of the GPU
  where drawing all of it took 23.1 ms. The holds, their towns and the
  companies out of view are not staged for the frame at all. Zoomed out
  over the whole lake, all of it is drawn, as before.
- **Portraits from the world itself.** The panels show each commander,
  each company to be trained (in the tier chosen) and each work to be
  built (at the stage it will be), drawn by the world's own renderer on a
  small stage of open ground under the moon, in the House's colours,
  framed by the model's size and kept once drawn. The stage's shaders are
  compiled away from the main thread the first time a portrait is asked
  for; until then the panels show the frame alone. Each of the keeper's
  holds has its vista at the head of its panel: the whole hold drawn by
  the same renderer from before its gate, its keep in its people's way,
  its walls and works as they stand, in its House's colour, drawn again
  as it grows. Every portrait and vista is painted as it is drawn
  ([`Painting`](../Sources/NullmereWorld/Painting.swift)): its colours laid
  on in strokes that keep to the forms, each spot taking the calmest of
  the four patches about it (a pixel's reach for a portrait, two for a
  vista, so windows and carts still show), dark ink along its edges, and
  the weave of a canvas under it, its corners in shadow.
- **Every surface has its grain.** Each colour a model is built of is
  stone, timber, thatch, slate or earth, or smooth, and the shader draws
  that grain on it in the model's own coordinates, so it keeps to the
  model as it moves: stone laid in courses, each block its own shade and
  mortar between; timber in planks with a grain down each; thatch in fine
  straws; slates in rows; earth in clods. Grain finer than a pixel fades
  to its mean, so nothing shimmers as the view draws back; the ground has
  its own grain of earth and moss.
- **The weather is the omen's.** While a Lean Watch lies on the realm,
  cold rain falls about the middle of the view and the moon is dimmed;
  under Rising Mist, banks of mist drift low over the land and the haze
  lies thick; a Still Night is clearer than most, and a Moonsalt Bloom
  brightens the moon. Where motion is still, the weather is drawn but not
  moved.
- **It moves.** Companies breathe at rest, march along their routes with
  their feet going, strike, turn to face their foe and fall; works rise
  under scaffolds as the watches pass; bows loose arrows that arc to their
  mark; banners and trees stir in the wind, torches flicker, hearths smoke
  and birds wheel over the water. Every hold in sight has its townsfolk,
  one for each work standing whole, up to six, in linen and wool with a
  band of their House's colour: a farmhand with a pitchfork goes out to the
  granary, carters haul logs from the sawpit and stone from the quarry, a
  salter carries a basket from the saltworks and porters go about the
  rest, out from the keep's door along the town's lanes (through the gate
  and round the walls, where the hold is walled), a while at their work and
  back, at a walk their feet hold the ground at. As the view comes down
  close the rest of a town's folk are out too, one for every three of its
  homes, up to ten, a seat's sixteen: householders in madder red,
  water-carriers with a pail from the well, elders on their sticks and
  children in weld yellow, out from the market by the keep's door through
  the gate and back, or to the feet of the works, round the ring lane
  outside the walls, each keeping to one side of the lane so those going
  out pass those coming back. They keep within a hold
  whose ward is broken, and stay in where motion is reduced. A cart goes on the way between each hold and
  the nearest other of its House within seven hexes, where unbroken land
  runs between, from beyond one's walls to beyond the other's and back,
  logs one way and stone the next.
- **Every hold is a town.** Lanes of trodden earth and set stones run out
  from the keep's door, one through the gate to the hold's edge and one to
  each work standing or rising, and a ring lane goes round outside the
  walls. Between them stand the homes of the hold's folk, their windows
  lit and their doors in their House's colour: whitewashed cottages under
  thatch, longhouses with their woodpiles, roundhouses, and tall townhouses
  of stone and timber under slate, all of them their people's way. A few
  stand about a bare keep and three more for every level its works rise,
  up to forty-four, and sixty-four about a seat, in the ward first and then
  out beyond the works, each facing its lane; a home once standing stays.
  Every hold has its well, a seat its market of stalls under awnings in
  its colour, and a granary its strip fields of grain at the hold's edge,
  one for each level to three. Nothing of the town stands on a lane, on
  the walls' ground, where a work stands or could, or on the hearts of the
  hexes about the hold, where companies stand.
- **The camera** pans, zooms, turns and leans, looking down on the whole
  lake from afar and leaning toward the horizon close in among the models.
  The map's marks (names, bars, ranks, the damage dealt) stand over the
  models; a Mac that cannot draw the world gets a still painting of it with
  flat marks instead.
- **The city view.** C, or Watch ▸ View the Seat Close, takes the view low
  over the keeper's seat, leaning in among its works and townsfolk: each
  work is named over its roof at its level (a work being raised says so),
  and a click on its name opens the hold's panel on its row, to raise it
  further. Back to the lake, or C again, returns the view to where it
  stood over the lake. It is never over another House's hold.
  A work chosen there may be set in a place of the keeper's own: each of
  the eighteen places round the keep whose ground is the hold's shows as a
  ring, filled where another work stands, and a click sets the work there,
  the other taking its old place. The rest stand where their ground suits
  them, as every work of a steward's hold always does; a place is kept
  with the hold, and the walls ring the keep where they always have.

## Direction

- **Client:** native Swift on macOS, using SwiftUI and AppKit for the
  interface, and Metal for the lake and the world.
- **Server:** [SpacetimeDB](https://spacetimedb.com) as the authoritative
  multiplayer backend, as it was for Warpkeep.
- **Characters:** non-player characters voiced by Apple's on-device model,
  through the Foundation Models framework. They never decide outcomes or
  grant stores.
- **Character:** open source and pseudonymous, executed with restraint.

[What carries over from Warpkeep](warpkeep-carryover.md), a plan
written before the build, covers the universe, principles and asset
licensing, and says where the build went another way.
