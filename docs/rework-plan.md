# Nullmere Online: audit and rework plan

Written on 14 November 2026, at `c5f4fa3`, on ael's direction: audit the
whole game honestly against the bar, then rebuild it slice by slice,
rewriting or replacing what is weak rather than patching it. Everything in
the repository is open to rebuilding.

**The bar.** Rise of Kingdoms level or better. Live SpacetimeDB with real
multiplayer. Original 3D models, animation, sound and music. Every Warpkeep
and Rise of Kingdoms system, plus new mechanics. A minimal, contextual
interface that respects screen space. A launcher titled exactly "Nullmere
Online". No single-player settings. Real on-device Apple language-model
interactions. A working companion iOS app.

**The short answer.** Nullmere today is not close to that bar. It is a wide,
carefully tested, turn-based 4X lobby with a dark, hard-to-read world, a
text interface, and a server design that keeps the game off SpacetimeDB's
own strengths. Its test discipline, its on-device-model safety design and
its honest status reporting are worth keeping. Most of the rest is rebuilt
below.

No part of this document scores the game. Each finding says what is there,
what evidence exists, and what has never been seen on real hardware.

## How the audit was done

- Five read-only reviews of the source, one each for the realm and
  networking, the rules, rendering and art, the Mac interface and launcher,
  and the on-device model with the phone app. They read code and documents;
  none built or ran anything. Brightness and screen-coverage figures are
  arithmetic from constants, not measurements.
- The screenshots CI took of the real app on its virtual Macs in run 966
  (`017c200`, every job green): the launcher, the default world view, the
  "bright" setting, the lake, a city close up, a battle, the far view, the
  rankings and first-steps cards, and two phone screens.
- What was not possible here: running the Mac or phone apps, hearing the
  sound, asking Apple's model anything, or reaching a live realm. Those
  stay **unverified** wherever they appear below.

## Audit

### 1. The clock: turn-based, not a persistent world

- The world advances in turns of 180 seconds ("watches"), each cut into 12
  steps of 15 seconds. A turn ends on the timer or when every player online
  presses Ready.
- The world freezes when nobody is online. After about six minutes away an
  AI plays your House for you.
- A game ("age") ends after a median of 168 turns, about eight hours, and
  the map is wiped. One player wins; only a "renown" number carries over.
- Each city has one build slot and one training slot. A session is a few
  clicks, then waiting for the turn.

Rise of Kingdoms is the opposite: one world that runs for months, timers of
minutes to days, armies that move in real time, and progress that is
yours to keep. Warpkeep, which Nullmere grew from, already had real-time
journeys and build timers; Nullmere dropped them. This is the largest
structural gap, and every system built on the turn inherits it.

### 2. The realm: not live, and not really on SpacetimeDB

- **No live realm exists.** Nothing is published to maincloud. The only
  multiplayer ever shown is CI's: up to 192 clients in one process on
  loopback.
- The Rust module has no game rules. It is a request queue, a store for
  JSON blobs and an identity filter. Every rule runs in one Swift process
  (the "steward") that someone must host and keep running beside the
  database. Going live therefore needs an always-on host as well as the
  maintainer's maincloud account, which is why it has not happened.
- Each order is an HTTP call that waits for the steward to read the whole
  request table, run the rules, recompute every online player's view and
  write it back as JSON pages. A player's view is 2.3 MB at 1,024 seats.
  Cost grows faster than player count: about 78 ms a turn at 96 seats and
  about 1 s at 768. A thousand players has never been played.
- Abuse is cheap: identities are free and anonymous, the newcomer limit is
  global (one script can take every seat), and the request table is
  unbounded.
- The live smoke workflow passes green when the realm is down.

What is sound: private tables, per-player visibility that is tested, and
clients that cannot call privileged reducers.

### 3. The rules: wide and shallow

- One struct holds the whole game: 108 stored fields, 96 of them optional,
  extended by 115 files and about a thousand functions. Fog of war is a
  copy of everything with fields blanked one by one, so a new field leaks
  by default.
