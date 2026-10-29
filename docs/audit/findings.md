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
| C7 | Increase Contrast raises some texts and not others, and brightens empty meters, pips and gridlines | fixed: one rule for every text in both faces (never under 4.5 to 1; with Increase Contrast 10 to 1 or more, the order kept), and a gentler one for lines, tracks, pips and gridlines |
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
