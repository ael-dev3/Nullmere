# Consistency audit, October 2026: findings and what became of them

Five read-only audits went through the whole game and repository, each
on one front:

- **A:** the rules against every text that states them.
- **B:** names and terms.
- **C:** look and assets.
- **D:** sound, MMO assumptions, and tests against the code.
- **E:** docs and scripts against behaviour.

Each finding below has an ID, what was wrong, and its status: **fixed**
(with the commit), or **kept**, with the reason.

## A: rules against text

| ID | Finding | Status |
| --- | --- | --- |
| A1 | Counsel says war on a liege frees its vassals; only its fall, or its own war on them, does | fixed |
| A2 | Beacon says "+N territory" at every level; only level II adds one tile | fixed |
| A3 | "Enough goodwill wins a pact" leaves out the steward that never forgets a war or a broken pact | fixed |
| A4 | README: "Leave, and your House stands as you left it"; a caretaker plays it | fixed |
| A5 | News and release notes: "every House's orders are carried out together"; a keeper's take effect at once | fixed |
| A6 | A keeper's tribute demand is described as a steward's ("it marches on you") | fixed |
| A7 | A Muster Hall III trains every company but the Lantern a watch faster; the panel shows the slower count | fixed |
| A8 | "Orders wait and go when the realm returns", yet the client drops one after five minutes, which the steward may still carry out | fixed |
| A9 | The caretaker is said to come "after two watches" and "begin nothing"; it comes after two watches' time and trains, founds and trades | fixed |
| A10 | The front door says "every seat is held" whenever no House is open, which has other causes | fixed |
| A11 | Who demands tribute, and what paying buys, are wrongly described | fixed |
| A12 | Fealty on losing a seat is said of any rival; it applies to a steward's House without vassals | fixed |
| A13 | The refusal for an order from a keeper with no House talks of seats | fixed |
| A14 | One refusal text is reused for unrelated causes (gift vs trade, amount, room, name taken) | fixed |
| A15 | README's dominion and Moonspire shares come from an older balance | fixed |
| A16 | "A second press within three seconds" leaves out VoiceOver's ten, and the tribute refusal | fixed |
| A17 | "Every keeper is seated anew" leaves out those long gone and the seat limit | fixed |
| A18 | A boost's text says "this hold's land", but it applies to the hold's whole yield. "When every keeper is ready" should say every keeper who is there | fixed |

## B: names and terms

