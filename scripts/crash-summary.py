#!/usr/bin/env python3
"""Says what macOS's crash reports tell of a crash: the process, its
exception and why it ended, and the frames of the thread that crashed.

    scripts/crash-summary.py [--only NAME] <report.ips or folder> ...
    scripts/crash-summary.py --self-test

A report (.ips) is a line of JSON about it, then the report itself as JSON.
For a folder, its six newest reports are read. Reports of other processes,
or that can't be read, are passed over.
"""
import json
import os
import sys


def summary(header, body, only=None):
    """The lines told of one report, or None if it isn't of `only`."""
    name = body.get("procName") or header.get("app_name") or header.get("name") or "?"
    if only and only.lower() not in name.lower():
        return None
    lines = [f"CRASH {name} at {header.get('timestamp', '?')}"]
    exception = body.get("exception") or {}
    if exception:
        told = " ".join(str(exception.get(key, "")) for key in ("type", "signal", "subtype")).split()
        lines.append("CRASH   exception " + " ".join(told))
    termination = body.get("termination") or {}
    if termination:
        reasons = termination.get("reasons") or []
        told = [str(termination.get("namespace", "")), str(termination.get("indicator", ""))] + [str(reason) for reason in reasons]
        lines.append("CRASH   ended by " + " ".join(part for part in told if part)[:300])
    for key, value in (body.get("asi") or {}).items():
        lines.append(f"CRASH   {key}: {' '.join(str(item) for item in value)[:300]}")
    images = body.get("usedImages") or []
    for thread in body.get("threads") or []:
        if not thread.get("triggered"):
            continue
        for frame in (thread.get("frames") or [])[:18]:
            index = frame.get("imageIndex", -1)
            image = images[index].get("name", "?") if 0 <= index < len(images) else "?"
            symbol = frame.get("symbol") or f"+{frame.get('imageOffset', 0)}"
            lines.append(f"CRASH   {image} {symbol}")
    return lines


def read(path):
    """A report's header and body, or None if it isn't one."""
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            header = json.loads(handle.readline())
            body = json.loads(handle.read())
    except (OSError, ValueError):
        return None
    if not isinstance(header, dict) or not isinstance(body, dict):
        return None
    return header, body


def reports(path, newest=6):
    """The report at `path`, or a folder's newest reports, newest first."""
    if not os.path.isdir(path):
        return [path]
    found = [os.path.join(path, name) for name in os.listdir(path) if name.endswith(".ips")]
    return sorted(found, key=os.path.getmtime, reverse=True)[:newest]


def self_test():
    header = {"app_name": "Nullmere Online", "timestamp": "2026-10-30 05:00:00"}
    body = {
        "procName": "Nullmere Online",
        "exception": {"type": "EXC_BREAKPOINT", "signal": "SIGTRAP"},
        "termination": {"namespace": "SIGNAL", "indicator": "Trace/BPT trap: 5"},
        "asi": {"libswiftCore.dylib": ["Fatal error: Index out of range"]},
        "usedImages": [{"name": "Nullmere Online"}, {"name": "SwiftUI"}],
        "threads": [
            {"frames": [{"imageIndex": 1, "symbol": "idle"}]},
            {"triggered": True, "frames": [{"imageIndex": 0, "symbol": "HouseRow.body.getter"}, {"imageIndex": 1, "imageOffset": 42}]},
        ],
    }
    lines = summary(header, body, only="nullmere")
    assert lines[0] == "CRASH Nullmere Online at 2026-10-30 05:00:00", lines
    assert "CRASH   exception EXC_BREAKPOINT SIGTRAP" in lines, lines
    assert "CRASH   ended by SIGNAL Trace/BPT trap: 5" in lines, lines
    assert "CRASH   libswiftCore.dylib: Fatal error: Index out of range" in lines, lines
    assert lines[-2:] == ["CRASH   Nullmere Online HouseRow.body.getter", "CRASH   SwiftUI +42"], lines
    assert summary(header, body, only="Safari") is None
    import tempfile
    with tempfile.TemporaryDirectory() as folder:
        for index in range(8):
            path = os.path.join(folder, f"Nullmere Online-{index}.ips")
            with open(path, "w", encoding="utf-8") as handle:
                handle.write(json.dumps(header) + "\n" + json.dumps(body))
            os.utime(path, (1_000_000 + index, 1_000_000 + index))
        newest = reports(folder)
        assert [os.path.basename(path) for path in newest[:2]] == ["Nullmere Online-7.ips", "Nullmere Online-6.ips"], newest
        assert len(newest) == 6 and read(newest[0]) == (header, body)
    assert read(os.devnull) is None
    print("crash-summary self-test passed")


def main(argv):
    if argv == ["--self-test"]:
        self_test()
        return 0
    only = None
    if len(argv) >= 2 and argv[0] == "--only":
        only, argv = argv[1], argv[2:]
    for given in argv:
        for path in reports(given):
            report = read(path)
            lines = report and summary(*report, only=only)
            if lines:
                print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
