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

MIRROR="${STICKLLM_DEBIAN_MIRROR:-http://deb.debian.org/debian/}"
SEC_MIRROR="${STICKLLM_DEBIAN_SECURITY_MIRROR:-http://security.debian.org/debian-security/}"

lb config \
  --architectures amd64 \
  --distribution bookworm \
  --archive-areas "main contrib non-free non-free-firmware" \
  --parent-archive-areas "main contrib non-free non-free-firmware" \
  --mirror-bootstrap "$MIRROR" \
  --mirror-chroot "$MIRROR" \
  --mirror-binary "$MIRROR" \
  --parent-mirror-bootstrap "$MIRROR" \
  --parent-mirror-chroot "$MIRROR" \
  --parent-mirror-binary "$MIRROR" \
  --mirror-chroot-security "$SEC_MIRROR" \
  --mirror-binary-security "$SEC_MIRROR" \
  --parent-mirror-chroot-security "$SEC_MIRROR" \
  --parent-mirror-binary-security "$SEC_MIRROR" \
  --binary-images iso-hybrid \
  --bootloaders "grub-efi,syslinux" \
  --debian-installer none \
  --apt-recommends false \
  --apt-indices true \
  --firmware-binary true \
  --firmware-chroot true \
  --memtest none \
  --iso-application "StickLLM" \
  --iso-volume "STICKLLM" \
  --iso-publisher "nink" \
  --linux-packages "linux-image linux-headers" \
  --chroot-squashfs-compression-type xz

echo "[stickllm] mirrors: $MIRROR / $SEC_MIRROR"
cat config/archives/*.list.chroot 2>/dev/null || true

mkdir -p config/package-lists
# Write package list inside the Linux volume (never copy CRLF from Windows).
cat > config/package-lists/stickllm.list.chroot <<'PKGS'
# StickLLM v0.1 amd-rtx3090
live-boot
live-config
live-config-systemd
systemd-sysv
sudo
curl
wget
ca-certificates
pciutils
usbutils
network-manager
openssh-client
parted
e2fsprogs
fdisk
util-linux
python3
jq
iproute2
iputils-ping
libgomp1
firmware-linux
firmware-linux-nonfree
firmware-misc-nonfree
nvidia-driver
nvidia-driver-libs
nvidia-kernel-dkms
nvidia-smi
libcuda1
nvidia-persistenced
PKGS

mkdir -p config/hooks/normal
for h in /stickllm/live-build/hooks/normal/*.hook.chroot; do
  base="$(basename "$h")"
  tr -d '\r' < "$h" > "config/hooks/normal/$base"
  chmod +x "config/hooks/normal/$base"
done

# Overlay into includes.chroot (after lb config created the tree)
mkdir -p config/includes.chroot
rsync -a /stickllm/overlay/ config/includes.chroot/
# systemd rejects unit files marked executable (common on Windows mounts)
find config/includes.chroot/etc/systemd -type f -name '*.service' -exec chmod 644 {} +
find config/includes.chroot/usr/local/bin -type f -exec chmod 755 {} +
find config/includes.chroot/etc/sudoers.d -type f -exec chmod 440 {} +

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
# Prefer tracked boot/grub.cfg (LF). Fall back to inline copy if missing.
if [[ -f /stickllm/boot/grub.cfg ]]; then
  tr -d '\r' < /stickllm/boot/grub.cfg > config/bootloaders/grub-efi/grub.cfg
else
  cp /dev/null config/bootloaders/grub-efi/grub.cfg
fi
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
