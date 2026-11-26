#!/usr/bin/env python3
"""Split measured Android hitch intervals without guessing their cause."""
import argparse
import json
import math
from pathlib import Path

TOLERANCE_US = 20_000
MAX_BRACKET_US = 2_000
MAX_REPORT = 1024 * 1024


def exact(value):
    if type(value) is int and abs(value) <= (1 << 53) - 1:
        return value
    if type(value) is float and math.isfinite(value) and value.is_integer() and abs(value) <= (1 << 53) - 1:
        return int(value)
    return None


def anchor(value):
    if not isinstance(value, dict):
        return None
    values = tuple(exact(value.get(k)) for k in ("ticks_before_usec", "realtime_usec", "ticks_after_usec"))
    if None in values:
        return None
    before, realtime, after = values
    if not 0 <= before <= after <= before + MAX_BRACKET_US or realtime < 946684800000000:
        return None
    # Offset range in microseconds between tick time and CLOCK_REALTIME.
    return before, after, realtime - after, realtime - before


def windows(report, minimum_us=16_000, maximum_us=4_000_000):
    report = report if isinstance(report, dict) else {}
    log = report.get("hitch_log", {})
    log = log if isinstance(log, dict) else {}
    anchors = report.get("clock_sync", {})
    first, last = (anchor(anchors.get(k)) for k in ("start", "capture")) if isinstance(anchors, dict) else (None, None)
    offsets = None
    if first and last and first[1] <= last[0]:
        low, high = min(first[2], last[2]), max(first[3], last[3])
        if high - low <= TOLERANCE_US:
            offsets = (low, high)
    items = []
    candidates = log.get("worst", [])
    for item in (candidates[:12] if isinstance(candidates, list) else []):
        if not isinstance(item, dict) or not isinstance(item.get("diagnostics"), dict):
            continue
        d = item["diagnostics"]
        draw = d.get("draw_callbacks", {})
        dispatch = d.get("next_scene_dispatch", {})
        if not isinstance(draw, dict) or not isinstance(dispatch, dict):
            continue
        if draw.get("status") != "ordered_synchronous_pair" or dispatch.get("status") != "ordered_signal":
            continue
        before, pre, post, end = (exact(draw.get(k)) for k in ("probe_usec", "pre_usec", "post_usec", "next_probe_usec"))
        signal = exact(dispatch.get("dispatch_usec"))
        if None in (before, pre, post, signal, end) or not 0 <= before <= pre <= post <= signal <= end:
            continue
        wall = end - before
        if not minimum_us < wall < maximum_us:
            continue
        phases = {"pre_draw":pre-before, "draw_callbacks":post-pre, "post_draw_to_signal":signal-post, "signal_to_probe":end-signal}
        result = {"frame":exact(item.get("frame")), "wall_usec":wall, "signals_usec":[before,pre,post,signal,end], "observed_phases_usec":phases}
        if offsets and first[0] <= before <= end <= last[1]:
            lo, hi = offsets
            result["realtime_range_usec"] = [[t+lo,t+hi] for t in result["signals_usec"]]
        items.append(result)
    source_build = log.get("build",{})
    build = {k:source_build[k] for k in ("version_name","commit") if isinstance(source_build, dict) and isinstance(source_build.get(k), str)}
    return {"build":build, "frames":exact(log.get("frames")), "over_16ms":exact(log.get("over_16ms")),
            "over_33ms":exact(log.get("over_33ms")), "matching_basis":"clock_brackets_and_ordered_callbacks" if offsets else "relative_only",
            "clock_offset_span_usec":None if offsets is None else offsets[1]-offsets[0], "windows":items}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("file", type=Path)
    parser.add_argument("--min-ms", type=int, default=16)
    parser.add_argument("--max-ms", type=int, default=4000)
    args = parser.parse_args()
    if args.file.stat().st_size > MAX_REPORT or not 0 <= args.min_ms < args.max_ms:
        parser.error("invalid bounds or oversized report")
    report = json.loads(args.file.read_text())
    print(json.dumps(windows(report, args.min_ms*1000, args.max_ms*1000), indent=2))


if __name__ == "__main__":
    main()
