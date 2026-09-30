#!/bin/bash
# Build a threaded, GDScript-only Web release template from the pinned engine.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_COMMIT=ed1daf0bf001b61586d9930840f2f1394092c079
SOURCE_DIR="$PWD/docs/godot"
if ! command -v emcc >/dev/null; then
  printf 'Emscripten is required. Install/activate emsdk, or on macOS: brew install emscripten\n' >&2
  exit 1
fi
if [[ ! -d "$SOURCE_DIR/.git" ]]; then
  git clone --depth 1 --branch 4.7.2-stable https://github.com/godotengine/godot.git "$SOURCE_DIR"
fi
if [[ "$(git -C "$SOURCE_DIR" rev-parse HEAD)" != "$GODOT_COMMIT" ]]; then
  printf 'Unexpected Godot revision; expected %s. Refusing to build.\n' "$GODOT_COMMIT" >&2
  exit 1
fi
touch "$SOURCE_DIR/.gdignore"
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
exec "$SCONS_BIN" -C "$SOURCE_DIR" \
  platform=web target=template_release module_mono_enabled=no threads=yes \
  optimize=size debug_symbols=no lto=none disable_3d=yes \
  modules_enabled_by_default=no module_gdscript_enabled=yes \
  module_noise_enabled=yes module_godot_physics_2d_enabled=yes module_text_server_adv_enabled=yes \
  module_freetype_enabled=yes module_svg_enabled=yes module_regex_enabled=yes module_webp_enabled=yes \
  -j"${BUILD_JOBS:-6}" "$@"