| ID | Finding | Status |
| --- | --- | --- |
| B1 | One word per concept: company (not unit, army), age (not game), steward (not rival), caretaker, stores (not resources), pact (not treaty), offer (not proposal), moonsalt, tile (not hex), found (not settle), strike (not attack), enemy (not foe), Moonspire stage, building levels in numerals, cunning (not shrewd, greedy) | fixed |
| B2 | The ending lines always say "the Nullmere", even in another age's lake | fixed |
| B3 | "The Still" against "still water" and "dead water" | fixed |
| B4 | "Lantern" is singular among plural company names, which breaks sentences ("Your Lantern are lost") | fixed |
| B5 | Stances dropped into sentences ("at pact with", "offers pact") | fixed |
| B6 | Build, raise and muster used loosely for the same acts | fixed |
| B7 | Whose key it is ("the realm's key" vs "this Mac's key"), and "the realm" vs "the realm's server" | fixed |
| B8 | Words with two meanings: realm (also a House's holds), steward (also the server process), keeper (also the operator), Sworn (also the vassal badge), "free House" vs seat, "granaries are empty" | fixed |
| B9 | The Guide names Full Keyboard Access where the setting is Keyboard navigation | fixed |
| B10 | "Enter World" and "Leave the World" | fixed |
| B11 | The product is called "Nullmere" and "the launcher" in places a player reads | fixed |
| B12 | The keychain item has no label | fixed |
| B13 | Keys: ⌘? (the Guide), "." and M are undocumented; the launcher's footer keys are in lower case | fixed |
| B14 | Button titles in title case among sentence case; "Close Houses" vs "Close the …"; "Reduce motion" | fixed |
| B15 | Curly quotes round envoys' words among straight apostrophes; minus sign vs hyphen; "..." vs "…" | fixed |
| B16 | British spelling: towards, licence (noun), per cent | fixed |

## C: look and assets

| ID | Finding | Status |
| --- | --- | --- |
| C1 | The map's lake is not the launcher's: a bright moon path, a greyer moon image, another glow and breath, other stars | fixed: the map's water is the launcher's still glass, no path; its moon, halo, breath and stars are the launcher's |
| C2 | The front door and model gate darken the whole window, sky and title too; the launcher darkens only the water | fixed: the door and the gate darken only the water below the waterline, with the launcher's own scrim |
| C3 | The front door and model gate box their content in cards; the launcher sets it on the water | fixed: the door and the gate stand on the water in the launcher's type: its heading, status line and lit choices, the gate through the launcher's own requirement view |
| C4 | Status dots differ between the launcher and the front door | fixed: the door shows the realm's state with the launcher's status dot |
| C5 | Capitals: other weights, no lead-in padding (centred caps sit left of their rule), shadow vs glow | fixed: centred capitals take the launcher's lead-in, so they sit centred over their rule. Kept: the map's dense panels keep their heavier weights and a dark shadow over the busy map, where the lake screens' thin type and glow wouldn't read |
| C6 | Launcher text shrinks with the window to 6–7 pt; the game's small sizes ignore a floor; Larger Text not in the launcher | fixed: the launcher's type keeps 9 points at the least and the game's 8, both 11 with Larger Text, which sets the launcher's type too |
| C7 | Increase Contrast raises some texts and not others, and brightens empty meters, pips and gridlines | fixed: one rule for every text in both faces (solid, never under 5.5 to 1; with Increase Contrast 12 to 1 or more, the order kept; under 14 points never thinner than regular), and a gentler one for lines, tracks, pips and gridlines; held by Xcode's accessibility audit in CI |
| C8 | The map ignores the Motion setting and the frame rate cap, jumps under Reduce Motion, and its clock wraps out of step | fixed: the map follows Motion, Frame rate and Resolution, its clock is the launcher's, and below full motion panels fade rather than slide |
| C9 | The title's fades differ between screens, and every crossing replays the first falling star | fixed: one reveal time for the title on every lake screen, and the lake's time carries from one lake to the next, so the first falling star falls once. The letters settle only in the launcher's opening, by design |
| C10 | The fallbacks drawn without Metal differ from the Metal scenes (shore, stars, unexplored ground) | fixed: the lake without Metal draws the shader's own mesas and bank (LakeShore), its tinted stars, mist and vignette; the map without Metal its mist, the stars in the still water and the moon's layered halo |
| C11 | Colours copied by hand between launcher and game; README describes moving water; the icon shows a broken reflection | fixed: the game's ink and glow are the launcher's; the README describes still water; the icon is redrawn by `Tools/icon/make-icon.py` as the launcher's still lake, the moon given back whole |
| C12 | The shaders' hash functions are Dave Hoskins' "Hash without Sine" (MIT), copied uncredited; the project wants original work only | fixed: both shaders use a hash written for Nullmere, tested even and free of lattices in float32; the far shore's noise offsets were refitted so the scene keeps its mesas |
| C13 | `realm-server/Cargo.toml` says MIT; the project is Apache-2.0 | fixed |

## E: docs and scripts against behaviour

| ID | Finding | Status |
| --- | --- | --- |
| E1 | `docs/warpkeep-carryover.md` reads as current; it was the plan before the build | fixed |
| E2 | README and Settings describe moving water, rings and a star falling twice a minute | fixed |
| E3 | GO-LIVE says the steward's log shows every order and turn | fixed |
| E4 | README: "a small, personally curated community"; anyone with the app can enter | fixed |
| E5 | A second steward: "finds it held and gives up" | fixed |
| E6 | `make smoke-menu` is said to run "in each model state" | fixed |
| E7 | The steward is said to run in a container whenever Docker is there | fixed |
| E8 | `make check-shader` compiles only the lake's shader | fixed |
| E9 | Leftovers from two apps; CI comments; debug variables that need `NULLMERE_KEEPER`; the settings domain; CI's triggers; the coverage listing; the layout; `coverage.py --help`; script headers | fixed |

## D: sound, MMO assumptions, tests against the code

| ID | Finding | Status |
| --- | --- | --- |
| D1 | Being struck, losing a company, a hold struck and hunger make no sound; a strike heard from another keeper shows no blows | fixed |
| D2 | Refusing a steward's tribute, which is war, sounds a click, not war's cue | fixed |
| D3 | Settings are split: volumes only in the world, motion and display only in the launcher; the Watch menu's toggles stay live in the launcher; one setting has three names | fixed |
| D4 | The world ignores the launcher's Motion; Settings says motion follows the system | fixed |
| D5 | `.rise` is said to sound when a hold is founded or a work completed; it sounds when the order is given, and completions are silent | fixed |
| D6 | Many watch bells at once can clip | fixed |
| D7 | Turning sound back on snaps in at full level, with stale tails | fixed |
| D8 | The Play panel ("this build of the launcher can't enter the realm") is unreachable and treats the launcher and the game as two products | fixed |
| D9 | Single-player paths remain public: `GameApp.init(address:)`, `GameSession.init(state:)`, `RealmState.init(name:world:keeper:)`; `GameSettings` defaults to one keeper named Aurel | fixed |
| D10 | Tests that can't fail or don't test what they say: strike targets in peace, every cue at once, leaving a link, a narration render, an `if let` that hides its assertion, a seed-dependent vassal | fixed |
| D11 | Stale test and doc comments: seeds that no longer fall, "twelve stewards, thirty watches", "the greatest House free", two apps, "a game", a doc comment on the wrong function | fixed |

## Found while fixing

| ID | Finding | Status |
| --- | --- | --- |
| X1 | The panning benchmark's slowest frames failed CI when the shared runner's GPU was busy, the code under it unchanged | fixed: each figure is the steadiest of three passes, so a busy spell spoils one pass and a slower game slows all three |
| X2 | The tempers don't win alike: over 528 ages of stewards alone, ambitious 37%, cunning 28%, wary 19%, steadfast 17%. An earlier claim that they did rested on one lucky sample of 96 | kept, and stated in the README: it is each temper's nature (the warlike take most dominions, the builders win by the Moonspire), and no keeper plays a temper. Making the builders expand like the ambitious only widened the gap |
| X3 | Seat 0 won 30 of 192 ages in two samples | no change: a fresh sample of 192, with every House's events counted, found nothing, and over all 528 ages the seats win alike within chance (χ² 14.7 on 11 degrees of freedom) |
| X4 | The launcher's Settings couldn't set Larger Text, and the realm's set it apart from the display settings | fixed: one setting, Text (Standard, Larger), in both Settings, kept where Larger Text always kept its choice; ⇧⌘+ sets it too, and both rows follow |
| X5 | At a door out of reach, the lit choice stayed on Enter, which can't be taken, so Return did nothing | fixed: while the realm is out of reach Try again is lit, and Enter again once it answers |
| X6 | Coverage fell under two floors after the audit's own changes (the game's interface 97.26% against 97.5%, the launcher 98.00% against 98%) | fixed with tests of what had never run: the sound fading out, back in and stopping, every panel over the map, the door in a window following the realm, the race near its end said in words, the shared display setter, the Mac waking heard; 97.70% and 98.37% |

