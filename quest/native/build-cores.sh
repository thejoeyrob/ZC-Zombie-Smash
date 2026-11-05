#!/usr/bin/env bash
# Builds the open-source emulator cores (libretro) as shared libraries for the headset (android) or this computer (linux).
#   build-cores.sh android    (needs ANDROID_NDK_ROOT)  -> quest/bin/cores/lib<name>_libretro.so  (arm64)
#   build-cores.sh linux                                -> same names, built for the desktop (for tests)
# A core that fails to build is skipped, so one problem never loses the others. Licences: see docs/EMULATOR.md.
set -uo pipefail
PLATFORM="${1:-android}"
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$HERE/_work/cores"
OUT="$HERE/../bin/cores"
mkdir -p "$WORK" "$OUT"
# name | repository | exact commit (pinned: the build never follows a moving branch)
CORES=(
  "fceumm|https://github.com/libretro/libretro-fceumm|e0f3086a8104f8fbbe49a2615b10401504a9533f"
  "snes9x2010|https://github.com/libretro/snes9x2010|fe690dd321fa5a46b5234a2bde089d2518c62b0e"
  "genesis_plus_gx|https://github.com/libretro/Genesis-Plus-GX|f27655b592ef43f317272d79883bcaa10d3ac8ad"
  "gambatte|https://github.com/libretro/gambatte-libretro|77f2567d718b8973d02caa2daa8dce4953faf811"
)
built=0
for entry in "${CORES[@]}"; do
  IFS='|' read -r name repo ref <<< "$entry"
  echo "=== $name"
  dir="$WORK/$name"
  if [ ! -d "$dir" ]; then
    mkdir -p "$dir" && git -C "$dir" init -q && git -C "$dir" fetch -q --depth 1 "$repo" "$ref" && git -C "$dir" checkout -q FETCH_HEAD || { echo "fetch failed for $name"; rm -rf "$dir"; continue; }
    git -C "$dir" submodule update --init --depth 1 -q 2>/dev/null || true
  fi
  ok=0
  if [ "$PLATFORM" = "android" ]; then
    mk="$(grep -rl --include=Android.mk -E 'LOCAL_MODULE[[:space:]]*:?=[[:space:]]*retro[[:space:]]*$' "$dir" | head -1)"
    if [ -z "$mk" ]; then echo "no Android.mk for $name"; continue; fi
    jni="$(dirname "$mk")"
    proj="$(dirname "$jni")"
    app_mk=""
    [ -f "$jni/Application.mk" ] && app_mk="NDK_APPLICATION_MK=$jni/Application.mk"
    ( cd "$proj" && "$ANDROID_NDK_ROOT/ndk-build" -j"$(nproc)" NDK_PROJECT_PATH="$proj" APP_BUILD_SCRIPT="$mk" $app_mk APP_ABI=arm64-v8a APP_PLATFORM=android-29 ) > "$WORK/$name.log" 2>&1 && ok=1
    if [ $ok = 1 ]; then
      so="$(find "$proj" -path '*arm64-v8a*' -name 'libretro.so' | head -1)"
      [ -n "$so" ] && cp "$so" "$OUT/lib${name}_libretro.so" || ok=0
    fi
  else
    mf="$(find "$dir" -maxdepth 2 -name 'Makefile.libretro' | head -1)"
    [ -z "$mf" ] && mf="$(find "$dir" -maxdepth 2 -name 'Makefile' | head -1)"
    ( cd "$(dirname "$mf")" && make -f "$(basename "$mf")" -j"$(nproc)" platform=unix ) > "$WORK/$name.log" 2>&1 && ok=1
    if [ $ok = 1 ]; then
      so="$(find "$dir" -name '*_libretro.so' | head -1)"
      [ -n "$so" ] && cp "$so" "$OUT/lib${name}_libretro.so" || ok=0
    fi
  fi
  if [ $ok = 1 ]; then built=$((built+1)); echo "built $name"; else echo "FAILED $name (last lines of its log:)"; tail -15 "$WORK/$name.log"; fi
done
echo "cores built: $built"
ls -la "$OUT"
