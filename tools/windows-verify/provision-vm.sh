#!/usr/bin/env bash
# Provision a Windows VM on a Fedora/KVM host (this is "danoontje") for the
# ConPTY soak verification. REVIEW BEFORE RUNNING — by default this is a
# DRY RUN that only prints what it would do. Pass --go to actually execute.
#
# Scope: this VM verifies the ConPTY *resource leak* (culprits #1-#4). It does
# NOT verify the GPU/TDR hypothesis (#5): a stock VM renders through a software
# (WARP) adapter, so `make run` cannot exhibit a real display-driver TDR here.
# Chasing #5 needs GPU passthrough (vfio) or bare metal — see README appendix.
#
# Prereqs you must supply:
#   WIN_ISO     path to a Windows 10/11 or Server 2022 install ISO
#   VIRTIO_ISO  path to the virtio-win ISO (storage/net drivers)
#               https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/
set -euo pipefail

GO=0
[[ "${1:-}" == "--go" ]] && GO=1

VM_NAME="${VM_NAME:-clide-win-verify}"
RAM_MB="${RAM_MB:-8192}"
VCPUS="${VCPUS:-4}"
DISK_GB="${DISK_GB:-80}"
DISK_PATH="${DISK_PATH:-/var/lib/libvirt/images/${VM_NAME}.qcow2}"
WIN_ISO="${WIN_ISO:-}"
VIRTIO_ISO="${VIRTIO_ISO:-}"
OS_VARIANT="${OS_VARIANT:-win11}"   # `osinfo-query os` for the full list; win11 needs TPM+UEFI

run() { echo "+ $*"; [[ "$GO" == 1 ]] && "$@"; }

echo "== clide Windows verify VM provisioner =="
echo "   mode:    $([[ $GO == 1 ]] && echo EXECUTE || echo 'DRY RUN (pass --go to execute)')"
echo "   vm:      $VM_NAME  ${VCPUS} vCPU / ${RAM_MB}MB / ${DISK_GB}GB"
echo "   disk:    $DISK_PATH"
echo "   variant: $OS_VARIANT"
echo

# 1. Host tooling (Fedora). Idempotent; safe to re-run.
if ! command -v virt-install >/dev/null 2>&1; then
  echo "-- installing virtualization stack (needs sudo) --"
  run sudo dnf install -y @virtualization
  run sudo systemctl enable --now libvirtd
else
  echo "-- virt-install present --"
fi

# 2. Validate the ISOs the caller must provide.
if [[ -z "$WIN_ISO" || ! -f "$WIN_ISO" ]]; then
  echo "!! set WIN_ISO=/path/to/Windows.iso (got: '${WIN_ISO:-unset}')" >&2
  [[ "$GO" == 1 ]] && exit 2
fi
if [[ -z "$VIRTIO_ISO" || ! -f "$VIRTIO_ISO" ]]; then
  echo "!! set VIRTIO_ISO=/path/to/virtio-win.iso (got: '${VIRTIO_ISO:-unset}')" >&2
  [[ "$GO" == 1 ]] && exit 2
fi

# 3. Backing disk.
run sudo qemu-img create -f qcow2 "$DISK_PATH" "${DISK_GB}G"

# 4. Define + start the VM. UEFI + TPM 2.0 satisfy Win11; drop --tpm and use
#    --boot uefi=off for older guests. virtio disk/net need the VIRTIO_ISO
#    drivers loaded during Windows setup ("Load driver" -> the virtio CD).
run sudo virt-install \
  --name "$VM_NAME" \
  --memory "$RAM_MB" \
  --vcpus "$VCPUS" \
  --cpu host-passthrough \
  --os-variant "$OS_VARIANT" \
  --boot uefi \
  --tpm backend.type=emulator,backend.version=2.0,model=tpm-crb \
  --disk "path=$DISK_PATH,bus=virtio,format=qcow2" \
  --disk "path=$WIN_ISO,device=cdrom,boot.order=1" \
  --disk "path=$VIRTIO_ISO,device=cdrom" \
  --network network=default,model=virtio \
  --graphics spice \
  --video qxl \
  --noautoconsole

cat <<EOF

Next:
  1. virt-viewer $VM_NAME   # finish the interactive Windows install
                            # (Load driver -> virtio CD for the disk; install virtio NIC after)
  2. Inside Windows, fetch this repo's tools and run, from an ELEVATED PowerShell:
       pwsh -File tools\\windows-verify\\bootstrap-windows.ps1
  3. New shell, then:
       pwsh -File tools\\windows-verify\\soak-conpty.ps1 -Iterations 40
EOF
