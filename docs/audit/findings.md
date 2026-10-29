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
| C1 | The map's lake is not the launcher's: a bright moon path, a greyer moon image, another glow and breath, other stars | open |
| C2 | The front door and model gate darken the whole window, sky and title too; the launcher darkens only the water | open |
| C3 | The front door and model gate box their content in cards; the launcher sets it on the water | open |
| C4 | Status dots differ between the launcher and the front door | open |
| C5 | Capitals: other weights, no lead-in padding (centred caps sit left of their rule), shadow vs glow | open |
| C6 | Launcher text shrinks with the window to 6–7 pt; the game's small sizes ignore a floor; Larger Text not in the launcher | open |
| C7 | Increase Contrast raises some texts and not others, and brightens empty meters, pips and gridlines | open |
| C8 | The map ignores the Motion setting and the frame rate cap, jumps under Reduce Motion, and its clock wraps out of step | open |
| C9 | The title's fades differ between screens, and every crossing replays the first falling star | open |
| C10 | The fallbacks drawn without Metal differ from the Metal scenes (shore, stars, unexplored ground) | open |
| C11 | Colours copied by hand between launcher and game; README describes moving water; the icon shows a broken reflection | open |
| C12 | The shaders' hash functions are Dave Hoskins' "Hash without Sine" (MIT), copied uncredited; the project wants original work only | open |
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
