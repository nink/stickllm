#!/bin/bash
# Remaster hybrid ISO: menus + local chat + SSH + web gateway.
set -euo pipefail

IN="${1:?iso in}"
OUT="${2:?iso out}"
STICKLLM="${3:?stickllm repo root}"

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq xorriso squashfs-tools rsync ca-certificates > /dev/null

work=/tmp/stickllm-local-patch
rm -rf "$work"
mkdir -p "$work/iso" "$work/sq" "$work/new"

echo "[stickllm] extracting ISO tree..."
xorriso -osirrox on -indev "$IN" -extract / "$work/iso"

SQ="$work/iso/live/filesystem.squashfs"
test -f "$SQ"

echo "[stickllm] unsquashfs..."
unsquashfs -f -d "$work/sq" "$SQ" >/dev/null

echo "[stickllm] injecting overlay..."
rsync -a \
  "$STICKLLM/overlay/usr/local/bin/stickllm-bootstatus" \
  "$STICKLLM/overlay/usr/local/bin/stickllm-local-chat" \
  "$STICKLLM/overlay/usr/local/bin/stickllm-console-setup" \
  "$STICKLLM/overlay/usr/local/bin/stickllm-gateway" \
  "$work/sq/usr/local/bin/"
rsync -a \
  "$STICKLLM/overlay/etc/systemd/system/stickllm-bootstatus.service" \
  "$STICKLLM/overlay/etc/systemd/system/stickllm-local.service" \
  "$STICKLLM/overlay/etc/systemd/system/stickllm-console-setup.service" \
  "$STICKLLM/overlay/etc/systemd/system/stickllm-ssh.service" \
  "$STICKLLM/overlay/etc/systemd/system/stickllm-ui.service" \
  "$work/sq/etc/systemd/system/"
mkdir -p "$work/sq/etc/ssh/sshd_config.d" "$work/sq/opt/stickllm/ui"
rsync -a "$STICKLLM/overlay/etc/ssh/sshd_config.d/stickllm.conf" "$work/sq/etc/ssh/sshd_config.d/"
rsync -a "$STICKLLM/ui/" "$work/sq/opt/stickllm/ui/"

sed -i 's/\r$//' \
  "$work/sq/usr/local/bin/stickllm-bootstatus" \
  "$work/sq/usr/local/bin/stickllm-local-chat" \
  "$work/sq/usr/local/bin/stickllm-console-setup" \
  "$work/sq/usr/local/bin/stickllm-gateway" \
  "$work/sq/etc/systemd/system/"stickllm-*.service \
  "$work/sq/etc/ssh/sshd_config.d/stickllm.conf"
chmod 755 \
  "$work/sq/usr/local/bin/stickllm-bootstatus" \
  "$work/sq/usr/local/bin/stickllm-local-chat" \
  "$work/sq/usr/local/bin/stickllm-console-setup" \
  "$work/sq/usr/local/bin/stickllm-gateway"
chmod 644 "$work/sq/etc/systemd/system/"stickllm-*.service
chmod 644 "$work/sq/etc/ssh/sshd_config.d/stickllm.conf"

mkdir -p "$work/sq/etc/systemd/system/multi-user.target.wants"
for u in stickllm-console-setup stickllm-bootstatus stickllm-local stickllm-ssh; do
  ln -sfn "/etc/systemd/system/${u}.service" \
    "$work/sq/etc/systemd/system/multi-user.target.wants/${u}.service"
done
# UI unit already enabled from original image; refresh symlink
ln -sfn /etc/systemd/system/stickllm-ui.service \
  "$work/sq/etc/systemd/system/multi-user.target.wants/stickllm-ui.service"

echo "[stickllm] ensuring openssh-server in squashfs..."
mkdir -p "$work/sq/dev" "$work/sq/proc" "$work/sq/sys" "$work/sq/run" "$work/sq/dev/pts"
mount --bind /dev "$work/sq/dev"
mount -t devpts devpts "$work/sq/dev/pts" || true
mount -t proc proc "$work/sq/proc"
mount -t sysfs sys "$work/sq/sys"
mount -t tmpfs tmpfs "$work/sq/run"
cp /etc/resolv.conf "$work/sq/etc/resolv.conf"
chroot "$work/sq" /bin/bash -c "set -e; export DEBIAN_FRONTEND=noninteractive; apt-get update -qq; apt-get install -y -qq openssh-server openssh-sftp-server; systemctl disable ssh.service 2>/dev/null || true; systemctl disable sshd.service 2>/dev/null || true; rm -f /etc/systemd/system/multi-user.target.wants/ssh.service"
umount "$work/sq/dev/pts" 2>/dev/null || true
umount "$work/sq/run" "$work/sq/sys" "$work/sq/proc" "$work/sq/dev"

echo "[stickllm] rewriting boot menus..."
mkdir -p "$work/iso/boot/grub" "$work/iso/isolinux"
tr -d '\r' < "$STICKLLM/boot/grub.cfg" > "$work/iso/boot/grub/grub.cfg"
tr -d '\r' < "$STICKLLM/boot/isolinux/live.cfg" > "$work/iso/isolinux/live.cfg"
if [[ -f "$STICKLLM/boot/isolinux/isolinux.cfg" ]]; then
  tr -d '\r' < "$STICKLLM/boot/isolinux/isolinux.cfg" > "$work/iso/isolinux/isolinux.cfg"
fi
if [[ -f "$STICKLLM/boot/isolinux/menu.cfg" ]]; then
  tr -d '\r' < "$STICKLLM/boot/isolinux/menu.cfg" > "$work/iso/isolinux/menu.cfg"
fi

echo "[stickllm] mksquashfs..."
rm -f "$work/new/filesystem.squashfs"
mksquashfs "$work/sq" "$work/new/filesystem.squashfs" -comp xz -b 1M -Xdict-size 100% -noappend >/dev/null
cp -f "$work/new/filesystem.squashfs" "$work/iso/live/filesystem.squashfs"

echo "[stickllm] rebuilding hybrid ISO..."
rm -f "$OUT"
XORRISO_ARGS=(
  -indev "$IN"
  -outdev "$OUT"
  -boot_image any replay
  -map "$work/iso/boot/grub/grub.cfg" /boot/grub/grub.cfg
  -map "$work/iso/isolinux/live.cfg" /isolinux/live.cfg
  -map "$work/iso/live/filesystem.squashfs" /live/filesystem.squashfs
)
if [[ -f "$work/iso/isolinux/isolinux.cfg" ]]; then
  XORRISO_ARGS+=(-map "$work/iso/isolinux/isolinux.cfg" /isolinux/isolinux.cfg)
fi
if [[ -f "$work/iso/isolinux/menu.cfg" ]]; then
  XORRISO_ARGS+=(-map "$work/iso/isolinux/menu.cfg" /isolinux/menu.cfg)
fi
XORRISO_ARGS+=(-chmod 0444 /boot/grub/grub.cfg /isolinux/live.cfg -- -commit)
xorriso "${XORRISO_ARGS[@]}"

ls -lh "$OUT"
echo "docker-patch-iso-local: OK"
