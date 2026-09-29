#!/usr/bin/env python3
"""Serial, unprofiled windowed battle comparison using the same Godot runtime."""
import argparse
import json
import os
from pathlib import Path
import platform
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, default=ROOT)
    parser.add_argument("--godot", type=Path, default=ROOT / f"docs/godot/bin/godot.macos.template_debug.{platform.machine()}")
    parser.add_argument("--rounds", type=int, default=3)
    parser.add_argument("--sides", type=int, nargs="+", default=[40, 80])
    parser.add_argument("--steps", type=int, default=300)
    parser.add_argument("--output", type=Path, default=ROOT / ".godot/battle-benchmark")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    results = []
    for count in args.sides:
        for trial in range(args.rounds):
            projects = [("baseline", args.baseline), ("candidate", args.candidate)]
            if trial % 2: projects.reverse()
            for label, path in projects:
                env = os.environ.copy()
                env.update(RTS_BATTLE_SIEGE="1", RTS_BATTLE_MAP="generated",
                           RTS_BATTLE_SIDE=str(count), RTS_BENCH_STEPS=str(args.steps),
                           RTS_NAV_PROFILE="0", RTS_BENCH_NO_FOG="0", RTS_BENCH_PROJECTION="2.5d")
                log_path = args.output / f"{label}-{count}-{trial + 1}.log"
                print(f"RUN {label} attackers={count} trial={trial + 1}", flush=True)
                with log_path.open("w") as log:
                    completed = subprocess.run(
                        [str(args.godot.resolve()), "--path", str(path.resolve()),
                         "--script", "res://tests/performance_battle_poc.gd",
                         "--windowed", "--resolution", "1280x720"],
                        env=env, stdout=log, stderr=subprocess.STDOUT, timeout=180,
                        check=False)
                output = log_path.read_text()
                if completed.returncode or "ERROR:" in output:
                    raise RuntimeError(f"Battle benchmark failed: {log_path}")
                row = next(json.loads(line.removeprefix("BATTLE_POC "))
                           for line in output.splitlines() if line.startswith("BATTLE_POC "))
                if row["hp_lost"] <= 0 or row["headless"]:
                    raise RuntimeError(f"Benchmark did not render a live fight: {log_path}")
                row.update(variant=label, trial=trial + 1)
                results.append(row)
                (args.output / "timings.json").write_text(json.dumps(results, indent=2) + "\n")
                print(f"DONE {label} frame={row['frame']} simulation={row['simulation']}", flush=True)


if __name__ == "__main__":
    main()
