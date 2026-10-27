#!/usr/bin/env bash
# Takes up a signing identity for a release, from secrets in the
# environment, into a keychain of its own, and the notary's credentials
# with it when they're there. Used by .github/workflows/release.yml with the
# Developer ID, and by scripts/rehearse-release.sh with a throwaway one.
#
#   MACOS_CERTIFICATE           the certificate and key, a base64 .p12
#   MACOS_CERTIFICATE_PASSWORD  its password
#   APPLE_API_KEY               an App Store Connect API key, base64 .p8 (optional)
#   APPLE_API_KEY_ID            its key id
#   APPLE_API_ISSUER            its issuer id
#   IDENTITY_KIND               the identity's name begins so (default:
#                               "Developer ID Application")
#
# Prints, and writes to $GITHUB_OUTPUT when set: identity=, keychain=, and
# notary=nullmere when the notary's credentials were stored.
set -euo pipefail

: "${MACOS_CERTIFICATE:?the base64 .p12 is needed}"
KIND="${IDENTITY_KIND:-Developer ID Application}"
WORK="${RUNNER_TEMP:-$(mktemp -d)}"
keychain="$WORK/release.keychain-db"
password="$(uuidgen)"

security delete-keychain "$keychain" >/dev/null 2>&1 || true
security create-keychain -p "$password" "$keychain"
security set-keychain-settings -lut 3600 "$keychain"
security unlock-keychain -p "$password" "$keychain"
printf '%s' "$MACOS_CERTIFICATE" | base64 --decode > "$WORK/certificate.p12"
security import "$WORK/certificate.p12" -k "$keychain" -P "${MACOS_CERTIFICATE_PASSWORD:-}" -T /usr/bin/codesign >/dev/null
rm -f "$WORK/certificate.p12"
security set-key-partition-list -S apple-tool:,apple: -s -k "$password" "$keychain" >/dev/null
# shellcheck disable=SC2046
security list-keychains -d user -s "$keychain" $(security list-keychains -d user | tr -d '"')
identity="$(security find-identity -v -p codesigning "$keychain" | sed -n "s/.*\"\\($KIND.*\\)\"/\\1/p" | head -n 1)"
if [ -z "$identity" ]; then
    echo "error: no valid \"$KIND\" signing identity in the certificate" >&2
    security find-identity -p codesigning "$keychain" >&2 || true
    exit 1
fi

notary=""
if [ -n "${APPLE_API_KEY:-}" ]; then
    : "${APPLE_API_KEY_ID:?APPLE_API_KEY_ID is needed with APPLE_API_KEY}"
    : "${APPLE_API_ISSUER:?APPLE_API_ISSUER is needed with APPLE_API_KEY}"
    printf '%s' "$APPLE_API_KEY" | base64 --decode > "$WORK/api-key.p8"
    xcrun notarytool store-credentials nullmere --key "$WORK/api-key.p8" \
        --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER" --keychain "$keychain"
    rm -f "$WORK/api-key.p8"
    notary=nullmere
fi

echo "Signing as: $identity"
[ -n "$notary" ] && echo "Notarizing with the stored profile: $notary"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
    {
        echo "identity=$identity"
        echo "keychain=$keychain"
        echo "notary=$notary"
    } >> "$GITHUB_OUTPUT"
fi
