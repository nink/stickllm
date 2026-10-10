#!/bin/bash
# Remaster hybrid ISO: menus + local chat + SSH + web gateway.
set -euo pipefail

IN="${1:?iso in}"
OUT="${2:?iso out}"
STICKLLM="${3:?stickllm repo root}"

export DEBIAN_FRONTEND=noninteractive
echo "[stickllm] installing patch tools..."
apt-get update -qq
apt-get install -y -qq xorriso squashfs-tools rsync ca-certificates
echo "[stickllm] tools ready"

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
  "$STICKLLM/overlay/usr/local/bin/stickllm-tls" \
  "$STICKLLM/overlay/usr/local/bin/stickllm-kiosk" \
  "$STICKLLM/overlay/usr/local/bin/stickllm-nvidia-prep" \
  "$STICKLLM/overlay/usr/local/bin/stickllm-pick-gpus" \
  "$STICKLLM/overlay/usr/local/bin/stickllm-usb-claim" \
  "$STICKLLM/overlay/usr/local/bin/stickllm-model-probe" \
  "$STICKLLM/overlay/usr/local/bin/stickllm-download-model" \
  "$STICKLLM/overlay/usr/local/bin/stickllm-select-model" \
  "$STICKLLM/overlay/usr/local/bin/stickllm-vault" \
  "$STICKLLM/overlay/usr/local/bin/stickllm-persist" \
  "$STICKLLM/overlay/usr/local/bin/stickllm-status" \
  "$STICKLLM/overlay/usr/local/bin/stickllm-pair" \
  "$STICKLLM/overlay/usr/local/bin/stickllm-control" \
  "$STICKLLM/overlay/usr/local/bin/stickllm-llama-start" \
  "$work/sq/usr/local/bin/"
rsync -a \
  "$STICKLLM/overlay/etc/systemd/system/stickllm-bootstatus.service" \
  "$STICKLLM/overlay/etc/systemd/system/stickllm-local.service" \
  "$STICKLLM/overlay/etc/systemd/system/stickllm-console-setup.service" \
  "$STICKLLM/overlay/etc/systemd/system/stickllm-ssh.service" \
  "$STICKLLM/overlay/etc/systemd/system/stickllm-ui.service" \
  "$STICKLLM/overlay/etc/systemd/system/stickllm-llama.service" \
  "$STICKLLM/overlay/etc/systemd/system/stickllm-nvidia.service" \
  "$STICKLLM/overlay/etc/systemd/system/stickllm-usb.service" \
  "$STICKLLM/overlay/etc/systemd/system/stickllm-control.service" \
  "$STICKLLM/overlay/etc/systemd/system/stickllm-tls.service" \
  "$STICKLLM/overlay/etc/systemd/system/stickllm-kiosk.service" \
  "$STICKLLM/overlay/etc/systemd/system/stickllm-openwebui.service" \
  "$work/sq/etc/systemd/system/"
# openwebui may be absent upstream; only sync if present
if [[ -f "$STICKLLM/overlay/etc/systemd/system/stickllm-openwebui-bootstrap.service" ]]; then
  rsync -a \
    "$STICKLLM/overlay/etc/systemd/system/stickllm-openwebui-bootstrap.service" \
    "$work/sq/etc/systemd/system/"
fi
# Bake getty@tty1 gate so console-setup need not daemon-reload mid-boot.
mkdir -p "$work/sq/etc/systemd/system/getty@tty1.service.d"
rsync -a \
  "$STICKLLM/overlay/etc/systemd/system/getty@tty1.service.d/stickllm-conflict.conf" \
  "$work/sq/etc/systemd/system/getty@tty1.service.d/"
# Soft-fail nvidia-persistenced when libnvidia-cfg is missing / skewed.
mkdir -p "$work/sq/etc/systemd/system/nvidia-persistenced.service.d"
rsync -a \
  "$STICKLLM/overlay/etc/systemd/system/nvidia-persistenced.service.d/stickllm-softfail.conf" \
  "$work/sq/etc/systemd/system/nvidia-persistenced.service.d/"
# NM: fail-fast carrier; short start timeout so splash cannot stick on NetworkManager.
mkdir -p "$work/sq/etc/NetworkManager/conf.d" \
  "$work/sq/etc/systemd/system/NetworkManager.service.d"
rsync -a \
  "$STICKLLM/overlay/etc/NetworkManager/conf.d/stickllm-no-block.conf" \
  "$work/sq/etc/NetworkManager/conf.d/"
rsync -a \
  "$STICKLLM/overlay/etc/systemd/system/NetworkManager.service.d/stickllm-timeout.conf" \
  "$work/sq/etc/systemd/system/NetworkManager.service.d/"
