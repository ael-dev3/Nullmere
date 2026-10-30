# Nullmere Online against Rise of Kingdoms: the gap list

The bar, set by ael on October 30: Nullmere Online is to be a complete game
on the level of Rise of Kingdoms or better, native to the Mac. Everything
below is scored against Rise of Kingdoms, honestly: anything 2D, a
placeholder, stubbed or simulated scores under ten. The rules hold
throughout: one shared realm and nothing played alone, the launcher titled
exactly Nullmere Online, and every asset original. This list is kept
current as the work goes; each line says what is there now, not what is
planned.

## Where it stands

| | Requirement | Score now | What is there | What Rise of Kingdoms has that this lacks |
|---|---|---|---|---|
| 1 | Live realm, real multiplayer | 3 | A SpacetimeDB module and a steward that runs the rules; keepers' Macs connect over HTTP, read the realm about once a second, and send orders; CI raises a real SpacetimeDB server and plays keepers through it | A realm that is up for everyone (it waits on the maintainer's maincloud sign-in); pushed updates over a live connection rather than reads once a second; play in real time rather than in ten-minute watches; chat |
| 2 | 3D world in Metal | 0 | A 2D map: one fragment shader paints hex terrain and the still lake from a tile texture; holds and companies are flat vector line art | Everything: a 3D terrain with relief, a 3D lake, a camera that tilts and turns, and a 3D model for every company, work, hold and feature of the land |
| 3 | Animation | 1 | The lake's light and mist move; pieces glide between tiles | Companies that idle, march, strike and fall; works that rise from scaffolds and grow with each level; combat effects; life in the world (smoke, banners, torches, birds) |
| 4 | Sound and music | 4 | A synthesised night (drone, wind), a score written as it plays, and sounds for orders, battles, bells and envoys | A sound for every action and every event, and music that follows peace, war and the hour |
| 5 | Depth of systems | 2 | Holds with eight works, five kinds of company, four stores, wars, pacts, peace, fealty, tribute, trade, gifts, omens, a chronicle, and two roads to winning an age | Research and a tech tree; troop tiers; commanders with skills and levels; gathering from the land; alliances of many Houses; rallies; marches that take time across the map; events; a keeper's progress across ages |
| 6 | Interface and onboarding | 4 | A spare, consistent, accessible interface; a seat briefing, first steps, counsel and a guide | A screen for every system above, and an onboarding that walks a new keeper through the first hour |

Overall against Rise of Kingdoms: **2 of 10**.

## What closes each gap

Each item is done when it is real, in the shipped app, tested, and shown in
CI (a test, a figure, or a screenshot). Ticked items are done.

### 1. Live realm, real multiplayer
- [ ] Several keepers' clients, as shipped, play together in CI against a real SpacetimeDB server: they arrive, see each other, trade, ally, march on each other and fight
- [ ] A live connection: the realm's updates pushed to the client over SpacetimeDB's WebSocket subscription, the reads once a second kept only as a fallback
- [ ] Marches and battles that play out across the watch in the client, not in a single jump at its turn
- [ ] Words between keepers: a realm channel and an alliance channel
- [ ] One workflow that raises the realm on maincloud from CI once the maintainer adds the token (the sign-in itself is the maintainer's)

### 2. 3D world in Metal
- [ ] A model library of original procedural meshes, built and tested on Linux, previewed as images
- [ ] Terrain as a 3D mesh with relief: still water, shallows, strand, salt flats, greyfields, blackwood, barrows and the spine, each with its own form
- [ ] The lake as a 3D surface that mirrors the moon and the stars, black and still
- [ ] A camera that pans, zooms, tilts and turns, with the map's picking and VoiceOver's elements through it
- [ ] A model for every company kind and tier, every work at every level, every hold, and every feature of the land
- [ ] Moonlight, torchlight and mist; the render held to its frame budget in CI

### 3. Animation
- [ ] Companies: idle, march, attack and death
- [ ] Works: construction from scaffold to finish, and each upgrade
- [ ] Combat: arrows, clashes, the fallen
- [ ] Ambience: smoke, banners, torches, birds and the drift of mist

### 4. Sound and music
- [ ] A sound for every order and every event, checked by a test that none is silent
- [ ] Music that follows peace and war

### 5. Depth of systems
- [ ] Research: a tree of studies with prerequisites, costs and time, each changing the rules it names
- [ ] Troop tiers, unlocked by research and the Muster Hall
- [ ] Commanders: heroes with skills, experience and levels, who lead marches
- [ ] Gathering: stores in the land, worked by companies sent to them
- [ ] Alliances of many Houses, with their own counsel and help
- [ ] Rallies: several Houses' companies joined against one target
- [ ] Marches across the map that take time to arrive
- [ ] Events: realm-wide happenings with their own goals and rewards
- [ ] Progress: a keeper's renown and rewards that carry across ages

### 6. Interface and onboarding
- [ ] A screen for every system above, keyboard and VoiceOver included
- [ ] An onboarding that teaches the first hour in play

## The order of the work

1. The 3D world: the model library, then the Metal renderer for terrain, lake and models, then the camera, picking and VoiceOver through it.
2. The depth of systems, rules first (tested on Linux), then the realm and the interface for each.
3. Animation, on the models as they land.
4. The live connection and the multiplayer test.
5. Sound for every action, and music by the state of the realm.
6. The onboarding over all of it.

What only a person can do stays as it was: raising the realm on maincloud
with the maintainer's account, signing and notarizing the release, and
playing it by ear with VoiceOver on a real Mac.
