#!/usr/bin/env python3
"""Serial repeatable dragging during the real six-building siege (headless by default).

A synthetic OS pointer drives the production macOS selection state machine.
Records polling stalls, preceding frame/search costs and queue work separately.
Use --windowed for actual frame_post_draw intervals; neither mode measures the
physical mouse-to-display latency or macOS input delivery itself.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def fingerprint(project):
    digest = hashlib.sha256()
    files = [project / 'project.godot', project / 'tests/selection_battle_latency_poc.gd', project / 'tools/battle_deer_poc.gd']
    files += list((project / 'scripts').rglob('*.gd')) + list((project / 'data').rglob('*.json'))
    for path in sorted(files):
        digest.update(str(path.relative_to(project)).encode())
        digest.update(path.read_bytes())
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', type=Path, default=ROOT / 'docs/godot/bin/godot.macos.template_debug.arm64')
    parser.add_argument('--project', type=Path, default=ROOT, help='Use an isolated project copy for stable comparisons')
    parser.add_argument('--baseline', type=Path, help='Compare two code versions with background recovery enabled in both')
    parser.add_argument('--seconds', type=float, default=12)
    parser.add_argument('--rounds', type=int, default=2)
    parser.add_argument('--windowed', action='store_true')
    parser.add_argument('--output', type=Path, default=ROOT / '.godot/selection-latency')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    modes = [] if args.baseline else [(args.project, True, True, 'current')]
    for repeat in range(args.rounds):
        if args.baseline:
            versions = [('before', args.baseline), ('after', args.project)]
            if repeat % 2: versions.reverse()
            modes.extend((project, True, False, label) for label, project in versions)
        else:
            modes.extend((args.project, mode, False, 'current') for mode in ([False, True] if repeat % 2 == 0 else [True, False]))
    reports = []
    fingerprints = {project: fingerprint(project) for project, _, _, _ in modes}
    for index, (project, enabled, idle, label) in enumerate(modes):
        source_fingerprint = fingerprints[project]
        if fingerprint(project) != source_fingerprint:
            raise RuntimeError('Project changed during A/B; use an isolated project copy')
        name = f'{index}-{label}-{"idle" if idle else "siege"}-{"async" if enabled else "sync"}'
        env = {k: v for k, v in os.environ.items() if not k.startswith(('RTS_POC_', 'RTS_DRAG_'))}
        env.update(RTS_ASYNC_NAV=str(int(enabled)), RTS_NAV_PROFILE='0', RTS_DRAG_IDLE=str(int(idle)), RTS_DRAG_SECONDS=str(args.seconds))
        command = [str(args.godot.resolve()), '--path', str(project.resolve()), '--log-file', str((args.output / f'{name}.engine.log').resolve()), '--script', 'res://tests/selection_battle_latency_poc.gd']
        command += ['--windowed', '--resolution', '1280x800'] if args.windowed else ['--headless']
        try:
            run = subprocess.run(command, env=env, capture_output=True, text=True, timeout=args.seconds + 30)
        except subprocess.TimeoutExpired as exc:
            text = exc.stdout or b''
            if isinstance(text, bytes):
                text = text.decode(errors='replace')
            (args.output / f'{name}.log').write_text(text + '\nTIMEOUT\n')
            raise RuntimeError(f'Timeout: {name}; log saved') from exc
        text = run.stdout + run.stderr
        (args.output / f'{name}.log').write_text(text)
        results = [json.loads(line.removeprefix('SELECTION_LATENCY_PROFILE ')) for line in text.splitlines() if line.startswith('SELECTION_LATENCY_PROFILE ')]
        if run.returncode or 'ERROR:' in text or len(results) != 1 or 'SELECTION_BATTLE_LATENCY_POC_OK' not in text:
            raise RuntimeError(f'Invalid PoC: {name}; log saved')
        if fingerprint(project) != source_fingerprint:
            raise RuntimeError('Project changed during a run; result rejected, log saved')
        report = results[0]
        report['source_fingerprint'] = source_fingerprint
        report['version'] = label
        if args.windowed and report['render_samples'] == 0:
            raise RuntimeError('Windowed run produced no rendered frames')
        report['run'] = name
        reports.append(report)
        (args.output / 'results.json').write_text(json.dumps(reports, indent=2) + '\n')
        timing = report['timings']
        print(f'{name}: poll gap p95={timing["poll_gap_ms"]["p95"]:.2f} max={timing["poll_gap_ms"]["max"]:.2f} ms; queue max={timing["queue_ms"]["max"]:.2f} ms; >40 ms gaps={len(report["slow_polls"])}; mismatches={report["overlay_mismatches"]}', flush=True)


if __name__ == '__main__':
    main()
