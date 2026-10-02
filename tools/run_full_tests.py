#!/usr/bin/env python3
"""Run the discovered regression suite and every audit PoC without hiding failures.

The default all profile runs every executable tests/*.gd and tests/*.js;
regression explicitly defers only the four-seed balance experiment.
Each invocation creates its own output directory. Exit 1 means a regression,
timeout, runtime error, incomplete exploration, or an unresolved audit bug.
Observations in the original audit are recorded but are not failures.
"""
import argparse
import concurrent.futures
import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import signal
import shutil
import subprocess
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[1]
AUDIT = ROOT / "poc/exploration-2026-10-02/explore.gd"
PRINT_LOCK = threading.Lock()
NODE = "node"
CANCELLED = threading.Event()


def request_cancel(_signum, _frame):
    # A handler only requests shutdown. Worker threads own and reap their
    # process groups, and the main thread still writes a complete partial index.
    CANCELLED.set()


def publish(record, output):
    with PRINT_LOCK:
        if record["status"] != "cancelled" or record["seconds"]:
            print(f"{record['status'].upper():16} {record['name']} ({record['seconds']:.1f}s)", flush=True)
        with (output / "progress.jsonl").open("a") as stream:
            stream.write(json.dumps(record, ensure_ascii=False) + "\n")
    return record


def cancelled_record(script, name, timeout, rendering):
    return {"name": name, "script": str(script.relative_to(ROOT)), "status": "cancelled",
            "rendering": rendering, "exit_code": None, "seconds": 0,
            "timeout_seconds": timeout, "terminated_early": False, "first_error": None,
            "command": [], "log": None, "cases": [], "started": False}


def scene_tree_script(path, visited=None):
    visited = set() if visited is None else visited
    if path in visited or not path.exists():
        return False
    visited.add(path)
    match = re.search(r"^extends\s+(.+)$", path.read_text(), re.M)
    if not match:
        return False
    base = match.group(1).strip()
    if base == "SceneTree":
        return True
    if base.startswith('"res://'):
        return scene_tree_script(ROOT / base.strip('"')[6:], visited)
    return False


def discover():
    return sorted(p for p in (ROOT / "tests").glob("*.gd") if scene_tree_script(p))


def audit_cases():
    source = AUDIT.read_text()
    declaration = re.search(r"var cases\s*:=\s*\[(.*?)\]", source, re.S)
    if declaration is None:
        raise ValueError("Could not discover audit case IDs")
    return re.findall(r'"([a-z_]+)"', declaration.group(1))


def needs_renderer(path):
    source = path.read_text()
    return any(token in source for token in ("RenderingServer.force_draw", "get_texture().get_image", "await RenderingServer.frame_post_draw")) or path.stem in ("performance_pan", "performance_visible", "display_settings", "smoke")


def isolated_project(path, output, name):
    """Mirror resource paths while overriding only the test's user:// location."""
    for child in ROOT.iterdir():
        if child.name not in ("project.godot", ".git", "tmp"):
            (path / child.name).symlink_to(child, target_is_directory=child.is_dir())
    (path / "tmp").mkdir()
    directory_id = hashlib.sha256(str(output).encode()).hexdigest()[:16]
    user_name = f"AgeOfEmpireLite-full-tests/{directory_id}/{name}"
    source = (ROOT / "project.godot").read_text()
    source = source.replace("[application]", '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name=' + json.dumps(user_name), 1)
    (path / "project.godot").write_text(source)
    if platform.system() == "Darwin":
        return path.resolve() / user_name
    return Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / user_name


def snapshot():
    paths = [ROOT / "project.godot", ROOT / "tools/web_shell.html"]
    for directory in ("scripts", "tests", "data", "scenes", "assets"):
        paths += sorted(p for p in (ROOT / directory).rglob("*") if p.is_file() and p.suffix not in (".uid", ".import"))
    paths.append(AUDIT)
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}