- About 45 systems exist. Map generation, fog, pathfinding, diplomacy and
  the AI are deep. Most of the rest are miniatures of 75 to 250 lines:
  the economy (four resources, 13 buildings of five levels), research (28
  studies), the hospital (whole companies, not troop counts), and the
  Rise of Kingdoms features that the gap list ticks as done (VIP, items,
  shop, daily quests, events, expeditions, arena, kingdom-versus-kingdom).
- Combat is hex tactics between tokens with 0 to 100 health. "Troops" are a
  derived label; a "400,000-troop battle" is about sixteen tokens. There
  are no troop stacks, no real casualties, no wounded ratios.
- Known imbalance, from the project's own self-play: one victory route
  decides 93 of 96 games.
- About sixty coined nouns (watch, pace, keeper, hold, seat, steward,
  muster, ward, standard, happening, labour, charge, favour, veil) run
  through the interface, errors, code and documents. `docs/GAPS.md` is hard
  to read because of it, and it records most Rise of Kingdoms systems as
  met when they are met only in miniature.

Missing against Rise of Kingdoms: long real-time queues and speedups, a
main-building prerequisite chain to level 25, persistent account power,
troop-count training and hospitals, dozens of distinct commanders with
skills, several marches at once, alliances of a hundred or more with ranks,
overlapping events, progress while away. Missing against Warpkeep: the
permanent keep, time passing while away, rules inside the database module,
migrations.

### 4. The world on screen: dark, flat and small

From the screenshots and the shader constants:

- **It is permanent night, and too dark to read.** The default view is a
  murk in which the land, the lake and the unexplored ground are hard to
  tell apart. Moonlit grass works out at about 13 per cent brightness, 20
  to 23 per cent on the "bright" setting. The lake screenshot is almost
  entirely black. There is no sun, no time of day, no sky beyond stars.
- **No textures anywhere.** Models and terrain are flat vertex colour with
  procedural noise. There are no UVs, no normal maps, no material beyond a
  base colour.
- **Models are scripted boxes, cones and lofted rings.** Houses and trees
  have a budget of 300 triangles. A face is a cone and two boxes. Close up
  (the city and battle shots) it reads as a tidy low-poly prototype, well
  short of Rise of Kingdoms' painted, detailed look.
- **Everything is tiny at the opening zoom.** A soldier is about 18 points
  tall, a cottage about 10. Shadows and the detailed models are switched
  off at that zoom.
- **No post-processing.** One forward pass into an 8-bit target: no HDR,
  bloom, ambient occlusion, colour grading or atmosphere. Distance fades to
  black. The lake is one black quad.
- **Animation is stiff.** Six clips typed by hand as rotation tables, two
  bone influences, one 0.25-second cross-fade, no layering.
- The Linux preview used to check looks without a Mac renders with
  hand-copied shaders that have drifted from the real ones, so it cannot be
  trusted for colour.

What is sound: a working Metal renderer with instancing, skinning, a shadow
map, chunked terrain and a camera; a scripted model pipeline that
regenerates every asset; frame-time budgets held in CI.

### 5. The interface: a text interface over the map

- All eight side panels are text lists; one stacks about 23 sections. The
  game interface has 391 text views, 200 text buttons and three symbols.
  A selected army offers 16 verbs as capitalised words wrapping in a card.
- The inspector is a document docked in a corner, never beside the thing
  selected. A city's inspector also carries trading, letters and several
  unrelated features.
- Chrome is small on the default screen (about 5 to 7 per cent), but an
  open panel takes 35 to 45 per cent, two inspectors have no height limit,
  and the budget test checks only four tidy states.
- The type scale is fiction: size floors make almost every label draw at
  the same size, so hierarchy rests on 16 opacity values. Hints read like
  developer notes ("? Guide · 1–7 panels · Tab next company · ⌘↩ ready").
- Single-player furniture remains although no single-player setting does:
  the Ready button, the advisor, "Stay Ready Until Needed", first steps,
  charges. Entering the game takes up to four screens.

What is right: the launcher window, bundle and wordmark say exactly
"Nullmere Online"; there is no difficulty, seed, rivals or offline option
and a test guards that; one panel at a time; Hide the Interface.

### 6. On-device model: well designed, never observed

