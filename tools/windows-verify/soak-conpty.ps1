<#
.SYNOPSIS
  Soak-test the clide ConPTY backend on Windows and measure the orphaned-
  process / handle / thread leak — the verification for culprit #1 (and the
  amplifiers #2-#4) from docs/windows-freeze-analysis.

.DESCRIPTION
  Hypothesis under test (see the freeze report): each WindowsPty.start()
  pairs the child with its own conhost.exe/OpenConsole.exe, and because the
  child is NOT placed in a kill-on-close Job Object and the reader isolate
  blocks forever in ReadFile, those hosts are NOT reaped — they outlive the
  dart.exe test process and accumulate at the session level. A power-cycle-
  grade freeze is the cumulative end state of that leak across many runs.

  This script does NOT try to freeze the box. It runs the pty suite in a
  FRESH dart.exe per iteration (so anything the OS *should* reclaim at process
  exit is reclaimed) and then counts the conhost/cmd/OpenConsole processes
  that SURVIVE that exit. A residual count that climbs across iterations and
  never returns to baseline is the leak signature — it confirms #1 without
  needing the box to actually die.

  All samples are written line-buffered + flushed to a CSV OUTSIDE the build
  tree, so the evidence survives even if a later, harsher run does wedge the
  machine.

.PARAMETER Iterations   How many times to run the pty suite (default 25).
.PARAMETER RepoDir      Path to the clide checkout (default: two levels up).
.PARAMETER OutDir       Where to write the CSV + summary (default LOCALAPPDATA).
.PARAMETER TestSelector dart test args selecting the ConPTY suite.
.PARAMETER SettleMs     Pause after each iteration before sampling (let the
                        OS finish reaping legitimately-exited processes).
.PARAMETER PerIterTimeoutSec  Kill a dart.exe that runs longer than this (a
                        wedged test) and record the iteration as a hang, so one
                        stuck run can't stall the whole soak.

.EXAMPLE
  pwsh -File soak-conpty.ps1 -Iterations 40
#>
[CmdletBinding()]
param(
  [int]    $Iterations   = 25,
  [string] $RepoDir      = (Resolve-Path "$PSScriptRoot\..\..").Path,
  [string] $OutDir       = "$env:LOCALAPPDATA\clide\windows-verify",
  [string] $TestSelector = "--concurrency=1 --timeout 60s --tags pty test/pty/windows_pty_test.dart",
  [int]    $SettleMs     = 1500,
  [int]    $PerIterTimeoutSec = 180
)

$ErrorActionPreference = 'Stop'
$hostNames = @('conhost', 'OpenConsole', 'cmd')

function Get-HostCount {
  # Count the ConPTY host + shell processes currently alive.
  (Get-Process -Name $hostNames -ErrorAction SilentlyContinue | Measure-Object).Count
}

function Get-DartFootprint {
  # Summed handles + threads across every live dart.exe — a within-run
  # thrash indicator for culprit #2 (blocked-FFI isolate threads).
  $ds = Get-Process -Name dart -ErrorAction SilentlyContinue
  if (-not $ds) { return [pscustomobject]@{ procs = 0; handles = 0; threads = 0 } }
  [pscustomobject]@{
    procs   = ($ds | Measure-Object).Count
    handles = ($ds | Measure-Object -Property HandleCount -Sum).Sum
    threads = ($ds | ForEach-Object { $_.Threads.Count } | Measure-Object -Sum).Sum
  }
}

