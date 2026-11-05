#!/usr/bin/env bash
# Builds the libretro frontend plug-in (native/retro) with godot-cpp.
#   build-native.sh android   (needs ANDROID_NDK_ROOT)  -> quest/bin/libretro_frontend.android.template_release.arm64.so
#   build-native.sh linux                               -> quest/bin/libretro_frontend.linux.template_release.x86_64.so  (for desktop tests)
set -euo pipefail
PLATFORM="${1:-android}"
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$HERE/_work"
OUT="$HERE/../bin"
mkdir -p "$WORK" "$OUT" "$HERE/retro/include"
if [ ! -d "$WORK/godot-cpp" ]; then
  # pinned to an exact commit of godot-cpp's 4.4 branch
  mkdir -p "$WORK/godot-cpp" && git -C "$WORK/godot-cpp" init -q
  git -C "$WORK/godot-cpp" fetch -q --depth 1 https://github.com/godotengine/godot-cpp b0e3b1e4b78a606f48d162898afb5eeda533d2a9
  git -C "$WORK/godot-cpp" checkout -q FETCH_HEAD
fi
if [ ! -f "$HERE/retro/include/libretro.h" ]; then
  curl -fsSL -o "$HERE/retro/include/libretro.h" https://raw.githubusercontent.com/libretro/libretro-common/d9597c359a5ca8399a4e244f816e7e975a92a2aa/include/libretro.h
fi
python3 -m pip install -q scons >/dev/null 2>&1 || true
cd "$HERE/retro"
ARCH=$([ "$PLATFORM" = "android" ] && echo arm64 || echo x86_64)
GODOT_CPP_DIR="$WORK/godot-cpp" scons platform="$PLATFORM" arch="$ARCH" target=template_release -j"$(nproc)"
cp bin/libretro_frontend.*.so "$OUT/"
ls -la "$OUT"
