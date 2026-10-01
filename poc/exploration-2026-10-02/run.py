#!/usr/bin/env python3
"""Run existing regression scripts and exploratory cases with hard timeouts."""
import argparse
import concurrent.futures
import hashlib
import json
import os
import pathlib
import subprocess
import time

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = pathlib.Path(__file__).resolve().parent
ENGINE = ROOT / "docs/godot/bin/godot.macos.template_debug.arm64"
BASELINE = """smoke production_queue_regression unit_orders_regression player_input_actions_regression session_rules_regression simulation_runtime match_services match_changes match_simulation_regression selection enemy_inspection right_click_selection lobby_setup build_grid build_selection farm_cycle sheep_gathering deer_gathering villager_boar_escape villager_post_construction trade_post_targeting rally_landmarks fog_of_war fog_building_memory fog_unit_flash_poc chinese extended_systems objectives strategic_expansion combat_rules attack_weapon_selection balance_system landmark_catalog landmark_roles siege_rules siege_actions economy_siege_controls aoe4_requested_systems battle_experience navigation group_multiplayer map_generator map_strategy map_fairness""".split()
NAVIGATION = """navigation_poc navigation_poc_matrix navigation_range_stall_poc navigation_range_corner_poc navigation_range_siege_poc navigation_destination_poc navigation_state_poc navigation_tasks_poc navigation_corner_poc navigation_construction_poc navigation_replanning navigation_routes navigation_boundaries group_replanning group_chokepoint group_mass_chokepoint navigation_async_poc navigation_battle_retry_poc navigation_battle_recovery_poc navigation_battle_goal_poc""".split()

def run(script, timeout, case_ids=None, label=None):
    command = [str(ENGINE), "--path", str(ROOT), "--headless", "--script", script]
    if case_ids: command += ["--", *case_ids]
    started = time.monotonic()
    name = label or pathlib.Path(script).stem
    (OUT / "logs").mkdir(exist_ok=True)
    log = OUT / "logs" / f"{name}.log"
    env = os.environ.copy()
    if label and not script.startswith('res://tests/'):
        env['RTS_POC_RESULTS'] = f'res://poc/exploration-2026-10-02/results-{label}.json'
    try:
        with log.open("w") as stream:
            result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT, text=True, timeout=timeout, env=env)
        output = log.read_text()
        status = "passed" if result.returncode == 0 and "SCRIPT ERROR" not in output and "POC_FAIL" not in output else "failed"
        if script.endswith('/explore.gd') and result.returncode == 0 and 'EXPLORATION_COMPLETE' in output and '"runtime_error"' not in output:
            status = 'completed'
        code = result.returncode
    except subprocess.TimeoutExpired as exc:
        output = log.read_text()
        status, code = "timeout", None
    record = dict(script=script, status=status, exit_code=code, seconds=round(time.monotonic()-started, 3), command=command)
    print(f"{status.upper()} {name} ({record['seconds']}s)", flush=True)
    return record

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", action="store_true")
    parser.add_argument("--navigation", action="store_true")
    parser.add_argument("--cases", nargs='+')
    parser.add_argument("--label")
    parser.add_argument("--timeout", type=int, default=600)
    parser.add_argument("--jobs", type=int, default=2)
    args = parser.parse_args()
    suite = BASELINE if args.baseline else NAVIGATION if args.navigation else []
    scripts = [f"res://tests/{s}.gd" for s in suite] if suite else ["res://poc/exploration-2026-10-02/explore.gd"]
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        results = list(pool.map(lambda s: run(s, args.timeout, args.cases, args.label), scripts))
    name = "baseline.json" if args.baseline else "navigation.json" if args.navigation else "run.json"
    if args.label: name = args.label + '-run.json'
    (OUT / name).write_text(json.dumps(results, indent=2, ensure_ascii=False))
    if not suite:
        tracked = subprocess.check_output(["git", "ls-files", "scripts", "project.godot", "data"], cwd=ROOT, text=True).splitlines()
        manifest = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in tracked}
        (OUT / "source-manifest.json").write_text(json.dumps(manifest, indent=2))
    print(json.dumps({s: sum(r['status'] == s for r in results) for s in ['passed', 'completed', 'failed', 'timeout']}))

if __name__ == "__main__":
    main()