# A skeptic's review of every area, October 30

A third pass, by a reviewer looking for any reason the game falls short:
the standing rules, rules and balance, the realm and its network, the
interface and its accessibility, the look, the sound, speed, tests, and
docs and scripts. Accessibility was put to Apple's own audit on CI's Mac
for the first time (an XCUITest target), and the look was measured on a
WebGL render of the same shaders, which gives the Mac's figures to the
unit.

## Z: the standing rules

| ID | Finding | Status |
| --- | --- | --- |
| Z1 | Is the title exactly "Nullmere Online" everywhere it is shown? | verified: the bundle's name and display name, the window, the wordmark (drawn in capitals, read by VoiceOver as "Nullmere Online"), the release's disk image and notes, the news, the carry-over notes |
| Z2 | Is there any single-player setting? | verified none: the launcher's settings are motion, resolution, frame rate, text and full screen at launch; the realm's add only sound and keys. No world size, House count, difficulty or offline play anywhere; the only realm is the shared one |

## R: rules and balance

| ID | Finding | Status |
| --- | --- | --- |
| R1 | A keeper could declare war and have peace in the same watch, a steward's goodwill bought by gifts carrying over into the war | fixed: no peace before the steward has had a watch of its own at war; one far the stronger none until the war has run thirty watches; war forfeits the declarer's goodwill |
| R2 | A vassal could raise its Moonspire and win the age while sworn | fixed: a vassal can't start one, its works stop when it bends the knee, its tower is feared by no one, and the ascendancy needs a free House |
| R3 | Houses one keeper holds under other names could pour unlimited gifts into one | fixed: a House takes in gifts worth a hundred a watch at most, all givers together, moonsalt four |
| R4 | A lopsided trade between keepers bypassed that bound | fixed: what a trade between keepers gives one side beyond what it takes back is a gift and counts as one; the limit's words fit whoever's bound it is |
| R5 | A garrison that won a close fight stepped out of its hold; a scout drew a steward's army off a siege | fixed: the victor never steps out of a hold nor into one it can't take; garrisons strike only companies of war; besiegers turn only for what blocks them |
| R6 | The caretaker swore pacts for a keeper away, lending the keeper's sight | fixed: it swears none, but takes the peace that ends a war |
| R7 | The odds promised a hold to a striker the walls' blow would fell | fixed: a hold is promised only if the blow back can't kill the striker; the odds say when the victor takes the field |
| R8 | A steward refused a keeper's demand for tribute at no cost | fixed: the refusal is war, declared by the demander; the demand waits after a refusal, and demanding of a steward asks twice |
| R9 | Barter said "three to one" while moonsalt costs nine and fetches one | fixed in the words: moonsalt counts as three of any other store |
| R10 | A company trained with no room to stand said "Ready next watch" for ever, and could muster inside another House's hold | fixed: it says it waits for room; it never musters in another's hold |
| R11 | A realm took any seat count and quietly capped it | fixed: two to twelve, and the steward refuses any other number aloud |
| R12 | Does the watch wait on keepers who aren't seated, or count a fallen House? | not real: only seated keepers whose House stands count, a fallen one only when no standing keeper is there |
| R13 | The balance figures in the README were from before these rules | fixed: 528 ages played again under them (the Moonspire 74.6%, median 157 watches, a House fell in 36.7%; the seats win alike, χ² 4.5 on 11 degrees of freedom) |

