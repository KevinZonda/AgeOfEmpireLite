#!/usr/bin/env python3
"""Apply reviewed audit patches one at a time, fully test, commit, then push.

The user explicitly requested this sequence. This tool stops on conflicts,
new regression failures, incomplete tests, changed sources, or push rejection.
Known baseline failures remain visible in every complete test result.
"""
import argparse
import datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
AUDIT = ROOT / "poc/exploration-2026-10-02"
PLAN = AUDIT / "fixes-plan.json"
LEDGER = AUDIT / "fixes" / "milestones.json"
ACTIVE = None
spec = importlib.util.spec_from_file_location("full_test_runner", ROOT / "tools/run_full_tests.py")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


def command(args, capture=False):
    global ACTIVE
    ACTIVE = subprocess.Popen(args, cwd=ROOT, stdout=subprocess.PIPE if capture else None, text=True)
    output, _ = ACTIVE.communicate()
    code = ACTIVE.returncode
    ACTIVE = None
    if code:
        raise RuntimeError(f"Command failed ({code}): {args}")
    return output.strip() if capture else None


def cancel(signum, _frame):
    if ACTIVE is not None and ACTIVE.poll() is None:
        ACTIVE.send_signal(signal.SIGINT)
        try:
            ACTIVE.wait(timeout=10)
        except subprocess.TimeoutExpired:
            ACTIVE.terminate()
            try:
                ACTIVE.wait(timeout=10)
            except subprocess.TimeoutExpired:
                # Engines own separate process groups; reap them explicitly
                # before killing a runner that could not finish cancellation.
                rows = subprocess.check_output(["ps", "-axo", "pid=,ppid="], text=True)
                for row in rows.splitlines():
                    child, parent = map(int, row.split())
                    if parent == ACTIVE.pid:
                        try:
                            os.killpg(child, signal.SIGKILL)
                        except ProcessLookupError:
                            pass
                ACTIVE.kill()
                ACTIVE.wait()
    raise SystemExit(128 + signum)


def write_ledger(records):
    LEDGER.parent.mkdir(parents=True, exist_ok=True)
    LEDGER.write_text(json.dumps(records, indent=2, ensure_ascii=False) + "\n")
    lines = ["# Bug 修复与逐项全量验证", "",
             "原报告的 18 类问题逐项修复；追加 B19 为全量测试确认的空间索引漏碰撞，B20 为视觉快照隔离契约。每项先执行完整 regression 测试范围和 63 个探索场景，检查该项回归通过、没有新增失败及源码运行期间不变，再提交并推送。四种子平衡性统计实验在最终版本完整执行，默认 all 范围也包含该实验。", "",
             "全量结果保留未修复 PoC 和基线已有失败；`passed: false` 不会被改写为全绿。每轮 comparison 明确列出新增失败、已修复场景和执行缺失。", "",
             "|编号|修复|全量测试|新增失败|验证提交 / 推送|", "|---|---|---|---|---|"]
    for r in records:
        s = r["summary"]
        reg = s["regression"]
        proof = r.get("commit")
        commit = f"[{proof[:8]}](https://github.com/KevinZonda/AgeOfEmpireLite/commit/{proof})" if proof else "生成验证提交中"
        state = "已推送" if r.get("pushed") else "待推送"
        test = f"[结果]({r['output']}/summary.json)：{reg.get('passed', 0)}通过 / {reg.get('failed', 0)}已有失败 / {reg.get('timeout', 0)}超时，PoC {s['executed_audit_cases']}/{s['expected_audit_cases']}，范围 {s.get('profile', 'all')}"
        lines.append(f"|{r['id']}|{r['title']}|{test}|0|{commit} · {state}|")
    lines += ["", "重跑任一修复的完整验证：", "", "```sh",
              "python3 tools/run_full_tests.py --output /tmp/ageofempirelite-full-recheck --jobs 4 --timeout 600 --compare poc/exploration-2026-10-02/fixes/baseline", "```", "",
              "默认保留 AI 6000 步与四种子各 480 秒的完整模拟；渲染/原生窗口测试单独串行，user:// 使用每项测试独立目录。初始报告、原始失败证据与复现步骤见 [探索报告](README.md)。", ""]
    (AUDIT / "FIXES.md").write_text("\n".join(lines))


