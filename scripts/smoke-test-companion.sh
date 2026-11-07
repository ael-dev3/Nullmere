#!/usr/bin/env bash
# A keeper's phone beside their Mac, both real apps on one realm across the
# network: Nullmere Online (a debug build) enters the realm as a keeper and
# offers a link; Nullmere Companion, built for the iOS Simulator by
# scripts/build-companion.sh and run in one, takes the link as the phone's
# camera would, comes in as the keeper, keeps their House from the phone (a
# company dug in, words said to the realm, an alliance raised and words
# said to it, the keeper made ready so the watch turns, a hold set to work), each
# carried out by the realm, is set aside and comes in again by its own key;
# and the Mac sees the company dug in, hears the words, sees the alliance
# raised, the watch turned and the hold at work; and, seeing the company dug
# in, the Mac says so to the realm and the phone hears its answer come back.
# Then the phone takes counsel of a commander through its
# own on-device model, as the Mac's check does: heard and held to counsel's
# rules, or, where the simulator's Mac can't run the model, said to be
# unverified. Saves the companion's screens and the reports:
# build/companion-*.png, build/companion-report.txt,
# build/companion-mac-report.txt and build/counsel-phone-report.txt.
#
#   NULLMERE_REALM=http://127.0.0.1:3000/nullmere scripts/smoke-test-companion.sh
#
# Only debug builds heed NULLMERE_OFFER_LINK, NULLMERE_LINK_REPORT and the
# companion's NULLMERE_COMPANION_LINK, NULLMERE_COMPANION_TAB and
# NULLMERE_COUNSEL_REPORT.
set -Eeuo pipefail
# A step that stops the script says where, so no failure is a silent one.
trap 'echo "error: smoke-test-companion.sh stopped at line $LINENO: $BASH_COMMAND" >&2' ERR
cd "$(dirname "$0")/.."
# shellcheck source=settled-log.sh
. scripts/settled-log.sh

REALM="${NULLMERE_REALM:-http://127.0.0.1:3000/nullmere}"
APP="build/companion/Nullmere Companion.app"
BUNDLE_ID=online.nullmere.companion
KEEPER="${KEEPER:-Brannoc}"
MAC="${BIN:-$(swift build --show-bin-path)/NullmereLauncher}"
LINK="$PWD/build/companion-link.txt"
MAC_REPORT="$PWD/build/companion-mac-report.txt"
REPORT="build/companion-report.txt"
COUNSEL_REPORT="build/counsel-phone-report.txt"
IDENTITY="$PWD/build/companion-mac-identity"
mkdir -p build
rm -f "$LINK" "$MAC_REPORT" "$REPORT" "$COUNSEL_REPORT" "$IDENTITY" build/companion-*.png
[ -d "$APP" ] || scripts/build-companion.sh

# An iPhone of the newest iOS the simulators have, booted.
DEVICE="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
runtimes = json.load(sys.stdin)["devices"]
best = None
for runtime, devices in runtimes.items():
    if ".iOS-" not in runtime:
        continue
    version = tuple(int(part) for part in runtime.rsplit(".iOS-", 1)[1].split("-"))
    for device in devices:
        if device.get("isAvailable") and device["name"].startswith("iPhone"):
            if best is None or version > best[0]:
                best = (version, device["udid"], device["name"])
if best:
    print(best[1], ".".join(map(str, best[0])), best[2])
')"
if [ -z "$DEVICE" ]; then
    echo "error: no iPhone simulator is installed" >&2
    exit 1
fi
read -r UDID IOS NAME <<<"$DEVICE"
echo "On $NAME, iOS $IOS ($UDID)."
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"

mac=""
cleanup() {
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
    if [ -n "$mac" ]; then kill -TERM "$mac" 2>/dev/null || true; wait "$mac" 2>/dev/null || true; fi
    rm -f "$IDENTITY"
}
trap cleanup EXIT
shot() {
    sleep "${2:-6}"
    xcrun simctl io "$UDID" screenshot "build/companion-$1.png" >/dev/null 2>&1 || echo "warning: no screenshot of $1" >&2
}

# Before any link: the phone asks for the code its keeper's Mac shows.
xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
shot pairing
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true

