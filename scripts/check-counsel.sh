#!/usr/bin/env bash
# Takes counsel of a commander on this Mac: the app asks Apple's on-device
# model, as the game asks it on a keeper's Mac, to answer as the keeper's
# commander three questions about the realm as their House sees it, looking
# about them with the counsel's tools and putting forward an order, then
# stops an answer as it begins. Every answer is held to counsel's rules
# (answered at all, short, grave, no number nothing told it, no talk of games
# or models), the orders put forward must be ones the realm would take, the
# commander must remember what was said, and the stopped answer must stop.
# Needs Apple silicon, macOS 26, and Apple Intelligence turned on and
# downloaded.
#
#   scripts/check-counsel.sh               # builds the debug app, then asks it
#   scripts/check-counsel.sh --app <path>  # asks a debug app already built
#
# Writes build/counsel-report.txt: every question, what the commander looked
# at, what they answered and how long it took. Exits 0 when counsel kept every
# rule, 1 when it didn't, and 2 when this Mac's model isn't ready at all
# (CI's virtual runners aren't eligible), saying why: unverified, not passed.
set -euo pipefail
cd "$(dirname "$0")/.."
[ "$(uname -m)" = arm64 ] || { echo "error: this needs a Mac with Apple silicon" >&2; exit 1; }
major="$(sw_vers -productVersion | cut -d. -f1)"
[ "$major" -ge 26 ] || { echo "error: this needs macOS 26 or later (this is $(sw_vers -productVersion))" >&2; exit 1; }
app=""
case "${1:-}" in
    "") ;;
    --app) app="${2:?usage: scripts/check-counsel.sh [--app <path>]}" ;;
    *) echo "usage: scripts/check-counsel.sh [--app <path>]" >&2; exit 2 ;;
esac
mkdir -p build
if [ -z "$app" ]; then
    echo "== Building the debug app"
    BUNDLE_ID=online.nullmere.launcher.voices CONFIGURATION=debug OUTPUT_DIR=build/voices scripts/build-app.sh >/dev/null
    app="build/voices/Nullmere Online.app"
fi
[ -d "$app" ] || { echo "error: no app at $app" >&2; exit 1; }
report="$PWD/build/counsel-report.txt"
rm -f "$report"
echo "== Taking counsel of a commander through Apple's on-device model (a minute or two)"
open -W -n --env NULLMERE_COUNSEL_REPORT="$report" "$app"
[ -s "$report" ] || { echo "error: the app wrote no report of the counsel" >&2; exit 1; }
if head -n 1 "$report" | grep -q ", not ready ("; then
    head -n 1 "$report"
    echo "Counsel wasn't taken: this Mac's on-device model isn't ready. Unverified, not passed." >&2
    exit 2
fi
cat "$report"
[ "$(tail -n 1 "$report")" = "Counsel kept to its rules." ]
