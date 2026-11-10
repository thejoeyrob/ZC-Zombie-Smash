#!/usr/bin/env python3
"""Assert that a release APK includes the android-arm64 GDExtension and NES core.

Usage: python3 quest/tools/check-emulator-apk.py quest/build/zombie-smash-vr.apk
The check stops the CI pipeline before it uploads a misleading emulator build.
"""
import sys
import zipfile
from pathlib import Path

def audit(apk: Path) -> list[str]:
    with zipfile.ZipFile(apk) as z:
        names = z.namelist()
    # The native dependencies must be in the APK's arm64 lib directory, not merely a .gdextension descriptor in assets.
    native = [p for p in names if p.startswith('lib/arm64-v8a/') and p.endswith('.so')]
    failures = []
    if not any('retro_frontend' in p for p in native):
        failures.append('libretro_frontend.so GDExtension missing from lib/arm64-v8a')
    if not any('libfceumm_libretro.so' in p for p in native):
        failures.append('required libfceumm_libretro.so missing from lib/arm64-v8a')
    print('APK native libretro libraries:')
    for path in native:
        if 'retro' in path:
            print(' ', path)
    return failures

if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit('usage: check-emulator-apk.py path/to/build.apk')
    path = Path(sys.argv[1])
    if not path.is_file():
        sys.exit(f'APK not found: {path}')
    failures = audit(path)
    if failures:
        for message in failures:
            print('ERROR:', message, file=sys.stderr)
        sys.exit(1)
    print('PASS: Emulator native binaries present. Runtime loading still needs headset QA.')
