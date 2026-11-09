#!/usr/bin/env bash
# A keeper's phone beside their Mac, both real apps on one realm across the
# network: Nullmere Online (a debug build) enters the realm as a keeper and
# offers a link; Nullmere Companion, built for the iOS Simulator by
# scripts/build-companion.sh and run in one, takes the link as the phone's
# camera would, comes in as the keeper, keeps their House from the phone (a
# company dug in, words said to the realm, an alliance raised and words
# said to it, the caretaker's standing orders given, a line of its
# commanders stood in the Ring, the keeper made ready so the watch turns,
# a hold set to work), each
# carried out by the realm, is set aside and comes in again by its own key;
# and the Mac sees the company dug in, hears the words, sees the alliance
# raised, the line in the Ring, the watch turned and the hold at work, and
# its phone in the realm with it; and, seeing the company dug
# in, the Mac says so to the realm and the phone hears its answer come back.
# The phone reaches the realm through a line of its own (scripts/line-relay.py),
# which is cut and mended: it says the realm is out of reach, for how long
# and that it tries again, and keeps the House, says words to the realm while
# it is, and once the line is mended is in reach again by its own key, told
# back in step after how long, its words carried out and heard on the Mac
# (build/companion-lost.png and build/companion-mended.png), each with the
# Mac's own screen beside it (build/companion-beside-lost.png and
# build/companion-beside-mended.png).
# Then the phone takes counsel of a commander through its
# own on-device model, as the Mac's check does: heard and held to counsel's
# rules, or, where the simulator's Mac can't run the model, said to be
# unverified. Saves the companion's screens, the Mac's beside its House tab
# (build/companion-beside-mac.png, by scripts/beside.swift), and the reports:
# build/companion-*.png, build/companion-report.txt,
# build/companion-lost-report.txt, build/companion-mac-report.txt and
# build/counsel-phone-report.txt.
#
#   NULLMERE_REALM=http://127.0.0.1:3000/nullmere scripts/smoke-test-companion.sh
#
# Only debug builds heed NULLMERE_OFFER_LINK, NULLMERE_LINK_REPORT and the
# companion's NULLMERE_COMPANION_LINK, NULLMERE_COMPANION_TAB,
# NULLMERE_COMPANION_LOST and NULLMERE_COUNSEL_REPORT.
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
LOST_REPORT="build/companion-lost-report.txt"
LINE_LOG="build/companion-line.log"
IDENTITY="$PWD/build/companion-mac-identity"
mkdir -p build
rm -f "$LINK" "$MAC_REPORT" "$REPORT" "$COUNSEL_REPORT" "$LOST_REPORT" "$LINE_LOG" "$IDENTITY" build/companion-*.png
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
relay=""
cleanup() {
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
    if [ -n "$mac" ]; then kill -TERM "$mac" 2>/dev/null || true; wait "$mac" 2>/dev/null || true; fi
    if [ -n "$relay" ]; then kill -TERM "$relay" 2>/dev/null || true; wait "$relay" 2>/dev/null || true; fi
    rm -f "$IDENTITY"
}
trap cleanup EXIT
shot() {
    sleep "${2:-6}"
    xcrun simctl io "$UDID" screenshot "build/companion-$1.png" >/dev/null 2>&1 || echo "warning: no screenshot of $1" >&2
}

