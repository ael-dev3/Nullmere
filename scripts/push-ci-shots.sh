#!/usr/bin/env bash
# Keeps a CI run's screenshots, and each test's time where the run timed
# them, on the ci-shots branch, in a folder of the run's own, so they can be
# fetched with git alone. Two jobs of one run keep theirs in the same folder,
# and another run may keep its own in between: a push that loses that race
# takes what the branch holds now and puts its own on top. It never forces,
# so nothing another job kept is pushed away.
#
#   RUN=746 SHA=<commit> TOKEN=<token> scripts/push-ci-shots.sh build
#   CI_SHOTS_URL=<git url> RUN=746 SHA=<commit> scripts/push-ci-shots.sh build
set -euo pipefail
from="$(cd "${1:?usage: scripts/push-ci-shots.sh <folder of screenshots>}" && pwd)"
: "${RUN:?set RUN to the run number}"
: "${SHA:?set SHA to the commit of the run}"
# Counted as they are found: macOS's bash 3.2 takes an empty list for an
# unset one.
files=()
count=0
for file in "$from"/*.png "$from"/test-times.txt; do
    if [ -f "$file" ]; then files+=("$file"); count=$((count + 1)); fi
done
if [ "$count" -eq 0 ]; then
    echo "No screenshots to keep."
    exit 0
fi
url="${CI_SHOTS_URL:-https://x-access-token:${TOKEN:?a token that may push}@github.com/${GITHUB_REPOSITORY:?}.git}"
dir="$(mktemp -d)"
trap 'rm -rf "$dir" "$dir.push"' EXIT
cd "$dir"
git init -q
git config user.name "ci-shots"
git config user.email "ci-shots@users.noreply.github.com"
# A push that loses waits a while, longer each time and never quite as
# long as another that lost with it, and tries again.
for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if git fetch -q --depth 1 "$url" ci-shots 2>/dev/null; then
        git checkout -q -B ci-shots FETCH_HEAD
    elif git ls-remote --exit-code --heads "$url" ci-shots >/dev/null 2>&1; then
        # The branch is there but wasn't fetched: never begin it anew over it.
        sleep $((attempt + RANDOM % 4))
        continue
    else
        git checkout -q --orphan ci-shots
    fi
    mkdir -p "$RUN"
    cp "${files[@]}" "$RUN"/
    echo "$SHA" > "$RUN/COMMIT"
    git add "$RUN"
    # Nothing new when a push that seemed to fail had gone through after all.
    git diff --cached --quiet || git commit -q -m "Screenshots of run $RUN ($SHA)"
    if git push -q "$url" ci-shots 2>"$dir.push"; then
        echo "Kept $count files on ci-shots, in $RUN/."
        exit 0
    fi
    sleep $((attempt + RANDOM % 4))
done
echo "error: the screenshots couldn't be kept on ci-shots:" >&2
cat "$dir.push" >&2
exit 1
