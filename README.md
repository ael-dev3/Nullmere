<p align="center">
  <img src="Packaging/AppIcon.png" width="128" height="128" alt="Nullmere Online app icon: a full moon above a black lake, mirrored in the water">
</p>

<h1 align="center">Nullmere Online</h1>

Nullmere Online is a persistent multiplayer 4X for the Mac, for a small
community: one realm, twelve seats round its lake (a realm may be raised
with as many as ninety-six round a wider one), open to anyone with the
app. Every keeper shares one world, a great dead lake, held by a realm
server. Keepers explore, expand, build up their stores, make pacts and wage
war, and the alliances, politics and
drama they create leave a lasting history. It continues the universe,
premise and principles of [Warpkeep](https://github.com/ael-dev3/Warpkeep),
without Warpkeep's Farcaster identity.

This repository holds one Mac app, **Nullmere Online**: a black lake under
a full moon, with Play, News, Settings, Repository and Quit on the water.
Play crosses to the realm's front door: who you are on the lake, how the
realm stands, and the way in. Inside, you hold a House among other
keepers' Houses: found holds, work the land, train companies, make and
break pacts, and win the age by dominion or by raising the Moonspire.

Website: [nullmere.online](https://nullmere.online)

**Going live** takes five steps that need an account, a Mac or people only
the realm's maintainer has: raising the realm on maincloud, signing and
notarizing the release, hearing the voices and measuring on a Mac with
Apple Intelligence (one command, `scripts/check-on-mac.sh`), listening to
it with VoiceOver, and its first keepers. Each is rehearsed in CI where it
can be, and [docs/GO-LIVE.md](docs/GO-LIVE.md) is a checklist of commands
to paste, each with what it prints when it worked.
`scripts/go-live-status.sh` says where each step stands.

## Requirements

Nullmere Online runs only on Macs that can run Apple's on-device language model,
the roughly 3-billion-parameter model behind Apple Intelligence. Its
envoys and chronicler speak through that model, on your Mac, using the
[Foundation Models](https://developer.apple.com/documentation/foundationmodels)
framework. You need:

- a Mac with Apple silicon,
- macOS 26 Tahoe or later,
- Apple Intelligence turned on in System Settings, with its model downloaded.

The app is built for Apple silicon only and declares macOS 26 as its minimum,
so macOS won't open it anywhere else. On a Mac that meets both but can't use
the model, the launcher shows nothing but what is missing: that the Mac
doesn't support Apple Intelligence, that it is turned off, or that the
model is still downloading. It offers System Settings where that helps, and
Quit. The menu stays closed until the model is ready, and then the launcher
opens by itself. While the answer can still change, it checks again every
few seconds while it is in front, and whenever it comes back to the front.

To build the launcher you need Xcode 26 or later. It includes Swift 6.2 and
the macOS 26 SDK.

## Build and run

From a terminal:

```sh
git clone https://github.com/ael-dev3/Nullmere.git
cd Nullmere
swift run NullmereLauncher
```

From Xcode: open the package with `open Package.swift`, choose the
**NullmereLauncher** scheme and **My Mac**, then press ⌘R.

A realm to play in, hosted on your own Mac for development:

```sh
NULLMERE_REALM=local swift run NullmereLauncher
```

As a double-clickable app:

```sh
make app                          # or: scripts/build-app.sh
open "build/Nullmere Online.app"
```

`scripts/build-app.sh` makes an arm64 release build and assembles
`Nullmere Online.app` with its icon and Info.plist.
The icon is a Liquid Glass document, `Packaging/AppIcon.icon` (night,
reflection and a glass moon), compiled with `actool` into the app's asset
catalog; the classic `AppIcon.png` is the fallback where `actool` isn't
available. Both are drawn by `Tools/icon/make-icon.py`: the launcher's own
still lake, framed square around the moon. It signs the app ad hoc,
which is enough to run it on the Mac that built it. To sign with a
Developer ID instead, set `CODESIGN_IDENTITY`: the app is then signed with
the hardened runtime and a secure timestamp, ready to notarize. `VERSION`
sets the marketing version (default `0.3.0`).

**A release is one command.** `scripts/release.sh` builds the app and
packs it into `build/Nullmere-Online-<version>.dmg`, with a link to
Applications; CI makes this disk image on every run and keeps it. For a
public release, with an Apple Developer ID:

```sh
xcrun notarytool store-credentials nullmere --apple-id … --team-id …   # once
CODESIGN_IDENTITY="Developer ID Application: …" NOTARY_PROFILE=nullmere \
    VERSION=1.0.0 scripts/release.sh   # signs, notarizes and staples
```

Or from GitHub: with the Developer ID certificate and an App Store
Connect API key in the repository's secrets (`MACOS_CERTIFICATE`,
`MACOS_CERTIFICATE_PASSWORD`, `APPLE_API_KEY`, `APPLE_API_KEY_ID`,
`APPLE_API_ISSUER`), pushing a tag such as `v1.0.0` runs
`.github/workflows/release.yml`: it signs, notarizes and staples the disk
image and attaches it to a GitHub release.

CI rehearses that path on every run (`scripts/rehearse-release.sh`): a
throwaway self-signed identity takes the Developer ID's place through the
same steps, the app is signed with the hardened runtime and a secure
timestamp, the disk image is signed and checked, and the notarizing and
stapling, which no throwaway identity can have done, are printed rather
than sent; the first tagged release does those for real. The release
workflow ships nothing CI hasn't passed whole on the tagged commit. Adding
the secrets is all that's left, in one command that checks each file
first (docs/GO-LIVE.md, step 2):

```sh
scripts/set-release-secrets.sh DeveloperID.p12 AuthKey_XXXXXXXXXX.p8 <issuer id>
```

Tests and checks:

```sh
swift test                 # unit tests; on a Mac with Metal, the shader is also compiled on the GPU
make check-shader          # compile the lake's and the map's shaders with the offline Metal compiler
make smoke                 # build the app, open the launcher, check it starts and renders with Metal, take a screenshot
make smoke-menu            # open a debug build of the launcher with the model ready, Apple Intelligence off and the model downloading; type into it, photograph every screen
make smoke-game            # open a debug build, press Play, enter a realm hosted on the Mac as a keeper, take screenshots
scripts/ui-test.sh         # through Xcode's UI testing: every screen put to its accessibility audit, the map walked as VoiceOver walks it
scripts/check-voices.sh    # the voices, spoken by this Mac's on-device model through the debug app, every line held to their rules
```

CI runs all of these on a macOS 26 runner for every pull request and every
push to `main` or a working branch that touches the code, and keeps the
screenshots of the launcher, the realm's front door and the world.

Line coverage is held to a floor for each module, on macOS and, for the
rules, the realm and the launcher's logic, on Linux too (`scripts/coverage.py`). On macOS,
CI's summary lists the files with the most lines no test runs, and the
lines themselves (the command-line entry points, the launcher's and the
steward's, have no floor: CI runs both whole). What remains is mostly what a test can't
reach: `init(coder:)` stubs no window calls, SwiftUI state's initial values,
the fallbacks drawn when Metal or sound fails, the live environment's
closures (downloading the news, opening a link, quitting), trackpad
gestures, and Apple's on-device model, which `scripts/check-on-mac.sh` asks
on a Mac with Apple Intelligence. A few more are reached only by hand: a
menu's items, and VoiceOver's actions on the map (a test process has no
assistive technology to build SwiftUI's accessibility tree for).

Speed is held too (`scripts/perf-check.py`, against `perf/baseline.json`):
the tests print the GPU time of the world's frames at three zooms, the
lake's, panning, the models staged for a frame, the marks over the world
and the flat map's, an order's way through the realm and a watch of
twelve keepers, and each must stay within half again its baseline, a frame
never over a 60 Hz frame's 16.7 ms on CI's virtual GPU. A slow runner
widens the CPU figures' allowance by its pace, timed on plain work none of
it the game's, up to twice. `scripts/measure-mac.sh` takes the same figures
on a real Mac, where a ProMotion display's 120 Hz is what to read them
against.

The launcher and the game ask the Foundation Models framework through one
`ModelAvailabilityProvider`; tests stand in a fake one and walk every state
(ready, not eligible, Apple Intelligence off, downloading, and a reason
macOS hasn't named), including the launcher and the realm's front door
opening by themselves when the model arrives and closing again when it goes. Debug
builds also take:

| Variable | Effect |
| --- | --- |
| `NULLMERE_MODEL_STATE` | `ready`, `notEligible`, `notEnabled`, `downloading` or `unavailable` instead of asking the framework (`NULLMERE_SKIP_MODEL_CHECK=1` means `ready`) |
| `NULLMERE_LAUNCHER_KEYS` | Keys the launcher receives once its opening is over, such as `right,return` |
| `NULLMERE_NEWS_URL` | Another `https` news feed, such as a branch's copy |
| `NULLMERE_REALM` | `local`: host a realm on this Mac (kept in Application Support); or the `http(s)://server/database` address of another realm, such as `http://127.0.0.1:3000/nullmere` |
| `NULLMERE_REALM_SEED` | The words a newly hosted realm's world grows from |
| `NULLMERE_IDENTITY_FILE` | Keep the keeper's identity in this file instead of the keychain |
| `NULLMERE_STORE` | Keep what the app keeps (a hosted realm, the voices' words) in this folder instead of Application Support |
| `NULLMERE_KEEPER` | Enter the world at once under this name |
| `NULLMERE_TEXT` | `larger`: show the larger type without remembering it |
| `NULLMERE_SHOW` | With `NULLMERE_KEEPER`: `seat`, `unit`, `houses`, `chronicle`, `guide`: select the seat or a company, open a panel; `briefing`: keep the card a keeper first meets; `watch`: be ready after `NULLMERE_WATCH_AFTER` seconds (12.5) |
| `NULLMERE_AUTOPLAY` | With `NULLMERE_KEEPER`, in a hosted realm: let a steward play the keeper's House this many watches first |
| `NULLMERE_VOICEOVER` | `1`: the map offers its orders to the accessibility tree as when VoiceOver runs, for the UI tests |

Release builds ignore them all and always require the model.

## Using the launcher

| Key | Action |
| --- | --- |
| ← → | Move along the menu, or between the choices on a screen |
| ↑ ↓ | Choose a story in News or a row in Settings |
| Return or Space | Select; in Settings, cycle the option |
| ← → in Settings | Change the selected setting |
| Esc | Go back |
| ⌘, | Settings |
| ⌘Q | Quit |

Any key or click during the opening skips it. Everything also works with the
pointer, and the choice that is lit is always the one Return selects. Holding
Return or Esc acts once. With Keyboard navigation turned on in System
Settings, Tab moves focus between controls and Space presses the focused one.

- **Play** fades the launcher out and crosses to the realm's front door,
  in the same window. The on-device model's status is always shown at the
  bottom left.
- **News** lists the latest stories, with the chosen story beside them.
- **Settings** is described below.
- **Repository** opens this repository in your browser.
- **Quit** fades to black and quits.

### News

The news lives in this repository, in [`news/news.json`](news/news.json):

```json
{
  "items": [
    {
      "id": "full-moon",
      "date": "2026-10-24",
      "title": "A full moon over Nullmere",
      "body": "A few sentences, up to 280 characters.",
      "link": "https://github.com/ael-dev3/Nullmere"
    }
  ]
}
```

When you open News, the launcher downloads that file from the `main` branch
on `raw.githubusercontent.com`, at most once every ten minutes while it is
open, and saves the copy for the next launch. Offline, or while the
repository is private, it shows the saved copy, or the news it was built
with. Stories are listed newest first. Entries without a title, body or
valid date are skipped, and only `https` links are followed. The download
carries no cookies or identifiers, though GitHub sees your IP address as it
would for any web request. A test keeps the built-in news identical to the
file, so publishing news means editing `news/news.json` and the built-in copy
in [`News.swift`](Sources/LauncherCore/News.swift) together.

### Settings

Settings are stored in the app's user defaults (`online.nullmere.launcher`;
a `swift run` build keeps its own, under `NullmereLauncher`). The display
settings are one set, shown in the launcher's Settings and in the realm's
(⌘, at the front door or in the world), and the lake and the map both
follow them:

| Setting | Options | Effect |
| --- | --- | --- |
| Motion | System, Full, Reduced, Still | How much the lake and the map move. Full: flickering and falling stars, the opening, marches and blows played out, panels sliding in. Reduced: slower, gentler twinkling and water, no falling stars, no opening; marches and blows shown where they end, panels fading in. Still: a single frame, drawn again only when something changes. System follows *Reduce Motion*. |
| Resolution | Native, Balanced, Efficient | Renders the lake at 100%, 75% or 50% of native pixels, and the map at most at that |
| Frame rate | 30, 60, 120 | Upper bound for the lake's and the map's frame rate. Reduced motion, Low Power Mode, a Mac running hot, or another app in front lowers it to 30 |
| Text | Standard, Larger | Larger sets all the type a fifth larger, the launcher's and the game's, none of it under eleven points. ⇧⌘+ in the Watch menu sets it too |
| Full screen at launch | Off, On | Applies the next time the launcher opens |

The realm's Settings also hold its sound (on or off, the effects, the
night, the music and its score's volume) and counsel. The
launcher makes no sound; ⇧⌘M and ⇧⌘U turn sound and music off or on once
the realm shows.

## The realm

Nullmere Online is one world shared by every keeper: the realm holds it,
and the client on your Mac holds a copy, carries out your orders at once
as the realm will, and takes the realm's word as final.

- **The front door.** Choose the name you'll go by: two to twenty letters.
  It names you and the House you'll hold, and nothing else is asked. The
  realm knows you by an identity your Mac keeps in its keychain, and by
  your name. The front door, set on the water as the launcher's panels
  are, shows the realm's state: its age and watch, how many keepers are
  there, and how many seats are open. Its choices are the launcher's: one
  lit at a time, the one Return takes, the arrows moving along them and
  Esc going back. Entering seats you in a middling House of
  those open (at an age's start, all alike, the first); returning, you go
  straight back to yours. No newcomer may take up a House sworn to another,
  the House leading the lake, or one within reach of dominion or with its
  Moonspire risen. A name and an identity are had for the asking, so the
  realm takes in keepers new to it a few at a time, three in any watch's
  length; one who comes just after is asked to try again in a few minutes.
- **Seats.** The lake has twelve seats, held by the twelve elder Houses. A
  realm raised with more, up to ninety-six, lies on a lake as much wider
  as keeps each seat as much country (a radius of 72 hexes for forty-eight
  seats and 102 for ninety-six, against the realm proper's 36), its seats
  a longer walk from the shore so that they keep their room (on each
  lake's shape, forty-eight seats lay eight hexes or more apart and
  ninety-six seven or more), and the seats past twelve go to younger
  Houses, each with a name and a colour of its own, on the map and in its
  words. Seats no keeper holds are played by stewards, the same minds that
  once played rivals, until a keeper claims them. When every seat is
  held, a newcomer waits at the front door and steps in the moment one
  falls free. A seat whose keeper has been away a week goes back to the
  stewards for whoever is waiting (an hour, for a seat taken and never
  played); its House stands as it was, and the keeper, returning, waits
  in turn. You are there while your Mac is in use: the game tells the
  realm so, and stops when no one has used the Mac for five minutes, so a
  game left open with no one at it counts as gone.
  A keeper whose House falls may take up an open seat once an age, and
  otherwise looks on until the next. Meanwhile, after two watches away
  (counted in watches, however quickly they turn), a caretaker keeps the
  House: it answers envoys, builds and trains, guards the holds, fights on
  in wars already begun and sues for peace in one going badly, but begins
  no war, demand or pact and never bends the knee, though it takes a House
  offering fealty as a vassal. Peace offered to end a war it takes as a
  steward would; a pact offered it never swears, for a pact would lend the
  keeper's sight to another. While any keeper whose House stands is away,
  a watch lasts at least a third of its time, however ready those there
  are.
- **Fair seats.** Seats are spread evenly round the lake, none hemmed in
  with little land of its own; which House takes which is the luck of the
  draw, and the stewards take their turns starting one seat further round
  the lake each watch.
- **What you see.** The realm tells each keeper only what their House
  could know: the ground they've explored, the companies in their sight,
  their own stores, and the envoys and news that reach them. The world
  itself never leaves the server. An order the realm refuses is refused in
  the words your own view of the world would give, so a refusal never
  tells of a company out of your sight: one you can't see is, to an order,
  not there, and a strike where you can't see finds nothing to strike.
- **Gifts.** Send stores to any House you aren't at war with. Stewards
  remember gifts for twenty watches: a war seems older to them, and enough
  goodwill wins a pact, unless you once made war on them or a pact between
  you was broken. War on a House throws away the goodwill your gifts bought
  with it, and no gift moves a steward that fears your rising Moonspire. A
  House takes in gifts worth a hundred a watch at most, from every giver
  together, moonsalt counting four: enough to help an ally, never enough
  for Houses one keeper holds under other names to pour their stores into
  one. Between keepers, what a trade gives one side beyond what it takes
  back is a gift, and counts as one. A keeper hears of a gift, a war
  declared or an envoy sent the moment it happens, not when the watch
  turns.
- **Trade.** Offer any House you aren't at war with so much of one store
  for so much of another. Stewards weigh it by barter worth, the cunning
  asking most; allies, givers of gifts and a House short of what you offer
  ask less, though never below even, and none trades away the grain its
  companies need. A keeper
  answers by envoy. Stewards trade among themselves before they barter.
  The answer is always the realm's: your copy of the world
  can't see the others' stores, so it doesn't guess.
- **Who is there.** The front door names the keepers in the realm now,
  and each House in the Houses panel says who gives its orders: its
  keeper, here or away, or a steward.
- **Taking your seat.** The first time you enter an age, a card tells
  you the House you take up (its seat and holds, its strength among the
  Houses, its wars and pacts, which the stewards may have chosen for you)
  and the first three things to do. Those three then stay beside the map
  as a checklist, ticked as you do them, until all are done.
- **Coming back.** Return after watches have passed, and a card tells
  what happened while you were away: your stores and holds, and the news
  that touched your House.
- **What can't be undone asks twice.** Declaring war, breaking a pact,
  disbanding a company, refusing a steward's demand for tribute and
  demanding tribute of a steward each want a second press, with no clock
  to beat: the button keeps its name for VoiceOver and Voice Control, says
  what it asks, and lets go when another is pressed or it leaves the view.
  By the keys, B asks before founding a hold and M before a strike; the
  same key again carries it out.
- **Elsewhere.** While you are in another app, the Dock counts the
  watches that turned, and bounces once when something needs you.
- **The watch.** Each turn is a watch. Your orders take effect as you give
  them; say you're ready (⌘↩) when they're given. The watch turns when
  every keeper there is ready, or when its time runs out, three minutes;
  then the stewards act, and the lake yields, eats and mends. An empty
  realm sleeps until a keeper returns. Leave, and what you ordered still
  on its way goes to the realm first; after two watches away a caretaker
  keeps your House.
- **Treating with keepers.** Offers to another keeper wait as envoys for
  their answer, as theirs wait for yours. Envoys of stewards speak, in
  words written on your Mac; a keeper's envoy carries their own words, if
  they write any: one plain line, no addresses, read by that keeper alone.
  Hide a House's words from its envoy card; your Mac remembers.
- **Omens.** Now and then the lake turns for every House at once, for
  three to five watches: Moonsalt Bloom doubles moonsalt, Rising Mist shortens
  every sight by a tile, a Lean Watch takes a third of the grain, and a
  Still Night mends wards twice as fast. The chronicle tells when one
  falls and lifts, and a band under the top bar shows it while it lasts.
- **Where it comes from.** Press a store in the top bar for its account:
  what each hold yields a watch, what your companies eat, what an omen
  adds or takes, and the room left to keep it.
- **Ages.** When a House wins, the age ends. When the watch next turns, a
  new age begins on a fresh lake, and keepers are seated anew in the order
  they first came, as seats allow, but for any away longer than a seat is
  kept for them. One in the world when it begins, with no seat in it,
  goes back to the front door to wait there for one, and steps in the
  moment one falls free. Each age's lake has a shape of its own, in turn:
  the round Nullmere, the Twin Waters with a neck of land between them,
  the Sickle with land pushing in from one shore, and the Drowned Isles.
  The front door names the lake of the age, and the moon lies in the
  deepest water of each.
- **The server.** SpacetimeDB is the realm's authority of record: it knows
  each keeper by their identity, keeps the world, and lets no one but the
  steward write it. The steward runs the same Swift rules core the clients
  carry, so there is one set of rules. A keeper's client carries out their
  orders at once, as the realm will, and takes the realm's word as final.
  What chance decides, or what your copy can't see, is told and drawn as
  the realm decided it, when it answers, never as your Mac guessed it: a
  strike's blows and losses, a ruin's spoils, a new hold's name, a
  steward's answer. Your identity is made once and kept in your keychain,
  and never erased by the game, even should the realm's server stop
  taking it. For development a realm can also be hosted in-process
  (`NULLMERE_REALM=local`).

### Raising the realm

The realm proper is a [SpacetimeDB](https://spacetimedb.com) database with
the module in `realm-server/`, and a steward beside it running the rules.
Release builds go to `https://maincloud.spacetimedb.com/nullmere`.

**Going live is one command**, after signing in to SpacetimeDB once:

```sh
spacetime login                                # once: opens a GitHub sign-in
scripts/raise-realm.sh maincloud --dry-run     # optional: checks and builds everything, changes nothing
scripts/raise-realm.sh maincloud               # publishes the module, starts the steward
```

When the steward is up, the script reads the realm's status back as any
keeper would, and fails if the realm doesn't answer. CI runs the dry run
for maincloud, building the steward's image from `Dockerfile.steward` as
the realm proper's is built and starting it once, so the image can't fall
out of step with the code; and it raises a whole realm standing alone on
its own SpacetimeDB the same way (`scripts/raise-realm.sh local`, then
`--stop`).

The script checks its tools, publishes the module, keeps the steward's
token in `~/.config/nullmere` (readable by you alone), and starts the
steward: for maincloud, in a container (`Dockerfile.steward`, restarted with
the machine) when Docker is there; otherwise, and always for a local realm,
in the background, with its log beside the token. Run it again to update the module; the realm keeps its world. Ask
for a fresh realm with `SPACETIME_CLEAR=1`: the script stops the realm's
steward on this machine before it clears the database, since a steward
left running would publish the realm it held over the fresh one. Stop
any steward of it you run elsewhere first yourself.

The module can also be published from GitHub: put the token
`spacetime login show --token` prints in the `SPACETIME_TOKEN` secret, and
run **Publish the realm** (`.github/workflows/realm.yml`) from the Actions
tab. The steward still runs on a machine of yours, as that identity.

If the name `nullmere` is taken on maincloud, choose another with
`REALM_DB=…`, and build the app for it with
`REALM_ADDRESS=https://maincloud.spacetimedb.com/<name> scripts/build-app.sh`;
the address is kept in the app's Info.plist. `NULLMERE_REALM_NAME`,
`NULLMERE_REALM_SEED`, `NULLMERE_REALM_SEATS` and `NULLMERE_WATCH_SECONDS`
shape a new realm; a realm has two to ninety-six seats, and the steward
refuses to start, saying why, when asked for any other number.
`STEWARD=foreground` keeps the steward in the terminal. The Frontier is
raised the same way into a database of its own with `NULLMERE_FRONTIER=1`
and `NULLMERE_BORDERS` naming the realms it borders by address, between
commas; each of those realms' stewards is given the Frontier's address in
its own `NULLMERE_BORDERS`.

`scripts/raise-realm.sh local` raises the same realm on your own machine
(starting SpacetimeDB if it isn't running); open a debug build with
`NULLMERE_REALM=http://127.0.0.1:3000/nullmere`. CI runs this very script:
on Linux, two keepers play through the server, and two realms and the
Frontier are published as three databases whose stewards read each
other, keepers of each realm crossing to the Frontier, seated there for
their kingdoms at war, keeping its season to its end and told home of it
once; then three databases more, fresh, where the stewards run on their
own clocks and two keepers' own clients, the shipped link each, cross by
an order at home, go across to the Frontier by the same key, keep a
season of watches there and are told home; on macOS, the app itself
enters the world across the network (`scripts/smoke-test-network.sh`).

The steward takes up the realm where it stands after a restart. The
realm's tables are private: keepers write requests through reducers and
read only their own view and replies, through SpacetimeDB views
(`my_view`, `my_view_parts`, `my_replies`), and the realm's public status.
A keeper's view is kept in parts as the world is (its map, a page of each
long list, the rest), and its row names every part with the version it
was written at: a publication writes only the parts of each view that
changed and lets go of those a view no longer has, and a keeper's Mac
reads only the parts written since it last read, so a pace that moves a
few companies sends a page of them, not the whole world again. A request
carries a nonce of 1 to 64 bytes and at most 4 KB besides; a keeper may
have 32 requests waiting at most, and the steward carries out a few of
each keeper's every round, so no one keeper can crowd out the rest. A
request sent again, after its answer was lost, is carried out once. The
steward keeps the world and gives its answers in one transaction, so a
round it couldn't publish, or a steward stopped mid-round, loses and
doubles nothing; it says when a round fails, and every ten minutes how
the realm stands. It keeps in memory only what it needs of the keepers
there, and the realm forgets a keeper long gone with no seat (away a week,
or an hour if they never played), their name free again, so neither
grows with every identity ever heard from. It works out a keeper's view
only when something may have changed it, and sends with it what they
heard in the last two minutes, the latest sixteen publications' worth at
most. Answers are forgotten ten minutes on, those an earlier steward gave
too. One steward holds the realm at a time: any other finds it
held, tries again for two and a half minutes (a steward started again
waits the minute its old hold takes to lapse), then gives up. A container
is restarted after it, so stop a second one with `--stop`. The server
stamps each publication by its own clock, so a keeper arriving mid-watch
sees the watch's true time left, whatever their own clock says. If the
steward falls silent for a minute, every keeper is told the realm stands
still, and told again when it returns. An order that reached the realm
waits there for its answer, however long; one that can't reach it within
five minutes is let go, and its keeper told. Past those five minutes an
order is never sent again, only asked after, so none is carried out
twice. A client asks after each answer by its nonce alone, waits for what
came of an order by its view's version, fetching the parts of its view
only once that has moved on, and never takes a view older than the one it
has, nor one whose parts don't all match its row. The
realm answers each "here" too: a keeper it no longer knows, as after it is
begun anew, goes back to the front door within half a minute, though they
give no order. A key the server won't take is kept, never erased or made
anew: the keeper is told so, plainly, and it is offered again as the realm
is asked again. What a server says as it refuses is for whoever runs the
realm; keepers are told in plain words, never a status code.

## Playing Nullmere Online

- **The land.** Strand, salt flats, greyfields, blackwood and barrows ring
  the lake. Each yields grain, timber, stone or moonsalt to the hold whose
  territory it lies in; groves, seams, loam and moonsalt beds yield more.
  The Still, the lake's deep water, yields nothing and cannot be crossed;
  the shallows can.
  Drowned ruins hide something for the first company to search them.
- **Holds** gather what their land yields and store it, up to a limit that
  grows with each hold. Build Granaries, Sawpits, Quarries and Saltworks to
  boost a store, Walls to thicken the ward, Beacons to see further (at
  level II, a hold's land reaches a tile further too), and a Muster Hall to
  train stronger companies, at level III to train all but Lanterns a
  watch sooner, and to level V for the higher tiers. Barter a surplus
  for what you lack, three to one; moonsalt counts as three of any other
  store, so one costs nine of them, and fetches one. Each new hold costs
  more to found than the last, so a House grows by choice, not by habit. A
  company trained with no free tile within three of its hold waits,
  trained, and the hold trains no other until it has room to stand.
- **Companies.** Lanterns scout, Spears hold the line and take holds, Bows
  strike from two tiles, Riders are fast, and Founders found new holds.
  Every company but Lanterns eats a grain each watch. Spears, Bows and
  Riders muster in tiers I to V, each needing a Muster Hall as high as
  itself and the study that opens it (Close Order, Iron Ranks, Grey
  Companies, Moonsteel): a higher tier strikes harder, stands firmer and
  takes less of a blow, but costs more (moonsalt from tier III), eats more
  and takes longer to train. Lanterns and Founders muster in one.
  Companies that live through battles rise in rank (Blooded, Hardened,
  Sworn), each rank adding a tenth to attack and defence; chevrons over a
  company show it. A company that wins a close fight steps onto the
  fallen's ground, but never out of a hold, for a garrison holds its
  ground, nor into a hold it can't take. The odds shown before a strike
  say when the striker will take the ground or the hold, and never promise
  either to a company that may fall.
- **Studies.** An Archive opens a House's studies, one at a time: twenty-eight
  in four branches (Husbandry, Arms, Masonry, Lore), each needing an Archive
  of its circle, the studies it builds on, and its price. Each grade changes
  the rule it names: what the land yields, what a House can store, how soon
  works rise and companies muster and what they cost, attack and defence,
  wards, moves, sight, healing, commanders, and the tiers of companies of war.
  A higher Archive makes every study sooner. Stewards study too, each by its
  temper.
- **Commanders.** Every House begins with a commander, and gains more as its
  seat's Muster Hall reaches III and V and from Banner Lore, five at most.
  Each is of an archetype (warden, vanguard, outrider, gleaner, wallbreaker)
  and rises from level I to XXX with what its company lives through; its
  four skills come at levels I, V, X and XX: three always strengthen the
  company it leads, and one fires in battle once its fury has risen through
  enough battles, in its archetype's own look in the world: a ward of pale
  light closing over a warden's company, fire thrown out from a vanguard's,
  shafts of light falling about an outrider's, a ring of gold round a
  gleaner's, the ground breaking in a ring under a wallbreaker's, each with
  its light on the ground. A commander takes up a company of war at or beside one of
  its House's holds; if the company falls, it is carried home wounded for
  four watches.
- **Talents.** A commander gains a talent point at each level past the
  first, twenty-nine at the thirtieth, to spend a rank at a time in three
  trees of five talents: Steel (Keen Edge, Hunter's Mark, Ramming Drill,
  Blooded Steel, Battle Rage), Ward (Thick Hide, Field Surgeon, Gatewarden,
  Iron Ranks, Unbroken) and Road (Keen Eyes, Gleaner's Hand, Deep
  Saddlebags, Long Stride, Pathfinder). Each talent is opened by the one
  before it in its tree and has one to three ranks, each giving its edge
  again to the company the commander leads; Battle Rage fires its skill a
  battle sooner. There are more ranks than points, so every commander is
  grown one way. A commander's talents are forgotten all at once for 20
  moonsalt, every point given back. Stewards spend their commanders'
  points as they come, along the trees their archetype grows first.
- **Gear.** A company of the wilds struck down may leave a piece of gear,
  the more likely the higher its level (a quarter at level I, four in five
  at X): Saltwights a Salt Glaive, Blackwood Reavers a Reaver's Axe (both
  weapons), the Barrowkin Barrowplate, the Drowned Drowned Mail (both
  armour), Spine Hunters a Hunter's Eye (a charm). Levels I to III leave it
  plain, IV to VI fine, VII to IX masterwork, X fabled, and each step gives
  its edges again. A commander wears one of each, and the company it leads
  gains what each gives; taking up a piece puts back what it wore in that
  slot. A House's armoury keeps twelve pieces, worn or not; a piece found
  beyond them, or one the keeper breaks up, gives moonsalt, five for each
  step of its quality. Stewards arm their commanders with the finest they
  hold. A House knows its own gear, and of others' only what a commander
  in sight wears.
- **The wilds.** The realm raises hostile companies in the far country, six
  tiles or more from any hold: Saltwights on the flats, Blackwood Reavers,
  Barrowkin, Spine Hunters, the Drowned on the strand. They are of levels I
  to X, stronger the further from the holds and the later in the age, two
  for each seat at most. They never march and take no hold, and stand in
  the way. Any House may strike them without a war; they strike back at a
  company beside them, and mend while left be. What falls with them is
  stores for the House, and experience for the company's commander, more
  than any other battle gives. Stewards hunt the wilds near their land when
  they would strike them down with health to spare.
- **Gathering.** Sites come up in the land outside the holds, three for each
  seat: Fallow Fields of grain, Deadfall timber, Scree stone and Salt Pans of
  moonsalt, each the store of its ground, richer further out, and finite;
  when one is worked out another comes up elsewhere. Send a company of war
  to gather and it marches there, gathers each watch at its rate (by kind
  and tier, its House's studies and its commander), and once it carries all
  it can, or the site is worked out, brings its load home to the nearest
  hold. Any other order ends the errand, but a load is kept until the
  company comes by one of its holds. A gatherer struck down by a House at
  war with its own leaves half its load to the victor. Stewards at peace
  send idle companies to sites of the stores they run short of.
- **Alliances.** Any House not sworn to one may raise a banner, a named
  alliance it leads. Its leader invites Houses and answers those that ask
  to join; a House leaves when it will, and the leader may cast one out.
  An alliance takes a third of the lake's seats at most, and no House at war
  with one of its own. Allies make no war and no demands on each other,
  share their sight, and help each other's works, musters and studies:
  each ally helps each once, and every second help takes a watch off it,
  never its last. When the leader leaves or falls, the strongest still
  sworn takes up the banner; an alliance with none left is no more.
  Stewards raise banners, ask, invite and answer from the fifteenth watch,
  each by its temper.
- **Rallies.** A House of an alliance calls a rally at one of its holds with
  a Muster Hall, against a hold it has found of a House at war with it; it
  gathers for one to four watches, and the muster takes two companies and
  two more for each level of its Muster Hall. The caller and its allies at
  war with the same House send companies of war to it. When the gathering
  is done, those at the muster set out as one host, march at the pace of the
  slowest, and the moment all of it is in reach strike the hold together,
  arrows first, before its ward can mend; a company that breaks the ward
  takes the hold. Only the rally's side knows of it until it sets
  out; then the House it marches on knows too. A rally whose cause is gone
  (peace, its caller out of the alliance, its muster lost), whose muster is
  empty when it should set out, or whose host can't come to its hold within
  eight watches comes to nothing.
- **Keeping an ally's gates.** A company of war sent to an ally's hold
  stands at its gates; while it stands there, a company of a House at war
  with its own that strikes the hold is struck back from where it stands.
  Stewards call rallies by their temper, send companies they can spare to
  their side's rallies, and keep the gates of an ally's hold while a foe of
  both is near them.
- **Marches.** A keeper's view of the world lists the marches they may
  know of: for each of their companies on the march, the way it will go,
  where it is bound and the watch it should be there; for a host of their
  side, or one marching on a hold of theirs, the hold and the watch each
  company should be in reach of it; and for any other company in their
  sight on the march, the way it goes as far as they see it, never where
  it is bound. The ways are worked out on the keeper's own view of the
  land, so none bends round what they can't see.
- **Holy sites.** As the world is made, the lake is given its holy
  sites, one for every two seats and two at least, on open land at least
  five tiles from any hold and seven from each other: Moonwells (+8%
  attack to every company of the side that holds one), Still Stones (+8%
  defence) and Salt Altars (+15% gathered at the land's sites). A House
  takes one when a company of war of its stands on it as the watch turns
  with no foe at war beside it, and holds it until another does; what it
  gives, it gives the holder and its whole alliance. No hold is raised on
  one, and neither the wilds nor the land's sites rise there. Everyone
  hears when one changes hands (the chronicle, the age's story, is spared
  a line for each); each is drawn in the world as a ring of
  standing stones about its heart, its pennant in its holder's colour,
  and listed in the Realm (6).
- **The Infirmary.** A work every hold can raise, with two beds at its
  first level and one more at each level after. A House's company of war
  that falls (in battle, to a hold's walls, or to the wilds) is carried to
  the nearest of its holds with a bed free, if one has, and kept there as
  it was, its tier and rank with it; Founders and Lanterns aren't. From
  the hold's panel the keeper heals those waiting, as many as the House's
  stores pay for, each for half what mustering it anew would cost; healed
  companies rise whole beside the hold as the watch turns, their rank
  kept, their commander not (it is carried home wounded, as ever). A hold
  taken loses those in its beds. Only its own House knows who lies there.
  Stewards raise one at the seat once they muster, a larger one at war, and
  heal their fallen first. Each level has its own model: a lamplit ward of
  timber and thatch with its herb garden, then slate, a chimney for the
  healers' fire and linen drying on a line, a ward of pale stone with a
  round apse and a well, a covered walk with lanterns, and at the fifth a
  bell-cote and a moonsalt lamp. The healers' work has its own sound.
- **Alliance land.** A House of an alliance raises a standard on open
  ground it has explored, within four tiles of the alliance's holds,
  standards or hall and more than three from any other House's hold, for 60
  timber, 40 stone and 2 moonsalt: the land two tiles about it is the
  alliance's. There the alliance's companies stand a tenth firmer, mend
  five more each watch and gather a fifth more at the land's sites. An
  alliance keeps one standard, and one more for each of its Houses, eight
  at most (two more while its hall stands); no two alliances' lands
  overlap, and no hold is founded on a standard's ground. A standard has a ward of 60
  that mends ten a watch; a House at war with the one that raised it
  strikes it and tears it down when it breaks, as the chronicle tells. A
  House gone from the alliance, or fallen, takes its standards down as the
  watch turns. Stewards of an alliance with stores to spare raise one now
  and then where its land takes in the most sites of the land, and tear
  down a foe's within reach. Each standard is drawn in its alliance
  leader's colour, a tall swallow-tailed banner over a cairn with braziers
  burning; its ground, and the land about it, are named on hover; a
  ground's panel raises one, and the Alliance screen counts them.
- **Lairs of the wilds.** From the twelfth watch the realm raises lairs
  far out in the country, one every five watches while fewer stand than
  one for every three seats (two at least), on open land at least seven
  tiles from any hold and six from a holy site or another lair: a Salt
  Hollow, a Reavers' Stockade, a Barrow Hall, a Hunters' Eyrie or a
  Drowned Chapel, by the ground it rises on, of levels I to V, the later
  in the age the higher (200 to 1,800 strength). Nothing walks through
  one, and no company alone can strike it: a House of an alliance calls a
  rally against it from its hold with a Muster Hall, at peace or at war,
  and the host strikes it together, arrows first, those beside it taking
  its blow back. Broken, it is gone; its spoils are shared among the
  host's Houses by the companies each brought up to it, its caller finds a
  piece of gear among the ruins, the commanders learn from it, the Long
  Hunt counts it for the caller, and the chronicle tells it. A lair that
  holds mends a twentieth of its strength each watch. A House knows the
  lairs on ground it has explored; the host and those watching hear each
  strike. Stewards with companies to spare and no foe to rally on rally
  on the lowest lair they know near a hold with a Muster Hall, and send
  their companies to their side's lair rallies. Each lair has its own
  model, with its fire smoking or its cold light burning; it is named on
  hover, its ground's panel shows what stands of it and calls the rally,
  and each blow on it is drawn and reported.
- **Alliance studies.** An alliance studies together. Its leader chooses
  one of six studies to pursue from the Alliance screen (Fieldcraft,
  Masons' Compact, Drill Yards, Oath of Steel, Shield Oath and Shared
  Scrolls), and every House of it gives stores toward its next grade, fifty
  of a store or five moonsalt at a time; once the gifts together pay for
  a grade, it is learned at once and raises every House of the alliance:
  more gathered, works and musters sooner, every company of war striking
  harder or standing firmer, studies sooner, three grades a study. Every
  300 given, in barter worth, brings the giver a Salt Hourglass. What an
  alliance studies, and who gave what, is its own Houses' to know. A
  steward that leads an alliance chooses a study by its temper, and every
  steward of one gives a tenth of what it holds beyond plenty, one watch
  in three.
- **Alliance hall.** An alliance's leader begins its hall, its fortress,
  on open ground of the alliance's own land (within reach of its
  standards), more than three tiles from any other House's hold and clear
  of other alliances' land, for 200 grain, 400 timber, 400 stone and 20
  moonsalt; an alliance has one. It rises over four watches, its ward with
  it from 40 to 240. Whole, the land three tiles about it is the
  alliance's, the alliance's companies keeping it stand a quarter firmer,
  the rallies its Houses call take two more companies, and the alliance
  may keep two more standards; its ward mends fifteen a watch. Only the
  alliance's companies enter it or pass through it; a House at war with
  any of its Houses strikes it when none keeps it and tears it down when
  its ward breaks, and a hall whose alliance is no more falls into ruin.
  When it falls, its alliance's rallies send home the companies they no
  longer have room for. A steward that leads an alliance with stores to
  spare begins one from the fortieth watch on its land nearest its own
  holds; stewards at war tear down a foe's hall left unkept. The hall is
  modelled: a timbered hall on a platform of dressed stone, its roof, its
  tower's cone and its banners in the leader's colour, braziers burning at
  its door and smoke from its louvre; it rises from its platform within a
  scaffold, a watch's height at a time, the dust of its building about
  it, and burns when struck low. It is named on hover; its ground's panel
  describes it or, to the leader, begins it; the Alliance screen tells how
  it stands; and each of its happenings has its sound and its place.
- **Alliance coffers, storehouse and yards.** An alliance keeps coffers of
  its own, up to 2000 of each common store and 100 moonsalt: each of its
  standards yields them 5 grain, 5 timber and 5 stone a watch, its hall
  standing whole 15 of each and a moonsalt, and its yards a tithe. Whatever
  its Houses raise for it, standards, hall, storehouse and yards, the
  coffers pay for first and the House raising it the rest; what they hold
  is its own Houses' to know. Its leader raises a storehouse on its land
  (100 grain, 250 timber, 250 stone, 5 moonsalt), rising over two watches;
  whole, each of its Houses may lay up to 600 of each common store and 50
  moonsalt there from the Alliance screen, beyond its own storage and out
  of any taker's reach (a hold taken gives up only what its House keeps at
  hand), and take it back when it will; a House that leaves the alliance
  takes back all it laid up. Only the alliance's companies enter it; a
  House at war with one of its Houses strikes it when none keeps it, and
  tearing it down carries off what was laid up in it, as much as it can
  keep. Its leader also raises yards on its land, one of each store, for
  80 grain, 150 timber and 150 stone: a Tilled Acre, a Timber Yard, a
  Quarry and Salt Works, richer than the land's own sites (1500 of a
  common store, 300 moonsalt), that the alliance's companies alone work, a
  quarter faster than anywhere, the coffers taking a tenth more besides;
  an alliance gone, its yards go with it. Stewards raise yards from the
  thirtieth watch and a storehouse from the forty-fourth, lay up what they
  hold beyond seven tenths of their room and take it back when a store
  runs under four tenths, and work their own alliance's yards and no
  other's. Each is modelled in the alliance's colour: a long timbered barn
  with great strapped doors, a lean-to, sacks, barrels, planks and dressed
  stone before it and a hoist whose pulley turns and sack swings; a fenced
  acre with its granary on staddle stones and a scarecrow; log stacks, a
  sawpit and sheerlegs swinging a log; a quarry face cut in benches under
  a slewing derrick; salt pans, a well whose windlass turns and a boiling
  house whose fire leaps and chimney smokes. They are named on hover and
  to VoiceOver, raised from their ground's panel, told on the Alliance
  screen, and heard as they happen.
- **The Forge.** A work of five levels where a House's smiths work makings
  into gear of three sets: the Warden's Harness, the Raider's Kit and the
  Pathfinder's Gear, each a weapon, an armour and a charm. The makings are
  hide, iron, heartwood and moonglass: a company of the wilds leaves a
  piece of its kind's for each of its levels as it falls, a lair broken
  leaves three a level to every House of the host, and a company bringing
  in what it gathered brings a piece for every forty of grain, timber or
  stone, or every eight of moonsalt; a House keeps two hundred of each. A
  piece is forged from Commanders (4) for its makings and moonsalt, as fine
  as the House's highest Forge allows (plain at level I, fine at II,
  masterwork at IV, fabled at V, each finer twice the makings), every
  level above the first taking a tenth fewer makings. Two pieces of a set
  worn by one commander give its company more besides what each gives,
  all three more still. Stewards raise a Forge at their seat from the
  twenty-fourth watch, forge the set that suits their foremost commander a
  piece at a time, and arm a piece of it before another as fine. Each
  level of the Forge has its model: an open hearth under a lean-to, its
  coals glowing, a trip hammer beating on the anvil, growing into a stone
  smithy with bellows, a quench trough, a second hearth and a stand of
  mail, and at the fifth a moonglass furnace, a turning grindstone and the
  House's banner on its chimney; smoke rises from its chimney, and forging
  rings with three blows of the hammer.
- **Favour.** A keeper's favour with the lake, won each watch they keep
  in the realm (there as it turns): ten favour a watch, two more for
  every watch kept unbroken before it up to ten of them, a watch away
  breaking the streak. Favour raises the House they hold by levels, I at
  60 to X at 9000: each level 2% more gathered at the land's sites, works
  and studies 2% sooner, and musters 1% sooner. Every tenth watch kept
  unbroken brings a favour chest: a Salt Hourglass; from the fourth level
  caches of grain and timber; from the seventh a cache of stone and a
  Mending Draught; at the tenth a Ward Stone and a cache of moonsalt. It
  is the keeper's across ages, their House standing as high as it from
  the watch they take their seat; the Realm screen shows their level,
  what the next asks, their streak and when the next chest comes, and
  each level risen is told and heard.
- **The Sundering.** Kingdom against kingdom: from the fifty-fifth watch,
  and every ninety after, the lake's Houses stand for twelve watches as two
  kingdoms, the Eastern and the Western Shore, each by where its seat
  stands as it begins (a House fallen before it stands with neither).
  The shores take up arms: every House at peace with one across the
  water, but one sworn to its alliance or its liege or vassal, is at war
  with it until the Sundering ends, a war neither declared, laid down as
  it ends if still fought. Deeds across the shores score for the
  striker's kingdom and House: a
  point for every hundred troops of the other shore slain and five for a
  company felled, twenty-five for a hold taken, and five, thirty and
  twenty for a standard, a hall and a storehouse of the other shore's
  alliances torn down. When it ends, every standing House of the kingdom
  ahead is given 150 grain, timber and stone, 10 moonsalt, two Salt
  Hourglasses and a Ward Stone, and its foremost House is hailed its sword
  with a hundred more of each; a draw gives no spoils. It is told and
  heard as it begins and ends, kept on the Realm screen (your shore, your
  points, how the shores stand, or how the last ended), and its tally is
  known to all. The Frontier's shores never sunder: its kingdoms are the
  realms its keepers come from.
- **The Frontier.** Kingdom against kingdom across realms: the Frontier is
  a realm of its own, a database of its own with its own steward, where
  the kingdoms of the realms that border it meet, a season of twenty-four
  watches at a time. While a season is open there, a keeper presses Cross
  to the Frontier on the Realm screen: their realm takes the order, lists
  them as crossing with a levy of their House's strongest companies of
  war, up to six, and the app takes them across to the Frontier's database
  by the same identity (only ever on the same server), where a caretaker
  keeps their House at home. The Frontier seats no one its bordering realms
  don't list: each keeper's House stands there for their realm's kingdom,
  in their people's way, with their levy raised about its seat and at war
  with every other realm's House from the first; the Lost Shore's own
  Houses stand for none. A point for every hundred troops of another
  realm's kingdom slain, five for a company felled and twenty-five for a
  hold taken count for the striker's kingdom and House. As the season
  ends its result is kept in the Frontier's status, a new season begins
  with no one seated, and each realm's steward reads it and tells it home
  once: every keeper who crossed is home again, and the Houses of the
  kingdom that prevailed are given 300 grain, timber and stone, 20
  moonsalt, two Salt Hourglasses, a Ward Stone and a Mending Draught, and
  a title, Of the Frontier; a keeper who struck for a kingdom that didn't
  prevail brings home a hundred of each. The stewards never share a world:
  each reads the others' public status, as any keeper may, every five
  seconds; a realm lists its crossings there, and the Frontier its season
  and its last result. Return Home brings the keeper back; when the season
  ends they are taken home.
- **Troops.** A company is so many troops at its first muster, by its
  kind and tier: Spears 1,200 at the first tier to 2,400 at the fifth,
  Bows 1,000 to 2,000, Riders 800 to 1,600, Lanterns 60 and Founders 250,
  and those drilled into it since, as many standing as its health is a
  share of. Every battle counts the troops each side slew and lost, and
  its report, its tidings and its notice tell them; a company's panel
  shows its troops standing, and the Realm screen the House's army, all
  its companies of war together.
- **Drill.** A company of war standing at or beside one of its House's
  holds with a Muster Hall drills there when ordered (Drill, on its
  panel), taking on troops as each watch turns while it stays: half its
  first muster for each of the hall's levels, for twelve grain a first
  muster's worth at the first tier, dearer by tier as mustering is. It may
  lead its first muster once, eight times more for each level of its
  House's best Muster Hall, and once more for every three levels of the
  commander at its head: Spears of the fifth tier, with a Muster Hall V
  and a commander of the thirtieth level, lead 122,400. No hall drills
  troops its House's grain can't feed: none while its grain income would
  not cover what its companies eat, each a quarter as much again for every
  first muster drilled into it. Every troop counts, each the less the more
  there are: a company fights others the harder as the square root of its
  muster over its first (nine times its first muster, three times as
  hard), and weighs as much more in its House's strength; walls, wards and
  the wilds are struck as before. Drilled, a company stands in more
  figures on the map, Spears and Bows up to sixteen, Riders four abreast;
  its panel says how it drills and how many it may lead, and it crosses to
  the Frontier with its troops. The stewards drill those who wait beside
  their halls, but a steadfast or wary House raising its Moonspire keeps
  its grain for the tower while it is at peace. In 32 ages of eight
  stewards, a realm's armies came to 770,000 troops at the median as the
  age ended, against 209,000 on the same lakes before drill, and its
  greatest battles to 26,000 troops at the median and 55,000 at the most,
  against 10,000 and 18,000. The ages ran longer, 136 watches at the
  median against 107; the Moonspire decided 14 of them, against 10 before,
  and one of the 32 had no end by the 240th watch.
- **Heritages.** Every House comes of one of the lake's six peoples,
  dealt round the lake as an age begins, from a seat the seed chooses, so
  each has its seats: the Saltborn (half again the moonsalt from their
  holds; wards that mend half again as fast), the Fenfolk (Bows that strike
  a tenth harder; companies that see a tile further), the Blackwood Kin (a
  quarter more timber; Riders a tenth harder), the Spinewardens (a quarter
  more stone; Spears a tenth firmer), the Mound Clans (commanders who
  learn a quarter faster; studies a tenth sooner) and the Strandfolk (a
  quarter more grain; a fifth more gathered at the land's sites). Each has
  a company of its own at the fifth tier, the Salt Wardens, Reed Bows,
  Wood Riders, Spine Guard, Barrow Riders and Strand Bows, a twentieth
  stronger and firmer than others of its kind and named so wherever it is
  shown. A keeper takes up another heritage from the Realm screen, the
  first time freely and after that for 30 moonsalt; every House hears of
  it and the chronicle keeps it. The seat briefing and the Houses screen
  say what each House comes of, and stewards able to muster their own
  company at the fifth tier reach for it more often than not. Each people
  raises its keeps its own way: the Saltborn in salt-white stone crowned
  with moonsalt, the Fenfolk in weathered timber under steep reed, the
  Blackwood Kin in dark timber under steeper shingle, the Spinewardens in
  raw rock under a low slate roof, the Mound Clans in pale stone under
  turf, the Strandfolk whitewashed under sea-slate with a beacon burning
  on the parapet; a House that takes up another heritage raises its keeps
  anew.
- **The satchel.** Each House keeps items to use when it will, twenty of
  a kind at most: a Salt Hourglass brings a hold's work and muster a watch
  nearer, or the House's study (never its last watch: what is done is done
  as the watch turns); a Cache of Grain, Timber or Stone opens into 120 of
  it, a Cache of Moonsalt into 20, while the stores have room; a Ward Stone
  makes a hold's ward whole; a Mending Draught mends every hurt company of
  the House by 30. The charges bring them, the first steps hourglasses to
  learn by; each mark of a happening brings an hourglass or more, and its
  three foremost more again; a lair broken gives its caller an hourglass
  for each of its levels, and every House of the host a cache of what its
  wilds carry most of. Only its own House knows what is in a satchel. The
  Realm screen lists it and uses what works on the House; a hold's panel
  offers an hourglass while it has something under way and a ward stone
  while its ward is broken. Stewards turn an hourglass a watch on their
  works, their seat's first, mend a ward under half, open caches their
  stores can take, and share out a draught when three companies or more
  are badly hurt. An hourglass sounds as salt running out and a small
  glass chime.
- **Scouting.** Lanterns standing within two tiles of another House's
  hold scout it, at peace or at war, for all their moves. Their report
  goes to their House alone: every company of war at its gates (its own
  and its allies' keeping them), each with its tier, strength, rank and
  the commander leading it; its ward; the work it raises and the company
  it musters, with the watches left; the stores its taking would carry off
  (half a seat's, a hold's share otherwise); and how many lie in its
  Infirmary. It is filed among the Chronicle's Reports and shown on the
  hold's panel, beside a Scout button that sends the nearest Lanterns with
  moves left. The hold's House hears that it was watched, and both see the
  Lanterns' cold light circle the hold. At war, a steward's Lanterns
  within reach of a foe's hold scout it one watch in four.
- **Paces.** A realm's watch isn't resolved all at once as it turns; it
  passes in twelve paces. At each, every company on the march takes its
  share of the watch's moves, a step at a time, and every host on the
  march walks on and strikes the moment it is there; each steward gives
  its orders at a pace of its own, spread through the watch. Keepers see
  the steps as they are taken. A march keeps its way: found as the
  company sets out and walked pace by pace, it is sought anew only when
  its next step is shut, by a company come to stand in it, a hold fallen
  to another House or the wilds, and the company goes round; the realm
  keeps it, and no keeper's view carries it. As the watch turns,
  whatever the paces left (the watch turning early, a way shut for a
  while) is walked first, so a march goes as far in a watch as ever; the
  last pace is the turn's own.
  A battle goes on through the watch, as a field of battle (below).
- **Fields of battle.** In a realm, a strike on another House's company
  joins battle there, a field of battle that goes on pace by pace and takes
  in whole armies. Every company that strikes or is struck within five
  tiles of where it was joined fights in it on its House's side; a House
  new to it takes the side none of whose Houses it is at war with, so an
  ally striking in fights beside its ally, and a House at war with both
  sides joins battle anew. At every pace each company standing in it
  strikes a foe of the other side within its reach, arrows first: the one
  it fights while it can, else the nearest, the weakest first; so a company
  struck strikes back if it can reach its striker, and holds its ground
  doing it, while one sent against its foe takes the fallen's ground as
  ever. Its Houses' companies of war standing near it with no march or
  errand, and a foe of it in their reach, come into it. A company that
  marches off or leaves its span draws off. It is over when a pace passes
  without a blow, when one side has none left standing in it, or after two
  watches; the side still in it holds the field. Its blows are seen and
  heard as they fall, but told as one: battle joined, and its end, with
  each side's companies and troops, the troops slain and lost and the
  companies fallen in a report for every House that fought in it, its own
  companies one by one. A battle of six companies or more is the
  chronicle's. On the map, crossed blades stand over each field with the
  troops each side has standing there, and every company in it shows its
  troops; hovering it names the sides, VoiceOver lists it, and a company's
  panel says the battle it is in and how its sides stand. In an age of
  eight stewards, a hundred and seventy fields are fought in ninety
  watches, the greatest of eleven companies.
- **Happenings.** From the tenth watch, and every thirty after, the realm
  holds a happening for ten watches: the Long Hunt (companies of the wilds
  struck down, the greater the more), the Harvest Fair (stores brought home
  from the sites), the Raising (works raised, the higher the more), the
  Great Muster (companies mustered, by tier) or the Learned Season (grades
  of study learned), in turn from one the realm's seed chooses. Every House
  earns points by it; passing 10, 25 and 50 points brings stores as the
  watch turns; when it ends the three foremost are honoured in the chronicle
  and given stores. Its standings are known to every keeper. In a Long Hunt
  ambitious and cunning stewards hunt further afield; in a Harvest Fair the
  steadfast and the wary gather any store they have room for.
- **Might, deeds and charges.** A House's might sums its companies of war
  and walls, its works, its learning and its commanders; every keeper sees
  every House's might, and the Houses ranked by it. Thirteen deeds may be
  done once an age (Founder, Wildbane, Great Hunter, First Harvest, Scholar,
  Fifth Tier, Great Walls, Sworn, Host Triumphant, Conqueror, Honoured,
  Veteran Commander, Spire Begun), told as the watch turns. Every House is
  set eleven charges in turn, first steps from raising a Granary to a
  Muster Hall III and a company drilled there to twice its first muster,
  each bringing stores as the watch turns after it is done; the
  stewards meet them as they play. The ambitious weigh might, not arms
  alone, in choosing an alliance or an ally.
- **Renown.** As an age ends, each keeper who held a House in it is
  remembered in their own record: five renown for each deed their House
  did, ten if it stood at the end, fifty and a title for the age's victor,
  and its deeds join those of their other ages. Nothing else carries into
  the next age: there every House begins alike.
- **Words.** A keeper says a line to every keeper of the realm, or to their
  alliance alone: plain words, a hundred and forty letters at most, with no
  addresses, twenty lines a watch. The realm keeps the latest eighty; an
  alliance's words reach only its own Houses.
- **The world first.** The map is the screen; the interface keeps to
  its edges and comes when it is wanted. The top bar is three small
  islands, the House and the watch, the stores, and Ready, with the
  world between them. Every panel is on one rail in the corner, and
  nowhere else; the small map of the lake comes when the rail's Map asks
  for it. A notice shows for a few moments as it comes and fades (VoiceOver
  says each; the Chronicle keeps the realm's story); the charge before the
  House is a line, its name and Show me, until More asks how and what it
  brings; counsel speaks only when no charge does; envoys wait behind the
  one being heard, a line each; the keys are shown only while the first
  steps are taught.
- **The screens.** Each system has its panel, on a key, in the Watch menu
  and on the rail in the corner: the Archive (3) with the whole
  tree of studies, each grade's gain, price and time and why one can't be
  begun yet; Commanders (4), each with its level, experience and skills, set
  at the head of the company chosen or called back; Alliance (5), to raise
  a banner, ask, invite, answer, help, keep an ally's gates and send a
  company to a rally; the Realm (6), with the happening under way and its
  foremost, the charges kept, every deed, might and renown; and Words (7).
  The Chronicle switches to the House's battle reports: each battle and
  each blow on the wilds, how it came out, who struck whom, the blows and
  the fallen. A small map of the whole lake, on the rail's Map; a click
  there carries the view. Training chooses the tier; an enemy hold's panel
  calls a rally against it; a company says its tier, its commander and what
  it was sent to do;
  the wilds and the sites are named on hover and read to VoiceOver. Once
  the first steps are done, the charge before the House sits in the corner,
  its name with Show me to open the panel or choose what keeps it, and,
  asked for more, how to keep it and its reward: the first hour, taught in
  play.
- **Houses.** Other Houses are held by keepers, or by stewards with
  temperaments: ambitious, steadfast, wary or cunning. Declare war, offer
  peace or a pact, and answer envoys. Pacts share sight; breaking one is
  remembered. A steward makes no peace before it has had a watch of its own
  at war, and one far the stronger none until the war has run past thirty
  watches, whatever you gave it. A steward's garrison strikes only
  companies of war at its gates, and its army meets those that come close,
  but no scout draws it off a siege.
- **Conquest.** Taking a hold carries off its share of the loser's stores;
  a seat holds half of them. A House that loses its seat is shaken: every
  hold it has left loses most of its ward. A House that loses every hold
  falls, and its name passes into the chronicle.
- **Winning.** Raise the five stages of the **Moonspire** at your seat
  (ascendancy), or rule the lake (dominion): five of every twenty holds and
  at least ten, your vassals' counted with your own, or be the last House
  standing. Stewards fear every rising Moonspire and will march on it, and
  begin one only with the holds to store its last stage, or as the most
  renowned House on the lake.
- **Fealty.** A steward's House that loses its seat with four holds or
  fewer left, and no vassals of its own, bends the knee to the House that
  took it, if that House is sworn to no one; and a beaten House may offer
  fealty rather than fall. A vassal's holds count with its liege's, and it
  can never turn on its liege, nor win, nor raise its Moonspire while it
  serves: the works on its tower stop when it bends the knee. A liege who
  turns on a vassal frees it, and a liege's fall frees all its vassals.
- **How ages end.** In 48 ages of a realm as it stands by default, twelve
  seats on a lake of radius 36, played through by stewards alone, pace by
  pace, under the rules as they now stand, the shores at war in every
  Sundering, a field of battle five tiles about its heart, each level of
  a Muster Hall leading eight first musters more and every march keeping
  its way, the Moonspire decided 44 and dominion 4; an age ran 153
  watches at the median and 217 at the longest, and more than a quarter
  saw a House fall outright. The seats won alike, within chance (χ² 10.0
  on 11 degrees of freedom), and so did the tempers (χ² 1.5 on 3), the
  ambitious 21%, the cunning 31%, the wary 21% and the steadfast 27%, the
  Moonspire most of all for each: the four dominions went two to the
  cunning and one each to the ambitious and the steadfast. A realm's
  armies came to 1,870,000 troops at the median as its age ended, and its
  greatest battles to 79,200 troops at the median and 138,400 at the
  most, over 100,000 in ten of the ages.
- **Tribute.** From watch twenty, an ambitious or cunning steward a quarter
  stronger than a neighbour may demand a fifth of its stores. Paid, it keeps
  the peace for twenty watches, unless that neighbour's Moonspire rises;
  refused or ignored, it marches. You can demand tribute too: a steward
  that refuses you is at once at war with you, the war of your making; a
  keeper who refuses you owes nothing more, and war is yours to choose.
- **The race.** The Houses panel shows each House's holds towards dominion
  and its Moonspire's stages, and the game warns you, once, whenever any
  House comes near the end of either road. At the end of an age, a chart
  tells its story: every House's holds, watch by watch.
- **Battle.** Attackers lean into their blows, the struck shake, Bows'
  shots cross the gap, and the fallen fade where they stood.

- **Voices.** Envoys speak to you, and a chronicler writes beneath the
  moments that touch your House, in words written on your Mac by Apple's
  on-device model. They only speak; the rules decide everything.

- **Sound and music.** A cold drone and the night wind over the water, a
  low bell as each watch turns, and quiet cues, all synthesised as they
  play. Beneath them an original score is written as it plays: slow chords
  in D minor drifting under a sparse line of bell-like notes, joined at war
  by a distant drum and darker chords. ⇧⌘M turns all sound off, ⇧⌘U the
  music alone, and Settings (⌘,) sets each part's volume. Each kind of
  company sounds its own: Riders' hooves, a loosed bowstring, the clash
  of a blow struck in close, heard as well when the blow falls on yours.
  A company lost or hungry, or a seat lost, sounds dread; a work or company
  finished, a company risen in rank or a drowned ruin searched rises; a
  gift received, a peace or a pact sounds accord; and an order that begins
  a war sounds as war, refusing a steward's tribute too. What a watch
  brings sounds one after another after its bell, never all at once, and
  the low sounds carry overtones a laptop's speakers give. A sound is
  heard from where it happened: a battle to the left of the view leans
  into the left ear, one far beyond the view's edges is fainter, and the
  view turned turns the sound with it; what has no place (an order, the
  watch's bell, a choice) sounds in the middle. While a field of battle
  is in sight its din rises under the night: a clamour of voices, the
  tramp of feet and steel ringing on steel, as loud as the troops fighting
  there (twelve thousand or more as loud as it gets) and as near as the
  view stands, heard from where the field is across the view, easing in
  and out as battles are joined and end; it plays at the ambience's
  volume, and is still under the stillest motion. Sound fades out with
  the picture, and as the app quits, and back in from silence.
- **The advisor.** The House's steward reads each new charge aloud as it
  comes, what it is and how to keep it, in the Mac's own voice, a little
  low and unhurried; the first as the keeper enters the world. It is
  silent while VoiceOver speaks (which reads the charges itself), while
  the sound is off, or when Settings says so, and never says the same
  counsel twice running.
- **Watchmen.** When an enemy's companies gather near one of your holds,
  you're told, and a broken red ring marks the hold on the map.
- **Holds that grow.** A hold raises a side tower after a few works and a
  second after many, so a glance at the map shows which holds are built up.

Larger text (Text in either Settings, or ⇧⌘+ in the Watch menu) sets all
the type a fifth larger, the launcher's and the game's, none of it under
twelve and a half points; the panels grow to hold it. Every text reads by
one rule of contrast, in the launcher as in the game, made so that even a
full stop or a middle dot, a pixel or two across on a 1x display, stands
clear of the dark: solid, never fainter than nine tenths of the ink (the
full ink with Increase Contrast), on panels that are wholly dark, never
over the map showing through; words never under eleven points and spaced
capitals never under nine and a half; nothing under fourteen points
thinner than regular, nor under twelve lighter than medium. A House's
colour colouring words is lifted toward the ink to read at ten to one.
Xcode's accessibility audit holds every screen to it, and the type it
calls faint is measured from the screen's own pixels by WCAG's formula
(`scripts/ui-test.sh`).
VoiceOver reads the map, the panels and every notice.

Each age's lake grows from the realm's private words; the realm keeps the
world, so there is nothing to save.

| Key | Action |
| --- | --- |
| Click | Select a company, hold or tile |
| Right-click | March the selected company there, strike the enemy or the wilds there, or gather at a site of the land. Hovering an enemy in reach shows the battle's odds first |
| Drag, two-finger scroll | Pan; pinch, ⌘-scroll or a mouse wheel zooms |
| Tab or . | Next company waiting for orders |
| ] / [ | Every company in turn, forward or back, marching, fortified or spent too |
| H | Your holds in turn, the seat first |
| Space or Return | Choose whatever lies in the middle of the view, as a click there would |
| F / B | Fortify / found a hold with the selected Founders (B asks, B again founds) |
| M | March the selected company to the middle of the view; to strike there, M shows the odds and M again strikes: play without a pointer |
| Arrows or WASD, + − | Pan, zoom |
| Page Up / Page Down | Scroll the open panel, or the chosen hold's |
| 1 / 2 / ? or ⌘? | Houses / Chronicle / Guide |
| 3 / 4 / 5 / 6 / 7 | Archive / Commanders / Alliance / the Realm / Words |
| Esc | Close a panel, then clear the selection |
| ⌘↩ | Ready: done with this watch's orders (click Waiting to take it back) |
| ⇧⌘↩ | Stay ready until something needs you, up to ten watches |
| ⌘, | Settings: display and text (the launcher's), sound and volumes, letter keys alone or with ⌥, counsel |
| ⇧⌘M / ⇧⌘U / ⇧⌘+ | Sound on or off / the music / larger text |
| ⇧⌘W | Leave the world for the front door |

## Design

A full moon hangs over a great black lake. The water below gives it back
whole, still as black glass. Pale, thin type rests above the far shore. The mood is
vast, quiet and monumental, after the grand, minimal look of the Dune films.
There is no music in the launcher; the game makes its own sound as it plays.

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
  [`LakeShader.swift`](Sources/LauncherKit/Backdrop/LakeShader.swift), so plain
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

### The world in three dimensions

- **The land** is a mesh with relief, drawn by Metal from
  [`WorldShaders.swift`](Sources/NullmereWorld/WorldShaders.swift): the Spine's
  ridges, the barrows' mounds, the strand and the flats, and the still
  lake laid over it as a mirror of the stars and the moon. What the keeper
  has never seen lies under mist; what they saw once and see no longer,
  greyed as memory.
- **Every model is original and built from code**
  ([`Sources/NullmereModels`](Sources/NullmereModels)): each kind of company
  in its five tiers, the wilds and six commanders, keeps, walls and every
  work at every level, the land's firs, birches, heather, ferns, crags,
  reeds, pebbles, mounds and ruins, and what moves through the world.
  Companies stand in formation, fewer as they are worn down and more as they
  are drilled; holds lay out their works on the land around the keep. Near,
  the models show fine work that is left off from afar, where it is too
  small to see: a keep's quoins, framed windows with shutters in its House's
  colour, roof ribs, a half-timbered hall with a capped chimney, a log pile
  and a handcart (a seat's keep is 2,728 triangles, where it was 778); the
  walls' arrow loops, string courses, wall-walks, tower slits and finials,
  and iron bands on the gate; on every hall and round house of the works,
  courses across the roofs, boards and vents in the gables, hoops and
  finials; and in every work's yard but the Moonspire's, its odds and ends,
  barrels, crates, sacks, a bucket, a bench and stacks of logs, set down
  where nothing of the work stands and clear of the way to its door.
- **Only what the view reaches is drawn.** The land's furniture is kept
  on the GPU in square regions eight hexes on a side, each with the bounds
  of all it holds; each frame finds the regions inside the camera's view
  and draws just their runs of each kind. Near, over the realm proper's
  lake, a frame draws 7,600 of its 19,300 pieces; over a lake of
  forty-eight seats, 10,500 of 76,000, so a wider realm costs a near view
  little more than the realm proper's: on CI's Mac, 12.6 ms of the GPU
  where drawing all of it took 23.3 ms. The holds, their towns and the
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
  ([`Painting`](Sources/NullmereWorld/Painting.swift)): its colours laid
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
  back, at a walk their feet hold the ground at. They keep within a hold
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

### Tuning the scene in a browser

The scene section of the shader is written in the subset shared by Metal and
GLSL, so it can be previewed without rebuilding the app:

```sh
python3 -m http.server
# open http://localhost:8000/Tools/scene-preview/
```

Query parameters: `horizon`, `activity` (1 for full motion, 0.4 reduced,
0 still) and `time`, which freezes a moment. Try `?time=7.2` to catch the
first falling star.

The world's shaders are written the same way: the section between their
SCENE markers is shared by Metal and GLSL, so a browser draws the land,
the mist and the still water from the same code, over a world the
NullmereWorld tests write out (Playwright's Chromium draws it headless):

```sh
NULLMERE_WORLD_PREVIEW=build/world3d swift test --filter WorldPreviewTests
node Tools/world3d-preview/shoot.js build/world3d/world.json world.png seat   # or lake, whole, turned, moon, close, company
```

The models are previewed the same way: `NULLMERE_MODEL_PREVIEW=build/models
swift test --filter PreviewTests`, then `node Tools/model-preview/shoot.js
build/models/samples.json models.png "light=night"`. Away from a Mac,
`Tools/msl-check/check.sh <shader.metal>` parses Metal source with clang
for its syntax, names and types.

## Layout

```
Package.swift
Sources/
  LauncherCore/       Platform-independent logic: settings, navigation, news, model readiness, composition
  LauncherKit/        SwiftUI interface, Metal backdrop, services (on-device model, news)
  NullmereLauncher/   The Nullmere Online app's entry point
  NullmereCore/       The rules and the realm's authority: world generation, economy, war, diplomacy, stewards, keepers, watches, ages. Pure, deterministic Swift
  NullmereModels/     The world's shapes: the land's relief and mesh, and every model in it built from solids in code, with the rigs that move them. Pure Swift
  NullmereWorld/      The world as the GPU draws it, apart from the GPU: the camera, the shaders' source, the frame's data. Pure Swift
  NullmereRealm/      The client's line to the realm over SpacetimeDB or in-process, the steward, keeper identity. Foundation only
  NullmereKit/        The world's interface: front door, Metal world, panels, sound
  NullmereSteward/    The steward's command-line entry point
Tests/                LauncherCoreTests, LauncherKitTests, NullmereCoreTests, NullmereModelsTests, NullmereWorldTests, NullmereRealmTests, NullmereKitTests, and NullmereTestSupport (a SpacetimeDB in memory)
realm-server/         The SpacetimeDB module (Rust): keepers, requests, answers, the world
Dockerfile.steward    The steward in a container, as raise-realm.sh runs it
news/                 news.json, the launcher's news feed
perf/                 CI's performance baseline; scripts/measure-mac.sh adds figures from real Macs in perf/mac/
Packaging/            The Info.plist template, the Liquid Glass icon (AppIcon.icon) and the classic 1024 px icon
scripts/              Building, packing and checking a release; smoke tests; raising the realm; going live
Tools/icon/           Draws the icon, its Liquid Glass layers and the classic one (make-icon.py)
Tools/scene-preview/  Browser preview of the lake shader
Tools/world3d-preview/ Browser preview of the world's land, mist, water and staged models, from the shaders' shared section
Tools/model-preview/  Browser preview of the models, on a sheet
Tools/msl-check/      Checks Metal source with clang away from a Mac
docs/                 Going live; the consistency audit of October 2026 (docs/audit/); the plan made before the build for what carries over from Warpkeep
```

## Direction

- **Client:** native Swift on macOS, using SwiftUI and AppKit for the
  interface, and Metal for the lake and the world.
- **Server:** [SpacetimeDB](https://spacetimedb.com) as the authoritative
  multiplayer backend, as it was for Warpkeep.
- **Characters:** non-player characters voiced by Apple's on-device model,
  through the Foundation Models framework. They never decide outcomes or
  grant stores.
- **Character:** open source and pseudonymous, executed with restraint.

[What carries over from Warpkeep](docs/warpkeep-carryover.md), a plan
written before the build, covers the universe, principles and asset
licensing, and says where the build went another way.

## Licence

- Code is licensed under the [Apache License 2.0](LICENSE).
- Original art and documentation, including the app icon, are dedicated to
  the public domain under [CC0 1.0](LICENSE-CC0-1.0).
- The names Nullmere Online and Nullmere, and nullmere.online, identify the
  official project. Neither licence grants rights to them.