def verify(entry, output, already_fixed, profile):
    result = json.loads((output / "results.json").read_text())
    summary = result["summary"]
    if not summary.get("complete", False):
        raise RuntimeError("Incomplete test profile")
    if summary.get("profile") != profile:
        raise RuntimeError("Test profile differs from requested profile")
    comp = summary.get("comparison", {})
    if not comp.get("no_new_failures"):
        raise RuntimeError(f"{entry['id']} introduced failures or incomplete execution: {comp}")
    if summary["executed_audit_cases"] != summary["expected_audit_cases"]:
        raise RuntimeError("Incomplete audit")
    by_script = {r["script"]: r for r in result["regression"]}
    expected = {str(p.relative_to(ROOT)) for p in runner.discover() + list((ROOT / "tests").glob("*.js"))}
    if profile == "regression":
        expected.discard("tests/balance_multiseed.gd")
    if set(by_script) != expected or len(result["regression"]) != len(expected):
        raise RuntimeError("Executed script inventory differs from current project")
    required = entry.get("tests", [entry["test"]])
    for script in required:
        if by_script.get(script, {}).get("status") != "passed":
            raise RuntimeError(f"Required regression did not pass: {script}")
    cases = {c["id"]: c for r in result["exploration"] for c in r["cases"]}
    for case in set(entry["cases"]) | already_fixed:
        if cases.get(case, {}).get("status") != "pass":
            raise RuntimeError(f"Fixed audit case regressed: {case}")
    if business_sources(runner.snapshot()) != business_sources(result["source_after"]):
        raise RuntimeError("Source inventory or contents changed since tests")
    return summary


def generated_artifact(path):
    return Path(path).name == ".DS_Store" or path.startswith("assets/ui/command_icons/") and path.endswith(".library.translation")


def business_sources(snapshot):
    return {p: h for p, h in snapshot.items() if not generated_artifact(p)}


