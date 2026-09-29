#!/usr/bin/env python3
"""Run deterministic navigation PoCs and regressions; preserve logs and results.

Examples:
  python3 tools/check_navigation.py
  python3 tools/check_navigation.py --tests navigation_poc navigation_poc_matrix
  python3 tools/check_navigation.py --path /tmp/baseline --output /tmp/nav-before
"""
import argparse
import json
import os
from pathlib import Path
import platform
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
TESTS = [
    "navigation_async_poc", "deer_movement_poc", "navigation_battle_static_grid_poc",
    "navigation_battle_raster_poc", "navigation_battle_native_poc", "navigation_battle_goal_poc", "navigation_battle_recovery_poc", "navigation_battle_retry_poc", "navigation_search_work", "navigation_grid_raster", "navigation_dense_poc", "navigation_tasks_poc",
    "navigation_corner_poc", "navigation_state_poc",
    "navigation_poc", "navigation_poc_matrix", "navigation_construction_poc", "navigation", "navigation_routes",
    "navigation_replanning", "group_replanning", "group_chokepoint", "group_mass_chokepoint",
    "group_multiplayer", "terrain_selection_follow", "extended_systems",
    "economy_siege_controls", "smoke",
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--path", type=Path, default=ROOT)
    parser.add_argument("--output", type=Path, default=ROOT / ".godot/navigation-checks")
    default_engine = ROOT / f"docs/godot/bin/godot.macos.template_debug.{platform.machine()}"
    parser.add_argument("--godot", default=os.environ.get("GODOT", str(default_engine) if default_engine.exists() else "godot"))
    parser.add_argument("--tests", nargs="+", default=TESTS)
    parser.add_argument("--timeout", type=float, default=300)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    results = []
    for name in args.tests:
        log_path = args.output / f"{name}.log"
        started = time.monotonic()
        timed_out = False
        with log_path.open("w") as log:
            try:
                result = subprocess.run(
                    [args.godot, "--headless", "--log-file", str(log_path.with_suffix(".engine.log").resolve()), "--path", str(args.path),
                     "--script", f"res://tests/{name}.gd"],
                    stdout=log, stderr=subprocess.STDOUT, timeout=args.timeout,
                    check=False,
                )
                code = result.returncode
            except subprocess.TimeoutExpired:
                code, timed_out = -1, True
        output = log_path.read_text()
        errors = any(token in output for token in ["SCRIPT ERROR:", "ERROR:", "POC_FAIL"])
        passed = code == 0 and not errors and ("_OK" in output or "failures=0" in output or "PERFORMANCE_" in output)
        results.append(dict(test=name, passed=passed, exit_code=code,
                            timeout=timed_out, seconds=round(time.monotonic() - started, 3),
                            log=str(log_path.resolve())))
        print(f'{"PASS" if passed else "FAIL"} {name} ({results[-1]["seconds"]:.2f}s)', flush=True)
    (args.output / "results.json").write_text(json.dumps(results, indent=2) + "\n")
    return 0 if all(result["passed"] for result in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
