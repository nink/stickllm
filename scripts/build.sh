#!/usr/bin/env bash
# Reproducible StickLLM live ISO build (Debian live-build in Docker).
# Profile: amd-rtx3090 only.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PROFILE="amd-rtx3090"
ISO_NAME="stickllm-${PROFILE}.hybrid.iso"
MODEL_SHARD1="qwen2.5-7b-instruct-q5_k_m-00001-of-00002.gguf"
MODEL_SHARD2="qwen2.5-7b-instruct-q5_k_m-00002-of-00002.gguf"
MODEL_LINK="Qwen2.5-7B-Instruct-Q5_K_M.gguf"

echo "=== StickLLM build (${PROFILE}) ==="
./scripts/verify-host.sh

if [[ ! -f "models/${MODEL_SHARD1}" || ! -f "models/${MODEL_SHARD2}" ]]; then
  echo "Model shards missing — fetching…"
  ./scripts/download-model.sh
fi

./scripts/build-llama-server.sh

mkdir -p out live-build/work
WORK="$ROOT/live-build/work"
rm -rf "$WORK"
mkdir -p "$WORK"

echo "Assembling live-build tree…"

# Git Bash on Windows rewrites Unix-style Docker paths; disable conversion.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL='*'

docker run --rm --privileged \
  -v "${ROOT}:/stickllm:ro" \
  -v "${WORK}:/work" \
  -w //work \
  debian:bookworm \
  bash -lc '
    set -euo pipefail
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends \
      live-build live-boot live-config live-config-systemd \
      ca-certificates curl git rsync xz-utils \
      squashfs-tools xorriso isolinux syslinux-common \
      grub-pc-bin grub-efi-amd64-bin mtools dosfstools

    lb clean --purge || true
    lb config \
      --architectures amd64 \
      --distribution bookworm \
      --archive-areas "main contrib non-free non-free-firmware" \
      --binary-images iso-hybrid \
      --bootloaders "grub-efi,syslinux" \
      --debian-installer false \
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

    # Overlay → includes.chroot
    mkdir -p config/includes.chroot
    rsync -a /stickllm/overlay/ config/includes.chroot/

    # UI
    mkdir -p config/includes.chroot/opt/stickllm/ui
    rsync -a /stickllm/ui/ config/includes.chroot/opt/stickllm/ui/

    # Model shards (+ stable name symlink target)
    mkdir -p config/includes.chroot/opt/stickllm/models
    cp /stickllm/models/'"${MODEL_SHARD1}"' config/includes.chroot/opt/stickllm/models/
    cp /stickllm/models/'"${MODEL_SHARD2}"' config/includes.chroot/opt/stickllm/models/
    ln -sf '"${MODEL_SHARD1}"' config/includes.chroot/opt/stickllm/models/'"${MODEL_LINK}"'

    # Profile
    mkdir -p config/includes.chroot/etc/stickllm
    cp /stickllm/config/profiles/amd-rtx3090.toml config/includes.chroot/etc/stickllm/profile.toml

    # Ensure llama binary + libs present
    test -x config/includes.chroot/opt/stickllm/bin/llama-server

    # Boot menu branding
    mkdir -p config/bootloaders/grub-pc
    mkdir -p config/bootloaders/grub-efi
    cat > config/bootloaders/grub-efi/grub.cfg <<EOF
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
menuentry "StickLLM failsafe (nomodeset — diagnose only)" {
    linux /live/vmlinuz boot=live components username=user hostname=stickllm nomodeset noeject nopersistence
    initrd /live/initrd.img
}
EOF
    cp config/bootloaders/grub-efi/grub.cfg config/bootloaders/grub-pc/grub.cfg

    echo "[stickllm] lb build (long)…"
    lb build

    ls -lh
  '

# Collect ISO
shopt -s nullglob
FOUND=("$WORK"/*.hybrid.iso "$WORK"/*.iso)
if [[ ${#FOUND[@]} -eq 0 ]]; then
  echo "ERROR: no ISO produced in $WORK"
  ls -la "$WORK" || true
  exit 1
fi
cp -f "${FOUND[0]}" "out/${ISO_NAME}"
ls -lh "out/${ISO_NAME}"
echo "=== Build complete: out/${ISO_NAME} ==="
echo "Flash with docs/FLASH.md (Windows: .\\scripts\\flash-windows.ps1 -DriveLetter E)"
