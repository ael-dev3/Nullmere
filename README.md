<p align="center">
  <img src="Packaging/AppIcon.png" width="128" height="128" alt="Nullmere Online app icon: a full moon above a black lake, mirrored in the water">
</p>

<h1 align="center">Nullmere Online</h1>

Nullmere is a planned persistent multiplayer 4X strategy game for the Mac,
built for a small, personally curated community. Players explore, expand,
develop resources, make treaties and wage war, and the alliances, politics and
drama they create leave a lasting history. It continues the universe,
premise and principles of [Warpkeep](https://github.com/ael-dev3/Warpkeep),
without Warpkeep's Farcaster identity.

**This repository currently holds the native launcher**: the "Nullmere Online"
title screen. It shows a black lake under a full moon, with Play, News,
Settings, Repository and Quit on the water. There is no game client or server
yet.

Website: [nullmere.online](https://nullmere.online)

## Requirements

Nullmere runs only on Macs that can run Apple's on-device language model,
the roughly 3-billion-parameter model behind Apple Intelligence. Its
characters will speak through that model, on your Mac, using the
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

As a double-clickable app:

```sh
make app                          # or: scripts/build-app.sh
open "build/Nullmere Online.app"
```

`scripts/build-app.sh` makes an arm64 release build and assembles
`Nullmere Online.app` with its icon and Info.plist. It signs the app ad hoc,
which is enough to run it on the Mac that built it. To sign with a
Developer ID instead, set `CODESIGN_IDENTITY`: the app is then signed with
the hardened runtime and a secure timestamp, ready to notarize. `VERSION`
sets the marketing version (default `0.2.0`).

Tests and checks:

```sh
swift test                 # unit tests; on a Mac with Metal, the shader is also compiled on the GPU
make check-shader          # compile the shader with the offline Metal compiler
```

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

- **Play** fades the launcher out and opens the Nullmere game client
  (bundle identifier `online.nullmere.game`). Until the first realm opens
  there is no client, so Play says the shore is quiet. The on-device model's
  status is always shown at the bottom left.
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

Settings are stored in the `online.nullmere.launcher` user defaults:

| Setting | Options | Effect |
| --- | --- | --- |
| Motion | System, Full, Reduced, Still | How much moves. Full: flickering stars, falling stars, rings on the water and the opening. Reduced: slower water and gentle twinkling only. Still: a single frame. System follows *Reduce motion*. |
| Resolution | Native, Balanced, Efficient | Renders the lake at 100%, 75% or 50% of native pixels |
| Frame rate | 30, 60, 120 | Upper bound for the lake's frame rate. Reduced motion, Low Power Mode, a Mac running hot, or another app in front lowers it to 30 |
| Full screen at launch | Off, On | Applies the next time the launcher opens |

## Design

A full moon hangs over a great black lake. Its reflection breaks and gathers
on the water below. Pale, thin type rests above the far shore. The mood is
vast, quiet and monumental, after the grand, minimal look of the Dune films.
There is no music.

- **The moon** is a large, cold full moon at the top of the sky, the same
  view as the app icon. Its halo swells and settles very slowly, and thin
  haze drifting past catches its light.
- **The stars** flicker, each at its own pace. They flicker more near the
  horizon, as they do through deeper air. Now and then a star falls: the
  first a few seconds after the lake appears, then at random, about twice a
  minute, drawing a fading trail away from the moon.
- **The lake is water, not glass.** A long swell and wind ripples run toward
  the viewer, breaking the moon's reflection into moving slivers. Glints of
  moonlight flash on the facets turned toward the moon and trace its path to
  the far shore. Now and then rings spread where something touched the
  surface. Star reflections and falling stars ripple with the water. Far
  away, the surface lies smooth and mirrors the shore.
- **The title** is NULLMERE, set large in SF Pro Thin with wide tracking. The
  letters settle together as it appears. ONLINE sits beneath it between two
  hairlines that reach the width of the word. The menu is a single row of
  light, spaced capitals on the water, and the chosen word glows faintly
  over a hairline. Panels darken the water beneath them so their text stays
  legible over the reflection.
- **Rendering.** One fragment shader draws the whole scene procedurally. It
  is compiled at runtime from
  [`LakeShader.swift`](Sources/LauncherKit/Backdrop/LakeShader.swift), so plain
  `swift build` works. Stars and glints are sized in points, so they stay crisp
  at any window size or backing scale. Waves too small to draw cleanly fade
  out rather than shimmer, and the output is dithered so the dark gradients
  don't band.
- **Cost.** The lake renders only while the window is visible and motion is
  allowed, at the chosen frame rate and resolution. It drops to 30 frames a
  second while another app is in front, in Low Power Mode, and when the Mac
  runs hot. If the shader fails, a still SwiftUI painting of the scene
  replaces it.
- **Accessibility.** The launcher honours Reduce Motion and Increase
  Contrast, has VoiceOver labels and selection traits, and works fully from
  the keyboard.

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

## Layout

```
Package.swift
Sources/
  LauncherCore/       Platform-independent logic: settings, navigation, news, model readiness, composition
  LauncherKit/        SwiftUI interface, Metal backdrop, services (on-device model, news, game client)
  NullmereLauncher/   App entry point
Tests/                LauncherCoreTests, LauncherKitTests
news/                 news.json, the launcher's news feed
Packaging/            Info.plist template and the 1024 px app icon
scripts/              build-app.sh, check-shader.sh
Tools/scene-preview/  Browser preview of the lake shader
docs/                 Project notes, starting with what carries over from Warpkeep
```

## Direction

- **Client:** native Swift on macOS, using SwiftUI and AppKit for the
  interface, and Metal for the world if it earns its place.
- **Server:** [SpacetimeDB](https://spacetimedb.com) as the authoritative
  multiplayer backend, as it was for Warpkeep.
- **Characters:** non-player characters voiced by Apple's on-device model,
  through the Foundation Models framework. They never decide outcomes or
  grant resources.
- **Character:** open source and pseudonymous, executed with restraint.

[What carries over from Warpkeep](docs/warpkeep-carryover.md) covers the
universe, principles, rules core, world model, backend and asset licensing in
detail.

## License

- Code is licensed under the [Apache License 2.0](LICENSE).
- Original art and documentation, including the app icon, are dedicated to
  the public domain under [CC0 1.0](LICENSE-CC0-1.0).
- The Nullmere name and nullmere.online identify the official project. Neither
  license grants rights to them.
