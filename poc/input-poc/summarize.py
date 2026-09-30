#!/usr/bin/env python3
"""Compare actual HID edges with session, AppKit and Godot delivery on one wall clock."""
import bisect
import json
import pathlib
import sys

folder = pathlib.Path(sys.argv[1])
def rows(name):
    result = []
    for line in (folder / name).read_text().splitlines():
        try:
            result.append(json.loads(line))
        except json.JSONDecodeError:
            pass  # Last line may still be being written by a running probe.
    return sorted(result, key=lambda r: r['t'])
native = rows('native.jsonl')
engine = rows('engine.jsonl')
hid_down, session_down, app_down, godot_down = [], [], [], []
old_h = old_s = 0
for row in native:
    if row['layer'] == 'quartz':
        if row['hid'] and not old_h:
            hid_down.append(row)
        if row['session'] and not old_s:
            session_down.append(row)
        old_h, old_s = row['hid'], row['session']
    elif row['layer'] == 'appkit' and row['type'] == 1:
        app_down.append(row)
for row in engine:
    if row['layer'] == 'godot' and row.get('button') == 1 and row.get('pressed'):
        godot_down.append(row)

def first_delay(events, start, end):
    hits = [r for r in events if start - .004 <= r['t'] < end]
    return '--' if not hits else f"{(hits[0]['t']-start)*1000:.1f}"
print('Physical press -> delivery (ms); -- means no matching press before next HID press / 2s')
print(' #     epoch             session   AppKit    Godot   max frame*  scheduler  HID/Session transitions')
for i, down in enumerate(hid_down):
    start = down['t']
    end = min(start + 2, hid_down[i+1]['t'] if i+1 < len(hid_down) else start+2)
    frames = [r['gap_ms'] for r in engine if r['layer'] == 'frame' and start <= r['t'] < min(end, start+.8)]
    transitions = []
    prev = None
    for r in native:
        if r['layer'] != 'quartz' or not start <= r['t'] < min(end,start+.8):
            continue
        state = (r['hid'], r['session'])
        if state != prev:
            transitions.append(f"{(r['t']-start)*1000:.0f}:{state[0]}/{state[1]}")
            prev = state
    modes = [r for r in engine if r['layer'] == 'scheduler_mode' and r['t'] <= start]
    mode = ('original' if modes[-1]['original'] else 'patched') if modes else '--'
    print(f"{i+1:2d} {start:.6f} {first_delay(session_down,start,end):>9} {first_delay(app_down,start,end):>9} {first_delay(godot_down,start,end):>8} {max(frames,default=0):>10.1f}  {mode:>9}  {' '.join(transitions)}")
print('* frame gap during first 800ms; HID/session polling every ~2ms. Physical press includes clicks outside the POC.')
