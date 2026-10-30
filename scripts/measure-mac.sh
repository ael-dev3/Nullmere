#!/usr/bin/env bash
# Measures Nullmere Online on this Mac: the same frame, GPU and turn figures
# CI holds to perf/baseline.json, taken here and set beside CI's, and kept
# in perf/mac/<this Mac>.json to be committed, so the game's figures on real
# Apple silicon are on record. Needs a Mac with Apple silicon and macOS 26.
#
#   scripts/measure-mac.sh
set -euo pipefail
cd "$(dirname "$0")/.."

[ "$(uname -m)" = arm64 ] || { echo "error: this needs a Mac with Apple silicon" >&2; exit 1; }
model="$(sysctl -n hw.model)"
chip="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Apple silicon")"
memory="$(( $(sysctl -n hw.memsize) / 1073741824 )) GB"
system="macOS $(sw_vers -productVersion)"
name="$(echo "$model" | tr -c 'A-Za-z0-9,.-' '-' | sed 's/-*$//')"
mkdir -p build perf/mac

echo "== Measuring on $chip, $model, $memory, $system"
# Built as CI builds the figures it holds, with coverage on, so the two
# stand side by side on equal terms.
swift build --build-tests --enable-code-coverage >/dev/null
set +e
swift test --skip-build --enable-code-coverage --filter 'WorldPerformanceTests|FrameHarnessTests|OverlayPerformanceTests|ClientPaceTests|LakePerformanceTests|CalibrationTests|RealmTests/testTheRealmProperSeatsTwelveFairly' \
    2>&1 | tee build/mac-perf.log | grep -E "^PERF |error:"
status=${PIPESTATUS[0]}
set -e
# The run's own status decides, so one that crashes fails too; and its last
# count is the whole run's (each suite that passed has its own).
[ "$status" = 0 ] && grep "Executed .* tests" build/mac-perf.log | tail -n 1 | grep -Eq "(with|and) 0 failures" \
    || { echo "error: a measuring test failed, or the run ended early; see build/mac-perf.log" >&2; exit 1; }

echo
echo "== Beside CI's runner (perf/baseline.json)"
python3 scripts/perf-check.py build/mac-perf.log perf/baseline.json --report --json build/mac-perf.json
python3 - "$chip" "$model" "$memory" "$system" "perf/mac/$name.json" <<'PY'
import json, sys
chip, model, memory, system, out = sys.argv[1:]
figures = json.load(open("build/mac-perf.json"))["metrics"]
json.dump({"chip": chip, "model": model, "memory": memory, "system": system, "metrics": figures},
          open(out, "w"), indent=2, sort_keys=True)
frame = 1000 / 60
worst = max((v for k, v in figures.items() if ".gpu." in k or k.startswith("pan.")), default=0)
print(f"\nThe heaviest frame figure here: {worst:.2f} ms of a 60 Hz frame's {frame:.1f} ms.")
print(f"Kept in {out}: commit it, so these figures are on record.")
PY
