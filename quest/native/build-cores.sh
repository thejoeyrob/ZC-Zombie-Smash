#!/usr/bin/env bash
# Fatty's Game Shack: fail-closed libretro build for Android and Linux.
# Source pinned at the same commits as the quest-build baseline.
set -uo pipefail
PLATFORM="${1:-android}"
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$HERE/_work/cores"
OUT="$HERE/../bin/cores"
mkdir -p "$WORK" "$OUT"
CORES=(
  'fceumm|https://github.com/libretro/libretro-fceumm|e0f3086a8104f8fbbe49a2615b10401504a9533f'
  'snes9x2010|https://github.com/libretro/snes9x2010|fe690dd321fa5a46b5234a2bde089d2518c62b0e'
  'genesis_plus_gx|https://github.com/libretro/Genesis-Plus-GX|f27655b592ef43f317272d79883bcaa10d3ac8ad'
  'gambatte|https://github.com/libretro/gambatte-libretro|77f2567d718b8973d02caa2daa8dce4953faf811'
  'stella2014|https://github.com/libretro/stella2014-libretro|7d1361e407e63f29e52892655069e5fb4096e691'
  'gpsp|https://github.com/libretro/gpsp|5819380c2ffb0900219d700a382ee68c464ebb99'
  'mednafen_pce_fast|https://github.com/libretro/beetle-pce-fast-libretro|2de1ce1c3f237b161c126c54ba407990bb86d1e9'
  'prosystem|https://github.com/libretro/prosystem-libretro|8a88014287c7a01cd568067e5a557d0a2b2a051f'
  'handy|https://github.com/libretro/libretro-handy|bc55d462f0b2d6b073cec60fd1'
)
if [[ "$PLATFORM" == android && ! -x "${ANDROID_NDK_ROOT:-}/ndk-build" ]]; then
  echo 'ERROR: ANDROID_NDK_ROOT/ndk-build is unavailable' >&2
  exit 1
fi
# Avoid packaging stale cores from an earlier compile.
rm -f "$OUT"/lib*_libretro.so
built=0
failed=()
for entry in "${CORES[@]}"; do
  IFS='|' read -r name repo ref <<< "$entry"
  dir="$WORK/$name"
  log="$WORK/$name.log"
  echo "---- $name at $ref ----"
  if [[ ! -d "$dir/.git" ]]; then
    mkdir -p "$dir"
    git -C "$dir" init -q || { failed+=("$name:init"); continue; }
  fi
  if ! git -C "$dir" rev-parse --verify "$ref^{commit}" >/dev/null 2>&1; then
    git -C "$dir" fetch -q --depth 1 "$repo" "$ref" || { failed+=("$name:fetch"); continue; }
  fi
  git -C "$dir" checkout -q "$ref" || { failed+=("$name:checkout"); continue; }
  git -C "$dir" submodule update --init --depth 1 -q 2>/dev/null || true
  ok=0
  if [[ "$PLATFORM" == android ]]; then
    # Different libretro projects use different LOCAL_MODULE values. Never require the literal name 'retro'.
    mk="$(find "$dir" -name Android.mk -not -path '*/obj/*' -print -quit)"
    if [[ -z "$mk" ]]; then
      echo "ERROR $name: no Android.mk" | tee "$log"
      failed+=("$name:missing-Android.mk")
      continue
    fi
    jni="$(dirname "$mk")"
    proj="$(dirname "$jni")"
    cmd=("$ANDROID_NDK_ROOT/ndk-build" -j"$(nproc)" "NDK_PROJECT_PATH=$proj" "APP_BUILD_SCRIPT=$mk" "APP_ABI=arm64-v8a" "APP_PLATFORM=android-29")
    [[ -f "$jni/Application.mk" ]] && cmd+=("NDK_APPLICATION_MK=$jni/Application.mk")
    (cd "$proj" && "${cmd[@]}") >"$log" 2>&1 && ok=1
    if [[ $ok == 1 ]]; then
      so="$(find "$dir" -type f \( -name '*_libretro.so' -o -name 'libretro.so' \) -path '*arm64-v8a*' -print -quit)"
      [[ -n "$so" && -s "$so" ]] && cp "$so" "$OUT/lib${name}_libretro.so" || ok=0
    fi
  else
    mf="$(find "$dir" -maxdepth 3 -name Makefile.libretro -print -quit)"
    [[ -z "$mf" ]] && mf="$(find "$dir" -maxdepth 3 -name Makefile -print -quit)"
    if [[ -z "$mf" ]]; then
      echo "ERROR $name: no Makefile" | tee "$log"
      failed+=("$name:missing-Makefile")
      continue
    fi
    (cd "$(dirname "$mf")" && make -f "$(basename "$mf")" -j"$(nproc)" platform=unix) >"$log" 2>&1 && ok=1
    if [[ $ok == 1 ]]; then
      so="$(find "$dir" -type f -name '*_libretro.so' -print -quit)"
      [[ -n "$so" && -s "$so" ]] && cp "$so" "$OUT/lib${name}_libretro.so" || ok=0
    fi
  fi
  if [[ $ok == 1 ]]; then
    built=$((built + 1))
    echo "SUCCESS $name"
  else
    echo "FAILED $name" >&2
    tail -20 "$log" 2>/dev/null || true
    failed+=("$name:build")
  fi
done
echo "libretro: $built/${#CORES[@]} built; failed: ${failed[*]:-(none)}"
# NES is the minimum viable working emulator. Never call a zero-core build a success.
if [[ $built -eq 0 || ! -s "$OUT/libfceumm_libretro.so" ]]; then
  echo 'FATAL: required NES emulator missing; do not release an emulator-enabled APK' >&2
  exit 1
fi
