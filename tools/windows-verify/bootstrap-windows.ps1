<#
.SYNOPSIS
  Provision a fresh Windows machine (including a GCP Compute Engine Windows
  Server instance) to build and test clide's windows-support branch, then run
  the ConPTY soak. No winget dependency — works on Windows Server images that
  don't ship the Store.

.DESCRIPTION
  Installs Git (via Chocolatey) and the Flutter SDK (direct from Google's
  current stable — brings Dart). With -SkipVS it stops there: the ConPTY soak
  only needs Flutter/Dart (windows_pty.dart loads kernel32 at runtime). Without
  -SkipVS it also installs VS 2022 Build Tools (C++ workload) for
  `flutter build windows` + the C CLI. Then clones + checks out the branch and
  runs `flutter pub get`. Runs under Windows PowerShell 5.1 (no pwsh needed).

  Run from an ELEVATED PowerShell (Chocolatey + machine PATH need admin). On a
  fresh VM, fetch this script first:
    iwr https://raw.githubusercontent.com/postmeridiem/clide/windows-support/tools/windows-verify/bootstrap-windows.ps1 -OutFile $env:TEMP\bootstrap.ps1
    powershell -ExecutionPolicy Bypass -File $env:TEMP\bootstrap.ps1 -SkipVS

.PARAMETER RepoUrl  Git remote (default: GitHub origin).
.PARAMETER Branch   Branch to check out (default: windows-support).
.PARAMETER Dest     Checkout directory (default: %USERPROFILE%\src\clide).
.PARAMETER SkipVS   Skip VS Build Tools — enough for the ConPTY soak.
#>
[CmdletBinding()]
param(
  [string] $RepoUrl = 'https://github.com/postmeridiem/clide.git',
  [string] $Branch  = 'windows-support',
  [string] $Dest    = "$env:USERPROFILE\src\clide",
  [switch] $SkipVS
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Add-PersistentPath([string] $dir) {
  if (";$env:Path;" -notlike "*;$dir;*") { $env:Path = "$dir;$env:Path" }
  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  if (";$userPath;" -notlike "*;$dir;*") {
    [Environment]::SetEnvironmentVariable('Path', "$dir;$userPath", 'User')
  }
}

# -- Chocolatey (works on Server images that lack winget) -------------------
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
  Write-Host '==> installing Chocolatey' -ForegroundColor Cyan
  Set-ExecutionPolicy Bypass -Scope Process -Force
  Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
  Add-PersistentPath "$env:ProgramData\chocolatey\bin"
}

# -- Git --------------------------------------------------------------------
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Host '==> installing Git' -ForegroundColor Cyan
  choco install -y git
  Add-PersistentPath "$env:ProgramFiles\Git\cmd"
}

# -- Flutter (direct from Google; brings Dart) ------------------------------
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Host '==> installing Flutter (current stable)' -ForegroundColor Cyan
  $rel = Invoke-RestMethod 'https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json'
  $cur = $rel.releases | Where-Object { $_.channel -eq 'stable' } | Select-Object -First 1
  $zip = "$env:TEMP\flutter-stable.zip"
  Invoke-WebRequest -Uri "$($rel.base_url)/$($cur.archive)" -OutFile $zip
  $toolsDir = "$env:USERPROFILE\tools"
  New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
  Expand-Archive -Path $zip -DestinationPath $toolsDir -Force   # creates $toolsDir\flutter
  Add-PersistentPath "$toolsDir\flutter\bin"
}

# -- VS Build Tools (C++) — only when building, NOT for the soak ------------
if (-not $SkipVS) {
  Write-Host '==> installing VS 2022 Build Tools (C++ workload)' -ForegroundColor Cyan
  choco install -y visualstudio2022buildtools `
    --package-parameters '--add Microsoft.VisualStudio.Workload.VCTools --includeRecommended'
}

# refresh PATH so the just-installed tools resolve in THIS session
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'git not on PATH — open a new admin shell and re-run.' }
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw 'flutter not on PATH — open a new admin shell and re-run.' }

# -- clide ------------------------------------------------------------------
if (-not (Test-Path $Dest)) {
  Write-Host "==> git clone -> $Dest" -ForegroundColor Cyan
  git clone $RepoUrl $Dest
}
Push-Location $Dest
try {
  git fetch origin $Branch
  git checkout $Branch
  Write-Host '==> flutter pub get' -ForegroundColor Cyan
  flutter pub get
}
finally { Pop-Location }

Write-Host "`nReady. Open a NEW shell, then:" -ForegroundColor Green
Write-Host "  cd $Dest"
Write-Host "  powershell -ExecutionPolicy Bypass -File tools\windows-verify\soak-conpty.ps1 -Iterations 40"
