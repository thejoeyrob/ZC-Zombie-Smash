#!/usr/bin/env python3
"""Supplementary packaging check. Meta Dashboard and headset VRC remain required."""
import re,sys,zipfile
from pathlib import Path
apk,badging,manifest=map(Path,sys.argv[1:])
b=badging.read_text();m=manifest.read_text();errors=[]
if "name='com.thejoeyrob.fattysgameshack'" not in b:errors.append('Unexpected package identity')
if 'application-debuggable' in b or re.search(r'android:debuggable.*0xffffffff',m):errors.append('Debuggable APK')
if "native-code: 'arm64-v8a'" not in b:errors.append('Expected ARM64 only')
version=re.search(r"versionCode='(\d+)'",b)
if not version or int(version[1])<=105:errors.append('Version code must exceed baseline105 (also check latest Dashboard version)')
with zipfile.ZipFile(apk) as z:
 names=z.namelist()
 if any('libretro' in p.lower() for p in names):errors.append('Emulator native code in store candidate')
 if not any('lib/arm64-v8a/' in p for p in names):errors.append('ARM64 libraries missing')
if 'android.permission.INTERNET' not in m:errors.append('Multiplayer INTERNET permission missing')
if errors:raise SystemExit('\n'.join(errors))
print('APK package checks PASS; signature is checked separately by apksigner. This is not store approval.')