- The design is the strongest part of the game. Commanders and the people
  a player parleys with speak through Apple's Foundation Models framework
  on the device, from the player's own fogged view of the world. Anything
  they propose becomes an order line checked by the rules; nothing runs
  until the player confirms; the server judges again. There is no cloud
  fallback and no canned text in the model's place.
- **No real inference has ever been recorded.** CI's virtual Macs cannot
  run the model, and CI accepts that as a pass. Every test uses a stand-in.
  The model has never been seen to call a tool. All of it is unverified.
- Gaps in the design: tool arguments are free strings rather than
  constrained choices; "never invent a number" is enforced only by the
  prompt at run time; the token budget is a guess that omits tool schemas
  and never trims; one-shot voices on the Mac have no timeout; a model that
  finishes downloading after launch stays silent; memory is not shared
  between Mac and phone.
- Parley is cosmetic: an envoy "can't change your House's terms", so the
  conversation ends in the same accept or refuse the buttons offer.
- The README says characters "speak through Apple's on-device model" as
  fact. That overstates what has been shown.

### 7. Companion iOS app: works in a simulator, not on a phone

- CI builds it, launches it in a simulator against a local SpacetimeDB,
  links it to a Mac player, sends orders both ways and survives a cut
  connection. That much is shown.
- It has never run on a real iPhone. There is no Xcode project, no
  signing, no TestFlight path, no push notifications and no background
  refresh; it polls every two seconds and goes deaf when closed.
- It is a long form: one 3,201-line view with 198 text rows and 80 buttons,
  and a single visual, a flat hex chart. CI drives it through a debug
  harness; nothing taps the interface.

### 8. Sound and music: unheard

- The score is generated as it plays: slow chords under a wandering harp
  line, with a war variant. Its instruments and most of its 31 cues are
  third-party recordings (the VSCO-2-CE orchestra, CC0), stored at 24 kHz.
  Legally clean, but not original sound, and the music has no written
  themes a player would remember.
- Nobody working on this repository has heard it. All of it is unverified
  by ear.

### 9. What to keep

- The habit of testing everything, on Linux and on CI's Macs, with budgets
  for frame time and chrome that are never loosened.
- The on-device-model safety pipeline: grounded view, validated proposals,
  confirmation, no fallback.
- The Metal renderer's bones, the model pipeline, the hand-written
  SpacetimeDB client, the pairing scheme for the phone.
- The identity: a black, perfectly still lake, the Houses around it, the
  Moonspire.
- Honest status: nothing is called done without evidence.

## Decisions

These are settled so that work does not stall on them.

1. **One persistent world on server time.** No turns, no Ready button, no
   wipes. Every action is a timer that ends at a server time. The world
   runs with nobody online. Seasons last weeks and score alliances; cities,
   commanders and research persist across them.
2. **The rules live in the SpacetimeDB module.** A new Rust module holds
   normalised tables (player, city, building, troops, march, map chunk,
   alliance and so on), reducers that validate and apply orders, and
   scheduled reducers for timers. Clients subscribe to rows. There is no
   steward process. Going live becomes one module publish. Game numbers
   (costs, durations, unit stats) are rows in the module, so clients never
   carry a second copy of the rules.
3. **No AI players.** The world is filled by players, wild creatures, their
   lairs, resource sites and guarded neutral places. The 2,270-line AI and
   the caretaker go.
4. **Armies are troop counts.** Stacks by kind and tier, real casualties,
   wounded and dead, hospital capacity in troops, several marches at once,
   rallies and reinforcement.
5. **Daylight by default.** A sun, a sky and a day cycle on realm time, in
   high dynamic range. Night becomes bright moonlight, not darkness. The
   lake stays the one black, still thing in a bright world.
6. **Textures and rebuilt models.** Generated tiling textures first (no UVs
   needed), then models rebuilt with real detail, UVs and baked occlusion.
   Everything stays original and reproducible from scripts.
7. **A contextual interface.** Actions appear on the thing selected, as
   icons. Four destinations replace eight list panels. Three type sizes,
   three emphasis levels, one surface style.
