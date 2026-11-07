#!/usr/bin/env bash
# Everything going live asks of a real Mac, in one command: Apple's
# on-device model heard speaking every voice within its rules
# (scripts/check-voices.sh), a commander taking counsel through it, held to
# counsel's rules (scripts/check-counsel.sh), the game's frame, GPU and
# turn figures measured on Apple silicon beside CI's (scripts/measure-mac.sh),
# and the keeper's phone taking counsel and having the clerk read their own
# words through its model, in the iOS Simulator whose model is this Mac's
# (scripts/check-phone-counsel.sh).
# All four are kept in perf/mac/ and, when all pass, committed, so they are
# on record.
# Needs a Mac with Apple silicon, macOS 26, Xcode 26 with an iPhone
# simulator, and Apple Intelligence turned on and downloaded.
#
#   scripts/check-on-mac.sh             # check, hear, measure, commit
#   scripts/check-on-mac.sh --no-commit # check, hear, measure; leave perf/mac/ to commit
#
# Each part runs even when another fails; the summary says which passed,
# and the command fails unless all did. Counsel not taken because this Mac's
# model isn't ready is said to be unverified, not passed.
set -euo pipefail
cd "$(dirname "$0")/.."

commit=1
case "${1:-}" in
    "") ;;
    --no-commit) commit=0 ;;
    *) echo "usage: scripts/check-on-mac.sh [--no-commit]" >&2; exit 2 ;;
esac

# What this Mac must be, before the long part.
fail() { echo "error: $*" >&2; exit 1; }
[ "$(uname -s)" = Darwin ] || fail "this runs on a Mac"
[ "$(uname -m)" = arm64 ] || fail "this needs a Mac with Apple silicon"
major="$(sw_vers -productVersion | cut -d. -f1)"
[ "$major" -ge 26 ] || fail "this needs macOS 26 or later (this is $(sw_vers -productVersion))"
xcodebuild -version >/dev/null 2>&1 || fail "this needs Xcode 26: install it, then run: sudo xcode-select -s /Applications/Xcode.app"
echo "This Mac: $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'Apple silicon'), macOS $(sw_vers -productVersion), $(xcodebuild -version | head -n 1)"
echo

voices=failed
counsel=failed
figures=failed
phone=failed
echo "== 1 of 4: the voices"
if scripts/check-voices.sh; then voices=passed; fi
echo
echo "== 2 of 4: a commander's counsel"
heard=0
scripts/check-counsel.sh || heard=$?
case "$heard" in
    0) counsel=passed ;;
    2) counsel="unverified (the model isn't ready)" ;;
esac
echo
echo "== 3 of 4: the figures"
if scripts/measure-mac.sh; then figures=passed; fi
echo
echo "== 4 of 4: counsel and the clerk on the phone"
heard=0
scripts/check-phone-counsel.sh || heard=$?
case "$heard" in
    0) phone=passed ;;
    2) phone="unverified (the model gave no answer)" ;;
esac

echo
echo "== Summary"
printf '  %-28s %s\n' "The voices (Apple Intelligence)" "$voices" "Counsel (Apple Intelligence)" "$counsel" \
    "The figures (Apple silicon)" "$figures" "The phone (its Mac's model)" "$phone"
if [ "$voices" != passed ] || [ "$counsel" != passed ] || [ "$figures" != passed ] || [ "$phone" != passed ]; then
    echo
    echo "error: not everything passed; nothing was committed. See build/voices-report.txt, build/counsel-report.txt, build/mac-perf.log and build/counsel-phone-report.txt." >&2
    exit 1
fi

if [ "$commit" = 1 ]; then
    git add perf/mac
    if git diff --cached --quiet -- perf/mac; then
        echo "Nothing new to commit in perf/mac/."
    else
        git commit -m "Hear the voices and counsel, and measure the game on $(sysctl -n hw.model)" -- perf/mac
        echo "Committed. Put it on record: git push"
    fi
else
    echo "Kept in perf/mac/; commit and push it to put it on record."
fi
echo
scripts/go-live-status.sh
