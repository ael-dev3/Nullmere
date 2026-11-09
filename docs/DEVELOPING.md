# Developing Nullmere Online

Building, testing, releasing and previewing the game, and where its code lives.

- [Building](#building)
- [Releasing](#releasing)
- [Tests and checks](#tests-and-checks)
- [Debug builds](#debug-builds)
- [News](#news)
- [Previews](#previews)
- [The trailer](#the-trailer)
- [Layout](#layout)

## Building

The [README](../README.md#build-and-run) has the quick start. In more detail:

- **From Xcode:** open the package with `open Package.swift`, choose the
  **NullmereLauncher** scheme and **My Mac**, then press ⌘R.
- **A realm hosted on your own Mac**, for development:
  `NULLMERE_REALM=local swift run NullmereLauncher`. A debug build takes
  the other variables under [Debug builds](#debug-builds) too.
- **As a double-clickable app:**

  ```sh
  make app                          # or: scripts/build-app.sh
  open "build/Nullmere Online.app"
  ```

`scripts/build-app.sh` makes an arm64 release build and assembles
`Nullmere Online.app` with its icon and Info.plist. The icon is a Liquid
Glass document, `Packaging/AppIcon.icon` (night, reflection and a glass
moon), compiled with `actool` into the app's asset catalog; the classic
`AppIcon.png` is the fallback where `actool` isn't available. Both are drawn
by `Tools/icon/make-icon.py`: the launcher's own still lake, framed square
around the moon. The script signs the app ad hoc, which is enough to run it
on the Mac that built it. To sign with a Developer ID instead, set
`CODESIGN_IDENTITY`: the app is then signed with the hardened runtime and a
secure timestamp, ready to notarize. `VERSION` sets the marketing version
(default `0.3.0`).

### Nullmere Companion, the keeper's iPhone app

The companion is built from the same package: its screens in
`Sources/NullmereCompanion` (SwiftUI), over `Sources/NullmereCompanionCore`
(the link, the session and what the phone lists of a House, Foundation
only, so tested on Linux too).

- **For the iOS Simulator:** `scripts/build-companion.sh` builds it with
  `swift build --triple arm64-apple-ios26.0-simulator`, bundles
  `build/companion/Nullmere Companion.app` with its Info.plist (the
  `nullmere` link scheme its QR codes open, and local networking for a
  realm raised on the Mac), compiles the Mac app's Liquid Glass icon
  (`Packaging/AppIcon.icon`) for the phone, puts its entitlements in the
  binary as Xcode does for a simulator build, and signs it to run there. Then
  `xcrun simctl install booted "build/companion/Nullmere Companion.app"`.
- **On the keeper's iPhone:** open `Package.swift` in Xcode, choose the
  **NullmereCompanion** scheme and the phone, and set an Apple developer
  team to sign it. A phone needs iOS 26.
- **Both apps at once:** `scripts/smoke-test-companion.sh`, with a realm
  raised on this Mac (`STEWARD=background scripts/raise-realm.sh local`),
  enters it with a debug build of the Mac app, which offers a link, and
  runs the companion in a simulator, which takes it, gives orders (a
  company dug in, and a watch on, the blackwood set alight where it
  stands, a company's torches doused, a watchfire lit from its chart), is
  set aside and comes in again; the Mac must see the phone's orders, the
  fire burning where the phone set it, the company it doused marching dark
  and the watchfire burning where the phone lit it. Then
  the phone takes counsel of a commander through its own on-device model,
  as the Mac's check does (unverified where the simulator's Mac can't run
  the model). CI builds the companion and runs both apps together on
  every push, in a Mac job of its own beside the one that tests and
  bundles the Mac app, and keeps the companion's screens with the Mac's.
  It also builds the companion for an iPhone itself
  (`scripts/build-companion.sh --device`: arm64, the iOS SDK) into
  build/companion-device/, bundled but unsigned. For a keeper's own
  iPhone it is signed with an Apple developer team in Xcode: open
  Package.swift, choose the NullmereCompanion scheme and the device, and
  set the team.

## Releasing

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
first ([GO-LIVE.md](GO-LIVE.md), step 2):

```sh
scripts/set-release-secrets.sh DeveloperID.p12 AuthKey_XXXXXXXXXX.p8 <issuer id>
```

## Tests and checks

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
screenshots of the launcher, the realm's front door, the world and the
phone, two seconds of the great battle and of the seat's town in motion as
the world's renderer draws them (`world-battle-motion.gif`,
`world-town-motion.gif`, from `WorldRenderTests`), and each test's time,
slowest first, beside them on the `ci-shots` branch
(`<run>/test-times.txt`; `scripts/push-ci-shots.sh`).

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

## Debug builds

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
| `NULLMERE_OFFER_LINK` | With `NULLMERE_KEEPER`: offer a phone a link as the keeper comes in, and write the link its QR code carries to this file |
| `NULLMERE_LINK_REPORT` | With `NULLMERE_KEEPER`: write the companies of the keeper's House dug in, as this Mac sees them, to this file every second |
| `NULLMERE_COUNSEL_REPORT` | Take counsel of a commander through this Mac's own model, held to counsel's rules, write the report to this file and quit (scripts/check-counsel.sh) |

The companion's debug builds take `NULLMERE_COMPANION_LINK` (a link as the
Mac's QR code carries it: taken at once, then an order given, the phone set
aside and back, and a report written to its Documents),
`NULLMERE_COMPANION_TAB` (`house`, `army`, `alliance`, or `counsel` for
counsel with the House's first free commander) and `NULLMERE_COUNSEL_REPORT`
(counsel taken through the phone's own model as the Mac's check takes it,
its report written to Documents/counsel-report.txt), passed to the
simulator as `SIMCTL_CHILD_` variables.

Release builds ignore them all and always require the model.

## News

The news lives in this repository, in [`news/news.json`](../news/news.json):

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
in [`News.swift`](../Sources/LauncherCore/News.swift) together.

## Previews

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
node Tools/world3d-preview/shoot.js build/world3d/world.json world.png seat   # or lake, whole, turned, moon, close, company, folk, fishers, vigils
```

The models are previewed the same way: `NULLMERE_MODEL_PREVIEW=build/models
swift test --filter PreviewTests`, then `node Tools/model-preview/shoot.js
build/models/samples.json models.png "light=night"`. Away from a Mac,
`Tools/msl-check/check.sh <shader.metal>` parses Metal source with clang
for its syntax, names and types.

## The trailer

The trailer is a minute and fifty-nine seconds of the game's own world at
night, with no interface and nothing of the rules, every camera low and
slow near the water and the holds: the lake of the title screen under the
moon; low over the black water in to a hold on the shore; close by a
seat's Moonspire as its last stage rises in its scaffold and it is
crowned, and about the seat, the Moonspire whole; past a great hold, low
over its roofs; another House's Moonspire rising, its crane at work;
alongside a host on the march; a hold of another House besieged at its
gate, from behind the Mangonels hurling their stones at its walls in to
the spears striking at them, volleys loosed over the walls and back from
within, the hold burning behind them; rain off the lake; in among the
lines of a battle in the dark; the
moon eaten over the still water, and the field after under it; out over
the water to the moon's image on it; and the title. Nothing the game lays
over its world for its keepers is drawn: no lanes, no skill's ring, no
fireflies or dust hanging over the troops. Every frame is drawn by the game's own
renderers (the world's, and the launcher's lake), and its score is the
game's own synthesiser, the drums of war under the march and every blow
of the battle heard as the picture throws it. On a Mac:

```sh
scripts/render-trailer.sh                                  # build/trailer/nullmere-trailer.mp4
NULLMERE_TRAILER_MODE=stills scripts/render-trailer.sh     # a still from each shot
```

It is H.264 and AAC, 1920 by 1080 at sixty frames a second. The shots,
what moves in them and the score are `Sources/NullmereTrailer` (tested on
Linux too); the drawing and the writing, `Tests/TrailerRenderTests`. The
Trailer workflow renders it whenever they change and publishes it, with a
sheet of stills from it, as the assets of the `trailer` pre-release:
https://github.com/ael-dev3/Nullmere/releases/download/trailer/nullmere-trailer.mp4
(the stills: `nullmere-trailer-stills.jpg` beside it).

## Models made in Blender

The models made in Blender are made by scripts in `Art/blender`, run by
Blender's own Python module (`bpy` 5.2, for Python 3.13), with no
Blender window and nothing drawn by hand outside the script:

```sh
python3.13 -m venv .blender && .blender/bin/pip install bpy==5.2.3
.blender/bin/python Art/blender/spearman.py Art/models/spearman.glb
python3 Art/embed.py Art/models/spearman.glb Sources/NullmereModels/Art/Spearman.swift Art spearman Art/blender/spearman.py
```

The first line is needed once; `archer.py`, `lantern.py`, `rider.py`,
`commanders.py`, `mangonel.py`, `founder.py`, `hollow.py`, `thornwight.py`,
`colossus.py`, `folk.py` and `carters.py` make the archer, the lantern-bearer,
the rider, the commanders, the Mangonel, the founder, the three wilds, the
townsfolk and the carters the same way (the rider into `Art/models/rider.glb`, embedded
as `Art.horseman` in `Sources/NullmereModels/Art/Horseman.swift`; the
commanders into `Art/models/commanders.glb`, embedded as `Art.heroes` in
`Heroes.swift`; the Mangonel as `Art.engine` in `Engine.swift`; the founder
as `Art.settler` in `Settler.swift`; each wild in its own, `Hollow.swift`,
`Thornwight.swift` and `Colossus.swift`; the townsfolk as `Art.townsfolk` in
`Townsfolk.swift` and the carters as `Art.carters` in `Carters.swift`).
`keep.py` makes a hold's keep (`Art/models/keep.glb`, `Art.holdKeep` in
`Keep.swift`) and, given `seat` after the file, a seat's (`seat.glb`,
`Art.seatKeep` in `SeatKeep.swift`); like every building, it is made with
the shapes `Art/blender/building.py` lays out in the world's own axes and
measures, at ten times the world's size, with no skeleton, and each
people's look is a variant: its roof's pitch and its crown its own pieces,
its colours and grain given by the game for the materials it is made of.
`walls.py` makes the walls (`walls.glb`, `Art.wallsFile` in `Walls.swift`),
each of their five levels a tier of the file; `town.py` the town's pieces
(`town.glb`, `Art.townFile` in `TownFile.swift`), each a variant named as
the game names it. So are the holy sites (`shrines.py`: `shrines.glb`,
`Art.shrinesFile` in `ShrinesFile.swift`), the gathering sites (`sites.py`),
the lairs with the gatehold (`lairs.py`), an alliance's storehouse with its
yards (`stores.py`), the rigs a rising work is raised beside (`raising.py`),
the props (`props.py`), the land's furniture (`furnishings.py`), its
foliage swaying by its height above the ground, and the tokens set over
the land with the scaffold round a rising work (`tokens.py`), and the
land's marks (`marks.py`: a standard, a war camp, a host's banner, the
Drowned Crown, a listening stone, the pedlar's skiff), each kind a
variant by the name the game gives it, a talent's sigil and a crest's
charge by their numbers (`talentSigil0`, `crestCharge7`): a piece's tag
names its variants in letters and then any digits. What the world places
them and lights them by (a fire's smoke, a footing's height, where a
crest's shield hangs) stays in Swift beside them. A work's family is one script and one file, each level a
tier (`granary.py`: `granary.glb`, `Art.granaryFile` in `GranaryFile.swift`;
`beacon.py`: `beacon.glb`, `Art.beaconFile` in `BeaconFile.swift`; and so
the Sawpit, the Quarry, the Saltworks, the Muster Hall, the Infirmary, the
Archive, the Forge, the Wayhouse, the Masons' Lodge and the Moonspire; all on
`Art/blender/works.py`), its moving parts bones tagged for the levels they
stand at (`sack hoist@3`, which the importer keeps for that level under its
plain name) and its motion one action, `idle`: a part turned about its axis
or, like a fire, stretched. A block's `turn` in `building.py` runs from +x
toward +z, the other way round to the game's `.rotationY`; tests find a
moving part by its name, never by its place in the rig. The riders' and commanders' horse is
`Art/blender/horse.py`'s; the Mangonel's and the handcarts' wheels and the
handcart itself are `Art/blender/carts.py`'s. A figure's rig is held to 23
bones (24 parts with the game's root): a script folds the bones it does not
move away (`fold` in `Art/blender/common.py`: the rider's legs into his
seat), and `person.py` refuses to write more.
A script prints each tier's triangles far and near (and, with
`NULLMERE_PIECES` set to a tier or a variant, each piece's), and writes its file in one fixed order
(`Art/blender/canonical.py`), so running it again without a change gives
the same bytes. `Art/embed.py` writes the file into the package as Swift,
where the importer reads it; a test fails if the two differ. Pieces are
tagged by their names: `@2-5` for the tiers they are worn at, `@saltborn`
for a heritage's own, `!fine` for work drawn only near, and the actions
are named for the clips they play (`idle`, `march`, `attack`, `hit`,
`death`, `gather`); an action tagged as a piece is (`attack@warden`) is that
variant's in place of the one for all. The importer's own test arm is made the same way, by
`Art/blender/fixture_arm.py`.

## The score's instruments

The score plays notes of the
[VS Chamber Orchestra: Community Edition](https://github.com/sgossner/VSCO-2-CE)
(CC0 1.0), made into the package by `Art/sound/make.py` from a checkout of
just the files it names (the library is large; fetch those alone):

```sh
python3 -m pip install numpy scipy
python3 -I Art/sound/make.py <VSCO-2-CE checkout> Sources/NullmereSound/Recorded
```

Each note is made mono at 24 kHz, begun where it sounds, measured for the
pitch it truly sounds (a held note's through its players' vibrato), made as
loud to the ear as its fellows, its tail let go once it has died away, and
a held note looped over a stretch of its sustain that joins without a seam.
They are written as eight-bit blocks of differences in base64 Swift, read
back exactly by `Recordings.decode` in `Sources/NullmereSound/Recordings.swift`.
The files in `Recorded/` are generated: run the script again to change them.

## Layout

```
Package.swift
Sources/
  LauncherCore/       Platform-independent logic: settings, navigation, news, model readiness, composition
  LauncherKit/        SwiftUI interface, Metal backdrop, services (on-device model, news)
  NullmereLauncher/   The Nullmere Online app's entry point
  NullmereCore/       The rules and the realm's authority: world generation, economy, war, diplomacy, stewards, keepers, watches, ages. Pure, deterministic Swift
  NullmereModels/     The world's shapes: the land's relief and mesh, the models made in Blender read from their glTF files, and every other model built from solids in code, with the rigs that move them. Pure Swift
  NullmereWorld/      The world as the GPU draws it, apart from the GPU: the camera, the shaders' source, the frame's data. Pure Swift
  NullmereRealm/      The client's line to the realm over SpacetimeDB or in-process, the steward, keeper identity. Foundation only
  NullmereSound/      The game's sound apart from the Mac's audio engine: the synthesiser, its instruments and their recorded notes (Recorded/, made by Art/sound/make.py), its hall and the score. Pure Swift
  NullmereTrailer/    The trailer apart from the GPU: its world, its shots and what moves in them, and its score. Pure Swift
  NullmereKit/        The world's interface: front door, Metal world, panels, the audio engine
  NullmereCounsel/    Counsel of a House's commanders through Apple's on-device model (Foundation Models), and its check on a real Mac
  NullmereCompanionCore/ The keeper's phone apart from its screens: the link, the session, what it lists of a House. Foundation only
  NullmereCompanion/  Nullmere Companion, the keeper's iPhone app (SwiftUI); built for iOS by scripts/build-companion.sh
  NullmereSteward/    The steward's command-line entry point
Tests/                LauncherCoreTests, LauncherKitTests, NullmereCoreTests, NullmereModelsTests, NullmereWorldTests, NullmereSoundTests, NullmereRealmTests, NullmereCounselTests, NullmereCompanionCoreTests, NullmereKitTests, NullmereTrailerTests, TrailerRenderTests (the trailer drawn and written to a film, run by scripts/render-trailer.sh), and NullmereTestSupport (a SpacetimeDB in memory)
realm-server/         The SpacetimeDB module (Rust): keepers, requests, answers, the world
Dockerfile.steward    The steward in a container, as raise-realm.sh runs it
news/                 news.json, the launcher's news feed
perf/                 CI's performance baseline; scripts/measure-mac.sh adds figures from real Macs in perf/mac/
Packaging/            The Info.plist template, the Liquid Glass icon (AppIcon.icon) and the classic 1024 px icon
scripts/              Building, packing and checking a release; smoke tests; raising the realm; going live
Art/                  The models made in Blender: their scripts (blender/), the files they make (models/), and embed.py, which writes a file into the package; and sound/make.py, which makes the score's recorded notes
Tools/icon/           Draws the icon, its Liquid Glass layers and the classic one (make-icon.py)
Tools/scene-preview/  Browser preview of the lake shader
Tools/world3d-preview/ Browser preview of the world's land, mist, water and staged models, from the shaders' shared section
Tools/model-preview/  Browser preview of the models, on a sheet
Tools/msl-check/      Checks Metal source with clang away from a Mac
docs/                 Playing, the realm, developing, design, the gap list and going live; the audit of October 2026 (audit/); what carried over from Warpkeep; the README's stills (images/)
```
