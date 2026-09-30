#!/usr/bin/env python3
"""Build and repeat synthetic event/state schedules against the real game."""
import argparse
from collections import Counter, defaultdict
import itertools
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def native(mask, **kw):
    return dict(op="native", mask=mask, **kw)


def button(index, pressed, **kw):
    return dict(op="button", button=index, pressed=pressed, **kw)


POLL = {"op": "poll"}
FLUSH = {"op": "flush"}


def build_cases():
    cases = []

    def add(name, family, steps):
        cases.append(dict(id=name, family=family, steps=steps))

    # Controls and explicit contamination distinguish mask vs button semantics.
    add("right_tap_mask_zero", "right_control", [button(2, True, mask=0), button(2, False, mask=0), FLUSH, POLL])
    add("right_tap_mask_left_only", "right_control", [button(2, True, mask=1), button(2, False, mask=1), FLUSH, POLL])
    add("right_tap_mask_both", "right_control", [button(2, True, mask=3), button(2, False, mask=3), FLUSH, POLL])
    add("right_double_flag", "right_control", [button(2, True, double=True), FLUSH, button(2, False), FLUSH, POLL])
    add("right_held", "right_control", [native(2), button(2, True), FLUSH, POLL, POLL, native(0), button(2, False), FLUSH, POLL])
    add("right_delayed_left_release", "right_control", [button(2, True), FLUSH, button(1, False), FLUSH, button(2, False), FLUSH, POLL])
    add("right_duplicate_press", "right_control", [button(2, True), button(2, True), button(2, False), FLUSH, POLL])
    add("left_tap_before_right_same_batch", "delivered_left", [button(1, True), button(1, False), button(2, True), button(2, False), FLUSH, POLL])
    add("left_tap_after_right_same_batch", "delivered_left", [button(2, True), button(2, False), button(1, True), button(1, False), FLUSH, POLL])
    add("left_down_then_right_then_left_up", "delivered_left", [native(1), button(1, True), FLUSH, button(2, True), FLUSH, native(0), button(1, False), button(2, False), FLUSH, POLL])
    add("left_only_tap", "left_control", [button(1, True), button(1, False), FLUSH, POLL])
    add("left_only_held", "left_control", [native(1), button(1, True), FLUSH, POLL, POLL, native(0), button(1, False), FLUSH, POLL])
    add("left_event_after_native_release", "left_control", [native(1), native(0), button(1, True), button(1, False), FLUSH, POLL])
    add("left_missing_up_native_release", "left_control", [native(1), button(1, True), FLUSH, POLL, native(0), POLL])
    add("left_no_native_state_missing_up", "missing_release", [button(1, True), FLUSH, POLL])
    add("ctrl_click_native_left_held", "ctrl_mapping", [native(1), button(2, True, ctrl=True), FLUSH, POLL, POLL, native(0), button(2, False, ctrl=True), FLUSH, POLL])
    add("ctrl_click_native_left_tap_finished", "ctrl_mapping", [native(1), native(0), button(2, True, ctrl=True), button(2, False, ctrl=True), FLUSH, POLL])

    # All six interleavings preserving DOWN before UP for both streams,
    # and all 32 frame-poll placements around their four actions.
    for order in itertools.permutations(("R+", "R-", "N+", "N-")):
        if order.index("R+") > order.index("R-") or order.index("N+") > order.index("N-"):
            continue
        for poll_bits in range(32):
            steps = []
            for i in range(5):
                if poll_bits & (1 << i):
                    steps.append(POLL)
                if i < 4:
                    op = order[i]
                    if op.startswith("N"):
                        steps.append(native(1 if op == "N+" else 0))
                    else:
                        steps.extend([button(2, op == "R+"), FLUSH])
            add("interleave_" + "_".join(order) + f"_poll{poll_bits}", "native_left_interleaving", steps)

    # Frame phase vs pulse duration vs AppKit delivery delay. Virtual time,
    # no sleeping: same ordering the game would see at 30/60/120 FPS.
    for fps, phase, width, delay, mask in itertools.product((30, 60, 120), (0.05, 0.35, 0.65, 0.95), (0.1, 1, 5, 20), (0, 5, 30), (1, 2, 3)):
        period = 1000 / fps
        start = phase * period
        timeline = [(start, native(mask)), (start + width, native(0)), (start + delay, button(2, True)), (start + width + delay, button(2, False))]
        timeline.extend((i * period, POLL) for i in range(1, int((start + width + delay) / period) + 3))
        timeline.sort(key=lambda item: item[0])
        steps = []
        for t, step in timeline:
            steps.append(dict(step, t_ms=round(t, 4)))
            if step["op"] == "button":
                steps.append(dict(FLUSH, t_ms=round(t, 4)))
        family = "timing_right_native" if mask == 2 else "timing_left_native" if mask == 1 else "timing_both_native"
        add(f"timing_{fps}_{phase}_{width}_{delay}_mask{mask}", family, steps)
    return cases