8. **Plain words.** City, army, march, turn into minutes and hours. The
   fiction keeps its proper names (House, Nullmere, Moonspire, moonsalt)
   and drops the rest of the coined vocabulary from interface, code and
   documents.
9. **Build beside, then switch, then delete.** The new module and client
   grow in new directories with their own tests while the current game
   keeps passing CI. When the new core loop is playable the apps switch to
   it and the turn-based rules, the steward and their tests are deleted in
   the same change. Systems return in the new design, in the order below,
   not as ports.
10. **Evidence rules stay.** No test is deleted to get green except with
    the code it tested; no budget is loosened; anything needing a real Mac,
    a real iPhone, a live server or ears is marked unverified until someone
    has that evidence.

## The plan

Each slice is one or a few small commits to `main`, tested before pushing.
"Shown by" is the evidence that closes it.

### Phase 1. The world in daylight

Work on the existing renderer, which the new game keeps.

| # | Slice | Shown by |
|---|---|---|
| 1.1 | One lighting source shared by Metal and the Linux preview, so the preview can be trusted | A test that fails when the two differ; preview sheets |
| 1.2 | Sun, sky and day cycle on realm time; HDR target and filmic tone curve; daylight the default | CI's Mac screenshots; brightness tests on rendered frames |
| 1.3 | Terrain palette re-authored for daylight; terrain shadows; a quiet hex grid | Same |
| 1.4 | Open closer; shadows and detailed models at every zoom; per-instance level of detail | Screenshots; frame-time budget unchanged |
| 1.5 | Generated tiling textures for terrain and surfaces (colour and normal) | Screenshots close up |
| 1.6 | Water: depth tint, sky reflection, shoreline; the lake as black glass | Screenshots |
| 1.7 | Bloom, ambient occlusion, height fog, grading | Screenshots; frame-time budget unchanged |

### Phase 2. The realm in the database

A new module beside the old one.

| # | Slice | Shown by |
|---|---|---|
| 2.1 | Module layout: pure rules crate with unit tests, table and reducer crate; CI builds, tests and publishes it to a local SpacetimeDB | `cargo test`; CI job |
| 2.2 | Players and presence from connection events; names; per-identity and global rate limits inside reducers | Tests against a local server |
| 2.3 | The map as chunk rows: one continent around the lake, regions, passes, sites | Tests; rendered chart |
| 2.4 | Cities: placed on arrival; buildings to level 25 behind the Keep's level; build timers on scheduled reducers; two builders | Tests with a controllable clock |
| 2.5 | Resources: accrual by elapsed time with caps; stores | Tests |
| 2.6 | Troops as counts by kind and tier; training queues; power | Tests |
| 2.7 | Marches in real time: paths, speed, scheduled arrival, gathering, return; several at once | Tests; two clients see one march |
| 2.8 | Creatures and lairs; action points | Tests |
| 2.9 | Battle by troop counts: rounds, wounded and dead, hospital; reports as mail | Tests with fixed seeds |
| 2.10 | Cities under attack: scouting, garrison, reinforcement, shields, relocation | Tests |
| 2.11 | Research: two trees on timers | Tests |
| 2.12 | Commanders: distinct people with skills, levels, talents, pairing | Tests |
| 2.13 | Alliances: a hundred or more members, ranks, help, chat, territory, technology, rallies | Tests with many clients |
| 2.14 | Items and speedups, daily quests, overlapping events, favour (the VIP track) | Tests |
| 2.15 | The realm's contest: the Moonspire, passes and zones, seasons | Tests |
| 2.16 | Nullmere's own: parley, envoys, prisoners, petitions and the rest, redesigned on rows | Tests |

### Phase 3. Clients on rows

| # | Slice | Shown by |
|---|---|---|
| 3.1 | A Swift client for row subscriptions and reducer calls, with a typed row cache | Linux tests against a local server |
| 3.2 | The world scene drawn from rows: terrain, cities, marches moving between ticks | Preview sheets; CI screenshots |
| 3.3 | The city view: click a building to build or upgrade; timers | CI interface tests |
| 3.4 | The Mac app switches to the new realm; the turn-based rules, steward and their tests are deleted | CI green on the new stack alone |
| 3.5 | The phone app on the same client | CI simulator run |

