#!/usr/bin/env bash
# Everything going live asks of a real Mac, in one command: Apple's
# on-device model heard speaking every voice within its rules
# (scripts/check-voices.sh), and the game's frame, GPU and turn figures
# measured on Apple silicon beside CI's (scripts/measure-mac.sh). Both are
# kept in perf/mac/ and committed, so they are on record for everyone.
# Needs a Mac with Apple silicon, macOS 26, and Apple Intelligence turned
# on and downloaded.
#
#   scripts/check-on-mac.sh             # hear, measure, commit
#   scripts/check-on-mac.sh --no-commit # hear and measure; leave perf/mac/ to commit
set -euo pipefail
cd "$(dirname "$0")/.."

commit=1
[ "${1:-}" = --no-commit ] && commit=0

echo "== 1 of 2: the voices"
scripts/check-voices.sh
echo
echo "== 2 of 2: the figures"
scripts/measure-mac.sh

echo
if [ "$commit" = 1 ]; then
    git add perf/mac
    if git diff --cached --quiet -- perf/mac; then
        echo "Nothing new to commit in perf/mac/."
    else
        git commit -m "Hear the voices and measure the game on $(sysctl -n hw.model)" -- perf/mac
        echo "Committed. Push it to put it on record: git push"
    fi
else
    echo "Kept in perf/mac/; commit it to put it on record."
fi
scripts/go-live-status.sh
