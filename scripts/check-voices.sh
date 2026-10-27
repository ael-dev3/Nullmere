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
if grep -q "with 0 failures" build/voices-test.log && ! grep -q "skipped" build/voices-test.log; then
    echo
    echo "The voices speak within their rules. The lines: build/voices-report.txt"
else
    echo
    echo "error: the voices didn't pass; see build/voices-report.txt and build/voices-test.log" >&2
    exit 1
fi