if (-not (Get-Command dart -ErrorAction SilentlyContinue)) {
  throw "dart not on PATH. Run bootstrap-windows.ps1 first (installs Flutter/Dart)."
}
if (-not (Test-Path (Join-Path $RepoDir 'pubspec.yaml'))) {
  throw "RepoDir '$RepoDir' does not look like the clide checkout (no pubspec.yaml)."
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp   = Get-Date -Format 'yyyyMMdd-HHmmss'
$csv     = Join-Path $OutDir "soak-$stamp.csv"
$summary = Join-Path $OutDir "soak-$stamp.summary.txt"

# Self-describing header so a captured CSV stands alone.
$os = Get-CimInstance Win32_OperatingSystem
"# clide ConPTY soak — $(Get-Date -Format o)"                                  | Out-File $summary
"# OS build: $($os.Version) ($($os.Caption))  cores: $env:NUMBER_OF_PROCESSORS" | Out-File $summary -Append
"# repo: $RepoDir   iterations: $Iterations   selector: $TestSelector"          | Out-File $summary -Append
"iter,ts,host_count,host_orphans_vs_baseline,dart_peak_handles,dart_peak_threads,test_exit,test_secs,hung" | Out-File $csv

# Drain pre-existing hosts out of the measurement: baseline is whatever is
# alive BEFORE we spawn anything (Explorer/Terminal already own some conhosts).
$baseline = Get-HostCount
"baseline,$(Get-Date -Format o),$baseline,0,,,,," | Out-File $csv -Append
Write-Host "baseline ConPTY hosts: $baseline" -ForegroundColor Cyan

$series = @()
for ($i = 1; $i -le $Iterations; $i++) {
  $sw = [System.Diagnostics.Stopwatch]::StartNew()

  # Fresh dart.exe per iteration: Push-Location so `dart test` resolves the
  # package. -PassThru lets us poll its footprint while it runs.
  Push-Location $RepoDir
  $p = Start-Process -FilePath 'dart' `
        -ArgumentList "test $TestSelector" `
        -NoNewWindow -PassThru
  $peakHandles = 0; $peakThreads = 0; $hung = $false
  while (-not $p.HasExited) {
    if ($sw.Elapsed.TotalSeconds -gt $PerIterTimeoutSec) {
      # A wedged dart.exe (e.g. a ConPTY reader blocked forever in ReadFile)
      # would otherwise hang the soak. Kill the whole process tree and record
      # the iteration as a hang instead of spinning here indefinitely.
      Start-Process taskkill -ArgumentList "/T /F /PID $($p.Id)" -NoNewWindow -Wait -ErrorAction SilentlyContinue
      $hung = $true
      break
    }
    $fp = Get-DartFootprint
    if ($fp.handles -gt $peakHandles) { $peakHandles = $fp.handles }
    if ($fp.threads -gt $peakThreads) { $peakThreads = $fp.threads }
    Start-Sleep -Milliseconds 250
  }
  $exit = if ($hung) { 'TIMEOUT' } else { $p.ExitCode }
  Pop-Location
  $sw.Stop()

  # The dart.exe is gone. Anything the ConPTY teardown reaped properly is
  # gone with it. Let the OS settle, then count what SURVIVED.
  Start-Sleep -Milliseconds $SettleMs
  $now      = Get-HostCount
  $orphans  = $now - $baseline
  $series  += $orphans

  $row = "{0},{1},{2},{3},{4},{5},{6},{7},{8}" -f `
    $i, (Get-Date -Format o), $now, $orphans, $peakHandles, $peakThreads, $exit, [math]::Round($sw.Elapsed.TotalSeconds, 1), $hung
  $row | Out-File $csv -Append   # Out-File flushes per call — survives a wedge.

  $tag = if ($hung) { 'HANG' } elseif ($orphans -gt 0) { 'LEAK?' } else { 'clean' }
  $col = if ($hung) { 'Red' } elseif ($orphans -gt 0) { 'Yellow' } else { 'Green' }
  Write-Host ("iter {0,3}/{1}: hosts={2} orphans={3,4} dart_peak_handles={4} threads={5} exit={6} {7}" -f `
    $i, $Iterations, $now, $orphans, $peakHandles, $peakThreads, $exit, $tag) -ForegroundColor $col
}

# Verdict: did the orphan count trend UP and stay up? A leak shows a positive
# slope and an end-state well above baseline; a clean run hovers at ~0.
$final = $series[-1]
$max   = ($series | Measure-Object -Maximum).Maximum
$first = $series[0]
$verdict = if ($final -ge 3 -and $final -ge $first + 2) {
  "LEAK CONFIRMED (culprit #1): orphaned ConPTY hosts grew to $final over $Iterations runs and did not reclaim."
} elseif ($max -ge 3) {
  "INCONCLUSIVE: orphans peaked at $max but did not hold ($final at end) — re-run with more -Iterations."
} else {
  "NOT REPRODUCED here: orphan count stayed near baseline (max $max). The leak may need more runs, or the fix is already present."
}

"" | Out-File $summary -Append
"final orphans: $final   peak orphans: $max   series: $($series -join ',')" | Out-File $summary -Append
$verdict | Out-File $summary -Append
Write-Host "`n$verdict" -ForegroundColor Magenta
Write-Host "CSV:     $csv"
Write-Host "summary: $summary"

# Leave the user a cleanup handle for any stranded hosts.
$stray = Get-Process -Name $hostNames -ErrorAction SilentlyContinue
if (($stray | Measure-Object).Count -gt $baseline) {
  Write-Host "`nStray hosts still alive. To reclaim: Get-Process conhost,OpenConsole,cmd | Stop-Process -Force" -ForegroundColor DarkYellow
}
