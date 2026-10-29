#!/usr/bin/env python3
"""Line coverage of each module, from the JSON `swift test --enable-code-coverage`
leaves (its path is what `swift test --show-codecov-path` prints).

    scripts/coverage.py <codecov.json> [Module=floor ...] [--worst N] [--lines N]
    scripts/coverage.py --self-test

Prints a line per module under Sources/, and fails if any named module's
coverage is under its floor, in percent. With --worst, also lists the N
files with the most lines no test runs, where tests would do most good;
with --lines, the lines themselves of the first N of those.
"""
import json
import sys


def unrun_lines(segments):
    """The lines a file's coverage segments say were never run: each
    segment's count holds from its start to the next segment's."""
    counts = {}
    for here, after in zip(segments, segments[1:] + [None]):
        line, column, count, has_count = here[0], here[1], here[2], here[3]
        gap = len(here) > 5 and here[5]
        if not has_count or gap:
            continue
        end = after[0] if after is not None else line
        if after is not None and after[1] == 1 and end > line:
            end -= 1
        for number in range(line, end + 1):
            counts[number] = max(counts.get(number, 0), count)
    return sorted(number for number, count in counts.items() if count == 0)


def ranges(numbers, most=30):
    """1, 2, 3, 7 as "1-3, 7"."""
    spans = []
    for number in numbers:
        if spans and number == spans[-1][1] + 1:
            spans[-1][1] = number
        else:
            spans.append([number, number])
    text = [f"{a}-{b}" if a != b else f"{a}" for a, b in spans[:most]]
    if len(spans) > most:
        text.append(f"and {len(spans) - most} more")
    return ", ".join(text)


def self_test():
    # Lines 1-3 run; 4-6 not; 7 runs again; a gap region counts for nothing.
    segments = [[1, 1, 5, True, True], [4, 1, 0, True, True], [7, 1, 2, True, True],
                [8, 1, 0, True, False, True], [9, 1, 0, False, False]]
    assert unrun_lines(segments) == [4, 5, 6], unrun_lines(segments)
    assert ranges([1, 2, 3, 7, 9, 10]) == "1-3, 7, 9-10"
    assert ranges(list(range(0, 100, 2)), most=2) == "0, 2, and 48 more"
    print("coverage self-test passed")
    return 0


def main(argv):
    if len(argv) == 2 and argv[1] == "--self-test":
        return self_test()
    if len(argv) == 2 and argv[1] in ("-h", "--help"):
        print(__doc__)
        return 0
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
    shown = 0
    if "--lines" in args:
        at = args.index("--lines")
        shown = int(args[at + 1])
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
            files.append((lines.get("count", 0) - lines.get("covered", 0), lines.get("count", 0), path.split("/Sources/", 1)[1],
                          entry.get("segments", [])))
    failed = False
    for module in sorted(counted):
        if counted[module] == 0:
            continue
        percent = 100.0 * covered[module] / counted[module]
        floor = floors.get(module)
        note = ""
        if floor is not None:
            note = f" (floor {floor:g}%)"
            if percent < floor:
                note += " BELOW"
                failed = True
        print(f"COVERAGE {module} {percent:.2f}% of {counted[module]} lines{note}")
    ranked = sorted(files, key=lambda file: (file[0], file[1], file[2]), reverse=True)
    for missed, count, name, _ in ranked[:worst]:
        print(f"COVERFILE {name} {count - missed}/{count} lines, {missed} unrun")
    for missed, _, name, segments in ranked[:shown]:
        if missed:
            print(f"COVERLINES {name}: {ranges(unrun_lines(segments))}")
    for module in floors:
        if module not in counted:
            print(f"COVERAGE {module}: no lines measured")
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
