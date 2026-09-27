#!/bin/bash
# Build the local engine POC. Requires the matching source checkout and SCons.
set -euo pipefail
cd "$(dirname "$0")/../.."
SCONS_BIN="${SCONS_BIN:-scons}"
SOURCE_DIR="$PWD/docs/godot"
POC_PATCH="$PWD/docs/input-poc/godot-frame-wait.patch"
FIX_PATCH="$PWD/patches/godot-4.7.2-macos-frame-wait.patch"
if ! git -C "$SOURCE_DIR" apply --reverse --check "$POC_PATCH" 2>/dev/null; then
  if git -C "$SOURCE_DIR" apply --reverse --check "$FIX_PATCH" 2>/dev/null; then
    git -C "$SOURCE_DIR" apply --reverse "$FIX_PATCH"
  fi
  git -C "$SOURCE_DIR" apply --check "$POC_PATCH"
  git -C "$SOURCE_DIR" apply "$POC_PATCH"
fi
exec "$SCONS_BIN" -C docs/godot \
  platform=macos arch=arm64 target=template_debug disable_path_overrides=no extra_suffix=input_poc \
  optimize=size debug_symbols=no lto=none disable_3d=yes vulkan=no metal=no use_sdl=no \
  modules_enabled_by_default=no module_gdscript_enabled=yes module_noise_enabled=yes \
  module_text_server_adv_enabled=yes module_freetype_enabled=yes module_svg_enabled=yes \
  module_regex_enabled=yes -j"${BUILD_JOBS:-6}" "$@"