# Never stall multi-user / splash on NetworkManager DHCP wait-online (pre-chroot).
ln -sfn /dev/null "$work/sq/etc/systemd/system/NetworkManager-wait-online.service"
ln -sfn /dev/null "$work/sq/etc/systemd/system/systemd-networkd-wait-online.service"
rm -f "$work/sq/etc/systemd/system/network-online.target.wants/NetworkManager-wait-online.service"
rm -f "$work/sq/etc/systemd/system/network-online.target.wants/networking.service"
rm -f "$work/sq/etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service"
rm -f "$work/sq/lib/systemd/system/network-online.target.wants/NetworkManager-wait-online.service" 2>/dev/null || true
rm -f "$work/sq/usr/lib/systemd/system/network-online.target.wants/NetworkManager-wait-online.service" 2>/dev/null || true
mkdir -p "$work/sq/etc/ssh/sshd_config.d" "$work/sq/opt/stickllm/ui" \
  "$work/sq/etc/modprobe.d" "$work/sq/etc/modules-load.d" "$work/sq/etc/sudoers.d" \
  "$work/sq/etc/stickllm/models" "$work/sq/var/lib/stickllm/tls"
rsync -a "$STICKLLM/overlay/etc/ssh/sshd_config.d/stickllm.conf" "$work/sq/etc/ssh/sshd_config.d/"
rsync -a "$STICKLLM/overlay/etc/modprobe.d/stickllm-nvidia-alias.conf" "$work/sq/etc/modprobe.d/"
rsync -a "$STICKLLM/overlay/etc/modules-load.d/stickllm-nvidia.conf" "$work/sq/etc/modules-load.d/"
rsync -a "$STICKLLM/overlay/etc/sudoers.d/stickllm" "$work/sq/etc/sudoers.d/stickllm"
rsync -a "$STICKLLM/overlay/etc/stickllm/runtime.env" "$work/sq/etc/stickllm/runtime.env"
rsync -a "$STICKLLM/overlay/etc/stickllm/profile.toml" "$work/sq/etc/stickllm/profile.toml"
rsync -a "$STICKLLM/config/models/catalog.toml" "$work/sq/etc/stickllm/models/catalog.toml"
rsync -a "$STICKLLM/ui/" "$work/sq/opt/stickllm/ui/"
printf '%s\n' '{"mode":"ephemeral","profile":"amd-rtx3090","version":"0.3.0-dev"}' \
  >"$work/sq/opt/stickllm/ui/stickllm.json"

sed -i 's/\r$//' \
  "$work/sq/usr/local/bin/stickllm-bootstatus" \
  "$work/sq/usr/local/bin/stickllm-local-chat" \
  "$work/sq/usr/local/bin/stickllm-console-setup" \
  "$work/sq/usr/local/bin/stickllm-gateway" \
  "$work/sq/usr/local/bin/stickllm-tls" \
  "$work/sq/usr/local/bin/stickllm-kiosk" \
  "$work/sq/usr/local/bin/stickllm-nvidia-prep" \
  "$work/sq/usr/local/bin/stickllm-pick-gpus" \
  "$work/sq/usr/local/bin/stickllm-usb-claim" \
  "$work/sq/usr/local/bin/stickllm-model-probe" \
  "$work/sq/usr/local/bin/stickllm-download-model" \
  "$work/sq/usr/local/bin/stickllm-select-model" \
  "$work/sq/usr/local/bin/stickllm-vault" \
  "$work/sq/usr/local/bin/stickllm-persist" \
  "$work/sq/usr/local/bin/stickllm-status" \
  "$work/sq/usr/local/bin/stickllm-pair" \
  "$work/sq/usr/local/bin/stickllm-control" \
  "$work/sq/etc/systemd/system/"stickllm-*.service \
  "$work/sq/etc/systemd/system/getty@tty1.service.d/stickllm-conflict.conf" \
  "$work/sq/etc/systemd/system/nvidia-persistenced.service.d/stickllm-softfail.conf" \
  "$work/sq/etc/ssh/sshd_config.d/stickllm.conf" \
  "$work/sq/etc/modprobe.d/stickllm-nvidia-alias.conf" \
  "$work/sq/etc/modules-load.d/stickllm-nvidia.conf" \
  "$work/sq/etc/sudoers.d/stickllm" \
  "$work/sq/etc/stickllm/runtime.env" \
  "$work/sq/etc/stickllm/models/catalog.toml"
