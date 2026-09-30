#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
export GODOT_BIN="${GODOT_BIN:-$PWD/docs/godot/bin/godot.macos.template_debug.$(uname -m)}"
export TRACE_DIR="${TRACE_DIR:-/tmp/aoe-right-click-poc-$(date +%Y%m%d-%H%M%S)}"
exec poc/input-poc/run.sh --right-click "$@"
