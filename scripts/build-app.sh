#!/usr/bin/env bash
# Builds "Nullmere Online.app" from the Swift package.
#
#   scripts/build-app.sh                 # release build into build/
#   VERSION=0.3.0 scripts/build-app.sh   # set the marketing version
#
# The app is built for Apple silicon only and needs macOS 26, matching
# Apple Intelligence. It is ad-hoc signed, which is enough to run it on the
# Mac that built it. Set CODESIGN_IDENTITY to sign with a Developer ID
# instead, with the hardened runtime and a secure timestamp, ready to notarize.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Nullmere Online"
EXECUTABLE="NullmereLauncher"
CONFIGURATION="${CONFIGURATION:-release}"
VERSION="${VERSION:-0.2.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
OUTPUT_DIR="${OUTPUT_DIR:-build}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
APP="$OUTPUT_DIR/$APP_NAME.app"

echo "Building $EXECUTABLE ($CONFIGURATION, arm64)…"
swift build -c "$CONFIGURATION" --arch arm64 --product "$EXECUTABLE"
BIN_DIR="$(swift build -c "$CONFIGURATION" --arch arm64 --show-bin-path)"
ARCHS="$(lipo -archs "$BIN_DIR/$EXECUTABLE")"
if [ "$ARCHS" != "arm64" ]; then
    echo "Expected an arm64-only executable, got: $ARCHS" >&2
    exit 1
fi

echo "Assembling ${APP}…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$EXECUTABLE" "$APP/Contents/MacOS/$EXECUTABLE"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD_NUMBER/" Packaging/Info.plist > "$APP/Contents/Info.plist"
plutil -lint -s "$APP/Contents/Info.plist"

ICONSET="$(mktemp -d)/AppIcon.iconset"
trap 'rm -rf "$(dirname "$ICONSET")"' EXIT
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" Packaging/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" Packaging/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

echo "Signing ($CODESIGN_IDENTITY)…"
if [ "$CODESIGN_IDENTITY" = "-" ]; then
    TIMESTAMP="--timestamp=none"
else
    # Notarization needs a secure timestamp from Apple.
    TIMESTAMP="--timestamp"
fi
codesign --force --sign "$CODESIGN_IDENTITY" --options runtime "$TIMESTAMP" "$APP"
codesign --verify --strict "$APP"

echo "Built $APP"
