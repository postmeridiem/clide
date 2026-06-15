<#
.SYNOPSIS
  Abrupt-death ConPTY orphan probe — the failure-mode half of the soak.

.DESCRIPTION
  soak-conpty.ps1 measures the CLEAN path (dart exits normally, ConPTY
  teardown runs) and found NO leak on windows-latest: orderly close() reaps
  every host. That does not exercise the freeze hypothesis (T-424), which is
  about the parent dying WITHOUT teardown.

  This driver does. Per iteration it launches conpty_orphan_probe.dart — which
  starts $PtysPerIter real WindowsPty sessions on long-lived children and then
  blocks WITHOUT ever calling close() — waits for the ConPTY hosts to come up,
  then force-kills ONLY the dart.exe parent (taskkill /F, no /T) and counts the
  conhost / OpenConsole / cmd processes that SURVIVE. Because the children are
  not in a kill-on-close Job Object, abrupt parent death is expected to orphan
  them; a survivor count that climbs across iterations and never returns to
  baseline is the leak signature this probe is built to expose.

  By default it does NOT clean up between iterations, so accumulation is
  visible (the freeze is a cumulative end-state). A final sweep reclaims any
  strays. Pass -CleanEachIter to isolate the per-kill measurement instead.

  This is a DIAGNOSTIC, not a gate. It writes a CSV + verdict and always
  succeeds. Re-run it unchanged to validate the T-424 Job Object fix: with the
  job, survivors should drop to ~0.

.PARAMETER Iterations    How many spawn+kill cycles (default 15).
.PARAMETER PtysPerIter   WindowsPty sessions spawned per cycle (default 1).
.PARAMETER RepoDir       clide checkout (default: two levels up).
.PARAMETER OutDir        Where the CSV + summary land (default LOCALAPPDATA).
.PARAMETER SpawnWaitSec  Max wait for the hosts to appear before killing.
.PARAMETER SettleMs      Pause after the kill before counting survivors.
.PARAMETER CleanEachIter Reclaim strays after each cycle (isolate per-kill).

.EXAMPLE
  pwsh -File soak-conpty-kill.ps1 -Iterations 20 -PtysPerIter 2
#>
[CmdletBinding()]
param(
  [int]    $Iterations   = 15,
  [int]    $PtysPerIter  = 1,
  [string] $RepoDir      = (Resolve-Path "$PSScriptRoot\..\..").Path,
  [string] $OutDir       = "$env:LOCALAPPDATA\clide\windows-verify",
  [int]    $SpawnWaitSec = 25,
  [int]    $SettleMs     = 2000,
  [switch] $CleanEachIter
)

$ErrorActionPreference = 'Stop'
$hostNames = @('conhost', 'OpenConsole', 'cmd')
$probe     = Join-Path $PSScriptRoot 'conpty_orphan_probe.dart'

function Get-HostCount {
  (Get-Process -Name $hostNames -ErrorAction SilentlyContinue | Measure-Object).Count
}

function Clear-StrayHosts([int]$keep) {
  # Reclaim hosts above the baseline so the runner does not fill with orphans.
  $alive = Get-Process -Name $hostNames -ErrorAction SilentlyContinue |
    Sort-Object StartTime -Descending
  $over = ($alive | Measure-Object).Count - $keep
  if ($over -gt 0) { $alive | Select-Object -First $over | Stop-Process -Force -ErrorAction SilentlyContinue }
}

