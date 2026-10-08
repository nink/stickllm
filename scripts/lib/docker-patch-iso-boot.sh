#!/bin/bash
# Remaster StickLLM hybrid ISO with a fixed GRUB config (no full live-build).
set -euo pipefail

IN="${1:-/in/stickllm-amd-rtx3090.hybrid.iso}"
OUT="${2:-/out/stickllm-amd-rtx3090.hybrid.iso}"
GRUB_SRC="${3:-/stickllm/boot/grub.cfg}"

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq xorriso > /dev/null

tmp=/tmp/stickllm-patch
rm -rf "$tmp"
mkdir -p "$tmp"
cp "$GRUB_SRC" "$tmp/grub.cfg"
# Force LF
sed -i 's/\r$//' "$tmp/grub.cfg"

echo "[stickllm] patching GRUB in ISO…"
# Preserve El Torito + isohybrid boot bits; replace grub.cfg only.
xorriso -indev "$IN" -outdev "$OUT" -boot_image any replay \
  -map "$tmp/grub.cfg" /boot/grub/grub.cfg \
  -chmod 0444 /boot/grub/grub.cfg -- \
  -commit

ls -lh "$OUT"
echo "docker-patch-iso-boot: OK"