def failure_signatures(contents):
    """Stable diagnostic identities; assertion evidence and traces are omitted."""
    signatures = set()
    contents = re.sub(r"\x1b\[[0-9;]*m", "", contents)
    for raw in contents.splitlines():
        line = raw.strip()
        marker = re.match(r"^POC_FAIL\s+([\w:./-]+)", line)
        if marker:
            signatures.add("POC_FAIL " + marker.group(1))
        elif line.startswith(("SCRIPT ERROR:", "ERROR:")):
            # Source line numbers shift when code is repaired. Keep the error
            # itself, but never treat trace locations or changing float values
            # in diagnostic evidence as a new failure.
            line = re.sub(r"(?<=\.gd):\d+(?::\d+)?", ":<line>", line)
            line = re.sub(r"(?<![\w.])[-+]?(?:\d+\.\d+(?:[eE][-+]?\d+)?|\d+[eE][-+]?\d+)(?![\w.])", "<float>", line)
            signatures.add(line)
    return sorted(signatures)


def previous_failure_signatures(record, previous_file):
    if "failure_signatures" in record:
        return set(record["failure_signatures"])
    log = record.get("log")
    if log:
        path = Path(log)
        if not path.is_absolute():
            path = previous_file.parent / path
        if path.exists():
            return set(failure_signatures(path.read_text(errors="replace")))
    return set()


def stop_process(process):
    if process.poll() is None:
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            return
        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()


def execute(engine, script, name, output, timeout, case_ids=None, rendering=False):
    if not rendering:
        return execute_unlocked(engine, script, name, output, timeout, case_ids, rendering)
    # Different cumulative worktrees can validate concurrently, while native
    # windows and frame benchmarks share one renderer admission lock.
    lock_path = Path(tempfile.gettempdir()) / "ageofempirelite-native-regression.lock"
    with lock_path.open("a") as lock:
        while True:
            if CANCELLED.is_set():
                return publish(cancelled_record(script, name, timeout, rendering), output)
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                time.sleep(0.1)
        return execute_unlocked(engine, script, name, output, timeout, case_ids, rendering)


