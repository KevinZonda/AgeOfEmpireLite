#!/usr/bin/env python3
"""Run deterministic headless regressions; preserve logs and results.

Examples:
  python3 tools/check_navigation.py
  python3 tools/check_navigation.py --tests navigation_poc navigation_poc_matrix
  python3 tools/check_navigation.py --path /tmp/baseline --output /tmp/nav-before
  python3 tools/check_navigation.py --suite refactor --output /tmp/refactor-checks
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
    "navigation_destination_poc",
    "navigation_async_poc", "deer_movement_poc", "navigation_battle_static_grid_poc",
    "navigation_battle_raster_poc", "navigation_battle_native_poc", "navigation_battle_goal_poc", "navigation_battle_recovery_poc", "navigation_battle_retry_poc", "navigation_search_work", "navigation_grid_raster", "navigation_dense_poc", "navigation_tasks_poc",
    "navigation_corner_poc", "navigation_state_poc", "navigation_wildlife_churn_poc",
    "navigation_poc", "navigation_poc_matrix", "navigation_construction_poc", "navigation", "navigation_routes",
    "navigation_replanning", "group_replanning", "group_chokepoint", "group_mass_chokepoint",
    "group_multiplayer", "terrain_selection_follow", "extended_systems",
    "economy_siege_controls", "smoke",
]

# Rendering-driver comparisons and existing HUD/range-corner failures are run
# separately. The integration suite covers the shared state/behavior boundaries.
REFACTOR_TESTS = list(dict.fromkeys(TESTS + [
    "session_rules_regression", "unit_components_regression", "settings_store",
    "match_changes", "right_click_selection", "hud_command_pages",
    "production_queue_regression", "hud_queue_layout", "display_settings",
    "unit_preview_page", "tech_tree_page", "typography_scale", "battle_experience",
    "enemy_inspection", "health_bar_visibility", "map_setup_preview",
    "terrain_generation", "visual_state", "unit_visual_coverage", "fog_of_war",
    "fog_building_memory", "fog_rendering", "fog_unit_flash_poc",
    "combat_rules", "siege_rules", "aoe4_requested_systems", "chinese",
    "balance_system", "landmark_catalog", "landmark_roles", "landmark_selection",
    "landmark_occlusion", "rally_landmarks", "strategic_expansion", "objectives",
    "farm_cycle", "deer_gathering", "sheep_gathering", "villager_boar_escape",
    "build_grid", "build_selection", "selection", "minimap_projection",
    "isometric_view", "zoom_projection", "map_generator", "map_strategy",
    "map_fairness", "ai_tactics", "civ_map_ai", "island_ai_strategy", "ai_long_match",
    "navigation_range_siege_poc",
    "navigation_range_stall_poc", "navigation_segment_broadphase_poc",
]))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--path", type=Path, default=ROOT)
    parser.add_argument("--output", type=Path, default=ROOT / ".godot/navigation-checks")
    default_engine = ROOT / f"docs/godot/bin/godot.macos.template_debug.{platform.machine()}"
    parser.add_argument("--godot", default=os.environ.get("GODOT", str(default_engine) if default_engine.exists() else "godot"))
    parser.add_argument("--suite", choices=["navigation", "refactor"], default="navigation")
    parser.add_argument("--tests", nargs="+")
    parser.add_argument("--timeout", type=float, default=300)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    results = []
    tests = args.tests or (REFACTOR_TESTS if args.suite == "refactor" else TESTS)
    for name in tests:
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
        passed = code == 0 and not errors and ("_OK" in output or "failures=0" in output or "PERFORMANCE_" in output or "FOG_UNIT_FLASH_FIXED" in output)
        results.append(dict(test=name, passed=passed, exit_code=code,
                            timeout=timed_out, seconds=round(time.monotonic() - started, 3),
                            log=str(log_path.resolve())))
        print(f'{"PASS" if passed else "FAIL"} {name} ({results[-1]["seconds"]:.2f}s)', flush=True)
    (args.output / "results.json").write_text(json.dumps(results, indent=2) + "\n")
    return 0 if all(result["passed"] for result in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