# The Mac: in as the keeper, offering a link and saying what it sees.
started="$(date '+%Y-%m-%d %H:%M:%S')"
echo "Opening Nullmere Online and entering $REALM as ${KEEPER}, to offer a link…"
NULLMERE_MODEL_STATE=ready NULLMERE_LAUNCHER_KEYS=return NULLMERE_REALM="$REALM" NULLMERE_IDENTITY_FILE="$IDENTITY" \
    NULLMERE_KEEPER="$KEEPER" NULLMERE_OFFER_LINK="$LINK" NULLMERE_LINK_REPORT="$MAC_REPORT" NULLMERE_ANSWER_PHONE=1 \
    "$MAC" >build/companion-mac-stdout.log 2>&1 &
mac=$!
for _ in $(seq 1 90); do
    [ -s "$LINK" ] && break
    sleep 1
done
if [ ! -s "$LINK" ]; then
    echo "error: the Mac offered no link within 90 seconds" >&2
    # Why, in the game's own words: whether it entered, was refused or
    # couldn't reach the realm, or why no link was offered.
    settled_log "$started" online.nullmere.game "realm" \
        | grep -E "Entered the realm|refused|unreachable|No phone link" \
        | sed -E 's/^.*\[online\.nullmere\.game[^]]*\] /The Mac said: /' >&2 || true
    cat build/companion-mac-stdout.log >&2 || true
    exit 1
fi
INVITE="$(cat "$LINK")"
echo "The Mac offered a link to ${INVITE%%code=*}code=(twelve letters and figures)."

# The phone takes it, as its camera would hand it the link.
SIMCTL_CHILD_NULLMERE_COMPANION_LINK="$INVITE" SIMCTL_CHILD_NULLMERE_COMPANION_TAB=army \
    xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
DATA="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)"
KEPT="$DATA/Documents/companion-report.txt"
# Its steps take a minute or so, the watch turning when the keeper is ready
# among them; the report ends with the word on them all once they are done.
for _ in $(seq 1 240); do
    grep -qE "kept its keeper's House|^Broken" "$KEPT" 2>/dev/null && break
    sleep 1
done
cp "$KEPT" "$REPORT" 2>/dev/null || echo "The companion wrote no report." >"$REPORT"
shot army 2
# The apps' reports end without a newline: what follows starts its own line.
cat "$REPORT"; echo

# The Mac sees the company the phone ordered dug in.
COMPANY="$(sed -n 's/^Fortified company: //p' "$REPORT" | head -n 1)"
SEEN=no
if [ -n "$COMPANY" ]; then
    for _ in $(seq 1 30); do
        if grep -qE "(^| )$COMPANY( |$)" "$MAC_REPORT" 2>/dev/null; then SEEN=yes; break; fi
        sleep 1
    done
fi
echo "The Mac sees the phone's order: $SEEN ($(head -n 1 "$MAC_REPORT" 2>/dev/null || echo "no report"))"

# The Mac sees the hold the phone set to work, and hears the words it said.
WORK="$(sed -n 's/^At work: //p' "$REPORT" | head -n 1)"
WORKING=no
if [ -n "$WORK" ]; then
    for _ in $(seq 1 30); do
        if grep -qE "^at work: (.* )?$WORK( |$)" "$MAC_REPORT" 2>/dev/null; then WORKING=yes; break; fi
        sleep 1
    done
fi
echo "The Mac sees the phone's work: $WORKING ($(grep '^at work: ' "$MAC_REPORT" 2>/dev/null || echo "no report"))"
WORDS="$(sed -n 's/^Said to the realm: //p' "$REPORT" | head -n 1)"
HEARD=no
if [ -n "$WORDS" ]; then
    for _ in $(seq 1 30); do
        if grep -qxF "said: $WORDS" "$MAC_REPORT" 2>/dev/null; then HEARD=yes; break; fi
        sleep 1
    done
fi
echo "The Mac hears the phone's words: $HEARD"
# And back: the Mac, seeing the company the phone dug in, says so to the
# realm, and the phone hears it.
ANSWER="$(sed -n 's/^Heard from the Mac: //p' "$REPORT" | head -n 1)"
ANSWERED=no
[[ "$ANSWER" == "Seen on the Mac: "* ]] && ANSWERED=yes
echo "The phone hears the Mac's answer: $ANSWERED${ANSWER:+ ($ANSWER)}"
BANNER="$(sed -n 's/^Raised the banner of: //p' "$REPORT" | head -n 1)"
RAISED=no
if [ -n "$BANNER" ]; then
    for _ in $(seq 1 30); do
        if grep -qxF "alliance: $BANNER" "$MAC_REPORT" 2>/dev/null; then RAISED=yes; break; fi
        sleep 1
    done
