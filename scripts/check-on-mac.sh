#!/usr/bin/env bash
# Everything going live asks of a real Mac, in one command: Apple's
# on-device model heard speaking every voice within its rules
# (scripts/check-voices.sh), and the game's frame, GPU and turn figures
# measured on Apple silicon beside CI's (scripts/measure-mac.sh). Both are
# kept in perf/mac/ and, when both pass, committed, so they are on record.
# Needs a Mac with Apple silicon, macOS 26, Xcode 26, and Apple
# Intelligence turned on and downloaded.
#
#   scripts/check-on-mac.sh             # check, hear, measure, commit
#   scripts/check-on-mac.sh --no-commit # check, hear, measure; leave perf/mac/ to commit
#
# Each half runs even when the other fails; the summary says which passed,
# and the command fails unless both did.
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
figures=failed
echo "== 1 of 2: the voices"
if scripts/check-voices.sh; then voices=passed; fi
echo
echo "== 2 of 2: the figures"
if scripts/measure-mac.sh; then figures=passed; fi

echo
echo "== Summary"
printf '  %-28s %s\n' "The voices (Apple Intelligence)" "$voices" "The figures (Apple silicon)" "$figures"
if [ "$voices" != passed ] || [ "$figures" != passed ]; then
    echo
    echo "error: not everything passed; nothing was committed. See build/voices-report.txt and build/mac-perf.log." >&2
    exit 1
fi

if [ "$commit" = 1 ]; then
    git add perf/mac
    if git diff --cached --quiet -- perf/mac; then
        echo "Nothing new to commit in perf/mac/."
    else
        git commit -m "Hear the voices and measure the game on $(sysctl -n hw.model)" -- perf/mac
        echo "Committed. Put it on record: git push"
    fi
else
    echo "Kept in perf/mac/; commit and push it to put it on record."
fi
echo
scripts/go-live-status.sh
