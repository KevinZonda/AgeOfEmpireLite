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
    "navigation_destination_poc", "navigation_boundaries",
    "navigation_search_kernel", "navigation_kernel_geometry", "navigation_range_corner_poc",
    "navigation_async_poc", "deer_movement_poc", "navigation_battle_static_grid_poc",
    "navigation_battle_raster_poc", "navigation_battle_native_poc", "navigation_battle_goal_poc", "navigation_battle_recovery_poc", "navigation_battle_retry_poc", "navigation_search_work", "navigation_grid_raster", "navigation_dense_poc", "navigation_tasks_poc",
    "navigation_corner_poc", "navigation_state_poc", "navigation_wildlife_churn_poc",
    "navigation_poc", "navigation_poc_matrix", "navigation_construction_poc", "navigation", "navigation_routes",
    "navigation_replanning", "group_replanning", "group_chokepoint", "group_mass_chokepoint",
    "group_multiplayer", "terrain_selection_follow", "extended_systems",
    "economy_siege_controls", "smoke",
]

# Rendering-driver comparisons run separately.
# Range-corner reuse is repaired and belongs to the normal regression suite.
REFACTOR_TESTS = list(dict.fromkeys(TESTS + [
    "match_services", "session_rules_regression", "unit_components_regression", "unit_orders_regression", "match_simulation_regression", "settings_store",
    "match_changes", "player_command_catalog", "hud_resolution", "right_click_selection", "hud_command_pages", "player_input_actions_regression",
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
    parser.add_argument("--rendering", action="store_true", help="Use a real window/rendering driver for screenshot and pixel comparisons")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    results = []
    tests = args.tests or (REFACTOR_TESTS if args.suite == "refactor" else TESTS)
    for name in tests:
        log_path = args.output / f"{name}.log"
        started = time.monotonic()
        timed_out = False
        terminated_on_error = False
        with log_path.open("w") as log:
            display_args = ["--windowed", "--resolution", "1280x720"] if args.rendering else ["--headless"]
            env = os.environ.copy()
            if args.rendering:
                artifact = args.output / ("farm.png" if name == "farm_rendering" else name + "-images")
                env["RTS_RENDER_OUTPUT"] = str(artifact.resolve())
            process = subprocess.Popen(
                [args.godot, *display_args, "--log-file", str(log_path.with_suffix(".engine.log").resolve()), "--path", str(args.path),
                 "--script", f"res://tests/{name}.gd"],
                stdout=log, stderr=subprocess.STDOUT, env=env,
            )
            try:
                while process.poll() is None:
                    # A Godot assertion aborts the test coroutine but can leave
                    # SceneTree running forever. Preserve the failure and stop
                    # that engine instead of consuming the full timeout.
                    output = log_path.read_text()
                    if any(token in output for token in ["SCRIPT ERROR:", "ERROR:", "POC_FAIL"]):
                        terminated_on_error = True
                        process.terminate()
                        break
                    if time.monotonic() - started >= args.timeout:
                        timed_out = True
                        process.terminate()
                        break
                    time.sleep(0.1)
                try:
                    code = process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill()
                    code = process.wait()
                if timed_out: code = -1
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait()
        output = log_path.read_text()
        errors = any(token in output for token in ["SCRIPT ERROR:", "ERROR:", "POC_FAIL"])
        passed = code == 0 and not errors and ("_OK" in output or "failures=0" in output or "PERFORMANCE_" in output or "FOG_UNIT_FLASH_FIXED" in output or "channels_differing_over_one=0" in output or "BALANCE_SUMMARY cases=" in output)
        results.append(dict(test=name, passed=passed, exit_code=code,
                            timeout=timed_out, terminated_on_error=terminated_on_error, rendering=args.rendering, seconds=round(time.monotonic() - started, 3),
                            log=str(log_path.resolve())))
        print(f'{"PASS" if passed else "FAIL"} {name} ({results[-1]["seconds"]:.2f}s)', flush=True)
    (args.output / "results.json").write_text(json.dumps(results, indent=2) + "\n")
    return 0 if all(result["passed"] for result in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
