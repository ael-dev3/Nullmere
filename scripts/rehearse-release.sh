#!/usr/bin/env bash
# Rehearses a signed, notarized release with no Apple account: a throwaway
# self-signed code-signing identity, made here, takes the Developer ID's
# place through the very same steps
# (scripts/take-up-identity.sh, then scripts/release.sh, signing the app
# with the hardened runtime and a secure timestamp, and the disk image);
# notarizing is rehearsed too, printing what it would send to Apple. CI runs
# it, so a real release only wants the secrets. The throwaway identity is
# never trusted (that would wait on a password nobody types): codesign
# signs with it all the same, only warning that it chains to no root Apple
# trusts.
set -euo pipefail

cd "$(dirname "$0")/.."

NAME="Nullmere Rehearsal"
WORK="$(mktemp -d)"
OUTPUT_DIR="${OUTPUT_DIR:-build/rehearsal}"
cleanup() {
    security delete-keychain "$WORK/release.keychain-db" >/dev/null 2>&1 || true
    rm -rf "$WORK"
}
trap cleanup EXIT

echo "== A throwaway identity, \"$NAME\""
cat > "$WORK/openssl.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF
openssl req -x509 -newkey rsa:2048 -nodes -days 2 -config "$WORK/openssl.cnf" \
    -keyout "$WORK/key.pem" -out "$WORK/certificate.pem" 2>/dev/null
password="rehearsal"
# The legacy algorithms the macOS keychain imports, where the openssl has them.
legacy=""
openssl pkcs12 -help 2>&1 | grep -q -- "-legacy" && legacy="-legacy"
openssl pkcs12 -export $legacy -inkey "$WORK/key.pem" -in "$WORK/certificate.pem" -name "$NAME" \
    -out "$WORK/identity.p12" -passout "pass:$password"

echo "== Taking it up, as the release workflow takes up the Developer ID"
outputs="$WORK/outputs"
MACOS_CERTIFICATE="$(base64 < "$WORK/identity.p12")" MACOS_CERTIFICATE_PASSWORD="$password" \
    IDENTITY_KIND="$NAME" ALLOW_UNTRUSTED=1 RUNNER_TEMP="$WORK" GITHUB_OUTPUT="$outputs" scripts/take-up-identity.sh
identity="$(sed -n 's/^identity=//p' "$outputs")"
[ "$identity" = "$NAME" ] || { echo "error: took up \"$identity\", not \"$NAME\"" >&2; exit 1; }

echo "== Setting the release's secrets, rehearsed: each file checked, nothing set"
openssl ecparam -name prime256v1 -genkey -noout 2>/dev/null | openssl pkcs8 -topk8 -nocrypt -out "$WORK/AuthKey_REHEARSE01.p8"
DRY_RUN=1 IDENTITY_KIND="$NAME" MACOS_CERTIFICATE_PASSWORD="$password" \
    scripts/set-release-secrets.sh "$WORK/identity.p12" "$WORK/AuthKey_REHEARSE01.p8" 69a6de70-0000-47e3-e053-5b8c7c11a4d1
if DRY_RUN=1 IDENTITY_KIND="$NAME" MACOS_CERTIFICATE_PASSWORD=wrong \
    scripts/set-release-secrets.sh "$WORK/identity.p12" "$WORK/AuthKey_REHEARSE01.p8" 69a6de70-0000-47e3-e053-5b8c7c11a4d1 >/dev/null 2>&1; then
    echo "error: the secrets' check took a certificate with the wrong password" >&2
    exit 1
fi

echo "== Releasing, signed, the notarizing rehearsed"
rm -rf "$OUTPUT_DIR"
VERSION=0.0.0 OUTPUT_DIR="$OUTPUT_DIR" CODESIGN_IDENTITY="$identity" NOTARY_PROFILE=nullmere NOTARY_DRY_RUN=1 \
    scripts/release.sh | tee "$WORK/release.log"

echo "== Checking what was signed, as the release workflow checks what ships"
dmg="$OUTPUT_DIR/Nullmere-Online-0.0.0.dmg"
AUTHORITY="$NAME" scripts/verify-release.sh "$dmg" 0.0.0
test -s "$dmg.sha256" || { echo "error: no checksum beside the disk image" >&2; exit 1; }
(cd "$OUTPUT_DIR" && shasum -a 256 -c "$(basename "$dmg").sha256") || { echo "error: the checksum doesn't match the disk image" >&2; exit 1; }
# The check refuses what it should: an image signed by someone else.
if AUTHORITY="Developer ID Application: Someone Else" scripts/verify-release.sh "$dmg" 0.0.0 >/dev/null 2>&1; then
    echo "error: the check passed an image signed by someone else" >&2
    exit 1
fi
# And a version other than the one released.
if AUTHORITY="$NAME" scripts/verify-release.sh "$dmg" 9.9.9 >/dev/null 2>&1; then
    echo "error: the check passed an image named for another version" >&2
    exit 1
fi
grep -q "would run: xcrun notarytool submit" "$WORK/release.log" || { echo "error: notarizing wasn't rehearsed" >&2; exit 1; }
grep -q "would run: xcrun stapler staple" "$WORK/release.log" || { echo "error: stapling wasn't rehearsed" >&2; exit 1; }
echo "== The release's notes, as a signed release would have them"
scripts/release-notes.sh v0.0.0 signed | tee "$WORK/notes.md"
grep -qi "ad-hoc" "$WORK/notes.md" && { echo "error: a signed release's notes say ad-hoc" >&2; exit 1; }
scripts/release-notes.sh v0.0.0 | grep -qi "ad-hoc" || { echo "error: an unsigned release's notes don't say so" >&2; exit 1; }
echo "REHEARSAL signed by \"$NAME\" with the hardened runtime and a secure timestamp; the disk image signed; notarizing and stapling ready. A real release needs only the secrets."