def execute_unlocked(engine, script, name, output, timeout, case_ids=None, rendering=False):
    if script.suffix == ".js":
        name += "-js"
    if CANCELLED.is_set():
        return publish(cancelled_record(script, name, timeout, rendering), output)
    temporary = tempfile.TemporaryDirectory(prefix="ageofempirelite-test-")
    project = Path(temporary.name).resolve()
    user_dir = isolated_project(project, output, name)
    if script.suffix == ".js":
        command = [NODE, str(script)]
    else:
        display = ["--windowed", "--resolution", "1280x720", "--audio-driver", "Dummy"] if rendering else ["--headless"]
        command = [engine, "--path", str(project), *display, "--log-file", str(output / "logs" / f"{name}.engine.log"), "--script", "res://" + str(script.relative_to(ROOT))]
    if case_ids:
        command += ["--", *case_ids]
    env = os.environ.copy()
    child_cwd = ROOT
    child_home_removed = script.suffix != ".js" and platform.system() == "Darwin"
    if child_home_removed:
        # Godot macOS falls back to the current directory when HOME is absent.
        # Remove it only from this engine child, keeping the parent untouched.
        env.pop("HOME", None)
        child_cwd = project
    env["RTS_POC_RESULTS"] = str(output / f"{name}-cases.json")
    artifact = output / "images" / ("farm.png" if script.stem == "farm_rendering" else name)
    artifact.parent.mkdir(exist_ok=True)
    env["RTS_RENDER_OUTPUT"] = str(artifact)
    if script.stem == "balance_multiseed":
        # This is the complete default suite, independent of shorter benchmark
        # flags inherited from the invoking shell. Trace shows progress during
        # these long runs without changing the simulated duration or scenario.
        env.update(RTS_BALANCE_SEEDS="17,431,9021,4242", RTS_BALANCE_SECONDS="480", RTS_BALANCE_MATRIX="0", RTS_BALANCE_TRACE="1")
    if script.stem == "relic_rendering":
        command += ["--", str(artifact)]
    log_path = output / "logs" / f"{name}.log"
    started = time.monotonic()
    halted = None
    error_line = None
    with log_path.open("wb") as log:
        if CANCELLED.is_set():
            temporary.cleanup()
            return publish(cancelled_record(script, name, timeout, rendering), output)
        process = subprocess.Popen(command, cwd=child_cwd, stdout=log, stderr=subprocess.STDOUT, env=env, start_new_session=True)
        consumed = 0
        tail = ""
        while process.poll() is None:
            if CANCELLED.is_set():
                halted = "cancelled"
                stop_process(process)
                break
            if time.monotonic() - started >= timeout:
                halted = "timeout"
                stop_process(process)
                break
            with log_path.open("rb") as reader:
                reader.seek(consumed)
                chunk = reader.read()
                consumed += len(chunk)
            tail += chunk.decode("utf-8", errors="replace")
            # Godot assertion failures abort only the coroutine, often leaving
            # its SceneTree alive forever. Kill immediately with an explicit
            # record. Audit cases intentionally exercise stale-object errors,
            # so their final CASE records determine outcome instead.
            if not case_ids:
                match = re.search(r"^(?:SCRIPT ERROR:|ERROR: Failed to load script|ERROR: Parse Error).*", tail, re.M)
                if match:
                    halted = "failed"
                    error_line = match.group(0)
                    stop_process(process)
                    break
            tail = tail[-8192:]
            time.sleep(0.1)
    contents = log_path.read_text(errors="replace")
    cases = []
    for line in contents.splitlines():
        if line.startswith("CASE "):
            try:
                cases.append(json.loads(line[5:]))
            except json.JSONDecodeError:
                pass
    if halted:
        status = halted
    elif case_ids:
        complete = "EXPLORATION_COMPLETE" in contents and sorted(c["id"] for c in cases) == sorted(case_ids)
        runtime_error = any("runtime_error" in c.get("evidence", {}) for c in cases)
        if process.returncode != 0 or not complete or runtime_error:
            status = "failed"
        elif any(c["status"] == "bug" for c in cases):
            status = "unresolved_bugs"
        else:
            status = "passed"
    else:
        bad_output = "SCRIPT ERROR:" in contents or "POC_FAIL" in contents or bool(re.search(r"^ERROR:|\bchecks=\d+\s+failures=[1-9]\d*", contents, re.M))
        status = "passed" if process.returncode == 0 and not bad_output else "failed"
    balance_seeds = re.findall(r"^BALANCE seed=(\d+)\b", contents, re.M) if script.stem == "balance_multiseed" else None
    if balance_seeds is not None and status == "passed" and sorted(balance_seeds) != sorted(["17", "431", "9021", "4242"]):
        status = "failed"
    if status == "passed" and re.search(r"\b(?:SKIP|SKIPPED)\b", contents):
        status = "skipped"
    if user_dir.exists():
        saved = output / "userdata" / name
        saved.parent.mkdir(exist_ok=True)
        shutil.copytree(user_dir, saved)
        shutil.rmtree(user_dir)
    if any((project / "tmp").iterdir()):
        shutil.copytree(project / "tmp", output / "images" / f"{name}-tmp")
    temporary.cleanup()
    record = {"name": name, "script": str(script.relative_to(ROOT)), "status": status,
              "failure_signatures": failure_signatures(contents),
              "started": True,
              "rendering": rendering, "isolated_user_dir": str(user_dir),
              "child_cwd": str(child_cwd), "child_home_removed": child_home_removed,
              "user_dir_isolation": "macos_child_without_home" if child_home_removed else "custom_user_dir",
              "exit_code": process.returncode, "seconds": round(time.monotonic() - started, 3),
              "timeout_seconds": timeout, "terminated_early": halted == "failed", "first_error": error_line,
              "command": command, "log": str(log_path.relative_to(output)), "cases": cases}
    if balance_seeds is not None:
        record["balance_seeds_executed"] = balance_seeds
        record["balance_seconds_per_seed"] = 480
    return publish(record, output)