fi
echo "The Mac sees the alliance the phone raised: $RAISED"
ALLIED_WORDS="$(sed -n 's/^Said to the alliance: //p' "$REPORT" | head -n 1)"
ALLIES_HEARD=no
if [ -n "$ALLIED_WORDS" ]; then
    for _ in $(seq 1 30); do
        if grep -qxF "alliance said: $ALLIED_WORDS" "$MAC_REPORT" 2>/dev/null; then ALLIES_HEARD=yes; break; fi
        sleep 1
    done
fi
echo "The Mac hears the phone's words to the alliance: $ALLIES_HEARD"
TURNED_TO="$(sed -n 's/^Watch: //p' "$REPORT" | head -n 1)"
TURNED=no
if [ -n "$TURNED_TO" ]; then
    for _ in $(seq 1 30); do
        MAC_WATCH="$(sed -n 's/^watch: //p' "$MAC_REPORT" 2>/dev/null | head -n 1)"
        if [ -n "$MAC_WATCH" ] && [ "$MAC_WATCH" -ge "$TURNED_TO" ]; then TURNED=yes; break; fi
        sleep 1
    done
fi
echo "The Mac sees the watch the phone came to: $TURNED (the phone's watch ${TURNED_TO:-unknown}, the Mac's ${MAC_WATCH:-unknown})"

# The phone's other screens, in again by its own key each time, and
# counsel with the House's first free commander.
for tab in house land alliance counsel words; do
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
    SIMCTL_CHILD_NULLMERE_COMPANION_TAB="$tab" xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
    shot "$tab" 8
done

# Counsel through the phone's own model, as the keeper takes it there: the
# report is written once, whole, when the counsel is done.
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
COUNSEL="$DATA/Documents/counsel-report.txt"
rm -f "$COUNSEL"
echo "Taking counsel of a commander through the phone's own on-device model…"
SIMCTL_CHILD_NULLMERE_COUNSEL_REPORT=1 xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
for _ in $(seq 1 240); do
    [ -s "$COUNSEL" ] && break
    sleep 1
done
cp "$COUNSEL" "$COUNSEL_REPORT" 2>/dev/null || echo "The companion wrote no report of counsel." >"$COUNSEL_REPORT"
cat "$COUNSEL_REPORT"; echo
PHONE_COUNSEL=failed
# Read whole first: grep -q leaving a pipe early must not read as no match.
COUNSEL_FIRST="$(head -n 1 "$COUNSEL_REPORT")"
if [[ "$COUNSEL_FIRST" == *", not ready ("* ]]; then
    PHONE_COUNSEL="unverified: the model can't be asked here"
elif [[ "$COUNSEL_FIRST" == *", unheard ("* ]]; then
    PHONE_COUNSEL="unverified: the simulator's model is its Mac's, and it gave no answer"
elif [ "$(tail -n 1 "$COUNSEL_REPORT")" = "Counsel kept to its rules." ]; then
    PHONE_COUNSEL="heard, within its rules"
fi
echo "Counsel on the phone: $PHONE_COUNSEL"

if ! grep -q "The companion kept its keeper's House." "$REPORT"; then
    echo "error: the companion didn't keep its keeper's House" >&2
    exit 1
fi
if [ "$SEEN" != yes ]; then
    echo "error: the Mac never saw the order given on the phone" >&2
    exit 1
fi
if [ "$WORKING" != yes ]; then
    echo "error: the Mac never saw the hold the phone set to work" >&2
    exit 1
fi
if [ "$HEARD" != yes ]; then
    echo "error: the Mac never heard the words said on the phone" >&2
    exit 1
fi
if [ "$ANSWERED" != yes ]; then
    echo "error: the phone never heard the Mac's answer to its order" >&2
    exit 1
fi
if [ "$RAISED" != yes ]; then
    echo "error: the Mac never saw the alliance raised on the phone" >&2
    exit 1
fi
if [ "$ALLIES_HEARD" != yes ]; then
    echo "error: the Mac never heard the words said to the alliance on the phone" >&2
    exit 1
fi
if [ "$TURNED" != yes ]; then
    echo "error: the Mac never came to the watch the phone came to" >&2
    exit 1
fi
if [ "$PHONE_COUNSEL" = failed ]; then
    echo "error: counsel on the phone didn't keep its rules, or wasn't heard; see $COUNSEL_REPORT" >&2
    exit 1
fi
echo "Nullmere Companion, on iOS $IOS in the simulator, kept its keeper's House beside their Mac on the realm."
