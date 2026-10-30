#!/usr/bin/env bash
# Hears Nullmere Online's voices on this Mac: the app asks Apple's on-device
# model to speak for each kind of envoy and chronicle entry, as the game asks
# it on a keeper's Mac, and holds every line to the voices' rules (spoken at
# all, short, grave, no numbers but the facts', no talk of games or
# players). Needs Apple silicon, macOS 26, and Apple Intelligence turned on
# and downloaded. CI runs it on its runner's own model.
#
#   scripts/check-voices.sh               # builds the debug app, then asks it
#   scripts/check-voices.sh --app <path>  # asks a debug app already built
#
# The model answers an app, not a bare process such as a test runner's, so
# the debug app is opened as a keeper's Mac opens it, through Launch
# Services; only a debug build takes NULLMERE_VOICES_REPORT, and with it it
# speaks, writes build/voices-report.txt and goes.
set -euo pipefail
cd "$(dirname "$0")/.."

[ "$(uname -m)" = arm64 ] || { echo "error: this needs a Mac with Apple silicon" >&2; exit 1; }
major="$(sw_vers -productVersion | cut -d. -f1)"
[ "$major" -ge 26 ] || { echo "error: this needs macOS 26 or later (this is $(sw_vers -productVersion))" >&2; exit 1; }

app=""
case "${1:-}" in
    "") ;;
    --app) app="${2:?usage: scripts/check-voices.sh [--app <path>]}" ;;
    *) echo "usage: scripts/check-voices.sh [--app <path>]" >&2; exit 2 ;;
esac

mkdir -p build
if [ -z "$app" ]; then
    echo "== Building the debug app"
    BUNDLE_ID=online.nullmere.launcher.voices CONFIGURATION=debug OUTPUT_DIR=build/voices scripts/build-app.sh >/dev/null
    app="build/voices/Nullmere Online.app"
fi
[ -d "$app" ] || { echo "error: no app at $app" >&2; exit 1; }

report="$PWD/build/voices-report.txt"
rm -f "$report"
echo "== Asking Apple's on-device model for each voice (a minute or two)"
open -W -n --env NULLMERE_VOICES_REPORT="$report" "$app"
[ -s "$report" ] || { echo "error: the app wrote no report of the voices" >&2; exit 1; }
cat "$report"

if [ "$(tail -n 1 "$report")" = "Every line within the rules." ]; then
    if [ -z "${CI:-}" ]; then
        # Kept beside this Mac's measurements, to be committed: heard, on record.
        name="$(sysctl -n hw.model | tr -c 'A-Za-z0-9,.-' '-' | sed 's/-*$//')"
        mkdir -p perf/mac
        cp "$report" "perf/mac/$name-voices.txt"
        echo
        echo "The voices speak within their rules. The lines: perf/mac/$name-voices.txt"
    else
        echo
        echo "The voices speak within their rules."
    fi
else
    echo
    echo "error: the voices didn't keep their rules, or weren't heard; see build/voices-report.txt" >&2
    exit 1
fi
