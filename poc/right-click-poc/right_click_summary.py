#!/usr/bin/env python3
"""Print button/state/action timelines; no automatic guess about user intent."""
import argparse
import json
from pathlib import Path


def read_rows(path):
    rows = []
    if path.exists():
        for line in path.read_text().splitlines():
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                pass  # A live capture may end with a partially written row.
    return rows


def summarize(directory, window=4.0):
    engine = read_rows(directory / "engine.jsonl")
    native = read_rows(directory / "native.jsonl")
    interesting = []
    previous_masks = None
    appkit_types = {1: "left_down", 2: "left_up", 3: "right_down", 4: "right_up", 25: "other_down", 26: "other_up"}
    for row in native:
        if row.get("layer") == "appkit" and row.get("type") in appkit_types:
            interesting.append(dict(row, event=appkit_types[row["type"]]))
        elif row.get("layer") == "quartz":
            masks = tuple(row.get(k) for k in ("hid", "hid_right", "session", "session_right"))
            if masks != previous_masks:
                interesting.append(row)
                previous_masks = masks
    interesting += [r for r in engine if r.get("layer") in ("selection", "marker") or (r.get("layer") == "godot" and r.get("type") == "InputEventMouseButton")]
    interesting.sort(key=lambda r: r["t"])
    start = min((r["t"] for r in engine + native), default=0)
    markers = [r for r in engine if r.get("layer") == "marker"]
    failed = [r for r in markers if r.get("action") == "failed_right_click"]
    windows = [(r["t"] - window, r["t"] + 0.1) for r in failed] if window is not None else []
    output = [f"Capture: {directory}", f"Godot button events: {sum(r.get('type') == 'InputEventMouseButton' for r in engine)}; markers: {len(markers)}; failed-right markers: {len(failed)}", "AppKit native button numbers: 0 LEFT / 1 RIGHT. Godot button indices: 1 LEFT / 2 RIGHT. Masks: 1 LEFT / 2 RIGHT / 3 BOTH.", "HID/session snapshots are states, not proof of which gesture the user intended."]
    if windows:
        output.append(f"Showing {window:g}s before each F8 marker (use --all for full capture).")
    for row in interesting:
        if windows and not any(a <= row["t"] <= b for a, b in windows):
            continue
        compact = {k: v for k, v in row.items() if k not in ("t", "x", "y", "start_x", "start_y", "pointer_x", "pointer_y", "world_x", "world_y", "event_x", "event_y")}
        output.append(f"{row['t'] - start:9.4f}s {json.dumps(compact, ensure_ascii=False)}")
    return "\n".join(output) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    parser.add_argument("--window", type=float, default=4.0)
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = summarize(args.capture, None if args.all else args.window)
    if args.output:
        args.output.write_text(result)
    print(result, end="")


if __name__ == "__main__":
    main()
