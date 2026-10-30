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
| 1 | Live realm, real multiplayer | 5 | A SpacetimeDB module and a steward that runs the rules; keepers' Macs hear the realm's changes pushed over SpacetimeDB's WebSocket subscription, the reads kept as a fallback. CI raises a real SpacetimeDB server where two keepers' clients meet, give orders and turn the watch, trade through an envoy, ally, speak to the realm and to their alliance, go to war, and march one on the other's seat over thirty watches and strike it, both seeing every step. A realm's watch passes in twelve paces: marches step through it, hosts strike the moment they arrive, and stewards give their orders at paces spread through it, nothing saved for a burst at the turn; a battle goes on, blow after blow, through the paces | A realm that is up for everyone (it waits on the maintainer's maincloud sign-in); battles of whole armies, troops by the thousand; kingdoms of thousands |
| 2 | 3D world in Metal | 5 | Terrain as a 3D mesh with relief and its own grain of earth and moss; stone, timber, thatch, slate and earth drawn with their grain on every model; each omen's weather, rain or mist, over the world; the still lake mirroring the stars and the moon; a camera that pans, zooms, tilts and turns; picking and VoiceOver through it; original models built from code for every company in five tiers, every hold, work and wall at every level, the wilds, the sites of the land and the commanders; four lights of the world's own with the moon's; rendered on the GPU in CI | Hand-modelled detail at RoK's density; a city view inside the world |
| 3 | Animation | 6 | Companies idle, march, strike, gather and fall, easing from one clip to the next; works rise from scaffolds and finish in dust; blows land with sparks, a flash and light on the ground, the struck reel, arrows arc and kick up dust, wards splinter, the fallen raise dust; a commander's skill fires in a ring of gold; broken holds burn and smoke; fireflies, birds, banners and hearth smoke | Spell-like effects at RoK's scale; crowds and city life |
| 4 | Sound and music | 6 | A synthesised night, a score written as it plays that turns to war, and twenty-five cues made as they play, a sound for every order and every event that concerns the keeper, each held by tests above the night and all at once under clipping; every sound heard from where it happened, left or right of the view and fainter far off | Recorded orchestral music and foley |
| 5 | Depth of systems | 5 | Studies (28 in four branches, an Archive's circles), troop tiers I to V, commanders (five archetypes, twenty skills, thirty levels, fury, three talent trees, gear in three slots), the wilds at levels I to X, gathering at the land's sites, alliances with help and their own words, rallies, marches that take watches and say when they arrive, happenings with marks and honours, deeds, charges, might and renown across ages; holy sites held for their gifts; an Infirmary whose beds keep the fallen to be healed; every rule tested on Linux and played by the stewards | VIP, items, crafted equipment and sets, civilizations, kingdom against kingdom, alliance territory and buildings, barbarian forts, scouting |
| 6 | Interface and onboarding | 5 | A screen for every system: the Archive (3), Commanders (4), Alliance (5), the Realm (6) and Words (7), on keys, in the menu and on a row of buttons; a small map of the whole lake; battle reports in the Chronicle; tiers chosen in training; a site gathered by a right-click; a rally called from an enemy hold; the wilds and the sites named on hover and read to VoiceOver; portraits of every commander, company and work drawn from the world's own models; every screen through the Mac's accessibility audit in CI. The first hour taught in play: a briefing, three first steps, then ten charges one after another, each saying how, with Show me ringing the very control that keeps it, and a reward, each read aloud by the advisor as it comes; a Guide for every system | RoK's painted, illustrated interface |

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
- [x] Battles that last: in the realm, two companies locked in battle exchange blows again at the paces after the first, until one falls or draws off
- [ ] Battles of whole armies at RoK's scale, troops by the thousand
- [ ] The realm up for everyone on maincloud

### 2. 3D world in Metal
- [x] A model library of original procedural meshes, built and tested on Linux, previewed as images
- [x] Terrain as a 3D mesh with relief: still water, shallows, strand, salt flats, greyfields, blackwood, barrows and the spine, each with its own form
- [x] The lake as a 3D surface that mirrors the moon and the stars, black and still
- [x] A camera that pans, zooms, tilts and turns, with the map's picking and VoiceOver's elements through it
- [x] A model for every company kind and tier, every work at every level, every hold, and every feature of the land
- [x] Moonlight, firelight and the world's own lights; the render's frame times measured in CI
- [x] Textured detail: every model's stone, timber, thatch, slate and earth drawn with its grain in the shader, fading to its mean with distance; the ground's own grain
- [x] Weather: each omen's own over the world, rain and dimmed moon, banks of mist and thick haze, a clearer still night
- [ ] Hand-modelled detail at RoK's density

### 3. Animation
- [x] Companies: idle, march, attack, gather and death, eased from clip to clip
- [x] Works: construction from scaffold to finish, and each upgrade
- [x] Combat: arrows, clashes, sparks, the flash and its light, splinters, the fallen
- [x] Ambience: smoke, embers, fireflies, banners, torches, birds and the drift of mist
- [x] Skill effects for commanders' fury

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
- [x] Talent trees for commanders: three trees of five, a point a level, learned a rank at a time, forgotten for moonsalt
- [x] Equipment: gear left by the wilds in four qualities, worn in three slots, kept in an armoury, broken up for moonsalt
- [x] Holy sites: shrines held by standing on them, each giving its gift to the holder's whole alliance, contested by foes beside them
- [x] Hospitals and healing: an Infirmary at every hold whose beds keep the House's fallen companies of war, healed for half their muster's cost and rising whole as the watch turns, lost with a hold taken
- [ ] Alliance territory and buildings, and the rest of RoK's breadth

### 6. Interface and onboarding
- [x] A screen for every system above, keyboard and VoiceOver included
- [x] An onboarding that teaches the first hour in play
- [x] A voiced advisor: each new charge read aloud as it comes, silent under VoiceOver, with its own setting
- [x] Portraits in the panels: every commander, company and work drawn by the world's own renderer, in its House's colours
- [ ] Painted illustration for the interface at RoK's richness

## The order of the work

1. The 3D world: the model library, then the Metal renderer for terrain, lake and models, then the camera, picking and VoiceOver through it.
2. The depth of systems, rules first (tested on Linux), then the realm and the interface for each.
3. Animation, on the models as they land.
4. The live connection and the multiplayer test.
5. Sound for every action, and music by the state of the realm.
6. The onboarding over all of it.
7. Next: alliance territory and buildings; barbarian forts for rallies; scouting reports.

What only a person can do stays as it was: raising the realm on maincloud
with the maintainer's account, signing and notarizing the release, and
playing it by ear with VoiceOver on a real Mac.
