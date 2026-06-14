<#
.SYNOPSIS
  Provision a Windows VM (or bare machine) with everything needed to build and
  test clide's windows-support branch, then run the ConPTY soak.

.DESCRIPTION
  Installs (via winget): Git, the Flutter SDK (brings Dart), and Visual Studio
  2022 Build Tools with the C++ desktop workload — required for both the
  ConPTY FFI path and the `clide.c` AF_UNIX CLI (ws2_32 / afunix). Then clones
  the repo, checks out the branch, runs `flutter pub get`, and builds the C
  client. Nothing here freezes the box; it just gets you to a runnable state.

  Run from an ELEVATED PowerShell (winget package installs need admin). After
  it finishes, open a NEW shell so PATH updates take effect, then run
  soak-conpty.ps1.

.PARAMETER RepoUrl   Git remote (default: the GitHub origin).
.PARAMETER Branch    Branch to check out (default: windows-support).
.PARAMETER Dest      Checkout directory (default: %USERPROFILE%\src\clide).
#>
[CmdletBinding()]
param(
  [string] $RepoUrl = 'https://github.com/postmeridiem/clide.git',
  [string] $Branch  = 'windows-support',
  [string] $Dest    = "$env:USERPROFILE\src\clide"
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  throw "winget not found. Install 'App Installer' from the Microsoft Store (or use a Win11/Server 2022+ image)."
}

function Install-Pkg([string]$id, [string]$override = $null) {
  Write-Host "==> winget install $id" -ForegroundColor Cyan
  $args = @('install', '--id', $id, '-e', '--accept-source-agreements', '--accept-package-agreements')
  if ($override) { $args += @('--override', $override) }
  winget @args
  if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) {  # -1978335189 = already installed
    throw "winget install $id failed ($LASTEXITCODE)"
  }
}

Install-Pkg 'Git.Git'
Install-Pkg 'Flutter.Flutter'   # provides flutter + bundled dart
# VS 2022 Build Tools with the native C++ desktop workload (cl.exe, ws2_32, afunix.h).
Install-Pkg 'Microsoft.VisualStudio.2022.BuildTools' `
  '--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended'

# Re-resolve PATH for this session so the freshly installed tools are visible.
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
            [System.Environment]::GetEnvironmentVariable('Path','User')

if (-not (Get-Command git -ErrorAction SilentlyContinue))     { throw "git not on PATH after install — open a new shell and re-run from the clone step." }
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw "flutter not on PATH after install — open a new shell and re-run from the clone step." }

if (-not (Test-Path $Dest)) {
  Write-Host "==> git clone $RepoUrl -> $Dest" -ForegroundColor Cyan
  git clone $RepoUrl $Dest
}
Push-Location $Dest
try {
  git fetch origin $Branch
  git checkout $Branch
  Write-Host "==> flutter pub get" -ForegroundColor Cyan
  flutter pub get
  # Build the C CLI (needs the VS toolset; ci/build_cli_windows.sh wraps cl.exe).
  # Requires a bash — Git for Windows ships one at /usr/bin/bash.
  $bash = Join-Path $env:ProgramFiles 'Git\bin\bash.exe'
  if (Test-Path $bash) {
    Write-Host "==> build C CLI (ci/build_cli_windows.sh)" -ForegroundColor Cyan
    & $bash -lc "cd '$($Dest -replace '\\','/')' && ci/build_cli_windows.sh"
  } else {
    Write-Warning "Git Bash not found; skipping C CLI build. Build later with 'make clide-cli' from Git Bash."
  }
}
finally { Pop-Location }

Write-Host "`nReady. Open a NEW shell, then:" -ForegroundColor Green
Write-Host "  cd $Dest"
Write-Host "  pwsh -File tools\windows-verify\soak-conpty.ps1 -Iterations 40"
