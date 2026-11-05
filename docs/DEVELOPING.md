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
node Tools/world3d-preview/shoot.js build/world3d/world.json world.png seat   # or lake, whole, turned, moon, close, company
```

The models are previewed the same way: `NULLMERE_MODEL_PREVIEW=build/models
swift test --filter PreviewTests`, then `node Tools/model-preview/shoot.js
build/models/samples.json models.png "light=night"`. Away from a Mac,
`Tools/msl-check/check.sh <shader.metal>` parses Metal source with clang
for its syntax, names and types.

## The trailer

The trailer is a minute and fifty-two seconds of the game's own world at
night, with no interface and nothing of the rules, every camera low and
slow near the water and the holds: the lake of the title screen under the
moon; low over the black water in to a hold on the shore; about a seat,
its Moonspire crowned; past a great hold, low over its roofs; another
House's Moonspire rising, its crane at work; alongside a host on the
march; rain off the lake; in among the lines of a battle in the dark; the
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
the game names it. The riders' and commanders' horse is
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
  NullmereSound/      The game's sound apart from the Mac's audio engine: the synthesiser, its instruments, its hall and the score. Pure Swift
  NullmereTrailer/    The trailer apart from the GPU: its world, its shots and what moves in them, and its score. Pure Swift
  NullmereKit/        The world's interface: front door, Metal world, panels, the audio engine
  NullmereSteward/    The steward's command-line entry point
Tests/                LauncherCoreTests, LauncherKitTests, NullmereCoreTests, NullmereModelsTests, NullmereWorldTests, NullmereSoundTests, NullmereRealmTests, NullmereKitTests, NullmereTrailerTests, TrailerRenderTests (the trailer drawn and written to a film, run by scripts/render-trailer.sh), and NullmereTestSupport (a SpacetimeDB in memory)
realm-server/         The SpacetimeDB module (Rust): keepers, requests, answers, the world
Dockerfile.steward    The steward in a container, as raise-realm.sh runs it
news/                 news.json, the launcher's news feed
perf/                 CI's performance baseline; scripts/measure-mac.sh adds figures from real Macs in perf/mac/
Packaging/            The Info.plist template, the Liquid Glass icon (AppIcon.icon) and the classic 1024 px icon
scripts/              Building, packing and checking a release; smoke tests; raising the realm; going live
Art/                  The models made in Blender: their scripts (blender/), the files they make (models/), and embed.py, which writes a file into the package
Tools/icon/           Draws the icon, its Liquid Glass layers and the classic one (make-icon.py)
Tools/scene-preview/  Browser preview of the lake shader
Tools/world3d-preview/ Browser preview of the world's land, mist, water and staged models, from the shaders' shared section
Tools/model-preview/  Browser preview of the models, on a sheet
Tools/msl-check/      Checks Metal source with clang away from a Mac
docs/                 Playing, the realm, developing, design, the gap list and going live; the audit of October 2026 (audit/); what carried over from Warpkeep; the README's stills (images/)
```