def recompare(output, previous):
    """Compare completed cumulative-worktree evidence to the actual predecessor."""
    file = output / "results.json"
    result = json.loads(file.read_text())
    previous_file = previous / "results.json"
    prior = json.loads(previous_file.read_text())
    summary = result["summary"]
    old_tests = {r["script"]: r for r in prior["regression"]}
    now_tests = {r["script"]: r for r in result["regression"]}
    old_cases = {c["id"]: c for r in prior["exploration"] for c in r["cases"]}
    now_cases = {c["id"]: c for r in result["exploration"] for c in r["cases"]}
    added_diagnostics = {}
    new_failures = []
    for script, record in now_tests.items():
        old = old_tests.get(script)
        if record["status"] != "passed" and (not old or old["status"] == "passed"):
            new_failures.append(script)
        if record["status"] == "failed" and old and old["status"] == "failed":
            added = runner.previous_failure_signatures(record, file) - runner.previous_failure_signatures(old, previous_file)
            if added:
                added_diagnostics[script] = sorted(added)
    deferred = set(summary.get("deferred_benchmarks", []))
    comp = {"previous": str(previous_file), "profile": summary["profile"],
            "deferred_benchmarks": sorted(deferred), "new_regression_failures": sorted(new_failures),
            "new_failure_diagnostics": added_diagnostics,
            "regressed_audit_cases": [c for c, r in now_cases.items() if r["status"] == "bug" and old_cases.get(c, {}).get("status") == "pass"],
            "fixed_audit_cases": [c for c, r in now_cases.items() if r["status"] == "pass" and old_cases.get(c, {}).get("status") == "bug"],
            "missing_scripts": sorted(set(old_tests) - set(now_tests) - deferred),
            "missing_cases": sorted(set(old_cases) - set(now_cases)),
            "exploration_execution_failures": [r["name"] for r in result["exploration"] if r["status"] not in ("passed", "unresolved_bugs")],
            "incomplete_scripts": [r["script"] for r in result["regression"] if r["status"] in ("timeout", "cancelled", "skipped")]}
    gates = ["new_regression_failures", "new_failure_diagnostics", "regressed_audit_cases", "missing_scripts", "missing_cases", "exploration_execution_failures", "incomplete_scripts"]
    comp["no_new_failures"] = bool(summary.get("complete")) and not summary.get("changed_sources_during_run") and not any(comp[key] for key in gates)
    original = output / "comparison-precomputed.json"
    if not original.exists():
        original.write_text(json.dumps(summary.get("comparison", {}), indent=2, ensure_ascii=False) + "\n")
    summary["comparison"] = comp
    file.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")
    (output / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n")
    (output / "comparison.json").write_text(json.dumps(comp, indent=2, ensure_ascii=False) + "\n")


def verify_index(output, allowed):
    staged = command(["git", "diff", "--cached", "--name-only"], True).splitlines()
    unexpected = [p for p in staged if not any(p == a or p.startswith(a.rstrip("/") + "/") for a in allowed)]
    if unexpected:
        raise RuntimeError(f"Unrelated staged changes: {unexpected}")
    sources = json.loads((output / "results.json").read_text())["source_after"]
    for path, digest in sources.items():
        # The audit also hashes local generated artifacts for stability. These
        # two ignored artifact types have no committed source blob.
        generated = generated_artifact(path)
        if generated and subprocess.run(["git", "check-ignore", "-q", "--", path], cwd=ROOT).returncode == 0:
            continue
        blob = subprocess.check_output(["git", "show", f":{path}"], cwd=ROOT)
        if hashlib.sha256(blob).hexdigest() != digest:
            raise RuntimeError(f"Index differs from tested source: {path}")


def push_record(record, records):
    if command(["git", "rev-parse", "HEAD"], True) != record["commit"]:
        raise RuntimeError("HEAD changed since verification commit; refusing an unverified push")
    remote = command(["git", "ls-remote", "origin", "refs/heads/main"], True).split()[0]
    if remote != record["commit"]:
        command(["git", "push", "origin", f"{record['commit']}:refs/heads/main"])
        remote = command(["git", "ls-remote", "origin", "refs/heads/main"], True).split()[0]
    if remote != record["commit"]:
        raise RuntimeError("Remote main differs from verified commit")
    record.update(pushed=True, remote_commit=remote, phase="pushed")
    write_ledger(records)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--start", default="B01")
    parser.add_argument("--only", help="Handle only this bug")
    parser.add_argument("--already-applied", nargs="*", default=[])
    parser.add_argument("--reuse-results", nargs="*", default=[])
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument("--timeout", type=int, default=600)
    parser.add_argument("--profile", choices=("all", "regression"), default="all")
    parser.add_argument("--output-suffix", default="")
    parser.add_argument("--final-all", action="store_true", help="After every planned repair is pushed, run and publish the full all profile")
    parser.add_argument("--wait-for-results", action="store_true", help="Wait for already-running cumulative-worktree suites before publication")
    args = parser.parse_args()
    if command(["git", "branch", "--show-current"], True) != "main":
        raise RuntimeError("Expected main branch")
    plan = json.loads(PLAN.read_text())
    records = json.loads(LEDGER.read_text()) if LEDGER.exists() else []
    for record in records:
        if not record.get("pushed") and record.get("commit"):
            entry = next(e for e in plan if e["id"] == record["id"])
            prior_cases = {c for e in plan if any(r["id"] == e["id"] and r.get("pushed") for r in records) for c in e["cases"]}
            verify(entry, AUDIT / record["output"], prior_cases, record["summary"]["profile"])
            push_record(record, records)
            print(f"FIX_PUSHED {record['id']} {record['commit']}", flush=True)
    done = {r["id"] for r in records if r.get("pushed")}
    fixed = {c for e in plan if e["id"] in done for c in e["cases"]}
    previous = AUDIT / records[-1]["output"] if records else AUDIT / "fixes/baseline"
    for entry in plan:
        bug = entry["id"]
        if bug < args.start or bug in done or args.only and args.only != bug:
            continue
        output = AUDIT / "fixes" / (bug + args.output_suffix)
        print(f"FIX_BEGIN {bug}: {entry['title']}", flush=True)
        pending = next((r for r in records if r["id"] == bug and not r.get("pushed")), None)
        if pending:
            output = AUDIT / pending["output"]
        paths = set()
        for patch in entry["patches"]:
            paths.update(command(["git", "show", "--format=", "--name-only", patch], True).splitlines())
            if bug not in args.already_applied and not pending:
                command(["git", "cherry-pick", "--no-commit", patch])
        command(["git", "diff", "--check", "--", "scripts", "tests", "tools"])
        if bug not in args.reuse_results and not pending:
            # Full-test exit 1 includes known baseline failures and remaining
            # audit bugs. The explicit comparison/required-case gates below
            # decide whether this individual repair is safe to publish.
            global ACTIVE
            ACTIVE = subprocess.Popen([sys.executable, str(ROOT / "tools/run_full_tests.py"),
                                       "--output", str(output), "--jobs", str(args.jobs),
                                       "--timeout", str(args.timeout), "--profile", args.profile,
                                       "--compare", str(previous)], cwd=ROOT)
            code = ACTIVE.wait()
            ACTIVE = None
            if code not in (0, 1):
                raise RuntimeError(f"Full test runner aborted: {code}")
        if bug in args.reuse_results or pending:
            deadline = time.monotonic() + args.timeout * 6
            while not (output / "results.json").exists():
                if not args.wait_for_results or time.monotonic() > deadline:
                    raise RuntimeError(f"Completed evidence is not available: {output}")
                time.sleep(1)
            recompare(output, previous)
        summary = verify(entry, output, fixed, args.profile)
        record = {"id": bug, "title": entry["title"], "prepared_patches": entry["patches"],
                  "output": str(output.relative_to(AUDIT)), "summary": summary,
                  "verified_at": datetime.datetime.now().astimezone().isoformat(), "pushed": False, "phase": "verified"}
        if pending:
            records.remove(pending)
        records.append(record)
        write_ledger(records)
        paths.update([str(output.relative_to(ROOT)), str(LEDGER.relative_to(ROOT)),
                      str((AUDIT / "FIXES.md").relative_to(ROOT)), str(PLAN.relative_to(ROOT)),
                      "tools/fix_exploration_bugs.py", "tools/run_full_tests.py"])
        command(["git", "add", "--", *sorted(paths)])
        verify_index(output, paths)
        body = f"Full repository test run: {len(json.loads((output / 'results.json').read_text())['regression'])} scripts and {summary['executed_audit_cases']} audit cases.\nRequired regressions and previously fixed PoCs passed; comparison reports no new failures.\nKnown baseline failures remain recorded: {summary['regression']}.\nEvidence: {output.relative_to(ROOT)}/results.json"
        command(["git", "commit", "--quiet", "-m", f"Fix {bug}: {entry['title']}", "-m", body])
        record["commit"] = command(["git", "rev-parse", "HEAD"], True)
        record["phase"] = "committed"
        write_ledger(records)
        verify(entry, output, fixed, args.profile)
        verify_index(output, paths)
        push_record(record, records)
        fixed.update(entry["cases"])
        previous = output
        print(f"FIX_PUSHED {bug} {record['commit']}", flush=True)
    if args.final_all:
        if {e["id"] for e in plan} != {r["id"] for r in records if r.get("pushed")}:
            raise RuntimeError("Final verification requires every planned repair to be pushed")
        output = AUDIT / "fixes" / "final-all"
        print("FINAL_ALL_BEGIN", flush=True)
        ACTIVE = subprocess.Popen([sys.executable, str(ROOT / "tools/run_full_tests.py"),
                                   "--output", str(output), "--jobs", str(args.jobs),
                                   "--timeout", str(args.timeout), "--profile", "all",
                                   "--compare", str(previous)], cwd=ROOT)
        code = ACTIVE.wait()
        ACTIVE = None
        if code not in (0, 1):
            raise RuntimeError(f"Final full test aborted: {code}")
        summary = verify(plan[-1], output, fixed, "all")
        if not summary.get("complete_all") or not summary.get("passed"):
            raise RuntimeError(f"Final all profile is not fully green: {summary}")
        write_ledger(records)
        final = AUDIT / "fixes/final-verification.json"
        final.write_text(json.dumps({"summary": summary, "verified_source_revision": command(["git", "rev-parse", "HEAD"], True)}, indent=2, ensure_ascii=False) + "\n")
        with (AUDIT / "FIXES.md").open("a") as report:
            report.write("\n最终 all 范围全部通过，含四种子平衡性实验。证据：[最终全量结果](fixes/final-all/results.json)。\n")
        paths = {str(output.relative_to(ROOT)), str(final.relative_to(ROOT)),
                 str(LEDGER.relative_to(ROOT)), str((AUDIT / "FIXES.md").relative_to(ROOT))}
        command(["git", "add", "--", *sorted(paths)])
        verify_index(output, paths)
        command(["git", "commit", "--quiet", "-m", "Record final full-suite verification and pushed repair milestones"])
        command(["git", "push", "origin", "HEAD:main"])
        if command(["git", "ls-remote", "origin", "refs/heads/main"], True).split()[0] != command(["git", "rev-parse", "HEAD"], True):
            raise RuntimeError("Final verification push could not be confirmed")
        print("FINAL_ALL_PUBLISHED", flush=True)
    print("REQUESTED_FIX_RUN_COMPLETE", flush=True)


if __name__ == "__main__":
    signal.signal(signal.SIGINT, cancel)
    signal.signal(signal.SIGTERM, cancel)
    try:
        main()
    except Exception as exc:
        print(f"FIX_SEQUENCE_STOPPED: {exc}", file=sys.stderr, flush=True)
        raise SystemExit(1)
