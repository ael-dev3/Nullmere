#!/usr/bin/env bash
# Checks a packed release as a player would receive it, before it goes out:
# the disk image whole, the app inside it whole and signed, named Nullmere
# Online, a release build at the version being released, with a link to
# Applications; signed
# by the expected identity with the hardened runtime and a secure timestamp
# when one is named; notarized and stapled when that is claimed. Writes the
# image's SHA-256 beside it, for the release page.
#
#   scripts/verify-release.sh <disk image> <version>
#   AUTHORITY="Developer ID Application: …" NOTARIZED=1 \
#       scripts/verify-release.sh build/Nullmere-Online-1.0.0.dmg 1.0.0
#
# Used by CI on the ad-hoc image, by scripts/rehearse-release.sh on the
# image signed with a throwaway identity, and by the release workflow on
# the one that ships.
set -euo pipefail

dmg="${1:?the disk image}"
version="${2:?the version, such as 1.0.0}"
authority="${AUTHORITY:-}"
notarized="${NOTARIZED:-}"

fail() {
    echo "error: $*" >&2
    exit 1
}

[ -f "$dmg" ] || fail "no disk image at $dmg"
[ "$(basename "$dmg")" = "Nullmere-Online-${version}.dmg" ] || fail "the image is named $(basename "$dmg"), not Nullmere-Online-${version}.dmg"
hdiutil verify -quiet "$dmg" || fail "the disk image's checksum doesn't hold"

mount="$(mktemp -d)"
detach() {
    hdiutil detach -quiet "$mount" >/dev/null 2>&1 || hdiutil detach -quiet -force "$mount" >/dev/null 2>&1 || true
    rmdir "$mount" 2>/dev/null || true
}
trap detach EXIT
hdiutil attach -quiet -readonly -nobrowse -mountpoint "$mount" "$dmg"

app="$mount/Nullmere Online.app"
[ -d "$app" ] || fail "the image holds no Nullmere Online.app"
[ -L "$mount/Applications" ] && [ "$(readlink "$mount/Applications")" = /Applications ] || fail "the image has no link to Applications"
extra="$(ls -A "$mount" | grep -vx -e 'Nullmere Online\.app' -e 'Applications' -e '\.DS_Store' -e '\.fseventsd' -e '\.Trashes' -e '\.background' || true)"
[ -z "$extra" ] || fail "the image holds more than the app and the link: $extra"

plist="$app/Contents/Info.plist"
read_key() {
    plutil -extract "$1" raw "$plist"
}
[ "$(read_key CFBundleName)" = "Nullmere Online" ] || fail "the app is named \"$(read_key CFBundleName)\", not Nullmere Online"
[ "$(read_key CFBundleDisplayName)" = "Nullmere Online" ] || fail "the app shows as \"$(read_key CFBundleDisplayName)\", not Nullmere Online"
[ "$(read_key CFBundleShortVersionString)" = "$version" ] || fail "the app is version $(read_key CFBundleShortVersionString), not $version"
[ "$(read_key CFBundleIdentifier)" = online.nullmere.launcher ] || fail "the app goes by \"$(read_key CFBundleIdentifier)\", not online.nullmere.launcher"
executable="$app/Contents/MacOS/$(read_key CFBundleExecutable)"
[ "$(lipo -archs "$executable")" = arm64 ] || fail "the app isn't for Apple silicon alone"
# A debug build reads what its surroundings say, Apple Intelligence's state
# among it; only a debug build holds the name it reads that by.
if grep -qa NULLMERE_MODEL_STATE "$executable"; then
    fail "the app is a debug build; release builds are made by scripts/release.sh"
fi

codesign --verify --deep --strict "$app" || fail "the app's signature doesn't hold"
if [ -n "$authority" ]; then
    details="$(codesign -dvv "$app" 2>&1)"
    echo "$details" | grep -qxF "Authority=$authority" || fail "the app isn't signed by $authority"
    echo "$details" | grep -q "flags=.*runtime" || fail "the app lacks the hardened runtime notarization needs"
    echo "$details" | grep -q "^Timestamp=" || fail "the app lacks the secure timestamp notarization needs"
    codesign --verify --strict "$dmg" || fail "the disk image's signature doesn't hold"
    codesign -dvv "$dmg" 2>&1 | grep -qxF "Authority=$authority" || fail "the disk image isn't signed by $authority"
fi
if [ -n "$notarized" ]; then
    [ -n "$authority" ] || fail "a notarized release is signed by a Developer ID; name it in AUTHORITY"
    xcrun stapler validate "$dmg" || fail "the disk image's notarization isn't stapled"
    spctl --assess --type open --context context:primary-signature "$dmg" || fail "Gatekeeper refuses the disk image"
    spctl --assess --type execute "$app" || fail "Gatekeeper refuses the app"
fi

(cd "$(dirname "$dmg")" && shasum -a 256 "$(basename "$dmg")") > "$dmg.sha256"
echo "VERIFIED $(basename "$dmg"): Nullmere Online $version, ${authority:-ad-hoc} signed$([ -n "$notarized" ] && echo ", notarized and stapled"); SHA-256 $(cut -d' ' -f1 "$dmg.sha256")"
