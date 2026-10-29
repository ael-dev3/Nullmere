#!/usr/bin/env bash
# Checks the shell scripts as /bin/bash reads them (macOS's is 3.2; Linux
# has a newer one): each parses, and
# no variable runs into a non-ASCII character: bash 3.2 reads an ellipsis
# straight after a variable as part of its name. Brace the name instead.
set -euo pipefail
cd "$(dirname "$0")/.."
status=0
for script in scripts/*.sh; do
    /bin/bash -n "$script" || status=1
    if LC_ALL=C grep -nE '\$[A-Za-z_][A-Za-z0-9_]*[^ -~]' "$script"; then
        echo "error: $script: brace the variable before a non-ASCII character" >&2
        status=1
    fi
done
# What the scripts do, against stand-ins.
scripts/test-scripts.sh || status=1
# The Python helpers' own checks.
python3 scripts/perf-check.py --self-test || status=1
python3 scripts/coverage.py --self-test || status=1
[ "$status" = 0 ] && echo "The scripts read cleanly."
exit "$status"
