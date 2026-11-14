#!/usr/bin/env bash
# Live picture report. Run this on the computer with adb while you play. It writes picture-report-<date>-<time>.txt in the folder you run it from.
#   1. Plug in the headset (USB debugging on), run:  bash watch-picture.sh
#   2. Put the headset on and play as normal.
#   3. When the picture looks GOOD hold A+X (both hands) for half a second; when it looks BAD hold B+Y. The controllers buzz once.
#      (Or press g / b on this keyboard, then note the time. q ends the report.)
#   4. Send the report file back with a note of what you saw and when.
# It records, with the time of day: what the game says it is drawing each second (PERF lines), every change in picture size, edge detail or refresh rate,
# every time the headset takes focus off the game, and every change to the headset's own settings (what Quest Games Optimiser writes).
PKG=com.thejoeyrob.fattysgameshack
ADB=${ADB:-adb}
command -v "$ADB" >/dev/null 2>&1 || { echo "adb not found. Run this in the terminal that has adb."; exit 1; }
"$ADB" get-state >/dev/null 2>&1 || { echo "No headset found. Plug it in and accept the USB debugging prompt."; exit 1; }
OUT="picture-report-$(date +%Y%m%d-%H%M%S).txt"
RAW="$(mktemp)"
log() { printf '%s %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "$OUT"; }
props() { "$ADB" shell getprop 2>/dev/null | tr -d '\r' | grep -E '^\[(debug|persist)\.oculus\.|^\[debug\.ovr' | sort; }
focus() { "$ADB" shell dumpsys window 2>/dev/null | tr -d '\r' | grep -E 'mCurrentFocus' | head -1 | sed 's/^ *//'; }
"$ADB" logcat -c 2>/dev/null
"$ADB" logcat -v time godot:I '*:S' > "$RAW" 2>/dev/null &
LC=$!
trap 'kill $LC 2>/dev/null; rm -f "$RAW"; echo; echo "Report saved: $OUT"' EXIT
log "REPORT START  device=$("$ADB" shell getprop ro.product.model | tr -d '\r') ($("$ADB" shell getprop ro.product.device | tr -d '\r'))  os=$("$ADB" shell getprop ro.build.version.incremental | tr -d '\r')"
log "GAME $("$ADB" shell dumpsys package "$PKG" 2>/dev/null | tr -d '\r' | grep -m1 versionCode)"
prev=$(props); log "HEADSET SETTINGS AT START:"; echo "$prev" | sed 's/^/    /' | tee -a "$OUT"
pf=$(focus); log "FOCUS $pf"
log "Play now. A+X = looks GOOD, B+Y = looks BAD (or keys g / b here, q to stop)."
seen=0; n=0
while true; do
  key=""; read -t 1 -n 1 key 2>/dev/null
  case "$key" in g|G) log "MARK GOOD (keyboard)";; b|B) log "MARK BAD (keyboard)";; q|Q) break;; esac
  total=$(wc -l < "$RAW" | tr -d ' ')
  if [ "$total" -gt "$seen" ]; then
    tail -n +$((seen + 1)) "$RAW" | grep -E 'PERF |EVENT |STATE |CHANGE |OVERRIDES|MARK |PICTURE |PICTURELOG|HEADSET' | tee -a "$OUT"
    seen=$total
  fi
  n=$((n + 1))
  if [ $((n % 3)) -eq 0 ]; then
    cur=$(props)
    if [ "$cur" != "$prev" ]; then
      log "HEADSET SETTINGS CHANGED:"
      diff <(echo "$prev") <(echo "$cur") | sed 's/^/    /' | tee -a "$OUT"
      prev=$cur
    fi
  fi
  if [ $((n % 5)) -eq 0 ]; then
    cf=$(focus)
    if [ "$cf" != "$pf" ]; then log "FOCUS CHANGED: $cf"; pf=$cf; fi
  fi
done
