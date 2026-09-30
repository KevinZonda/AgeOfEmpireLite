#!/bin/bash
# Use an ordinary editor, keeping the existing installed Mono editor intact.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -z "${GODOT_EDITOR:-}" ]]; then
  if [[ "$(uname -s)" != Darwin ]]; then
    printf 'Set GODOT_EDITOR to the Godot 4.7.2 non-.NET editor executable.\n' >&2
    exit 1
  fi
  CACHE_DIR="$PWD/.godot/tools/web-export"
  GODOT_EDITOR="$CACHE_DIR/Godot.app/Contents/MacOS/Godot"
  if [[ ! -x "$GODOT_EDITOR" ]]; then
    mkdir -p "$CACHE_DIR"
    ARCHIVE="$CACHE_DIR/Godot_v4.7.2-stable_macos.universal.zip"
    curl -fL --retry 2 \
      https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_macos.universal.zip \
      -o "$ARCHIVE"
    python3 - "$ARCHIVE" "$CACHE_DIR" <<'PY'
import sys
import hashlib
import zipfile
with open(sys.argv[1], "rb") as downloaded:
    digest = hashlib.sha256()
    for chunk in iter(lambda: downloaded.read(1024 * 1024), b""):
        digest.update(chunk)
if digest.hexdigest() != "c58a24e31d720be9d62f60cb5627c4e695fb72f21b0cfe1bc9ccaa9a3b3ba63e":
    raise SystemExit("Godot editor download failed SHA-256 verification")
with zipfile.ZipFile(sys.argv[1]) as archive:
    archive.extractall(sys.argv[2])
PY
    chmod +x "$GODOT_EDITOR"
  fi
fi
EDITOR_VERSION="$("$GODOT_EDITOR" --version)"
if [[ "$EDITOR_VERSION" != 4.7.2.stable.* || "$EDITOR_VERSION" == *mono* ]]; then
  printf 'Web export requires a non-.NET Godot 4.7.2 editor, got: %s\n' "$EDITOR_VERSION" >&2
  exit 1
fi
if [[ ! -f docs/godot/bin/godot.web.template_release.wasm32.zip ]]; then
  printf 'Web template missing. Run make build-web first.\n' >&2
  exit 1
fi
mkdir -p build/web
touch build/.gdignore
"$GODOT_EDITOR" --headless --editor --path "$PWD" --import
"$GODOT_EDITOR" --headless --path "$PWD" --export-release Web "$PWD/build/web/index.html"
printf '\nWeb export: %s/build/web/index.html\nPreview with: make serve-web\n' "$PWD"
