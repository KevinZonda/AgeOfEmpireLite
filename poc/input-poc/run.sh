#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT_BIN="${GODOT_BIN:-/Applications/Godot_mono.app/Contents/MacOS/Godot}"
TRACE_DIR="${TRACE_DIR:-/tmp/aoe-input-poc-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$TRACE_DIR"
xcrun clang -dynamiclib -fobjc-arc -framework Cocoa -framework ApplicationServices poc/input-poc/native_probe.m -o "$TRACE_DIR/native_probe.dylib"
printf 'Trace directory: %s\n' "$TRACE_DIR"
export AOE_NATIVE_TRACE="$TRACE_DIR/native.jsonl"
export AOE_ENGINE_TRACE="$TRACE_DIR/engine.jsonl"
export DYLD_INSERT_LIBRARIES="$TRACE_DIR/native_probe.dylib"
exec "$GODOT_BIN" --path "$PWD" --script res://poc/input-poc/probe.gd -- "$@"
