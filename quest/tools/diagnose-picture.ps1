# Finds out why the picture is fuzzy on the headset (Windows PowerShell). Needs adb on the PATH, headset plugged in with USB debugging allowed.
#   powershell -ExecutionPolicy Bypass -File diagnose-picture.ps1          read only
#   powershell -ExecutionPolicy Bypass -File diagnose-picture.ps1 -Reset   also clears every debug.oculus.* override and restarts the game
param([switch]$Reset)
$PKG = "com.thejoeyrob.fattysgameshack"
if (-not (Get-Command adb -ErrorAction SilentlyContinue)) { Write-Host "adb not found. Install Android platform-tools and add it to PATH."; exit 1 }
if ((adb get-state 2>&1) -notmatch "device") { Write-Host "No headset found. Plug it in, put it on, accept the USB debugging prompt, then run again."; adb devices; exit 1 }
function Sec($t) { Write-Host ""; Write-Host "==== $t ====" }
Sec "Headset"
foreach ($p in "ro.product.model","ro.product.device","ro.product.name","ro.build.version.release","ro.build.version.incremental") { "{0,-34} {1}" -f $p, ((adb shell getprop $p) -join "").Trim() }
Sec "Overrides set on the headset (debug.oculus.*, what tools like Quest Games Optimiser change for every app)"
$all = adb shell getprop
$all | Select-String -Pattern '^\[(debug\.oculus\.|persist\.oculus\.|debug\.ovr|debug\.vr)' | Sort-Object | ForEach-Object { $_.Line }
Write-Host "(blank means nothing is overridden. Look for textureWidth / textureHeight, foveation.level, refreshRate, cpuLevel, gpuLevel.)"
Sec "The game"
adb shell dumpsys package $PKG | Select-String -Pattern 'versionCode|versionName|firstInstallTime|lastUpdateTime' | Select-Object -First 4 | ForEach-Object { $_.Line.Trim() }
Sec "What the game decided to draw (from its own log; start the game once if empty)"
adb logcat -d | Select-String -Pattern 'PICTURE eye=|HEADSET OVERRIDES|Refresh rate set|OpenXR is running' | Select-Object -Last 12 | ForEach-Object { $_.Line }
Write-Host "(eye= is the size per eye; multiplier 1.00 means the game adds nothing; headset_owns=true means a tool has taken over and the game stands down.)"
Sec "Display the system reports"
adb shell dumpsys display | Select-String -Pattern 'mode ?id|fps=|refreshRate|renderFrameRate' | Select-Object -First 8 | ForEach-Object { $_.Line.Trim() }
if ($Reset) {
  Sec "Clearing overrides"
  $all | Select-String -Pattern '^\[(debug\.oculus\.[^\]]+)\]' | ForEach-Object { $k = $_.Matches[0].Groups[1].Value; Write-Host "clear $k"; adb shell setprop $k "" }
  adb shell am force-stop $PKG
  Write-Host "Done. Start the game again and run this once more without -Reset."
}
Write-Host ""; Write-Host "Finished. If the picture is clear after -Reset, the fault was an override listed above."
