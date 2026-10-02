"""Record available regressions without certifying a blocked native suite."""
import argparse
import importlib.util
import json
import sys
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__, add_help=False)
parser.add_argument('--project', type=Path, required=True)
parser.add_argument('--native-blocker-evidence', type=Path, required=True)
args, remaining = parser.parse_known_args()
root = args.project.resolve()
blocker = args.native_blocker_evidence.resolve()
record = json.loads(blocker.read_text())
if record.get('status') not in ('timeout', 'failed') or not record.get('rendering'):
    parser.error('Native evidence must be a real failed renderer launch probe')
sys.argv = [sys.argv[0], *remaining]
spec = importlib.util.spec_from_file_location('suite', root / 'tools/run_full_tests.py')
suite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(suite)
original_execute = suite.execute
native_evidence = str(blocker)

def execute_available(engine, script, name, output, timeout, case_ids=None, rendering=False):
    if rendering:
        record = suite.cancelled_record(script, name, timeout, True)
        record.update(status='skipped', reason='native_window_startup_unavailable',
                      environment_blocker_evidence=native_evidence,
                      note='Not run: platform launch probe timed out before Godot startup. No prior game result reused.')
        return suite.publish(record, output)
    return original_execute(engine, script, name, output, timeout, case_ids, rendering)

suite.execute = execute_available
raise SystemExit(suite.main())
