#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ISO="${ISO:-$ROOT/out/stickllm-amd-rtx3090.hybrid.iso}"
DISK="${1:-}"

if [[ -z "$DISK" ]]; then
  echo "Usage: $0 /dev/diskN"
  diskutil list
  exit 1
fi

if [[ ! -f "$ISO" ]]; then
  echo "Missing ISO: $ISO"
  exit 1
fi

echo "ISO: $ISO"
diskutil info "$DISK" | egrep 'Device Identifier|Disk Size|Removable|Protocol' || true
read -r -p "Type FLASH to wipe and write $DISK: " C
[[ "$C" == "FLASH" ]] || { echo "Aborted"; exit 1; }

diskutil unmountDisk "$DISK"
RAW="${DISK/disk/rdisk}"
sudo dd if="$ISO" of="$RAW" bs=4m status=progress
sync
diskutil eject "$DISK"
echo "Done."
