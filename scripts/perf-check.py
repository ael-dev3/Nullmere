#!/usr/bin/env python3
"""Holds the frame and turn timings the tests print to their baselines.

    scripts/perf-check.py <test-log> <baseline.json> [--json out.json]
    scripts/perf-check.py <test-log> <baseline.json> --report   # told, never failed
    scripts/perf-check.py --self-test

The tests print `PERFMETRIC <name> <milliseconds>`. Each name in the
baseline must stay within its allowance:

    allowed = max(baseline * ratio, baseline + slack_ms), and at most `limit`

where `ratio` and `slack_ms` come from the metric or the file, so a noisy
runner doesn't fail CI but a real regression does. A metric whose baseline
is null is recorded, not held, until a baseline is written for it. With no
GPU on the runner the GPU metrics are missing; that is said, not failed.
Anything else missing fails, so a renamed metric can't slip its baseline.
Fails, too, if a figure is under a third of its baseline: either the
work is no longer measured, or the baseline should come down.

A shared runner is faster some days than others. The metric marked
"calibration" times a fixed piece of plain work, none of it the game's;
when this run's is slower than its baseline, every metric marked "cpu" is
allowed that much more, up to twice. A slower machine moves the
calibration and the CPU figures alike; a slower path in the game moves
only its own figure, and still fails, since the game's code can't slow
the calibration down. A machine more than twice as slow as the
baseline's isn't one to measure on: its CPU figures are held at twice.
"""
import json
import re
import sys

# The most a slow runner widens the CPU allowances.
MOST_PACE = 2.0

METRIC = re.compile(r"PERFMETRIC (\S+) ([0-9.]+)")


def parse(text):
    found = {}
    for match in METRIC.finditer(text):
        name, value = match.group(1), float(match.group(2))
        # A test run twice keeps its worse figure.
        found[name] = max(value, found.get(name, 0.0))
    return found


def check(found, baseline):
    """Returns (lines, failed)."""
    ratio = baseline.get("ratio", 1.5)
    slack = baseline.get("slack_ms", 1.0)
    metrics = baseline.get("metrics", {})
    gpu_measured = any(name in found for name, spec in metrics.items() if spec.get("gpu"))
    lines, failed = [], False
    pace = 1.0
    for name, spec in metrics.items():
        if spec.get("calibration") and spec.get("baseline") and name in found:
            pace = max(1.0, found[name] / spec["baseline"])
            held = " (held at most)" if pace > MOST_PACE else ""
            pace = min(pace, MOST_PACE)
            lines.append(f"PERF-CHECK this runner runs the plain work at {found[name]:.1f} ms against {spec['baseline']:.1f}: "
                         f"CPU figures allowed x{pace:.2f}{held}")
    for name in sorted(set(metrics) | set(found)):
        spec = metrics.get(name)
        value = found.get(name)
        if spec is None:
            lines.append(f"PERF-CHECK {name} {value:.2f} ms NEW (no baseline yet)")
            continue
        base = spec.get("baseline")
        if value is None and base is None:
            lines.append(f"PERF-CHECK {name} not measured (no baseline yet)")
            continue
        if value is None:
            if spec.get("gpu") and not gpu_measured:
                lines.append(f"PERF-CHECK {name} not measured: no GPU on this runner")
            else:
                lines.append(f"PERF-CHECK {name} MISSING")
                failed = True
            continue
        if base is None:
            lines.append(f"PERF-CHECK {name} {value:.2f} ms RECORDED (no baseline yet)")
            continue
        allowed = max(base * spec.get("ratio", ratio), base + spec.get("slack_ms", slack))
        if spec.get("calibration"):
            lines.append(f"PERF-CHECK {name} {value:.2f} ms (baseline {base:.2f}) CALIBRATION")
            continue
        if spec.get("cpu"):
            allowed *= pace
        if spec.get("limit") is not None:
            allowed = min(allowed, spec["limit"])
        verdict = "OK"
        if value > allowed:
            verdict = "REGRESSED"
            failed = True
        elif value < base / 3 and base > 0.5:
            verdict = "TOO FAST: lower the baseline or check the work is still measured"
            failed = True
        lines.append(f"PERF-CHECK {name} {value:.2f} ms (baseline {base:.2f}, allowed {allowed:.2f}) {verdict}")
    return lines, failed