## N: the realm and its network

| ID | Finding | Status |
| --- | --- | --- |
| N1 | Any new name took a seat; a fallen keeper took seat after seat; an unplayed seat was held a day; "here" went out on a timer, so a game left open held its seat | fixed: newcomers come in three a watch's length, an unplayed seat is held an hour, a fallen keeper rises once an age, and a keeper counts as there only while their Mac is used. A modified client can still script names and presence: the realm raises the cost, as no server can tell a person from a script |
| N2 | A refusal told what the fog hid (whose company stood unseen, whether a hidden company was a foe) and a strike could be loosed into the dark to probe | fixed: a refusal says no more than the keeper's own view, and strikes are checked against it first |
| N3 | The keeper's copy, without the realm's dice, told and drew strikes, losses, spoils and names by its own roll | fixed: it tells only what is certain; what chance decides comes from the realm's answer |
| N4 | A keeper with no seat in a new age stayed in the old world | fixed: back to the door, to wait |
| N5 | A key the server refused was erased and a new one made | fixed: the key is never erased or replaced; the keeper is told plainly and any order waits |
| N6 | Clearing a realm published over a steward still running | fixed: the steward stops first |
| N7 | Leaving dropped the orders still waiting to be sent | fixed: they go first, then the leaving |
| N8 | Those there could hurry the watch past a keeper away | fixed: while any keeper whose House stands is away, a watch lasts at least a third of its time |
| N11 | An older view could stand over a newer one | fixed: only a newer view is taken |
| N12 | An order expiring while asked after could crash the link | fixed |
| N13 | Server text and HTTP codes reached keepers; an unknown request was called "the realm isn't open"; the door blamed the key | fixed: plain words, the server's kept for the logs |
| N14 | A realm begun anew went unnoticed by a keeper giving no orders | fixed: noticed from its answer to "here", within half a minute |
| N15 | A reply was found by scanning, and a new steward kept its predecessor's replies for ever | fixed: replies are read by their nonce, and a steward taking over forgets the old ones, a few hundred at a time |
| N16 | A steward handed the realm by its owner could publish but not read it: SpacetimeDB lets only the database's owner read its private tables | kept: the realm proper runs its steward as the database's owner, which works; a dedicated steward identity needs views over the private tables, a schema migration on live data and a new hand-over in `raise-realm.sh`, too large and too risky for this pass. The test fake now keeps owner and steward apart, so the tests no longer hide it |
| N21 | Does a build with no realm address go to the realm proper? | not real: it goes to `https://maincloud.spacetimedb.com/nullmere`, as the scripts, README and CI's check say; the parsing is now pinned by a test |
| NT2 | The steward and the realm remembered every passer-by for ever | fixed: only keepers online, and seatless keepers long gone forgotten |
| NT3 | Every view was worked out again each round, with the whole heard history | fixed: only when it may have changed, the history kept to the latest sixteen |
| NT4 | Catching up fetched the whole world for an unchanged order; views decoded on the main thread | fixed: the version is checked first (fifty full fetches to none), views decode off the main thread |
| NT8 | The fake SpacetimeDB was kinder than the real one | fixed: it keeps the module's bounds, the lease's rollback and the owner apart from the steward; six integration tests pass against SpacetimeDB 2.13 itself |
| NT15 | CI never built the steward's image | fixed: the realm job builds `Dockerfile.steward` and starts it |

