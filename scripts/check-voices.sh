#!/usr/bin/env bash
# Hears Nullmere Online's voices on this Mac: Apple's on-device model speaks
# for each kind of envoy and chronicle entry, and every line is held to the
# voices' rules (spoken at all, short, grave, no numbers but the facts', no
# talk of games or players). Needs a Mac with Apple silicon, macOS 26 and
# Apple Intelligence turned on and downloaded. CI can't: it has none.
#
#   scripts/check-voices.sh        # prints the lines; build/voices-report.txt keeps them
set -euo pipefail
cd "$(dirname "$0")/.."

[ "$(uname -m)" = arm64 ] || { echo "error: this needs a Mac with Apple silicon" >&2; exit 1; }
major="$(sw_vers -productVersion | cut -d. -f1)"
[ "$major" -ge 26 ] || { echo "error: this needs macOS 26 or later (this is $(sw_vers -productVersion))" >&2; exit 1; }

echo "== Building"
swift build --build-tests >/dev/null
echo "== Asking Apple's on-device model for each voice (a minute or two)"
mkdir -p build
NULLMERE_LIVE_VOICES=1 swift test --skip-build --filter VoicesLiveTests 2>&1 | tee build/voices-test.log | grep -vE "^Test (Suite|Case)|^\s*Executed" || true
# The last count is the whole run's; a skip means no model answered.
total="$(grep "Executed .* tests" build/voices-test.log | tail -n 1)"
if echo "$total" | grep -Eq "(with|and) 0 failures" && ! echo "$total" | grep -q "skipped"; then
    # Kept beside this Mac's measurements, to be committed: heard, on record.
    name="$(sysctl -n hw.model | tr -c 'A-Za-z0-9,.-' '-' | sed 's/-*$//')"
    mkdir -p perf/mac
    cp build/voices-report.txt "perf/mac/$name-voices.txt"
    echo
    echo "The voices speak within their rules. The lines: perf/mac/$name-voices.txt"
else
    echo
    echo "error: the voices didn't pass; see build/voices-report.txt and build/voices-test.log" >&2
    exit 1
fi
