#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ISO="${ISO:-$ROOT/out/stickllm-amd-rtx3090.hybrid.iso}"
DEV="${1:-}"

if [[ -z "$DEV" ]]; then
  echo "Usage: $0 /dev/sdX"
  lsblk -d -o NAME,SIZE,MODEL,TRAN,RM
  exit 1
fi

if [[ ! -f "$ISO" ]]; then
  echo "Missing ISO: $ISO — run ./scripts/build.sh first"
  exit 1
fi

if [[ ! -b "$DEV" ]]; then
  echo "Not a block device: $DEV"
  exit 1
fi

RM="$(lsblk -dn -o RM "$DEV")"
if [[ "$RM" != "1" ]]; then
  echo "Refusing: $DEV is not removable"
  exit 1
fi

echo "ISO: $ISO"
lsblk -o NAME,SIZE,MODEL,LABEL "$DEV"
read -r -p "Type FLASH to wipe and write $DEV: " C
[[ "$C" == "FLASH" ]] || { echo "Aborted"; exit 1; }

sudo wipefs -a "$DEV"
sudo dd if="$ISO" of="$DEV" bs=4M status=progress oflag=sync
sync
echo "Done. Eject and boot (Secure Boot off)."
