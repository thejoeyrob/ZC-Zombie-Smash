# Live picture report (Windows PowerShell). Run from the folder you want the report in. Needs adb on PATH, headset plugged in with USB debugging allowed.
#   powershell -ExecutionPolicy Bypass -File watch-picture.ps1
# Play as normal. When the picture looks GOOD hold A+X (both hands) for half a second; BAD hold B+Y (the controllers buzz once). Or press g / b here. q ends it.
# Send back the picture-report-*.txt file with a note of what you saw and when.
$PKG = "com.thejoeyrob.fattysgameshack"
if (-not (Get-Command adb -ErrorAction SilentlyContinue)) { Write-Host "adb not found."; exit 1 }
if ((adb get-state 2>&1) -notmatch "device") { Write-Host "No headset found. Plug it in and accept the USB debugging prompt."; exit 1 }
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$out = "picture-report-$stamp.txt"
$full = "picture-fulllog-$stamp.txt"
$raw = [System.IO.Path]::GetTempFileName()
function Log($t) { $l = (Get-Date -Format "HH:mm:ss") + " " + $t; Write-Host $l; Add-Content -Path $out -Value $l }
function Props { (adb shell getprop) | Select-String -Pattern '^\[(debug|persist)\.oculus\.|^\[debug\.ovr' | ForEach-Object { $_.Line.Trim() } | Sort-Object }
function Focus { ((adb shell dumpsys window) | Select-String -Pattern 'mCurrentFocus' | Select-Object -First 1 | ForEach-Object { $_.Line.Trim() }) }
adb logcat -c | Out-Null
$p = Start-Process -FilePath adb -ArgumentList @("logcat","-v","time","godot:I","*:S") -RedirectStandardOutput $raw -NoNewWindow -PassThru
$pf2 = Start-Process -FilePath adb -ArgumentList @("logcat","-v","time","*:I") -RedirectStandardOutput $full -NoNewWindow -PassThru
function Thermal { "battery=" + ((adb shell dumpsys battery) | Select-String -Pattern 'level' | Select-Object -First 1 | ForEach-Object { ($_.Line -split ':')[1].Trim() }) + "% temp=" + ((adb shell dumpsys battery) | Select-String -Pattern 'temperature' | Select-Object -First 1 | ForEach-Object { ($_.Line -split ':')[1].Trim() }) }
$sysSeen = 0
Log ("REPORT START  device=" + ((adb shell getprop ro.product.model) -join "") + " (" + ((adb shell getprop ro.product.device) -join "") + ")")
$prev = Props; Log "HEADSET SETTINGS AT START:"; $prev | ForEach-Object { Log ("    " + $_) }
$pf = Focus; Log ("FOCUS " + $pf)
Log ("HEADSET " + (Thermal))
Log "Play now. A+X = looks GOOD, B+Y = looks BAD (or keys g / b here, q to stop)."
$seen = 0; $n = 0
try {
  while ($true) {
    Start-Sleep -Milliseconds 1000
    while ([Console]::KeyAvailable) {
      $k = [Console]::ReadKey($true).KeyChar
      if ($k -eq 'g') { Log "MARK GOOD (keyboard)" } elseif ($k -eq 'b') { Log "MARK BAD (keyboard)" } elseif ($k -eq 'q') { throw "done" }
    }
    $lines = @(Get-Content $raw -ErrorAction SilentlyContinue)
    if ($lines.Count -gt $seen) {
      $lines[$seen..($lines.Count - 1)] | Where-Object { $_ -match 'PERF |EVENT |STATE |CHANGE |OVERRIDES|MARK |PICTURE |PICTURELOG|HEADSET' } | ForEach-Object { Write-Host $_; Add-Content -Path $out -Value $_ }
      $seen = $lines.Count
    }
    $n++
    if ($n % 3 -eq 0) {
      $cur = Props
      $d = Compare-Object $prev $cur
      if ($d) { Log "HEADSET SETTINGS CHANGED:"; $d | ForEach-Object { Log ("    " + $_.SideIndicator + " " + $_.InputObject) }; $prev = $cur }
    }
    if ($n % 10 -eq 0) { Log ("HEADSET " + (Thermal)) }
    $fl = @(Get-Content $full -ErrorAction SilentlyContinue)
    if ($fl.Count -gt $sysSeen) {
      $fl[$sysSeen..($fl.Count - 1)] | Where-Object { $_ -match '(?i)foveat|resolution|swapchain|spacewarp|asw|dynamic.?res|refresh ?rate|thermal|throttl|cpu ?level|gpu ?level|optimi[sz]er|qgo|recommended|eye ?(buffer|texture)' -and $_ -notmatch 'godot' } | ForEach-Object { $l = "SYS " + $_.Substring(0, [Math]::Min(220, $_.Length)); Write-Host $l; Add-Content -Path $out -Value $l }
      $sysSeen = $fl.Count
    }
    if ($n % 5 -eq 0) { $cf = Focus; if ($cf -ne $pf) { Log ("FOCUS CHANGED: " + $cf); $pf = $cf } }
  }
} catch { } finally {
  if ($p -and -not $p.HasExited) { $p.Kill() }
  if ($pf2 -and -not $pf2.HasExited) { $pf2.Kill() }
  Remove-Item $raw -ErrorAction SilentlyContinue
  Write-Host ""; Write-Host ("Report saved: " + $out + "   (and the whole system log: " + $full + ")")
}