def self_test():
    baseline = {"ratio": 1.5, "slack_ms": 1.0, "metrics": {
        "a": {"baseline": 10.0, "gpu": True, "limit": 16.0},
        "b": {"baseline": 1.0},
        "c": {"baseline": None},
    }}
    found = parse("x PERFMETRIC a 14.0\nPERFMETRIC b 1.9\nPERFMETRIC c 3\nPERFMETRIC b 1.2\nPERFMETRIC d 2")
    assert found == {"a": 14.0, "b": 1.9, "c": 3.0, "d": 2.0}, found
    lines, failed = check(found, baseline)
    assert not failed, lines
    assert any("d 2.00 ms NEW" in line for line in lines), lines
    _, failed = check({"a": 15.5, "b": 1.0, "c": 1}, baseline)
    assert failed, "15.5 is over 10 x 1.5"
    _, failed = check({"a": 17.0, "b": 1.0}, {"metrics": {"a": {"baseline": 12.0, "limit": 16.0}}})
    assert failed, "over the limit"
    _, failed = check({"b": 1.0}, baseline)
    assert not failed, "GPU metrics missing without a GPU is not a failure"
    _, failed = check({"a": 10.0}, baseline)
    assert failed, "a CPU metric missing is"
    _, failed = check({"a": 2.0, "b": 1.0}, baseline)
    assert failed, "a third of the baseline is suspicious"
    paced = {"metrics": {"cal": {"baseline": 100.0, "calibration": True}, "w": {"baseline": 10.0, "cpu": True}}}
    _, failed = check({"cal": 100.0, "w": 16.0}, paced)
    assert failed, "on a machine of the baseline's pace, 16 is over 10 x 1.5"
    _, failed = check({"cal": 170.0, "w": 16.0}, paced)
    assert not failed, "on a machine 1.7 times slower, 16 is within 10 x 1.5 x 1.7"
    _, failed = check({"cal": 170.0, "w": 30.0}, paced)
    assert failed, "a path slower than the machine still fails"
    _, failed = check({"cal": 60.0, "w": 14.0}, paced)
    assert not failed, "a faster machine is held to the baseline as it is"
    lines, failed = check({"cal": 500.0, "w": 31.0}, paced)
    assert failed, "a machine five times slower widens the allowance twice, not five times: 31 is over 10 x 1.5 x 2"
    assert any("held at most" in line for line in lines), lines
    _, failed = check({"cal": 500.0, "w": 29.0}, paced)
    assert not failed, "29 is within 10 x 1.5 x 2"
    print("perf-check self-test passed")
    return 0


def main(argv):
    if len(argv) == 2 and argv[1] == "--self-test":
        return self_test()
    if len(argv) < 3:
        print(__doc__)
        return 2
    with open(argv[1], errors="replace") as handle:
        found = parse(handle.read())
    with open(argv[2]) as handle:
        baseline = json.load(handle)
    lines, failed = check(found, baseline)
    if "--report" in argv:
        # Another machine's figures, set beside CI's baselines: told, not held.
        lines = [line.replace("REGRESSED", "slower than CI").replace("MISSING", "not measured here") for line in lines]
        lines = [line.split(" TOO FAST")[0] + " faster than CI" if " TOO FAST" in line else line for line in lines]
        failed = False
    for line in lines:
        print(line)
    if "--json" in argv:
        out = argv[argv.index("--json") + 1]
        with open(out, "w") as handle:
            json.dump({"runner": baseline.get("runner"), "metrics": found}, handle, indent=2, sort_keys=True)
    if failed:
        print("PERF-CHECK failed: a figure regressed or went missing (see above)")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