chmod 755 \
  "$work/sq/usr/local/bin/stickllm-bootstatus" \
  "$work/sq/usr/local/bin/stickllm-local-chat" \
  "$work/sq/usr/local/bin/stickllm-console-setup" \
  "$work/sq/usr/local/bin/stickllm-gateway" \
  "$work/sq/usr/local/bin/stickllm-tls" \
  "$work/sq/usr/local/bin/stickllm-kiosk" \
  "$work/sq/usr/local/bin/stickllm-nvidia-prep" \
  "$work/sq/usr/local/bin/stickllm-pick-gpus" \
  "$work/sq/usr/local/bin/stickllm-usb-claim" \
  "$work/sq/usr/local/bin/stickllm-model-probe" \
  "$work/sq/usr/local/bin/stickllm-download-model" \
  "$work/sq/usr/local/bin/stickllm-select-model" \
  "$work/sq/usr/local/bin/stickllm-vault" \
  "$work/sq/usr/local/bin/stickllm-persist" \
  "$work/sq/usr/local/bin/stickllm-status" \
  "$work/sq/usr/local/bin/stickllm-pair" \
  "$work/sq/usr/local/bin/stickllm-control" \
  "$work/sq/usr/local/bin/stickllm-llama-start"
chmod 644 "$work/sq/etc/systemd/system/"stickllm-*.service
chmod 644 "$work/sq/etc/ssh/sshd_config.d/stickllm.conf"
chmod 644 "$work/sq/etc/modprobe.d/stickllm-nvidia-alias.conf"
chmod 644 "$work/sq/etc/modules-load.d/stickllm-nvidia.conf"
chmod 644 "$work/sq/etc/stickllm/runtime.env"
chmod 644 "$work/sq/etc/stickllm/models/catalog.toml"
chmod 440 "$work/sq/etc/sudoers.d/stickllm"

mkdir -p "$work/sq/etc/systemd/system/multi-user.target.wants"
# Enable core units (native UI only).
# TLS oneshot is safe even when STICKLLM_TLS=0 (v0.2 HTTP bakes).
for u in stickllm-console-setup stickllm-usb stickllm-control stickllm-tls stickllm-nvidia stickllm-bootstatus stickllm-local stickllm-kiosk stickllm-ssh stickllm-ui stickllm-llama; do
  ln -sfn "/etc/systemd/system/${u}.service" \
    "$work/sq/etc/systemd/system/multi-user.target.wants/${u}.service"
done

echo "[stickllm] ensuring openssh-server + openssl in squashfs..."
mkdir -p "$work/sq/dev" "$work/sq/proc" "$work/sq/sys" "$work/sq/run" "$work/sq/dev/pts"
mount --bind /dev "$work/sq/dev"
mount -t devpts devpts "$work/sq/dev/pts" || true
mount -t proc proc "$work/sq/proc"
mount -t sysfs sys "$work/sq/sys"
mount -t tmpfs tmpfs "$work/sq/run"
cp /etc/resolv.conf "$work/sq/etc/resolv.conf"
chroot "$work/sq" /bin/bash -c "set -e; export DEBIAN_FRONTEND=noninteractive; apt-get update -qq; apt-get install -y -qq openssh-server openssh-sftp-server parted e2fsprogs openssl cage chromium fonts-dejavu-core; apt-get install -y -qq cog 2>/dev/null || echo '[stickllm] cog not in apt — Chromium kiosk fallback'; systemctl disable ssh.service 2>/dev/null || true; systemctl disable sshd.service 2>/dev/null || true; rm -f /etc/systemd/system/multi-user.target.wants/ssh.service"
umount "$work/sq/dev/pts" 2>/dev/null || true
umount "$work/sq/run" "$work/sq/sys" "$work/sq/proc" "$work/sq/dev"

# Re-assert wait-online mask AFTER chroot apt (packages can restore wants/).
echo "[stickllm] masking wait-online (post-chroot)..."
ln -sfn /dev/null "$work/sq/etc/systemd/system/NetworkManager-wait-online.service"
ln -sfn /dev/null "$work/sq/etc/systemd/system/systemd-networkd-wait-online.service"
rm -f "$work/sq/etc/systemd/system/network-online.target.wants/NetworkManager-wait-online.service"
rm -f "$work/sq/etc/systemd/system/network-online.target.wants/networking.service"
rm -f "$work/sq/etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service"
rm -f "$work/sq/lib/systemd/system/network-online.target.wants/"*wait-online* 2>/dev/null || true
rm -f "$work/sq/usr/lib/systemd/system/network-online.target.wants/"*wait-online* 2>/dev/null || true
# Ensure bootstatus / console-setup / getty drop-ins survived chroot.
rsync -a \
  "$STICKLLM/overlay/etc/systemd/system/stickllm-bootstatus.service" \
  "$STICKLLM/overlay/etc/systemd/system/stickllm-console-setup.service" \
  "$work/sq/etc/systemd/system/"
rsync -a \
  "$STICKLLM/overlay/usr/local/bin/stickllm-console-setup" \
  "$STICKLLM/overlay/usr/local/bin/stickllm-bootstatus" \
  "$work/sq/usr/local/bin/"