def main():
    global NODE
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="New or empty evidence directory; never overwrites existing results")
    parser.add_argument("--jobs", type=int, default=2)
    parser.add_argument("--timeout", type=float, default=600, help="Per-script seconds (AI long-match gets 3x, multiseed balance gets 6x)")
    parser.add_argument("--engine", default=os.environ.get("GODOT"))
    parser.add_argument("--node", default=os.environ.get("NODE"), help="Node executable; automatically probes PATH and /usr/local/bin/node")
    parser.add_argument("--compare", type=Path, help="Previous results.json (or its directory); report new failures without masking current failures")
    parser.add_argument("--profile", choices=("all", "regression"), default="all", help="all includes the complete four-seed balance experiment; regression explicitly defers only that benchmark")
    parser.add_argument("--list", action="store_true", help="Print discovered scripts/cases without running")
    args = parser.parse_args()
    if args.jobs < 1 or args.timeout <= 0:
        parser.error("--jobs and --timeout must be positive")
    full_scripts = discover() + sorted((ROOT / "tests").glob("*.js"))
    deferred = ["tests/balance_multiseed.gd"] if args.profile == "regression" else []
    scripts = [path for path in full_scripts if str(path.relative_to(ROOT)) not in deferred]
    cases = audit_cases()
    if args.list:
        print(json.dumps({"profile": args.profile, "deferred_benchmarks": deferred, "scripts": [str(p.relative_to(ROOT)) for p in scripts], "rendering_scripts": [str(p.relative_to(ROOT)) for p in scripts if p.suffix == ".gd" and needs_renderer(p)], "audit_cases": cases}, indent=2))
        return 0
    CANCELLED.clear()
    signal.signal(signal.SIGINT, request_cancel)
    signal.signal(signal.SIGTERM, request_cancel)
    engine = args.engine or (str(ROOT / f"docs/godot/bin/godot.macos.template_debug.{platform.machine()}") if platform.system() == "Darwin" else "godot")
    candidates = [args.node] if args.node else list(dict.fromkeys([shutil.which("node"), "/usr/local/bin/node", "node"]))
    for candidate in candidates:
        if not candidate:
            continue
        try:
            probe = subprocess.run([candidate, "--version"], text=True, capture_output=True, timeout=5)
            if probe.returncode == 0:
                NODE = candidate
                break
        except (OSError, subprocess.TimeoutExpired):
            continue
    else:
        parser.error("No working Node runtime found; use --node /path/to/node")
    timestamp = datetime.datetime.now().astimezone().strftime("%Y%m%d-%H%M%S-%f")
    output = (args.output or ROOT / "poc/exploration-2026-10-02/fixes" / timestamp).resolve()
    if output.exists() and any(output.iterdir()):
        parser.error(f"Output directory is not empty: {output}")
    (output / "logs").mkdir(parents=True, exist_ok=True)
    before = snapshot()
    started = time.monotonic()
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    metadata = {"revision": revision, "engine": engine, "engine_version": subprocess.check_output([engine, "--version"], text=True).strip(),
                "runner_pid": os.getpid(),
                "profile": args.profile, "deferred_benchmarks": deferred,
                "node": NODE, "node_version": subprocess.check_output([NODE, "--version"], text=True).strip(),
                "started_at": datetime.datetime.now().astimezone().isoformat(), "jobs": args.jobs,
                "timeout_seconds": args.timeout, "discovered_full_script_count": len(full_scripts), "regression_count": len(scripts), "audit_count": len(cases), "source_before": before}
    (output / "environment.json").write_text(json.dumps(metadata, indent=2))
    print(f"Profile {args.profile}: running {len(scripts)} regression scripts and {len(cases)} audit cases; deferred benchmarks: {deferred}; evidence: {output}", flush=True)
    windowed = [path for path in scripts if path.suffix == ".gd" and needs_renderer(path)]
    headless = [path for path in scripts if path not in windowed]
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        regression = list(pool.map(lambda path: execute(engine, path, path.stem, output, args.timeout * {"ai_long_match": 3, "balance_multiseed": 6}.get(path.stem, 1)), headless))
    # Pixel captures and visible frame benchmarks need the real renderer and
    # run one at a time to avoid competing windows/GPU timing interference.
    regression += [execute(engine, path, path.stem, output, args.timeout, rendering=True) for path in windowed]
    # Small independent batches preserve all evidence if one scene aborts or
    # stalls. No test-results files in the initial audit directory are changed.
    batches = [cases[start:start + 8] for start in range(0, len(cases), 8)]
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        exploration = list(pool.map(lambda pair: execute(engine, AUDIT, f"audit-{pair[0]:02}", output, args.timeout, pair[1]), enumerate(batches)))
    after = snapshot()
    changed = sorted(path for path in before.keys() | after.keys() if before.get(path) != after.get(path))
    flat_cases = [case for result in exploration for case in result["cases"]]
    statuses = ("passed", "failed", "timeout", "unresolved_bugs", "skipped", "cancelled")
    summary = {"revision": revision, "seconds": round(time.monotonic() - started, 3),
               "profile": args.profile, "deferred_benchmarks": deferred,
               "regression": {status: sum(r["status"] == status for r in regression) for status in statuses},
               "audit": {status: sum(c["status"] == status for c in flat_cases) for status in ("pass", "bug", "observation")},
               "expected_audit_cases": len(cases), "executed_audit_cases": len(flat_cases), "changed_sources_during_run": changed}
    summary["cancelled"] = CANCELLED.is_set()
    expected_scripts = {str(path.relative_to(ROOT)) for path in scripts}
    actual_scripts = {r["script"] for r in regression}
    complete_script_inventory = actual_scripts == expected_scripts and len(regression) == len(scripts)
    complete_case_inventory = {c["id"] for c in flat_cases} == set(cases) and len(flat_cases) == len(cases)
    summary["expected_regression_scripts"] = len(scripts)
    summary["executed_regression_scripts"] = sum(r.get("started", False) for r in regression)
    complete_regression = not any(r["status"] in ("timeout", "cancelled", "skipped") for r in regression)
    complete_balance = all(len(r.get("balance_seeds_executed", [])) == 4 for r in regression if r["script"] == "tests/balance_multiseed.gd")
    summary["complete"] = not CANCELLED.is_set() and complete_script_inventory and complete_case_inventory and complete_regression and complete_balance
    summary["complete_all"] = summary["complete"] and not deferred
    passed = not CANCELLED.is_set() and not changed and all(r["status"] == "passed" for r in regression + exploration) and len(flat_cases) == len(cases)
    summary["passed"] = passed
    if args.compare:
        previous_file = args.compare / "results.json" if args.compare.is_dir() else args.compare
        previous = json.loads(previous_file.read_text())
        old_tests = {r["script"]: r for r in previous["regression"]}
        old_cases = {c["id"]: c for r in previous["exploration"] for c in r["cases"]}
        newly_failed = [r["script"] for r in regression if r["status"] != "passed" and (r["script"] not in old_tests or old_tests[r["script"]]["status"] == "passed")]
        new_failure_diagnostics = {}
        for current in regression:
            old = old_tests.get(current["script"])
            if current["status"] == "failed" and old and old["status"] == "failed":
                added = set(current["failure_signatures"]) - previous_failure_signatures(old, previous_file)
                if added:
                    new_failure_diagnostics[current["script"]] = sorted(added)
        regressed_cases = [c["id"] for c in flat_cases if c["status"] == "bug" and old_cases.get(c["id"], {}).get("status") == "pass"]
        fixed_cases = [c["id"] for c in flat_cases if c["status"] == "pass" and old_cases.get(c["id"], {}).get("status") == "bug"]
        missing_tests = sorted(set(old_tests) - {r["script"] for r in regression} - set(deferred))
        missing_cases = sorted(set(old_cases) - {c["id"] for c in flat_cases})
        exploration_failures = [r["name"] for r in exploration if r["status"] not in ("passed", "unresolved_bugs")]
        incomplete_scripts = [r["script"] for r in regression if r["status"] in ("timeout", "cancelled", "skipped")]
        comparison = {"previous": str(previous_file), "new_regression_failures": newly_failed,
                      "new_failure_diagnostics": new_failure_diagnostics,
                      "regressed_audit_cases": regressed_cases, "fixed_audit_cases": fixed_cases,
                      "missing_scripts": missing_tests, "missing_cases": missing_cases,
                      "profile": args.profile, "deferred_benchmarks": deferred,
                      "exploration_execution_failures": exploration_failures,
                      "incomplete_scripts": incomplete_scripts,
                      "no_new_failures": summary["complete"] and not (changed or newly_failed or new_failure_diagnostics or regressed_cases or missing_tests or missing_cases or exploration_failures or incomplete_scripts)}
        summary["comparison"] = comparison
        (output / "comparison.json").write_text(json.dumps(comparison, indent=2, ensure_ascii=False))
    result = {"summary": summary, "regression": regression, "exploration": exploration, "source_after": after}
    (output / "results.json").write_text(json.dumps(result, indent=2, ensure_ascii=False))
    (output / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False))
    print(json.dumps(summary, ensure_ascii=False), flush=True)
    return 130 if CANCELLED.is_set() else 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
