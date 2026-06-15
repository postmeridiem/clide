<#
.SYNOPSIS
  Headless one-shot: bootstrap the toolchain, run the ConPTY soak, and print
  the summary to stdout — i.e. to the GCE serial console. Lets you verify the
  ConPTY leak on a cloud VM with NO RDP and no interactive session.

.DESCRIPTION
  Intended as a GCE windows-startup-script. Drop this one line in as the
  startup script (it fetches + runs this file):

    [Net.ServicePointManager]::SecurityProtocol='Tls12'; iwr https://raw.githubusercontent.com/postmeridiem/clide/windows-support/tools/windows-verify/run-headless.ps1 -OutFile C:\run.ps1; powershell -ExecutionPolicy Bypass -File C:\run.ps1

  GCE captures startup-script output to the serial port, so the result is read
  with:  gcloud compute instances get-serial-port-output <vm> --zone <zone>
  — look between the ===CLIDE SOAK SUMMARY=== and ===CLIDE SOAK DONE=== markers.
  Runs as LocalSystem under Windows PowerShell 5.1; no winget, no RDP.
#>
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$raw = 'https://raw.githubusercontent.com/postmeridiem/clide/windows-support/tools/windows-verify'

Write-Output '===CLIDE BOOTSTRAP START==='
Invoke-WebRequest "$raw/bootstrap-windows.ps1" -OutFile C:\clide-bootstrap.ps1
powershell -ExecutionPolicy Bypass -File C:\clide-bootstrap.ps1 -SkipVS -Dest C:\clide

Write-Output '===CLIDE SOAK START==='
powershell -ExecutionPolicy Bypass -File C:\clide\tools\windows-verify\soak-conpty.ps1 -Iterations 40 -RepoDir C:\clide -OutDir C:\clide-soak

Write-Output '===CLIDE SOAK SUMMARY==='
$sum = Get-ChildItem C:\clide-soak\*.summary.txt -ErrorAction SilentlyContinue | Select-Object -Last 1
if ($sum) { Get-Content $sum.FullName | Write-Output } else { Write-Output '(no summary — a step above failed; scan the serial log for the error)' }
Write-Output '===CLIDE SOAK DONE==='
