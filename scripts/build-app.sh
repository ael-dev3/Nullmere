#!/usr/bin/env bash
# Builds "Nullmere Online.app", the launcher and the realm client in one app,
# from the Swift package.
#
#   scripts/build-app.sh                 # release builds into build/
#   VERSION=0.3.0 scripts/build-app.sh   # set the marketing version
#   REALM_ADDRESS=https://maincloud.spacetimedb.com/nullmere scripts/build-app.sh
#
# The app is built for Apple silicon only and needs macOS 26, matching
# Apple Intelligence. It is ad-hoc signed, which is enough to run it on the
# Mac that built it. Set CODESIGN_IDENTITY to sign with a Developer ID
# instead, with the hardened runtime and a secure timestamp, ready to notarize.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIGURATION="${CONFIGURATION:-release}"
VERSION="${VERSION:-0.3.0}"
# CFBundleShortVersionString: three numbers, as macOS compares versions.
echo "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || { echo "VERSION must be three numbers, such as 1.0.0 (not $VERSION)" >&2; exit 1; }
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
OUTPUT_DIR="${OUTPUT_DIR:-build}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
# The realm the app enters: as scripts/raise-realm.sh printed it.
REALM_ADDRESS="${REALM_ADDRESS:-https://maincloud.spacetimedb.com/nullmere}"
case "$REALM_ADDRESS" in
    http://*|https://*) ;;
    *) echo "REALM_ADDRESS must be an http(s) address, such as https://maincloud.spacetimedb.com/nullmere" >&2; exit 1 ;;
esac

echo "Building ($CONFIGURATION, arm64)…"
swift build -c "$CONFIGURATION" --arch arm64 --product NullmereLauncher
BIN_DIR="$(swift build -c "$CONFIGURATION" --arch arm64 --show-bin-path)"

ICONSET_ROOT="$(mktemp -d)"
trap 'rm -rf "$ICONSET_ROOT"' EXIT

# The icon: the Liquid Glass document Packaging/AppIcon.icon, compiled by
# actool into an asset catalog (macOS 26 lights its glass layers) and a
# matching AppIcon.icns for older places. Without actool, the classic icon
# alone is used.
ICNS="$ICONSET_ROOT/AppIcon.icns"
CATALOG=""
COMPILED="$ICONSET_ROOT/compiled"
mkdir -p "$COMPILED"
if xcrun --find actool >/dev/null 2>&1 && xcrun actool Packaging/AppIcon.icon \
        --compile "$COMPILED" --platform macosx --minimum-deployment-target 26.0 \
        --app-icon AppIcon --output-partial-info-plist "$ICONSET_ROOT/icon-info.plist" \
        --errors --warnings --output-format human-readable-text \
        && [ -s "$COMPILED/Assets.car" ]; then
    echo "Compiled the Liquid Glass icon."
    CATALOG="$COMPILED/Assets.car"
    if [ -s "$COMPILED/AppIcon.icns" ]; then
        cp "$COMPILED/AppIcon.icns" "$ICNS"
    fi
else
    echo "warning: could not compile Packaging/AppIcon.icon; using the classic icon only" >&2
fi
if [ ! -s "$ICNS" ]; then
    ICONSET="$ICONSET_ROOT/AppIcon.iconset"
    mkdir -p "$ICONSET"
    for size in 16 32 128 256 512; do
        sips -z "$size" "$size" Packaging/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
        double=$((size * 2))
        sips -z "$double" "$double" Packaging/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "$ICNS"
fi

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
    # The address is set by plutil, which escapes it: an & or a | in it
    # can't break the plist the way it would break a sed replacement.
    plutil -replace NullmereRealm -string "$REALM_ADDRESS" "$app/Contents/Info.plist"
    plutil -lint -s "$app/Contents/Info.plist"
    cp "$ICNS" "$app/Contents/Resources/AppIcon.icns"
    if [ -n "$CATALOG" ]; then
        cp "$CATALOG" "$app/Contents/Resources/Assets.car"
        plutil -replace CFBundleIconName -string AppIcon "$app/Contents/Info.plist"
    fi

    echo "Signing $1 ($CODESIGN_IDENTITY)…"
    codesign --force --sign "$CODESIGN_IDENTITY" --options runtime "$TIMESTAMP" "$app"
    codesign --verify --strict "$app"
    echo "Built $app"
}

bundle "Nullmere Online" NullmereLauncher Packaging/Info.plist
