#!/bin/bash
# Runs inside debian:bookworm.
# /stickllm = repo (ro), /work = Linux filesystem volume (rw) for live-build.
set -euo pipefail

MODEL_SHARD1="qwen2.5-7b-instruct-q5_k_m-00001-of-00002.gguf"
MODEL_SHARD2="qwen2.5-7b-instruct-q5_k_m-00002-of-00002.gguf"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  live-build live-boot live-config live-config-systemd \
  ca-certificates curl rsync xz-utils \
  squashfs-tools xorriso isolinux syslinux-common \
  grub-pc-bin grub-efi-amd64-bin mtools dosfstools

cd /work
rm -rf /work/*
lb clean --purge || true

lb config \
  --architectures amd64 \
  --distribution bookworm \
  --archive-areas "main contrib non-free non-free-firmware" \
  --binary-images iso-hybrid \
  --bootloaders "grub-efi,syslinux" \
  --debian-installer none \
  --apt-recommends false \
  --firmware-binary true \
  --firmware-chroot true \
  --memtest none \
  --iso-application "StickLLM" \
  --iso-volume "STICKLLM" \
  --iso-publisher "nink" \
  --linux-packages "linux-image linux-headers" \
  --debootstrap-options "--variant=minbase" \
  --chroot-squashfs-compression-type xz

mkdir -p config/package-lists
cp /stickllm/live-build/package-lists/stickllm.list.chroot config/package-lists/

mkdir -p config/hooks/normal
cp /stickllm/live-build/hooks/normal/*.hook.chroot config/hooks/normal/
chmod +x config/hooks/normal/*.hook.chroot

# Overlay into includes.chroot (after lb config created the tree)
mkdir -p config/includes.chroot
rsync -a /stickllm/overlay/ config/includes.chroot/

mkdir -p config/includes.chroot/opt/stickllm/ui
rsync -a /stickllm/ui/ config/includes.chroot/opt/stickllm/ui/

mkdir -p config/includes.chroot/opt/stickllm/models
cp "/stickllm/models/${MODEL_SHARD1}" config/includes.chroot/opt/stickllm/models/
cp "/stickllm/models/${MODEL_SHARD2}" config/includes.chroot/opt/stickllm/models/

mkdir -p config/includes.chroot/etc/stickllm
cp /stickllm/config/profiles/amd-rtx3090.toml config/includes.chroot/etc/stickllm/profile.toml

test -x config/includes.chroot/opt/stickllm/bin/llama-server
test -f config/includes.chroot/opt/stickllm/lib/libllama-server-impl.so
test -f "config/includes.chroot/opt/stickllm/models/${MODEL_SHARD1}"

mkdir -p config/bootloaders/grub-pc config/bootloaders/grub-efi
cat > config/bootloaders/grub-efi/grub.cfg <<'EOF'
set default=0
set timeout=8
menuentry "StickLLM ephemeral (amd-rtx3090) [default]" {
    linux /live/vmlinuz boot=live components quiet username=user hostname=stickllm noeject nopersistence
    initrd /live/initrd.img
}
menuentry "StickLLM with persistence (only if you ran stickllm-persist)" {
    linux /live/vmlinuz boot=live components quiet username=user hostname=stickllm noeject persistence persistence-label=STICKLLM-DATA
    initrd /live/initrd.img
}
menuentry "StickLLM failsafe (nomodeset - diagnose only)" {
    linux /live/vmlinuz boot=live components username=user hostname=stickllm nomodeset noeject nopersistence
    initrd /live/initrd.img
}
EOF
cp config/bootloaders/grub-efi/grub.cfg config/bootloaders/grub-pc/grub.cfg

echo "[stickllm] lb build (long)…"
lb build

mkdir -p /stickllm-out
shopt -s nullglob
for f in /work/*.hybrid.iso /work/*.iso; do
  cp -f "$f" /stickllm-out/
  ls -lh "$f"
done
echo "docker-build-live: OK"