## U: the interface and its accessibility

| ID | Finding | Status |
| --- | --- | --- |
| U1 | Nothing put the app to Apple's accessibility audit, nor walked the map as VoiceOver does | fixed: an XCUITest target runs on CI's Mac, launches the app with a store and bundle id of its own, puts every screen to `performAccessibilityAudit()` (launcher, News, Settings, the requirement, the door open and out of reach, the briefing, the seat, the panels, a trade written, war asked twice, the realm's Settings) and walks the lake map through the accessibility tree |
| U2 | The audit's first rounds: roles, names, unlabelled lists and menus, the window's fit | fixed |
| U3 | Type failed the audit at 1x: small, thin or dim type, marks a pixel across, panels the moving map showed through | fixed: no text fainter than nine tenths of the ink; words never under 11 points nor capitals under 9.5; nothing under 14 points thinner than regular, nor under 12 lighter than medium; every panel, the top bar and the hints wholly dark; colours that colour words lifted toward the ink |
| U4 | Words straight on the lake failed at 16:1 by their own pixels: the audit finds no ground behind type drawn over Metal | fixed: such words lie on the water's own dark, which looks the same and gives the audit a ground |
| U5 | Without a pointer, not everything could be reached: companies only while awaiting orders, holds not at all, the middle of the view not chosen, panels not scrolled | fixed: ] and [ go round every company, H round the holds, Space or Return chooses what lies in the middle, Page Up and Down scroll |
| U6 | Character keys acted with no way to turn them off (WCAG 2.1.4) | fixed: a setting makes them need Option |
| U7 | Buttons that ask twice ran a clock and changed their name while armed | fixed: no clock to beat, the name kept, the question in their value; B and M ask twice by the keys too |
| U8 | VoiceOver wasn't told what a key chose or did; the rotor didn't bring the view to its choice; an opened panel didn't take the cursor | fixed |
| U9 | Colour alone said who owns a hold, what a cost lacks and whose line a chart draws | fixed with Differentiate without colour: ownership marks, "short" in words, patterned lines; the chart is an audio graph |
| U10 | Targets under 24 points | fixed |
| U11 | The Dock bounced for companies the keeper had left waiting on purpose | fixed: it calls for what waits anew, a company at its march's end or a hold that can now pay for work |
| U12 | The top bar overflowed a 960-point window at the new type floor | fixed |
| U13 | The door's name field: AppKit's field editor is not its parent's child | kept: AppKit's own; the UI test names it and leaves it aside, the field's own label and value audited |
| U14 | Does the door's lit button weigh as the launcher's? | verified: it is the launcher's own menu button |
| U15 | The watch's countdown changed what VoiceOver reads every second, so the tree never held still: the audit of a crowded panel ran out of time | fixed: said by the minute ("Turns in about 2 minutes"), still shown to the second; the world's audits run with Motion set to Still, and a timed-out audit is tried twice more |
| U16 | In a window as short as CI's (1024 by 674 points) the launcher's News and Settings ran under the footer: Back lay beneath the key hint's pill, which took its click; at 960 by 600, or with Larger type, worse | fixed: the open screen lies at its depth where there's room, rises toward the title's foot where there isn't, and draws its lines closer where even that isn't enough, never into the footer; the pill and the water's dark behind words take no clicks. The UI test holds Back above the footer and answering, with Larger type too |
| U17 | Xcode's contrast audit called faint the light words on the night water that its own pixels show at about sixteen to one, their faintest stroke above eight to one | fixed in how it's judged: each text the audit calls faint is measured from the screen's pixels by WCAG's formula, and fails if its type is under 4.5:1 or can't be measured; where a crowded screen holds more than the audit can judge in its time, every text on it is measured so |
| U18 | A hold's works and companies read as seventy-odd pieces: a work's name, its level, what it does, its cost and its watches each apart | fixed: each row reads as what it is, what the next step does and costs, and its button |
| U19 | The app was lost under the audit once ("Lost connection to the application") | watched: the audit job tells any crash report of the app, why and where; it hasn't happened again |
| U20 | With the realm's Settings open, the audit judged the window behind the sheet, which the Mac dims to three to one and holds out of reach; and the sheet's own container, which SwiftUI makes for it, names nothing | kept, and judged as it is: the window behind a modal sheet is inactive, which WCAG asks no contrast of, so the test measures only what lies in the sheet; the sheet's content reads as Settings, and its container is named in the audit's notes as AppKit's field editor is. Hiding the window behind from VoiceOver was tried: a view's hiding set false overrides what lies within it, and laid bare the door's unseen key buttons |
| U23 | The keys' hint in the map's corner was meant hidden from VoiceOver, but a container's own hiding, set false, overrode it, so VoiceOver read its marks | fixed: it reads on purpose now, the keys said as words |
| U21 | The UI test's check that the title reads Nullmere Online could be met by the window, named for the app | fixed: it finds the title's own words, smaller than the window |
| U22 | The pixel measure took a race row's red meter for its type | fixed: a mark far longer than it is thick (a bar, a rule) is judged as a graphic, at WCAG's 3:1, not as type |

## V: the look

| ID | Finding | Status |
| --- | --- | --- |
| V1 | Under a panel the moon's image vanished | fixed: it dims to a ghost, a third of itself or less (0.30 measured), never gone |
| V2 | The scene clock started over with a jump: drifts and pulses weren't whole turns of its period | fixed: every motion comes round a whole number of times; drifts go round a circle from where they began |
| V3 | The map's reflected stars and salt glints swam as the map panned | fixed: held by the world, as its moon is |
| V4 | The lanterns' flicker seamed where world units meet | fixed |
| V5 | The map's moon wore another face than the launcher's | fixed: the same noise turn for turn, and its one bright crater |
| V6 | Features ended in seams at their tile's edge | fixed: each fades before it, and toward the shore |
| V7 | The moonlight pooled round a fixed point, wherever the lake laid the moon | fixed: round the moon's image |
| V8 | The moon breathed and the stars twinkled more than a still night does; stars blinked out | fixed: halved; no star blinks out |
| V9 | The lake without Metal drew the moon as a flat coin: a third moon | fixed: the shader's face, worked out on the CPU from the same noise and held to it by tests |
| V10 | Does the map pop when its render scale changes at zoom 44? | not real: the two scales differ by 0.35 in 255 on average |
| V11 | Still black lake, stars, moonlight: does every view keep to it? | verified on the WebGL render: open water 11 from afar, no path under the moon (14 against 9 beside it), the moon's face 493 close up with water 17 around it, the unknown a dark mist in banks |

## S: sound

| ID | Finding | Status |
| --- | --- | --- |
| S1 | The ambience's clock was a Float and stood still after eight and a half minutes | fixed: double precision |
| S2 | The wind's filter was set per sample and sounded different at other sample rates | fixed: set in hertz |
| S3 | Dread and hooves had no overtones a laptop's speakers give | fixed |
| S4 | Cues were cut off as sound faded; notes stopped at eight seconds; the score's chord change clicked; a watch's sounds piled up; quitting cut the sound | fixed: cues fade with the rest, notes ring out, the change is smooth, a watch's sounds follow its bell, quitting fades |
| S5 | Volumes stepped, the sum could clip, the audio thread allocated | fixed: volumes ease, the sum is softened to full scale at most, room is made up front |
| S6 | A night turned down to nothing sounded for a few hundredths of a second | fixed: sound begins at the volumes it was given |
| S7 | Gifts received, ranks won, ruins searched and seats lost were silent | fixed |

## P: speed

| ID | Finding | Status |
| --- | --- | --- |
| P1 | The perf gate's calibration timed the game's own stewards, so a slower rules path raised its own allowance | fixed: it times plain work, none of it the game's |
| P2 | A slow runner could widen the allowances without end; the worst frames had no bound of their own | fixed: held at twice; the p95 frames at half again their baselines and never past a 60 Hz frame |
| P3 | The calibration's baseline is an estimate | kept as it stands: CI's first figure for it came on a slow day (its realm watches at 1.3 to 1.5 times their own); the note in `perf/baseline.json` says so |
| P4 | The first of the twelve-seat realms timed also paid for the process's first realm (its tables, caches and first pages), and came within 2% of its bound on a slow runner | fixed: one realm is made and played first, untimed; the first realm's own seed is still a fifth heavier than the others', as its baseline allows |

## T: tests

| ID | Finding | Status |
| --- | --- | --- |
| T1 | A render helper that drew nothing at all passed for drawn | fixed: every rendered view must show pixels standing out from black |
| T2 | The press test tried Halt only if its world happened to give a company a march | fixed: it always marches one |
| T3 | Tests skipped when the dice gave no steward of a temperament | fixed: a steward is made so |
| T4 | The soak test could run out CI's clock rather than fail | fixed: it fails past a second a watch on every lake |
| T5 | The tests' own figures broke on the changes (a Float at full scale, a URL's slash, a mist sampled elsewhere, a top bar wider) | fixed, each checked against the render or the rule. Two bounds moved to what the scene now draws: the veiled image to a third (0.30 measured, against 0.3) and the moonless lake's moon to 580 at its heart, the Metal moon's being 620 to 640 with its seas |
| T6 | The quiet realm's test held that the view is read again for an order, and raced the next poll for it | fixed: it waits for that read |
| T7 | The voices' check ran in the test runner's bare process, which on CI's runner found Apple's model not ready while the app there found it ready: it could only fail there, or be skipped | fixed: the app asks the model, as on a keeper's Mac (`scripts/check-voices.sh`); the rules it holds each line to are tested with stand-in voices. CI asks its runner's own model so too, and holds every line to the rules when it speaks; a runner whose model isn't ready says so (the audit job's runner was found not eligible), so a real Mac's hearing stays on the go-live list |
| T8 | The fixes of this review left new code untested: NullmereKit's coverage fell to 96.8%, under its floor | fixed: tested, back above the floor |

## K: docs, scripts and the release

| ID | Finding | Status |
| --- | --- | --- |
| K1 | The steps only the maintainer can take weren't a checklist to paste | fixed: `docs/GO-LIVE.md` is one, each block pasted as it stands (one block filled in first), each with what it prints when it worked, checked against the scripts' own lines |
| K2 | Hearing the voices and measuring on a real Mac took several commands | fixed: `scripts/check-on-mac.sh` does both, says which passed, and commits the figures |
| K3 | A tag could release a commit CI never passed | fixed: the release workflow releases nothing unless a CI run passed on that very commit |
| K4 | A debug build or a test build's bundle id could ship | fixed: a release is always the release build under the app's own id, and `verify-release.sh` fails either |
| K5 | The realm's dry run said all was well when the maintainer wasn't signed in | fixed: its last line says so |
| K6 | The notes for a build not notarized said to right-click, which macOS 15 and later no longer allow | fixed: Open Anyway, in Privacy & Security |
| K7 | "Nullmere" alone in the news and the carry-over notes | fixed: Nullmere Online |
| K8 | The world preview's generator could be a stale one that no longer built | fixed: rebuilt each time, judged by the compiler's exit |
