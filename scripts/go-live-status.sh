#!/usr/bin/env bash
# Says where each step of going live stands (docs/GO-LIVE.md), and for
# each one not yet done, the one command that does it. Changes nothing.
#
#   scripts/go-live-status.sh                  # the realm proper
#   REALM_ADDRESS=http://127.0.0.1:3000/nullmere scripts/go-live-status.sh
#   scripts/go-live-status.sh --expect-realm   # fails unless the realm answers
#
# The release and its secrets are read with the GitHub CLI (gh) where it is
# signed in; without it, that step says it can't tell.
set -euo pipefail
cd "$(dirname "$0")/.."

ADDRESS="${REALM_ADDRESS:-https://maincloud.spacetimedb.com/nullmere}"
HOST="${ADDRESS%/*}"
DB="${ADDRESS##*/}"
EXPECT_REALM=0
[ "${1:-}" = --expect-realm ] && EXPECT_REALM=1

line() { printf '%-22s %s\n' "$1" "$2"; }
also() { printf '%-22s %s\n' "" "$1"; }
done_steps=0

echo "Nullmere Online, going live: where it stands"
echo

# 1. The realm: its status, read as a keeper would.
status_json=""
token="$(curl -s -m 10 -X POST "$HOST/v1/identity" 2>/dev/null | sed -n 's/.*"token":"\([^"]*\)".*/\1/p' || true)"
if [ -n "$token" ]; then
    status_json="$(curl -s -m 10 -X POST -H "Authorization: Bearer $token" --data "SELECT version, status FROM status" \
        "$HOST/v1/database/$DB/sql" 2>/dev/null || true)"
fi
realm="$(STATUS="$status_json" python3 -c '
import json, os
try:
    rows = json.loads(os.environ["STATUS"])[0]["rows"]
    s = json.loads(rows[0][1])
    online = s["online"]
    print("watch {0}, {1} of {2} seats held, {3} keeper{4} online|{5}".format(
        s["watch"], s["seats"] - s["freeSeats"], s["seats"], online, "" if online == 1 else "s", s["keepers"]))
except Exception:
    pass
' 2>/dev/null || true)"
keepers=""
if [ -n "$realm" ]; then
    keepers="${realm##*|}"
    line "1. The realm" "UP at $ADDRESS: ${realm%|*}"
    done_steps=$((done_steps + 1))
elif [ -n "$token" ]; then
    line "1. The realm" "NOT RAISED: SpacetimeDB answers at $HOST, but no realm \"$DB\" stands there"
    also "spacetime login && scripts/raise-realm.sh maincloud"
else
    line "1. The realm" "OUT OF REACH: nothing answers at $HOST"
    also "spacetime login && scripts/raise-realm.sh maincloud"
fi

# 2. The release: signed and notarized, or not yet.
secrets="MACOS_CERTIFICATE MACOS_CERTIFICATE_PASSWORD APPLE_API_KEY APPLE_API_KEY_ID APPLE_API_ISSUER"
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    # Listing secrets needs admin rights to the repository; without them
    # the secrets can't be told from missing ones.
    readable=1
    have="$(gh secret list 2>/dev/null | awk '{print $1}')" || readable=0
    missing=""
    if [ "$readable" = 1 ]; then
        for secret in $secrets; do
            echo "$have" | grep -qx "$secret" || missing="$missing $secret"
        done
    fi
    release="$(gh release view --json tagName,body --jq '.tagName + "|" + (.body | test("ad-hoc"; "i") | tostring)' 2>/dev/null || true)"
    if [ -n "$release" ] && [ "${release##*|}" = false ]; then
        line "2. The release" "NOTARIZED: ${release%|*}"
        done_steps=$((done_steps + 1))
    elif [ -n "$release" ]; then
        line "2. The release" "AD-HOC SIGNED: ${release%|*} is not notarized"
    else
        line "2. The release" "NONE YET"
    fi
    if [ "$readable" = 0 ]; then
        also "can't read the repository's secrets here (they need admin rights to list)"
    elif [ -n "$missing" ]; then
        also "secrets missing:$missing"
        also "scripts/set-release-secrets.sh DeveloperID.p12 AuthKey_XXXXXXXXXX.p8 <issuer id>"
    elif [ "${release##*|}" != false ]; then
        also "the secrets are all set: git tag v1.0.0 && git push origin v1.0.0"
    fi
else
    line "2. The release" "CAN'T TELL: the GitHub CLI isn't signed in here (gh auth login)"
    also "scripts/set-release-secrets.sh DeveloperID.p12 AuthKey_XXXXXXXXXX.p8 <issuer id>, then tag a version"
fi

# 3. On a real Mac: the voices heard with Apple Intelligence, and the
# figures measured on Apple silicon, both on record (scripts/check-on-mac.sh).
on_mac=0
report="$(ls perf/mac/*-voices.txt 2>/dev/null | head -n 1 || true)"
[ -n "$report" ] || report=build/voices-report.txt
if [ -s "$report" ] && grep -q "Every line within the rules." "$report"; then
    line "3. The voices" "HEARD, within their rules ($report)"
    on_mac=$((on_mac + 1))
elif [ -s "$report" ]; then
    line "3. The voices" "OUT OF BOUNDS: see $report"
    also "scripts/check-voices.sh"
else
    line "3. The voices" "NOT YET HEARD"
    also "scripts/check-on-mac.sh  (on a Mac with Apple Intelligence)"
fi
measured="$(ls perf/mac/*.json 2>/dev/null | tr '\n' ' ' || true)"
if [ -n "$measured" ]; then
    line "3. The figures" "MEASURED: $measured"
    on_mac=$((on_mac + 1))
else
    line "3. The figures" "NOT YET MEASURED"
    also "scripts/check-on-mac.sh  (on a Mac with Apple silicon)"
fi
[ "$on_mac" = 2 ] && done_steps=$((done_steps + 1))

# 4. VoiceOver, listened to: no machine can tell how it sounds.
line "4. VoiceOver" "BY EAR: docs/GO-LIVE.md, step 4 (CI audits every screen and walks the map: scripts/ui-test.sh)"

# 5. The first keepers.
if [ -n "$keepers" ] && [ "$keepers" -gt 0 ]; then
    line "5. Keepers" "$keepers keeper$([ "$keepers" = 1 ] || echo s) known to the realm"
    done_steps=$((done_steps + 1))
else
    line "5. Keepers" "NONE YET: they come once the realm is up and a release is out"
fi

echo
echo "$done_steps of the 4 steps a machine can check are done; step 4 is by ear."
if [ "$EXPECT_REALM" = 1 ] && [ -z "$realm" ]; then
    echo "error: the realm at $ADDRESS doesn't answer" >&2
    exit 1
fi
