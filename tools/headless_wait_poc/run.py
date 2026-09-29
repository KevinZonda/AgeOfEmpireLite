#!/usr/bin/env python3
"""Bounded macOS headless frame-wait reproduction and regression check.

Each run uses an isolated empty project and kills/reaps the child on timeout.
Launch Services CPU is system-wide and may include unrelated application work.
"""
import argparse
import datetime
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
CASES = [("headless_120", ["--headless"], 120),
         ("headless_60", ["--headless"], 60),
         ("headless_default", ["--headless"], 0),
         ("display_driver_120", ["--display-driver", "headless"], 120)]


def cpu_seconds(pid):
    value = subprocess.check_output(
        ["ps", "-p", pid, "-o", "time="], text=True).strip()
    return sum(float(part) * 60 ** i
               for i, part in enumerate(reversed(value.split(":"))))


def run_case(engine, project, flags, fps, duration, ls_pid):
    env = dict(os.environ, AOE_WAIT_POC_FPS=str(fps),
               AOE_WAIT_POC_SECONDS=str(duration))
    cpu_before = cpu_seconds(ls_pid)
    started = time.monotonic()
    try:
        process = subprocess.run(
            [str(engine), *flags, "--path", str(project), "--script", "res://probe.gd"],
            env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            timeout=duration + 15, check=False)
        output, code = process.stdout, process.returncode
        timed_out = False
    except subprocess.TimeoutExpired as exc:
        output = exc.stdout or b""
        if isinstance(output, bytes):
            output = output.decode(errors="replace")
        code, timed_out = None, True
    elapsed = time.monotonic() - started
    cpu = (cpu_seconds(ls_pid) - cpu_before) / elapsed * 100
    probe = None
    for line in output.splitlines():
        if line.startswith("HEADLESS_WAIT_RESULT "):
            probe = json.loads(line.removeprefix("HEADLESS_WAIT_RESULT "))
    # Default headless sleep is 6900 us (~145 iterations/s), even with max_fps=0.
    lower, upper = (fps * 0.7, fps * 1.1 + 2) if fps else (10, 180)
    passed = (code == 0 and "ERROR:" not in output and probe is not None
              and probe["display"] == "headless" and probe["draw_signals"] == 0
              and lower <= probe["iterations_per_second"] <= upper)
    return dict(passed=passed, exit_code=code, timed_out=timed_out, probe=probe,
                launchservicesd_cpu_percent=round(cpu, 2),
                process_wall_seconds=round(elapsed, 3), output=output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--candidate", type=Path)
    parser.add_argument("--seconds", type=float, default=3)
    parser.add_argument("--output", type=Path,
                        default=ROOT / ".godot/headless-wait-poc/results.json")
    args = parser.parse_args()
    if platform.system() != "Darwin":
        parser.error("This PoC measures the macOS headless implementation.")
    if not (args.baseline or args.candidate) or args.seconds < 1:
        parser.error("Specify a baseline and/or candidate, and at least 1 second.")
    ls_pid = subprocess.check_output(["pgrep", "-x", "launchservicesd"], text=True).strip()
    magnet = subprocess.run(["pgrep", "-x", "Magnet"], stdout=subprocess.DEVNULL).returncode == 0
    report = dict(timestamp=datetime.datetime.now().astimezone().isoformat(),
                  macos=platform.mac_ver()[0], magnet_running=magnet, runs=[])
    if not magnet:
        print("Magnet is not running; the original trigger may not reproduce.", flush=True)
    with tempfile.TemporaryDirectory(prefix="aoe-headless-wait-") as directory:
        project = Path(directory)
        (project / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/name="Headless wait PoC"\n'
            '[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        shutil.copyfile(HERE / "probe.gd", project / "probe.gd")
        (project / ".godot").mkdir()
        (project / ".godot/global_script_class_cache.cfg").write_text("list=Array[Dictionary]([])\n")
        for label, engine in [("baseline", args.baseline), ("candidate", args.candidate)]:
            if engine is None:
                continue
            engine = engine.resolve(strict=True)
            cpu_before, started = cpu_seconds(ls_pid), time.monotonic()
            time.sleep(1)
            idle_cpu = (cpu_seconds(ls_pid) - cpu_before) / (time.monotonic() - started) * 100
            for case, flags, fps in CASES:
                result = run_case(engine, project, flags, fps, args.seconds, ls_pid)
                result.update(label=label, case=case, engine=str(engine),
                              idle_launchservicesd_cpu_percent=round(idle_cpu, 2))
                report["runs"].append(result)
                probe = result["probe"] or {}
                print(f'{label}/{case}: within limit={result["passed"]}, '
                      f'iterations/s={probe.get("iterations_per_second")}, '
                      f'launchservicesd={result["launchservicesd_cpu_percent"]}%', flush=True)
                args.output.parent.mkdir(parents=True, exist_ok=True)
                args.output.write_text(json.dumps(report, indent=2) + "\n")
    # Baseline violations demonstrate the bug; only candidate violations fail the check.
    return int(any(not r["passed"] for r in report["runs"] if r["label"] == "candidate"))


if __name__ == "__main__":
    raise SystemExit(main())