mkdir -p "$work/sq/etc/systemd/system/getty@tty1.service.d"
rsync -a \
  "$STICKLLM/overlay/etc/systemd/system/getty@tty1.service.d/stickllm-conflict.conf" \
  "$work/sq/etc/systemd/system/getty@tty1.service.d/"
sed -i 's/\r$//' \
  "$work/sq/usr/local/bin/stickllm-console-setup" \
  "$work/sq/usr/local/bin/stickllm-bootstatus" \
  "$work/sq/etc/systemd/system/stickllm-bootstatus.service" \
  "$work/sq/etc/systemd/system/stickllm-console-setup.service" \
  "$work/sq/etc/systemd/system/getty@tty1.service.d/stickllm-conflict.conf"
chmod 755 "$work/sq/usr/local/bin/stickllm-console-setup" "$work/sq/usr/local/bin/stickllm-bootstatus"

echo "[stickllm] rewriting boot menus..."
mkdir -p "$work/iso/boot/grub" "$work/iso/isolinux"
tr -d '\r' < "$STICKLLM/boot/grub.cfg" > "$work/iso/boot/grub/grub.cfg"
tr -d '\r' < "$STICKLLM/boot/isolinux/live.cfg" > "$work/iso/isolinux/live.cfg"
tr -d '\r' < "$STICKLLM/boot/isolinux/isolinux.cfg" > "$work/iso/isolinux/isolinux.cfg"
tr -d '\r' < "$STICKLLM/boot/isolinux/menu.cfg" > "$work/iso/isolinux/menu.cfg"
tr -d '\r' < "$STICKLLM/boot/isolinux/stdmenu.cfg" > "$work/iso/isolinux/stdmenu.cfg"
if [[ -f "$STICKLLM/boot/grub/theme.txt" ]]; then
  tr -d '\r' < "$STICKLLM/boot/grub/theme.txt" > "$work/iso/boot/grub/theme.txt"
fi
if [[ -f "$STICKLLM/boot/isolinux/splash.png" ]]; then
  cp -f "$STICKLLM/boot/isolinux/splash.png" "$work/iso/isolinux/splash.png"
  cp -f "$STICKLLM/boot/isolinux/splash.png" "$work/iso/boot/grub/splash.png"
fi

echo "[stickllm] mksquashfs..."
rm -f "$work/new/filesystem.squashfs"
# Drop -Xdict-size 100% (produced unreadable ID tables). -no-xattrs keeps image simple.
mksquashfs "$work/sq" "$work/new/filesystem.squashfs" \
  -comp xz -b 1M -noappend -no-xattrs >/dev/null
echo "[stickllm] verifying new squashfs is readable..."
unsquashfs -no-xattrs -cat "$work/new/filesystem.squashfs" \
  /etc/systemd/system/stickllm-bootstatus.service | grep -q network-online.target
test -L "$work/sq/etc/systemd/system/NetworkManager-wait-online.service"
cp -f "$work/new/filesystem.squashfs" "$work/iso/live/filesystem.squashfs"
ls -lh "$work/iso/live/filesystem.squashfs"

echo "[stickllm] rebuilding hybrid ISO..."
rm -f "$OUT"
XORRISO_ARGS=(
  -indev "$IN"
  -outdev "$OUT"
  -boot_image any replay
  -map "$work/iso/boot/grub/grub.cfg" /boot/grub/grub.cfg
  -map "$work/iso/isolinux/live.cfg" /isolinux/live.cfg
  -map "$work/iso/isolinux/isolinux.cfg" /isolinux/isolinux.cfg
  -map "$work/iso/isolinux/menu.cfg" /isolinux/menu.cfg
  -map "$work/iso/isolinux/stdmenu.cfg" /isolinux/stdmenu.cfg
  -map "$work/iso/live/filesystem.squashfs" /live/filesystem.squashfs
)
if [[ -f "$work/iso/boot/grub/theme.txt" ]]; then
  XORRISO_ARGS+=(-map "$work/iso/boot/grub/theme.txt" /boot/grub/theme.txt)
fi
if [[ -f "$work/iso/isolinux/splash.png" ]]; then
  XORRISO_ARGS+=(-map "$work/iso/isolinux/splash.png" /isolinux/splash.png)
  XORRISO_ARGS+=(-map "$work/iso/boot/grub/splash.png" /boot/grub/splash.png)
fi
XORRISO_ARGS+=(-chmod 0444 /boot/grub/grub.cfg /isolinux/live.cfg /isolinux/menu.cfg -- -commit)
xorriso "${XORRISO_ARGS[@]}"

ls -lh "$OUT"
echo "docker-patch-iso-local: OK"
