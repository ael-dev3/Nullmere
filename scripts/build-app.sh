#!/usr/bin/env bash
# Builds "Nullmere Online.app" (the launcher) and "Nullmere.app" (the game)
# from the Swift package.
#
#   scripts/build-app.sh                 # release builds into build/
#   VERSION=0.3.0 scripts/build-app.sh   # set the marketing version
#
# The apps are built for Apple silicon only and need macOS 26, matching
# Apple Intelligence. They are ad-hoc signed, which is enough to run them on
# the Mac that built them. Set CODESIGN_IDENTITY to sign with a Developer ID
# instead, with the hardened runtime and a secure timestamp, ready to notarize.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIGURATION="${CONFIGURATION:-release}"
VERSION="${VERSION:-0.3.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
OUTPUT_DIR="${OUTPUT_DIR:-build}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"

echo "Building ($CONFIGURATION, arm64)…"
swift build -c "$CONFIGURATION" --arch arm64 --product NullmereLauncher
swift build -c "$CONFIGURATION" --arch arm64 --product Nullmere
BIN_DIR="$(swift build -c "$CONFIGURATION" --arch arm64 --show-bin-path)"

ICONSET_ROOT="$(mktemp -d)"
trap 'rm -rf "$ICONSET_ROOT"' EXIT
ICONSET="$ICONSET_ROOT/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" Packaging/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" Packaging/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
ICNS="$ICONSET_ROOT/AppIcon.icns"
iconutil -c icns "$ICONSET" -o "$ICNS"

if [ "$CODESIGN_IDENTITY" = "-" ]; then
    TIMESTAMP="--timestamp=none"
else
    # Notarization needs a secure timestamp from Apple.
    TIMESTAMP="--timestamp"
fi

# bundle <app name> <executable> <Info.plist template>
bundle() {
    local app="$OUTPUT_DIR/$1.app"
    local executable="$2"
    local archs
    archs="$(lipo -archs "$BIN_DIR/$executable")"
    if [ "$archs" != "arm64" ]; then
        echo "Expected an arm64-only $executable, got: $archs" >&2
        exit 1
    fi

    echo "Assembling ${app}…"
    rm -rf "$app"
    mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
    cp "$BIN_DIR/$executable" "$app/Contents/MacOS/$executable"
    sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD_NUMBER/" "$3" > "$app/Contents/Info.plist"
    plutil -lint -s "$app/Contents/Info.plist"
    cp "$ICNS" "$app/Contents/Resources/AppIcon.icns"

    echo "Signing $1 ($CODESIGN_IDENTITY)…"
    codesign --force --sign "$CODESIGN_IDENTITY" --options runtime "$TIMESTAMP" "$app"
    codesign --verify --strict "$app"
    echo "Built $app"
}

bundle "Nullmere Online" NullmereLauncher Packaging/Info.plist
bundle "Nullmere" Nullmere Packaging/Game-Info.plist
