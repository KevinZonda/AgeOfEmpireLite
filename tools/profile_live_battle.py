#!/usr/bin/env python3
"""Serial A/B of real windowed siege frames, including rendering and frame waits."""
import argparse
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, default=ROOT)
    parser.add_argument("--baseline-engine", type=Path, required=True)
    parser.add_argument("--candidate-engine", type=Path,
                        default=ROOT / "docs/godot/bin/godot.macos.template_debug.arm64")
    parser.add_argument("--buildings", nargs="+", type=int, choices=[1, 6], default=[1, 6])
    parser.add_argument("--rounds", type=int, default=2)
    parser.add_argument("--frames", type=int, default=360)
    parser.add_argument("--focus", action="store_true", help="All attackers target one building in the cluster")
    parser.add_argument("--output", type=Path, default=ROOT / ".godot/live-battle-profile")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    reports = []
    for repeat in range(args.rounds):
        for buildings in args.buildings:
            order = ["baseline", "candidate"] if repeat % 2 == 0 else ["candidate", "baseline"]
            for version in order:
                project = getattr(args, version).resolve()
                engine = getattr(args, version + "_engine").resolve()
                env = {k: v for k, v in os.environ.items() if not k.startswith("RTS_POC_")}
                env.update(RTS_POC_FRAMES=str(args.frames), RTS_POC_BUILDINGS=str(buildings), RTS_NAV_PROFILE="0")
                env["RTS_POC_FOCUS"] = "1" if args.focus else "0"
                command = [str(engine), "--path", str(project), "--script", "res://tools/battle_deer_poc.gd",
                           "--windowed", "--resolution", "1280x800"]
                result = subprocess.run(command, env=env, stdout=subprocess.PIPE,
                                        stderr=subprocess.STDOUT, text=True, timeout=180, check=False)
                name = f"{repeat + 1}-{buildings}-{version}"
                (args.output / f"{name}.log").write_text(result.stdout)
                rows = [json.loads(line.removeprefix("LIVE_PROFILE "))
                        for line in result.stdout.splitlines() if line.startswith("LIVE_PROFILE ")]
                if result.returncode or "ERROR:" in result.stdout or len(rows) != 1:
                    raise RuntimeError(f"Invalid run: {name}; see saved log")
                row = rows[0]
                if row["damage"] <= 0 or row["viewport"] != "(1280, 800)":
                    raise RuntimeError(f"No battle damage or incorrect viewport: {name}")
                row.update(version=version, round=repeat + 1, project=str(project), engine=str(engine))
                reports.append(row)
                (args.output / "results.json").write_text(json.dumps(reports, indent=2) + "\n")
                print(f'{name}: frame={row["timings"]["frame_ms"]["mean"]:.2f} ms '
                      f'P95={row["timings"]["frame_ms"]["p95"]:.2f} ms damage={row["damage"]:.0f}', flush=True)


if __name__ == "__main__":
    main()