if (-not (Get-Command dart -ErrorAction SilentlyContinue)) {
  throw "dart not on PATH. Run bootstrap-windows.ps1 first (installs Flutter/Dart)."
}
if (-not (Test-Path (Join-Path $RepoDir 'pubspec.yaml'))) {
  throw "RepoDir '$RepoDir' does not look like the clide checkout (no pubspec.yaml)."
}
if (-not (Test-Path $probe)) {
  throw "probe not found: $probe"
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp   = Get-Date -Format 'yyyyMMdd-HHmmss'
$csv     = Join-Path $OutDir "soak-kill-$stamp.csv"
$summary = Join-Path $OutDir "soak-kill-$stamp.summary.txt"

$os = Get-CimInstance Win32_OperatingSystem
"# clide ConPTY ABRUPT-DEATH orphan probe — $(Get-Date -Format o)"                    | Out-File $summary
"# OS build: $($os.Version) ($($os.Caption))  cores: $env:NUMBER_OF_PROCESSORS"        | Out-File $summary -Append
"# repo: $RepoDir  iterations: $Iterations  ptys/iter: $PtysPerIter  cleanEach: $CleanEachIter" | Out-File $summary -Append
"iter,ts,hosts_before,hosts_after_spawn,hosts_after_kill,iter_survivors,cumulative_vs_baseline,spawned_ok,probe_pid" | Out-File $csv

$baseline = Get-HostCount
"baseline,$(Get-Date -Format o),$baseline,,,,0,," | Out-File $csv -Append
Write-Host "baseline ConPTY hosts: $baseline" -ForegroundColor Cyan

$iterSurvivors = @()
for ($i = 1; $i -le $Iterations; $i++) {
  $before = Get-HostCount

  # Launch the probe: it starts $PtysPerIter WindowsPty sessions and blocks
  # without close(). -PassThru gives us the dart.exe pid to kill.
  Push-Location $RepoDir
  $p = Start-Process -FilePath 'dart' `
        -ArgumentList "run `"$probe`" $PtysPerIter" `
        -NoNewWindow -PassThru
  Pop-Location

  # Wait for the ConPTY hosts to actually come up (count rises above $before).
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $spawned = $false
  while ($sw.Elapsed.TotalSeconds -lt $SpawnWaitSec) {
    if ($p.HasExited) { break }              # probe died early — unexpected
    if ((Get-HostCount) -gt $before) { $spawned = $true; Start-Sleep -Milliseconds 600; break }
    Start-Sleep -Milliseconds 300
  }
  $afterSpawn = Get-HostCount

  # ABRUPT parent death: kill ONLY dart.exe. No /T — we are testing whether the
  # ConPTY children survive their parent (they will, absent a kill-on-close
  # job; that survival IS the leak).
  if (-not $p.HasExited) {
    Start-Process taskkill -ArgumentList "/F /PID $($p.Id)" -NoNewWindow -Wait -ErrorAction SilentlyContinue
  }

  Start-Sleep -Milliseconds $SettleMs
  $afterKill   = Get-HostCount
  $survivors   = $afterKill - $before          # net hosts this cycle left behind
  $cumulative  = $afterKill - $baseline         # running accumulation vs baseline
  $iterSurvivors += $survivors

  $row = "{0},{1},{2},{3},{4},{5},{6},{7},{8}" -f `
    $i, (Get-Date -Format o), $before, $afterSpawn, $afterKill, $survivors, $cumulative, $spawned, $p.Id
  $row | Out-File $csv -Append

  $tag = if (-not $spawned) { 'NO-SPAWN' } elseif ($survivors -gt 0) { 'ORPHANED' } else { 'reaped' }
  $col = if (-not $spawned) { 'DarkYellow' } elseif ($survivors -gt 0) { 'Yellow' } else { 'Green' }
  Write-Host ("iter {0,3}/{1}: before={2} spawn={3} afterkill={4} survivors={5,3} cum={6,3} {7}" -f `
    $i, $Iterations, $before, $afterSpawn, $afterKill, $survivors, $cumulative, $tag) -ForegroundColor $col

  if ($CleanEachIter) { Clear-StrayHosts -keep $baseline; Start-Sleep -Milliseconds 500 }
}

# Verdict: did abrupt parent death orphan the ConPTY hosts?
$totalSurv = ($iterSurvivors | Measure-Object -Sum).Sum
$leakIters = ($iterSurvivors | Where-Object { $_ -gt 0 } | Measure-Object).Count
$endCum    = (Get-HostCount) - $baseline
$verdict = if ($leakIters -ge [math]::Max(2, [int]($Iterations * 0.5))) {
  "LEAK CONFIRMED (culprit #1 / T-424): abrupt parent death orphaned ConPTY hosts in $leakIters/$Iterations cycles (total survivors $totalSurv). Without a kill-on-close Job Object the children outlive dart.exe."
} elseif ($totalSurv -gt 0) {
  "PARTIAL: orphans appeared in $leakIters/$Iterations cycles (total $totalSurv) but not consistently — re-run with more -Iterations / -PtysPerIter to confirm the slope."
} else {
  "NOT REPRODUCED: every cycle's hosts were reaped even on abrupt kill (the OS broke the pipes and conhost exited). The Job Object may be unnecessary on this OS build, or the leak needs a different trigger."
}

"" | Out-File $summary -Append
"iter survivors: $($iterSurvivors -join ',')"                                  | Out-File $summary -Append
"cycles with orphans: $leakIters/$Iterations   total survivors: $totalSurv   end cumulative: $endCum" | Out-File $summary -Append
$verdict | Out-File $summary -Append
Write-Host "`n$verdict" -ForegroundColor Magenta
Write-Host "CSV:     $csv"
Write-Host "summary: $summary"

# Always sweep strays at the end so we never leave the box (or a re-run's
# baseline) polluted, regardless of -CleanEachIter.
Clear-StrayHosts -keep $baseline
