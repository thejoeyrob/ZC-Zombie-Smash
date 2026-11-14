#!/usr/bin/env bash
# Finds out why the picture is fuzzy on the headset. Run it on a computer with adb, with the headset plugged in (or on wireless adb) and developer mode on.
#   bash diagnose-picture.sh            read only: shows what is overridden and what the game drew
#   bash diagnose-picture.sh --reset    also clears every debug.oculus.* override (what Quest Games Optimiser and similar tools set) and restarts the game
# Send the whole output back.
PKG=com.thejoeyrob.fattysgameshack
ADB=${ADB:-adb}
command -v "$ADB" >/dev/null 2>&1 || { echo "adb not found. Install Android platform-tools, or run this in the terminal that has adb."; exit 1; }
"$ADB" get-state >/dev/null 2>&1 || { echo "No headset found. Plug it in, put it on, and accept the 'Allow USB debugging' prompt; then run again."; "$ADB" devices; exit 1; }
sec() { printf '\n==== %s ====\n' "$1"; }

sec "Headset"
for p in ro.product.model ro.product.device ro.product.name ro.build.version.release ro.build.version.incremental; do printf '%-34s %s\n' "$p" "$("$ADB" shell getprop $p | tr -d '\r')"; done

sec "Overrides set on the headset (debug.oculus.*, these are what tools like Quest Games Optimiser change for every app)"
"$ADB" shell getprop | tr -d '\r' | grep -i -E '^\[debug\.oculus\.|^\[persist\.oculus\.|^\[debug\.ovr|^\[debug\.vr' | sort || true
echo "(a blank list means nothing is overridden. Look for textureWidth / textureHeight (picture size), foveation.level (edges drawn softer), refreshRate, cpuLevel, gpuLevel.)"

sec "The game"
"$ADB" shell dumpsys package "$PKG" 2>/dev/null | tr -d '\r' | grep -E 'versionCode|versionName|firstInstallTime|lastUpdateTime' | head -4
if ! "$ADB" shell pm list packages 2>/dev/null | tr -d '\r' | grep -q "$PKG"; then echo "The game ($PKG) is not installed on this headset."; fi

sec "What the game decided to draw (from its own log; start the game once after this runs if it is empty)"
"$ADB" logcat -d 2>/dev/null | tr -d '\r' | grep -E 'PICTURE eye=|HEADSET OVERRIDES|Refresh rate set|OpenXR is running' | tail -12
echo "(eye= is the size drawn per eye; multiplier 1.00 means the game adds nothing; headset_owns=true means a tool has taken over the picture size and the game stands down.)"

sec "Display the system reports"
"$ADB" shell dumpsys display 2>/dev/null | tr -d '\r' | grep -i -E 'mode ?id|fps=|refreshRate|renderFrameRate' | head -8

if [ "$1" = "--reset" ]; then
  sec "Clearing overrides"
  for k in $("$ADB" shell getprop | tr -d '\r' | grep -E '^\[debug\.oculus\.' | sed -E 's/^\[([^]]+)\].*/\1/'); do
    echo "clear $k"; "$ADB" shell setprop "$k" "" 2>/dev/null
  done
  "$ADB" shell am force-stop "$PKG"
  echo "Done. Start the game again and run this script once more (without --reset) to see what it draws now."
fi
echo
echo "Finished. If the picture is clear after --reset, the fault was an override listed above."
