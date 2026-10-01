#!/usr/bin/env python3
"""Run and retain the gather-switch PoC, rejecting script errors and timeouts."""
import argparse
import json
import os
from pathlib import Path
import platform
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, default=Path(os.environ.get(
        "GODOT", str(ROOT / f"docs/godot/bin/godot.macos.template_debug.{platform.machine()}"))))
    parser.add_argument("--suite", choices=["standard", "crowd"], default="standard")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--runs", type=int, default=2)
    parser.add_argument("--timeout", type=float, default=300)
    args = parser.parse_args()
    if args.output is None:
        args.output = HERE / ("crowd-results" if args.suite == "crowd" else "results")
    if args.runs < 1:
        parser.error("--runs must be at least 1")
    args.output.mkdir(parents=True, exist_ok=True)
    results = []
    for number in range(1, args.runs + 1):
        log_path = args.output / f"run-{number}.log"
        report_path = (args.output / f"run-{number}.json").resolve()
        report_path.unlink(missing_ok=True)
        env = dict(os.environ, RTS_GATHER_POC_OUTPUT=str(report_path))
        script = "gather_crowd_poc.gd" if args.suite == "crowd" else "gather_switch_poc.gd"
        command = [str(args.godot), "--headless", "--path", str(ROOT),
                   "--script", f"res://poc/gather-switch-poc/{script}"]
        started = time.monotonic()
        timed_out = False
        script_error = False
        with log_path.open("w") as log:
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, env=env)
            while process.poll() is None:
                output = log_path.read_text()
                script_error = "SCRIPT ERROR:" in output or "ERROR:" in output
                timed_out = time.monotonic() - started > args.timeout
                if script_error or timed_out:
                    process.terminate()
                    break
                time.sleep(0.1)
            try:
                code = process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                code = process.wait()
        output = log_path.read_text()
        report = json.loads(report_path.read_text()) if report_path.exists() else {}
        passed = (code == 0 and not timed_out and not script_error
                  and "ERROR:" not in output and "CHECK_FAIL" not in output
                  and report.get("failures") == 0 and report.get("checks", 0) > 0
                  and "GATHER_SWITCH_POC" in output)
        results.append({"run": number, "suite": args.suite, "passed": passed, "exit_code": code,
                        "seconds": round(time.monotonic() - started, 3),
                        "timeout": timed_out, "script_error": script_error,
                        "checks": report.get("checks"), "cases": len(report.get("cases", [])),
                        "log": log_path.name, "report": report_path.name})
        print(f'{"PASS" if passed else "FAIL"} run {number}: {results[-1]}', flush=True)
    (args.output / "summary.json").write_text(json.dumps(results, indent=2) + "\n")
    return 0 if all(result["passed"] for result in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
