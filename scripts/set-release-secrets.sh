#!/usr/bin/env bash
# Puts the five secrets the release workflow signs and notarizes with into
# this repository, from the files Apple gives, with the GitHub CLI: nothing
# to base64 by hand, nothing to paste into a web page.
#
#   scripts/set-release-secrets.sh DeveloperID.p12 AuthKey_ABC123DEFG.p8 <issuer id>
#
# The .p12 is the Developer ID Application certificate with its key,
# exported from Keychain Access; its password is asked for (or read from
# MACOS_CERTIFICATE_PASSWORD). The .p8 is an App Store Connect API key
# (Users and Access > Integrations); its id is read from the file's name as
# Apple gives it (or from KEY_ID), and the issuer id is the one shown above
# the keys. Each is checked before anything is set.
#
#   DRY_RUN=1      checks everything, sets nothing
#   IDENTITY_KIND  the identity's name begins so (default "Developer ID
#                  Application"; scripts/rehearse-release.sh uses its own)
set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
    echo "error: $*" >&2
    exit 1
}

p12="${1:-}"
p8="${2:-}"
issuer="${3:-}"
[ -n "$p12" ] && [ -n "$p8" ] && [ -n "$issuer" ] || fail "usage: scripts/set-release-secrets.sh DeveloperID.p12 AuthKey_XXXXXXXXXX.p8 <issuer id>"
[ -f "$p12" ] || fail "no certificate at $p12"
[ -f "$p8" ] || fail "no API key at $p8"
KIND="${IDENTITY_KIND:-Developer ID Application}"

# The API key: a private key, its id from its name, the issuer an id.
grep -q "BEGIN PRIVATE KEY" "$p8" || fail "$p8 isn't an App Store Connect API key (no private key in it)"
key_id="${KEY_ID:-$(basename "$p8" .p8 | sed -n 's/^AuthKey_\([A-Z0-9]\{10\}\)$/\1/p')}"
[ -n "$key_id" ] || fail "can't read the key's id from the name $(basename "$p8") (Apple names it AuthKey_XXXXXXXXXX.p8); set KEY_ID"
echo "$key_id" | grep -Eq '^[A-Z0-9]{10}$' || fail "$key_id isn't a key id (ten capitals and digits)"
echo "$issuer" | grep -Eq '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' \
    || fail "$issuer isn't an issuer id (it looks like 69a6de70-0000-47e3-e053-5b8c7c11a4d1)"

# The certificate: it opens with its password and holds the identity.
password="${MACOS_CERTIFICATE_PASSWORD:-}"
if [ -z "$password" ] && [ -t 0 ]; then
    read -rsp "The password $p12 was exported with: " password
    echo
fi
legacy=""
openssl pkcs12 -help 2>&1 | grep -q -- "-legacy" && legacy="-legacy"
subject="$(P12_PASSWORD="$password" openssl pkcs12 $legacy -in "$p12" -nokeys -passin env:P12_PASSWORD 2>/dev/null \
    | openssl x509 -noout -subject 2>/dev/null || true)"
[ -n "$subject" ] || fail "$p12 doesn't open with that password"
echo "$subject" | grep -q "$KIND" || fail "$p12 holds \"$subject\", not a \"$KIND\" identity"
P12_PASSWORD="$password" openssl pkcs12 $legacy -in "$p12" -nocerts -nodes -passin env:P12_PASSWORD 2>/dev/null \
    | grep -q "PRIVATE KEY" || fail "$p12 holds the certificate without its key: export both from Keychain Access"

echo "Certificate: ${subject#subject=}"
echo "API key:     $key_id, issuer $issuer"

if [ "${DRY_RUN:-}" = 1 ]; then
    echo "Checked. Would set MACOS_CERTIFICATE, MACOS_CERTIFICATE_PASSWORD, APPLE_API_KEY, APPLE_API_KEY_ID and APPLE_API_ISSUER."
    exit 0
fi

command -v gh >/dev/null 2>&1 || fail "the GitHub CLI sets the secrets: brew install gh"
gh auth status >/dev/null 2>&1 || fail "sign the GitHub CLI in first: gh auth login"
base64 < "$p12" | tr -d '\n' | gh secret set MACOS_CERTIFICATE
printf '%s' "$password" | gh secret set MACOS_CERTIFICATE_PASSWORD
base64 < "$p8" | tr -d '\n' | gh secret set APPLE_API_KEY
printf '%s' "$key_id" | gh secret set APPLE_API_KEY_ID
printf '%s' "$issuer" | gh secret set APPLE_API_ISSUER
echo
echo "The five secrets are set. A signed, notarized release is now a tag away:"
echo "  git tag v1.0.0 && git push origin v1.0.0"