def analyze(reports, cases):
    aggregates = defaultdict(Counter)
    failures = []
    representatives = {}
    repeat_fingerprints = defaultdict(set)
    direct_fingerprints = {}
    driver_mismatches = []
    by_case = {c["id"]: c for c in cases}
    for report in reports:
        for row in report["rows"]:
            key = (row["family"], row["variant"], row["driver"])
            counter = aggregates[key]
            counter["runs"] += 1
            counter["selection_lost"] += row["selection_lost"]
            counter["stray_selection"] += row["family"] not in ("left_control", "delivered_left", "missing_release") and row["final"]["begins"] > 0
            counter["no_order_dispatch"] += row["final"]["orders"] == 0
            counter["no_move"] += row["final"]["order"] != "move"
            counter["moved_then_selection_lost"] += row["selection_lost"] and row["final"]["order"] == "move"
            counter["still_dragging"] += row["final"]["dragging"]
            fingerprint = json.dumps(row["final"], sort_keys=True)
            identity = (report["map_seed"], row["case"], row["variant"], row["driver"])
            repeat_fingerprints[identity].add(fingerprint)
            if row["driver"] == "direct":
                direct_fingerprints[(report["map_seed"], row["case"], row["variant"], row["trial"])] = fingerprint
            elif row["driver"] == "engine_immediate":
                direct_key = (report["map_seed"], row["case"], row["variant"], row["trial"])
                if direct_fingerprints.get(direct_key) != fingerprint:
                    driver_mismatches.append(dict(seed=report["map_seed"], **row))
            if row["family"] in ("right_control", "timing_right_native") and (row["selection_lost"] or row["final"]["order"] != "move" or row["final"]["begins"]):
                failures.append(dict(reason="normal_right_control_failed", seed=report["map_seed"], **row))
            if row["family"] == "left_control" and not row["selection_lost"]:
                failures.append(dict(reason="normal_left_control_failed", seed=report["map_seed"], **row))
            if row["selection_lost"] or row["final"]["dragging"]:
                rep_key = f"{row['family']}/{row['variant']}/{row['driver']}"
                if rep_key not in representatives:
                    representatives[rep_key] = dict(seed=report["map_seed"], schedule=by_case[row["case"]]["steps"], **row)
    instability = [dict(identity=k, distinct_results=len(v)) for k, v in repeat_fingerprints.items() if len(v) != 1]
    return dict(synthetic=True, physical_gesture_reproduced=False, cases_per_map=len(cases), total_runs=sum(len(r["rows"]) for r in reports), map_seeds=[r["map_seed"] for r in reports], repeats=reports[0]["repeats"], aggregates=[dict(family=k[0], variant=k[1], driver=k[2], **v) for k, v in sorted(aggregates.items())], control_failures=failures, repeat_instability=instability, direct_vs_engine_immediate_mismatches=driver_mismatches, representatives=representatives)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repeats", type=int, default=3)
    parser.add_argument("--seeds", default="12345,4242,431")
    parser.add_argument("--output", type=Path, default=ROOT / "poc/right-click-poc/right-click-matrix.json")
    args = parser.parse_args()
    godot = os.environ.get("GODOT_BIN", str(ROOT / "docs/godot/bin/godot.macos.template_debug.arm64"))
    cases = build_cases()
    reports = []
    with tempfile.TemporaryDirectory(prefix="aoe-right-click-matrix-") as temp:
        temp_path = Path(temp)
        for seed in map(int, args.seeds.split(",")):
            config = temp_path / f"cases-{seed}.json"
            result = temp_path / f"results-{seed}.json"
            config.write_text(json.dumps(dict(map_seed=seed, repeats=args.repeats, cases=cases)))
            env = dict(os.environ, AOE_RIGHT_CLICK_CASES=str(config), AOE_RIGHT_CLICK_MATRIX=str(result))
            completed = subprocess.run([godot, "--path", str(ROOT), "--headless", "--script", "res://poc/right-click-poc/right_click_matrix.gd"], env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
            print(completed.stdout, end="", flush=True)
            if completed.returncode or not result.exists():
                raise SystemExit("Matrix Godot process failed")
            reports.append(json.loads(result.read_text()))
        summary = analyze(reports, cases)
        args.output.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    print("TOTAL", summary["total_runs"], "CONTROL_FAILURES", len(summary["control_failures"]), "UNSTABLE", len(summary["repeat_instability"]), "DRIVER_MISMATCHES", len(summary["direct_vs_engine_immediate_mismatches"]))
    for row in summary["aggregates"]:
        if row["driver"] == "engine_immediate":
            print(json.dumps(row))
    if summary["control_failures"] or summary["repeat_instability"] or summary["direct_vs_engine_immediate_mismatches"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
