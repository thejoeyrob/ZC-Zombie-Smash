#!/usr/bin/env bash
# Writes quest/bin/retro.gdextension listing the plug-in and every core that was built, so each one is packed into the app.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="$HERE/../bin"
{
  echo '[configuration]'
  echo 'entry_symbol = "retro_library_init"'
  echo 'compatibility_minimum = "4.4"'
  echo
  echo '[libraries]'
  echo 'linux.x86_64 = "res://bin/libretro_frontend.linux.template_release.x86_64.so"'
  echo 'android.arm64 = "res://bin/libretro_frontend.android.template_release.arm64.so"'
  echo
  echo '[dependencies]'
  printf 'android.arm64 = {\n'
  first=1
  for f in "$BIN"/cores/lib*_libretro.so; do
    [ -e "$f" ] || continue
    [ $first = 1 ] || printf ',\n'
    first=0
    printf '"res://bin/cores/%s": ""' "$(basename "$f")"
  done
  printf '\n}\n'
} > "$BIN/retro.gdextension"
cat "$BIN/retro.gdextension"
