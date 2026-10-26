#!/usr/bin/env bash
# Packs Nullmere Online for players in one command: the app, signed, in a
# disk image with a link to Applications; notarized and stapled when the
# credentials are there.
#
#   scripts/release.sh                         # ad-hoc signed, as CI does
#   CODESIGN_IDENTITY="Developer ID Application: …" NOTARY_PROFILE=nullmere \
#       VERSION=1.0.0 scripts/release.sh       # ready for anyone's Mac
#
# NOTARY_PROFILE names credentials kept in the keychain once, with
#   xcrun notarytool store-credentials nullmere --apple-id … --team-id …
# REALM_ADDRESS, if set, is passed on to scripts/build-app.sh.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.3.0}"
OUTPUT_DIR="${OUTPUT_DIR:-build}"
IDENTITY="${CODESIGN_IDENTITY:--}"
APP="$OUTPUT_DIR/Nullmere Online.app"
DMG="$OUTPUT_DIR/Nullmere-Online-$VERSION.dmg"

if [ -n "${NOTARY_PROFILE:-}" ] && [ "$IDENTITY" = "-" ]; then
    echo "error: notarizing needs a Developer ID; set CODESIGN_IDENTITY" >&2
    exit 1
fi

VERSION="$VERSION" OUTPUT_DIR="$OUTPUT_DIR" CODESIGN_IDENTITY="$IDENTITY" scripts/build-app.sh

echo "Packing $DMG…"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create -quiet -volname "Nullmere Online" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
if [ "$IDENTITY" != "-" ]; then
    codesign --force --sign "$IDENTITY" --timestamp "$DMG"
fi

if [ -n "${NOTARY_PROFILE:-}" ]; then
    echo "Notarizing…"
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
    spctl --assess --type open --context context:primary-signature --verbose "$DMG"
    echo "Notarized and stapled: $DMG"
else
    echo "Packed $DMG (not notarized: set CODESIGN_IDENTITY and NOTARY_PROFILE for a public release)"
fi