# The Mac's own screen as the phone's screen `$1` was just taken, the two
# set side by side in build/companion-beside-$1.png.
beside() {
    if screencapture -x "build/companion-mac-$1.png" 2>/dev/null && [ -s "build/companion-$1.png" ]; then
        swift scripts/beside.swift "build/companion-mac-$1.png" "build/companion-$1.png" "build/companion-beside-$1.png" \
            && echo "The Mac and the phone photographed together: build/companion-beside-$1.png" \
            || echo "warning: the Mac and the phone weren't set side by side ($1)" >&2
    else
        echo "warning: no photograph of the Mac beside the phone ($1)" >&2
    fi
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

# The phone reaches the realm through a line of its own, carried byte for
# byte, to be cut and mended later on: the network lost under the phone and
# found again, the Mac and the realm going on all the while.
SERVER="${REALM#*://}"
SERVER="${SERVER%%/*}"
python3 scripts/line-relay.py 0 "$SERVER" >"$LINE_LOG" 2>&1 &
relay=$!
for _ in $(seq 1 40); do
    grep -q "^listening " "$LINE_LOG" 2>/dev/null && break
    sleep 0.25
done
LINE_PORT="$(sed -n 's/^listening //p' "$LINE_LOG")"
if [ -z "$LINE_PORT" ]; then
    echo "error: the phone's line to the realm didn't open" >&2
    cat "$LINE_LOG" >&2 || true
    exit 1
fi
INVITE="$(python3 -c '
import sys, urllib.parse as up
link, port = sys.argv[1], sys.argv[2]
parts = up.urlsplit(link)
items = [(key, up.urlunsplit(up.urlsplit(value)._replace(netloc="127.0.0.1:" + port)) if key == "realm" else value)
         for key, value in up.parse_qsl(parts.query, keep_blank_values=True)]
print(up.urlunsplit(parts._replace(query=up.urlencode(items))))
' "$INVITE" "$LINE_PORT")"
echo "The phone reaches the realm through a line of its own, by port $LINE_PORT."

# The phone takes it, as its camera would hand it the link.
SIMCTL_CHILD_NULLMERE_COMPANION_LINK="$INVITE" SIMCTL_CHILD_NULLMERE_COMPANION_TAB=army \
    xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
DATA="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)"
KEPT="$DATA/Documents/companion-report.txt"
# Its steps take a few minutes, the watch turning when the keeper is ready
# among them (at once while no keeper whose House stands is away, as CI
# runs it; a third of a watch into it were one away); the report ends with
# the word on them all once they are done.
for _ in $(seq 1 360); do
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

# The Mac sees its keeper's phone in the realm with them, by the realm's
# word on the devices it has heard from lately.
PHONE_SEEN=no
for _ in $(seq 1 30); do
    if grep -qE "^phone: in" "$MAC_REPORT" 2>/dev/null; then PHONE_SEEN=yes; break; fi
    sleep 1
done
echo "The Mac sees its phone in the realm: $PHONE_SEEN ($(grep '^phone: ' "$MAC_REPORT" 2>/dev/null || echo "no report"))"

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
STANDING="$(sed -n 's/^Standing orders: //p' "$REPORT" | head -n 1)"
STOOD=no
if [ -n "$STANDING" ]; then
    for _ in $(seq 1 30); do
        if grep -qxF "standing: $STANDING" "$MAC_REPORT" 2>/dev/null; then STOOD=yes; break; fi
        sleep 1
    done
fi
echo "The Mac sees the standing orders the phone gave: $STOOD${STANDING:+ ($STANDING)}"
RING_LINE="$(sed -n 's/^Ring line: //p' "$REPORT" | head -n 1)"
IN_RING=no
if [ -n "$RING_LINE" ]; then
    for _ in $(seq 1 30); do
        if grep -qxF "ring: $RING_LINE" "$MAC_REPORT" 2>/dev/null; then IN_RING=yes; break; fi
        sleep 1
    done
fi
echo "The Mac sees the line the phone stood in the Ring: $IN_RING${RING_LINE:+ (commanders $RING_LINE)}"
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

# The phone's line to the realm cut and mended: in again by its own key, it
# says the realm is out of reach and keeps the House, says words to the realm
# while it is, and once the line is mended is in reach again, its words
# carried out by the realm and heard on the Mac. Word of the cut and of the
# mending is left in its Documents, for it to time itself by.
LOST="$DATA/Documents/lost-report.txt"
rm -f "$LOST" "$DATA/Documents/line-cut" "$DATA/Documents/line-mended"
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
SIMCTL_CHILD_NULLMERE_COMPANION_LOST=1 xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
for _ in $(seq 1 60); do
    grep -qE "^In again|^Broken" "$LOST" 2>/dev/null && break
    sleep 1
done
echo "Cutting the phone's line to the realm…"
kill -USR1 "$relay" 2>/dev/null || echo "warning: the phone's line had already gone" >&2
touch "$DATA/Documents/line-cut"
for _ in $(seq 1 90); do
    grep -qE "^Said while cut off: |^Broken" "$LOST" 2>/dev/null && break
    sleep 1
done
shot lost 1
# The Mac beside it: still in the realm while its phone is out of reach.
beside lost
echo "Mending it…"
kill -USR2 "$relay" 2>/dev/null || echo "warning: the phone's line had already gone" >&2
touch "$DATA/Documents/line-mended"
for _ in $(seq 1 150); do
    grep -qE "came back to the realm|^Broken" "$LOST" 2>/dev/null && break
    sleep 1
done
# Back in step: the House tab tells after how long out of touch, the Mac
# beside it.
shot mended 1
beside mended
cp "$LOST" "$LOST_REPORT" 2>/dev/null || echo "The companion wrote no report of its line cut." >"$LOST_REPORT"
cat "$LOST_REPORT"; echo
CUT_OFF="$(sed -n 's/^Said while cut off: //p' "$LOST_REPORT" | head -n 1)"
CAME_BACK=no
if [ -n "$CUT_OFF" ] && grep -q "The companion came back to the realm." "$LOST_REPORT"; then
    for _ in $(seq 1 30); do
        if grep -qxF "said: $CUT_OFF" "$MAC_REPORT" 2>/dev/null; then CAME_BACK=yes; break; fi
        sleep 1
    done
fi
echo "The Mac hears what the phone said while its line was down: $CAME_BACK"

# The phone's other screens, in again by its own key each time, and
# counsel with the House's first free commander, then asked a question,
# with what came of it: the model's answer, or why there was none.
for tab in house market ventures land alliance realm counsel counsel-asked words; do
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
    SIMCTL_CHILD_NULLMERE_COMPANION_TAB="$tab" xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
    if [ "$tab" = counsel-asked ]; then shot "$tab" 20; else shot "$tab" 8; fi
    # The Mac's own screen as the phone's House tab is taken, the two set
    # side by side: one House, its watch and its stores alike on both.
    if [ "$tab" = house ]; then
        if screencapture -x build/companion-mac.png 2>/dev/null && [ -s build/companion-house.png ]; then
            swift scripts/beside.swift build/companion-mac.png build/companion-house.png build/companion-beside-mac.png \
                && echo "The Mac and the phone photographed together: build/companion-beside-mac.png" \
                || echo "warning: the Mac and the phone weren't set side by side" >&2
        else
            echo "warning: no photograph of the Mac beside the phone" >&2
        fi
    fi
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
if [ "$PHONE_SEEN" != yes ]; then
    echo "error: the Mac never saw its phone in the realm" >&2
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
if [ "$STOOD" != yes ]; then
    echo "error: the Mac never saw the standing orders given on the phone" >&2
    exit 1
fi
if [ -n "$RING_LINE" ] && [ "$IN_RING" != yes ]; then
    echo "error: the Mac never saw the line stood in the Ring on the phone" >&2
    exit 1
fi
if [ "$TURNED" != yes ]; then
    echo "error: the Mac never came to the watch the phone came to" >&2
    exit 1
fi
if [ "$CAME_BACK" != yes ]; then
    echo "error: the phone didn't come back to the realm when its line was mended, or the Mac never heard it; see $LOST_REPORT" >&2
    exit 1
fi
if [ "$PHONE_COUNSEL" = failed ]; then
    echo "error: counsel on the phone didn't keep its rules, or wasn't heard; see $COUNSEL_REPORT" >&2
    exit 1
fi
echo "Nullmere Companion, on iOS $IOS in the simulator, kept its keeper's House beside their Mac on the realm."
