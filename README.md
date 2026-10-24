<p align="center">
  <img src="Packaging/AppIcon.png" width="128" height="128" alt="Nullmere Online app icon: a moon above a still black lake">
</p>

<h1 align="center">Nullmere Online</h1>

Nullmere is a planned persistent multiplayer 4X strategy game for the Mac,
built for a small, personally curated community. Players explore, expand,
develop resources, make treaties and wage war, and the alliances, politics and
drama they create leave a lasting history. It continues the universe,
premise and principles of [Warpkeep](https://github.com/ael-dev3/Warpkeep),
without Warpkeep's Farcaster identity.

**This repository currently holds the native launcher**: the "Nullmere Online"
title screen with Play, Settings and Quit. There is no game client or server yet.

Website: [nullmere.online](https://nullmere.online)

## Requirements

- macOS 14 Sonoma or later
- Xcode 15 or later, or another Swift 5.9+ toolchain with the macOS SDK

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

`scripts/build-app.sh` makes a release build and assembles
`Nullmere Online.app` with its icon and Info.plist. It signs the app ad hoc,
which is enough to run it on the Mac that built it. To sign with a
Developer ID instead, set `CODESIGN_IDENTITY`. `VERSION` sets the marketing
version (default `0.1.0`).

Tests and checks:

```sh
swift test                 # unit tests; on a Mac with Metal, the shader is also compiled on the GPU
make check-shader          # compile the shader with the offline Metal compiler
```

## Using the launcher

| Key | Action |
| --- | --- |
| ↑ ↓ | Choose a menu item or settings row |
| Return or Space | Select; in Settings, cycle the option |
| ← → | Change the selected setting |
| Esc | Go back |
| ⌘, | Settings |
| ⌘Q | Quit |

Any key or click during the opening skips it. Everything also works with the
pointer.

**Play** says that the first realm has not opened yet. **Settings** stores its
values in the `online.nullmere.launcher` user defaults:

| Setting | Options | Effect |
| --- | --- | --- |
| Motion | System, Full, Reduced, Still | Speed of the water, star twinkle and opening. System follows *Reduce motion*. Still renders a single frame and stops. |
| Resolution | Native, Balanced, Efficient | Renders the lake at 100%, 75% or 50% of native pixels |
| Frame rate | 30, 60, 120 | Upper bound for the lake's frame rate |
| Full screen at launch | Off, On | Applies the next time the launcher opens |

## Design

A deep black lake under a cold moon, water so still it holds the stars,
distant flat-topped mesas, and a pale title set wide above the far shore.
The mood is vast, quiet and monumental. Nothing on screen asks for
attention: there is no music, and only a slow twinkle, a faint swell, mist on
the waterline and, about once a minute, a meteor that also crosses the
reflection.

- **Scene.** One fragment shader draws everything procedurally: sky, three
  layers of point stars, a faint galactic band, the moon with limb darkening,
  the shore, mist, and the mirrored water with depth-dependent reflectance.
  It is compiled at runtime from
  [`LakeShader.swift`](Sources/LauncherKit/Backdrop/LakeShader.swift), so plain
  `swift build` works. Stars are sized in points, so they stay crisp at any
  window size or backing scale, and the output is dithered so the dark
  gradients don't band.
- **Type.** SF Pro: a thin title tracked at 0.62 em, which settles in from
  wider spacing as it appears, and light uppercase labels. Pale, slightly
  cold ink with a faint glow. Tracking is balanced on both sides so words
  centre optically.
- **Cost.** The lake renders only while the window is visible and motion is
  allowed, at the chosen frame rate and resolution. If Metal is unavailable
  or the shader fails, a static SwiftUI rendition replaces it.
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

Query parameters: `horizon`, `twinkle` and `time` (to freeze a moment).

## Layout

```
Package.swift
Sources/
  LauncherCore/       Platform-independent logic: settings, navigation, scene clock, composition
  LauncherKit/        SwiftUI interface, Metal backdrop, window and keyboard handling
  NullmereLauncher/   App entry point
Tests/                LauncherCoreTests, LauncherKitTests
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
- **Later:** NPCs voiced by Apple's on-device Foundation Models. They never
  decide outcomes or grant resources.
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
