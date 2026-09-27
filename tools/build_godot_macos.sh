#!/bin/bash
# Reproducible local runtime for the macOS input fix. Does not replace installed Godot.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_COMMIT=ed1daf0bf001b61586d9930840f2f1394092c079
SOURCE_DIR="$PWD/docs/godot"
FIX_PATCH="$PWD/patches/godot-4.7.2-macos-frame-wait.patch"
POC_PATCH="$PWD/docs/input-poc/godot-frame-wait.patch"
if [[ "$(uname -s)" != Darwin ]]; then
  printf 'This runtime build targets macOS.\n' >&2
  exit 1
fi
if [[ ! -d "$SOURCE_DIR/.git" ]]; then
  git clone --depth 1 --branch 4.7.2-stable https://github.com/godotengine/godot.git "$SOURCE_DIR"
fi
if [[ "$(git -C "$SOURCE_DIR" rev-parse HEAD)" != "$GODOT_COMMIT" ]]; then
  printf 'Unexpected Godot revision; expected %s. Refusing to change this checkout.\n' "$GODOT_COMMIT" >&2
  exit 1
fi
touch "$SOURCE_DIR/.gdignore"
if ! git -C "$SOURCE_DIR" apply --reverse --check "$FIX_PATCH" 2>/dev/null; then
  if git -C "$SOURCE_DIR" apply --reverse --check "$POC_PATCH" 2>/dev/null; then
    git -C "$SOURCE_DIR" apply --reverse "$POC_PATCH"
  fi
  git -C "$SOURCE_DIR" apply --check "$FIX_PATCH"
  git -C "$SOURCE_DIR" apply "$FIX_PATCH"
fi
if [[ -z "${SCONS_BIN:-}" ]]; then
  if command -v scons >/dev/null; then
    SCONS_BIN="$(command -v scons)"
  else
    BUILD_ENV="$SOURCE_DIR/.build-venv"
    if [[ ! -x "$BUILD_ENV/bin/scons" ]]; then
      python3 -m venv "$BUILD_ENV"
      "$BUILD_ENV/bin/pip" install scons==4.11.1
    fi
    SCONS_BIN="$BUILD_ENV/bin/scons"
  fi
fi
GODOT_ARCH="$(uname -m)"
exec "$SCONS_BIN" -C "$SOURCE_DIR" \
  platform=macos arch="$GODOT_ARCH" target=template_debug disable_path_overrides=no \
  optimize=size debug_symbols=no lto=none disable_3d=yes vulkan=no metal=no use_sdl=no \
  accesskit=no angle=no modules_enabled_by_default=no module_gdscript_enabled=yes \
  module_noise_enabled=yes module_godot_physics_2d_enabled=yes module_text_server_adv_enabled=yes \
  module_freetype_enabled=yes module_svg_enabled=yes module_regex_enabled=yes \
  -j"${BUILD_JOBS:-6}" "$@"
