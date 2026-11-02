#!/usr/bin/env bash
# Builds the browser version of the VR arcade into <out>/ (a plain static site). Needs godot on the PATH and the Godot web export templates.
# Usage: tools/build-web.sh <quest dir> <out dir>
set -euo pipefail
Q="$(cd "$1" && pwd)"
OUT="$2"
W=/tmp/webproj
python3 "$Q/tools/web-prepare.py" "$Q" "$W"
cp "$Q/export_presets.cfg" "$W/export_presets.cfg"
# in the light copy the heavy files are already gone, so only the add-ons need excluding
sed -i 's#^exclude_filter=.*assets/audio/mus-.*#exclude_filter="addons/*"#' "$W/export_presets.cfg"
cd "$W"
godot --headless --path . --import || true
mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html 2>&1 | grep -iE "^ERROR|SCRIPT ERROR" | head -10 || true
test -s build/web/index.pck
rm -rf "$OUT"; mkdir -p "$OUT"
cp build/web/* "$OUT/"
echo "web build: $(du -sh "$OUT" | cut -f1)"
