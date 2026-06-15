# windows-verify — ConPTY leak verification kit

Tooling to **verify (or refute) the Windows test-freeze assessment** for the
`windows-support` branch on a real Windows VM. See the full analysis in
`docs/windows-freeze-analysis.md` (or the report shared in the session).

> **Status: nothing here runs automatically.** These scripts are inert until
> you invoke them. `provision-vm.sh` is a **dry run** unless you pass `--go`.

## What this verifies — and what it can't

| Hypothesis | In scope here? | Why |
|---|---|---|
| **#1** orphaned `conhost.exe`/`cmd.exe` accumulation (no Job Object) | **✅ yes** | `soak-conpty.ps1` measures the orphan count directly — this is the headline result. |
| **#2** unkillable blocked-FFI isolate threads | ✅ partial | Per-run `dart.exe` peak handle/thread footprint is sampled; the leak is reclaimed at process exit, so it shows as a *within-run* spike, not cross-run growth. |
| **#3** narrow-terminal CRLF conhost spin | ⚠️ manual | Surfaces as a host that pegs a CPU core; watch Task Manager during a soak. The real fix is clamping `cols/rows ≥ 2` + a unit test. |
| **#4** `ClosePseudoConsole` hang (pre-24H2) | ⚠️ partial | Run on a **pre-24H2** image (build < 26100) *and* a 24H2+ image to see the version-gated intermittency. |
| **#5** GPU/display-driver TDR (`0x116`) — the real black-screen | **❌ no** | A stock VM uses a software (WARP) adapter; `make run` cannot trigger a hardware TDR. Needs GPU passthrough or bare metal — see the appendix. |

The leak (#1) is the **test-path** explanation and the actionable one. A VM is
the right instrument for it; it is the wrong instrument for #5.

## On a cloud VM (GCP) — no local hypervisor

If the host has no KVM (e.g. VT-x disabled in firmware), run this on a GCP
Windows Server instance instead — real hardware acceleration, nothing installed
locally. From the GCP Cloud Shell (browser; `gcloud` preinstalled):

```bash
gcloud compute instances create clide-win-verify \
  --zone=us-central1-a --machine-type=e2-standard-4 \
  --image-family=windows-2022 --image-project=windows-cloud \
  --boot-disk-size=100GB --boot-disk-type=pd-ssd
gcloud compute reset-windows-password clide-win-verify --zone=us-central1-a --user=admin
```

RDP to the printed IP with the printed credentials (KDE: KRDC; or
`flatpak install flathub org.remmina.Remmina`). Then run steps 2-3 below inside
Windows (`bootstrap-windows.ps1 -SkipVS` is winget-free and Server-compatible).
Stop the VM when idle, delete it when done:

```bash
gcloud compute instances stop   clide-win-verify --zone=us-central1-a   # idle
gcloud compute instances delete clide-win-verify --zone=us-central1-a   # done
```

## The three steps

1. **Provision the VM** (on the Fedora/KVM host — "danoontje"):
   ```bash
   WIN_ISO=~/iso/Win11.iso VIRTIO_ISO=~/iso/virtio-win.iso \
     tools/windows-verify/provision-vm.sh          # dry run — prints the plan
   WIN_ISO=... VIRTIO_ISO=... tools/windows-verify/provision-vm.sh --go   # execute
   ```
   Finish the interactive Windows install in `virt-viewer` (load the virtio
   disk driver from the second CD during setup).

2. **Bootstrap the toolchain** (inside Windows, elevated PowerShell). No winget
   dependency, so this also works on Windows Server / GCP images. For the soak,
   `-SkipVS` installs only Flutter/Dart:
   ```powershell
   powershell -ExecutionPolicy Bypass -File tools\windows-verify\bootstrap-windows.ps1 -SkipVS
   ```
   Drop `-SkipVS` to also install VS 2022 Build Tools (needed only for
   `flutter build windows` + the C CLI). Clones + checks out `windows-support`.

3. **Run the soak** (new shell, so PATH is fresh):
   ```powershell
   powershell -ExecutionPolicy Bypass -File tools\windows-verify\soak-conpty.ps1 -Iterations 40
   ```

## Reading the result

`soak-conpty.ps1` runs the ConPTY suite in a **fresh `dart.exe` per
iteration** and, after each one exits, counts the `conhost`/`OpenConsole`/`cmd`
processes that **survived** (baseline-subtracted). It writes a per-iteration
CSV + a summary to `%LOCALAPPDATA%\clide\windows-verify\` (flushed each line,
so the data survives even if a later run wedges the box).

- **Orphan count climbs and stays up** (e.g. +1 per iteration, never reclaimed)
  → **leak confirmed (#1)**: ConPTY hosts outlive the test process. This is the
  cumulative starvation that, across many runs, thrashes the session to a
  power-cycle.
- **Orphan count hovers at ~0** → not reproduced in this config (more
  iterations may be needed, or the Job-Object fix is already in place).
- **`dart_peak_handles`/`threads` ratchet up *within* a run** → corroborates #2
  (blocked reader/waiter isolates), reclaimed when `dart.exe` exits.

The script never tries to crash the machine — it proves the *mechanism* (an
unreclaimed, monotonically growing host population), which is the safe and
sufficient verification.

## Safety notes

- Snapshot the VM before soaking (`virsh snapshot-create-as clide-win-verify clean`)
  so you can roll back instead of reinstalling.
- If hosts strand after a run: `Get-Process conhost,OpenConsole,cmd | Stop-Process -Force`.
- Do this in a VM, not a machine you care about — the whole point is to provoke
  a resource leak.

## Appendix — chasing the GPU/TDR hypothesis (#5)

A software-rendered VM can't reproduce a real display-driver TDR. To test #5
you need **GPU passthrough** (bind the GPU to `vfio-pci`, pass it with
`--hostdev`, install the vendor WDDM driver in the guest) or, more simply, run
`make run` / `make run-testmode` on the **bare-metal Windows box** that
actually froze. Then, as a *diagnostic only*, raise `TdrDelay` (or set
`TdrLevel=0`) under
`HKLM\System\CurrentControlSet\Control\GraphicsDrivers` and see whether a
previously-rebooting `make run` now only stutters/recovers — and read Event
Viewer for **Display 4101** / **BugCheck 0x116** after any freeze. Revert the
registry change afterward.
