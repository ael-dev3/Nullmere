#!/usr/bin/env python3
"""Line coverage of each module, from the JSON `swift test --enable-code-coverage`
leaves (its path is what `swift test --show-codecov-path` prints).

    scripts/coverage.py <codecov.json> [Module=floor ...] [--worst N]

Prints a line per module under Sources/, and fails if any named module's
coverage is under its floor, in percent. With --worst, also lists the N
files with the most lines no test runs, where tests would do most good.
"""
import json
import sys


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    try:
        with open(argv[1]) as handle:
            report = json.load(handle)
    except OSError as error:
        print(f"COVERAGE not measured: {error}. (A failed test run leaves no coverage.)")
        return 1
    floors = {}
    worst = 0
    args = argv[2:]
    if "--worst" in args:
        at = args.index("--worst")
        worst = int(args[at + 1])
        del args[at:at + 2]
    for arg in args:
        name, _, floor = arg.partition("=")
        floors[name] = float(floor)
    covered, counted = {}, {}
    files = []
    for data in report.get("data", []):
        for entry in data.get("files", []):
            path = entry.get("filename", "")
            if "/Sources/" not in path or "/.build/" in path:
                continue
            module = path.split("/Sources/", 1)[1].split("/", 1)[0]
            lines = entry.get("summary", {}).get("lines", {})
            covered[module] = covered.get(module, 0) + lines.get("covered", 0)
            counted[module] = counted.get(module, 0) + lines.get("count", 0)
            files.append((lines.get("count", 0) - lines.get("covered", 0), lines.get("count", 0), path.split("/Sources/", 1)[1]))
    failed = False
    for module in sorted(counted):
        if counted[module] == 0:
            continue
        percent = 100.0 * covered[module] / counted[module]
        floor = floors.get(module)
        note = ""
        if floor is not None:
            note = f" (floor {floor:.0f}%)"
            if percent < floor:
                note += " BELOW"
                failed = True
        print(f"COVERAGE {module} {percent:.1f}% of {counted[module]} lines{note}")
    for missed, count, name in sorted(files, reverse=True)[:worst]:
        print(f"COVERFILE {name} {count - missed}/{count} lines, {missed} unrun")
    for module in floors:
        if module not in counted:
            print(f"COVERAGE {module}: no lines measured")
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