### Phase 4. Interface

| # | Slice | Shown by |
|---|---|---|
| 4.1 | Design tokens: three sizes, three emphasis levels, one surface; shared components | Snapshot tests |
| 4.2 | An icon action ring on the selection and a small callout anchored to it | Interface tests; screenshots |
| 4.3 | Four destinations (House, Alliance, Realm, Mail) and a command palette | Chrome budget test over every state |
| 4.4 | Play lands a returning player in the world; identity moves to an account page | Interface test |
| 4.5 | Plain words throughout | A test that fails on the retired vocabulary in player-facing text |

### Phase 5. Art and animation

| # | Slice | Shown by |
|---|---|---|
| 5.1 | Blender's Python module installed in the tooling; one command rebuilds every model | Reproducible build of `Art/models` |
| 5.2 | Hero assets rebuilt with real detail: the Keep, city buildings, the four troop kinds, commanders | Model sheets; screenshots |
| 5.3 | UVs and baked occlusion and colour atlases | Screenshots close up |
| 5.4 | Animation: four influences, per-figure phase, more clips, hit reactions | Preview clips; frame-time budget |

### Phase 6. On-device model

| # | Slice | Shown by |
|---|---|---|
| 6.1 | Counsel and parley grounded on the new rows; proposals become reducer calls | Tests with a stand-in; unverified on hardware |
| 6.2 | Constrained tool arguments, fewer tools, real token counting, capped tool results | Tests |
| 6.3 | The number checker runs on every answer at run time | Tests |
| 6.4 | Parley that changes something: terms negotiated in conversation, validated by the server | Tests |
| 6.5 | A recorded run on an eligible Mac and iPhone, transcripts committed | **Needs hardware**: unverified until then |

### Phase 7. Companion

| # | Slice | Shown by |
|---|---|---|
| 7.1 | Redesign around cards and the chart; interface tests that tap | CI simulator |
| 7.2 | An Xcode app target with signing settings for a device build | Builds unsigned in CI; **needs a developer team** to run on a phone |
| 7.3 | Push for attacks and finished timers | **Needs Apple push credentials** |

### Phase 8. Sound and music

| # | Slice | Shown by |
|---|---|---|
| 8.1 | Written themes over the generated bed: a title theme, a city theme, a war theme | Rendered audio files in CI artefacts; **unverified by ear** |
| 8.2 | Original instruments in place of the third-party recordings | Same; kept only if a listener prefers them |

### Phase 9. Live

| # | Slice | Shown by |
|---|---|---|
| 9.1 | Publishing the module is the whole deployment; the smoke test fails when the realm is down | CI |
| 9.2 | The module on maincloud | **Needs the maintainer's token** as the `SPACETIME_TOKEN` secret, then one workflow run |
| 9.3 | Latency and load measured from separate machines | Published figures |

## Order of work

1. Phase 1, slices 1.1 to 1.4: the fastest visible change, on code that
   stays.
2. Phase 2, slices 2.1 to 2.7, with 3.1 to 3.3 alongside: a real-time city,
   troops and marches, playable by two clients.
3. Slice 3.4, the switch, together with 4.1 to 4.3 so the new game arrives
   with the new interface.
4. The remaining Phase 2 systems in order, each landing with its interface.
5. Phases 5 to 8 interleaved with step 4, art first.
6. Phase 9 whenever the maintainer's token is in place; nothing else waits
   on it.

## What cannot be proven from here

| Item | Why | What it needs |
|---|---|---|
| A live realm | Publishing needs the maintainer's maincloud account | The `SPACETIME_TOKEN` secret and one run of the realm workflow |
| Apple's model speaking | CI's virtual Macs are not eligible | A run on an Apple-silicon Mac and an iPhone with Apple Intelligence on |
| The phone app on a phone | No signing identity | A developer team |
| How it sounds | No audio output in CI or here | A listener |
| Frame rate on real hardware | CI's Macs are virtual | A run of the frame-time checks on a real Mac |

## Status

Updated as slices land.

| Slice | State | Commit | Evidence |
|---|---|---|---|
| Audit and plan | Done | this commit | This document |
