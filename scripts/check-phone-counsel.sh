#!/usr/bin/env bash
# Takes counsel of a commander, and has the House's clerk read a keeper's
# own words, on the keeper's phone: Nullmere Companion, built for the iOS
# Simulator and run in one, asks the phone's on-device model as the
# companion asks it in the keeper's hand. A simulator's model is its Mac's,
# so on a Mac with Apple Intelligence this is that model's own answer.
# Counsel is held to counsel's rules as on the Mac (scripts/check-counsel.sh);
# the clerk's reading of plain words into the order book is written beside
# it, each line with the order the realm would take or why not.
# Needs Apple silicon, macOS 26, Xcode 26 with an iPhone simulator, and Apple
# Intelligence turned on and downloaded.
#
#   scripts/check-phone-counsel.sh               # builds the companion, then asks it
#   scripts/check-phone-counsel.sh --app <path>  # asks a companion already built
#
# Writes build/counsel-phone-report.txt and build/clerk-phone-report.txt,
# and, heard within counsel's rules off CI, keeps them in perf/mac/ to be
# committed. Exits 0 when counsel kept every rule, 1 when it didn't, and 2
# when the model couldn't be asked or gave no answer, saying why:
# unverified, not passed.
set -euo pipefail
cd "$(dirname "$0")/.."
[ "$(uname -m)" = arm64 ] || { echo "error: this needs a Mac with Apple silicon" >&2; exit 1; }
app="build/companion/Nullmere Companion.app"
case "${1:-}" in
    "")
        echo "== Building the companion for the iOS Simulator"
        scripts/build-companion.sh >/dev/null
        ;;
    --app) app="${2:?usage: scripts/check-phone-counsel.sh [--app <path>]}" ;;
    *) echo "usage: scripts/check-phone-counsel.sh [--app <path>]" >&2; exit 64 ;;
esac
[ -d "$app" ] || { echo "error: no companion at $app" >&2; exit 1; }
BUNDLE_ID=online.nullmere.companion

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
[ -n "$DEVICE" ] || { echo "error: no iPhone simulator is installed (Xcode, Settings, Components)" >&2; exit 1; }
read -r UDID IOS NAME <<<"$DEVICE"
echo "On $NAME, iOS $IOS ($UDID)."
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$UDID" "$app"
trap 'xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true' EXIT

DATA="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)"
COUNSEL="$DATA/Documents/counsel-report.txt"
CLERK="$DATA/Documents/clerk-report.txt"
rm -f "$COUNSEL" "$CLERK"
echo "== Taking counsel of a commander, and the clerk's reading, through the phone's own on-device model (a minute or two)"
SIMCTL_CHILD_NULLMERE_COUNSEL_REPORT=1 xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
for _ in $(seq 1 300); do
    [ -s "$COUNSEL" ] && [ -s "$CLERK" ] && break
    sleep 1
done
mkdir -p build
counsel=build/counsel-phone-report.txt
clerk=build/clerk-phone-report.txt
cp "$COUNSEL" "$counsel" 2>/dev/null || echo "The companion wrote no report of counsel." >"$counsel"
cp "$CLERK" "$clerk" 2>/dev/null || echo "The companion wrote no report of the clerk's reading." >"$clerk"
cat "$counsel"; echo
cat "$clerk"; echo
first="$(head -n 1 "$counsel")"
if [[ "$first" == *", not ready ("* ]] || [[ "$first" == *", unheard ("* ]]; then
    echo "Counsel on the phone wasn't heard: the model couldn't be asked, or gave no answer. Unverified, not passed." >&2
    exit 2
fi
if [ "$(tail -n 1 "$counsel")" != "Counsel kept to its rules." ]; then
    echo "error: counsel on the phone broke its rules; see $counsel" >&2
    exit 1
fi
if [ -z "${CI:-}" ]; then
    # Kept beside this Mac's own counsel, to be committed: the phone's
    # counsel and the clerk's reading heard from the model itself.
    name="$(sysctl -n hw.model | tr -c 'A-Za-z0-9,.-' '-' | sed 's/-*$//')"
    mkdir -p perf/mac
    cp "$counsel" "perf/mac/$name-counsel-phone.txt"
    cp "$clerk" "perf/mac/$name-clerk-phone.txt"
    echo "Counsel on the phone kept to its rules. What was heard: perf/mac/$name-counsel-phone.txt and perf/mac/$name-clerk-phone.txt"
fi
