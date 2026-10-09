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
  "$STICKLLM/overlay/usr/local/bin/stickllm-openwebui" \
  "$STICKLLM/overlay/usr/local/bin/stickllm-openwebui-bootstrap" \
  "$STICKLLM/overlay/usr/local/bin/stickllm-nvidia-prep" \
  "$STICKLLM/overlay/usr/local/bin/stickllm-pick-gpus" \
  "$STICKLLM/overlay/usr/local/bin/stickllm-usb-claim" \
  "$STICKLLM/overlay/usr/local/bin/stickllm-model-probe" \
  "$STICKLLM/overlay/usr/local/bin/stickllm-download-model" \
  "$STICKLLM/overlay/usr/local/bin/stickllm-vault" \
  "$STICKLLM/overlay/usr/local/bin/stickllm-persist" \
  "$STICKLLM/overlay/usr/local/bin/stickllm-status" \
  "$STICKLLM/overlay/usr/local/bin/stickllm-pair" \
  "$STICKLLM/overlay/usr/local/bin/stickllm-control" \
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
  "$STICKLLM/overlay/etc/systemd/system/stickllm-openwebui.service" \
  "$STICKLLM/overlay/etc/systemd/system/stickllm-openwebui-bootstrap.service" \
  "$work/sq/etc/systemd/system/"
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
# Optional Open WebUI slim (docker save tar from scripts/fetch-openwebui-slim.ps1)
OWUI_TAR="$STICKLLM/vendor/open-webui/open-webui-slim.image.tar"
if [[ -f "$OWUI_TAR" ]]; then
  echo "[stickllm] extracting Open WebUI slim into squashfs..."
  mkdir -p "$work/sq/opt/stickllm/open-webui" "$work/owui-img"
  tar -xf "$OWUI_TAR" -C "$work/owui-img"
  python3 - "$work/owui-img" "$work/sq/opt/stickllm/open-webui" <<'PY'
import json, os, subprocess, sys, tarfile
img, dest = sys.argv[1], sys.argv[2]
manifest = json.load(open(os.path.join(img, "manifest.json")))
layers = manifest[0]["Layers"]
os.makedirs(dest, exist_ok=True)
for layer in layers:
    path = os.path.join(img, layer)
    print(f"  layer {layer}", flush=True)
    with tarfile.open(path, "r") as tf:
        # Bookworm Python 3.11 has no filter= kwarg
        tf.extractall(dest)
print("open-webui extract ok", flush=True)
PY
  if [[ -f "$STICKLLM/vendor/open-webui/bin/open-webui" ]]; then
    mkdir -p "$work/sq/opt/stickllm/open-webui/bin"
    rsync -a "$STICKLLM/vendor/open-webui/bin/open-webui" "$work/sq/opt/stickllm/open-webui/bin/"
    chmod 755 "$work/sq/opt/stickllm/open-webui/bin/open-webui"
  fi
  # Prefer image start.sh if present
  if [[ -x "$work/sq/opt/stickllm/open-webui/app/backend/start.sh" ]]; then
    mkdir -p "$work/sq/opt/stickllm/open-webui/bin"
    cat >"$work/sq/opt/stickllm/open-webui/bin/open-webui" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/app/backend"
# stickllm-openwebui passes: serve --host … --port …
# upstream start.sh ignores unknown args; export HOST/PORT instead
exec bash ./start.sh
EOF
    chmod 755 "$work/sq/opt/stickllm/open-webui/bin/open-webui"
  fi
  rm -rf "$work/owui-img"
  du -sh "$work/sq/opt/stickllm/open-webui" || true
fi
printf '%s\n' '{"mode":"ephemeral","profile":"amd-rtx3090","version":"0.2.1"}' \
  >"$work/sq/opt/stickllm/ui/stickllm.json"

sed -i 's/\r$//' \
  "$work/sq/usr/local/bin/stickllm-bootstatus" \
  "$work/sq/usr/local/bin/stickllm-local-chat" \
  "$work/sq/usr/local/bin/stickllm-console-setup" \
  "$work/sq/usr/local/bin/stickllm-gateway" \
  "$work/sq/usr/local/bin/stickllm-tls" \
  "$work/sq/usr/local/bin/stickllm-openwebui" \
  "$work/sq/usr/local/bin/stickllm-openwebui-bootstrap" \
  "$work/sq/usr/local/bin/stickllm-nvidia-prep" \
  "$work/sq/usr/local/bin/stickllm-pick-gpus" \
  "$work/sq/usr/local/bin/stickllm-usb-claim" \
  "$work/sq/usr/local/bin/stickllm-model-probe" \
  "$work/sq/usr/local/bin/stickllm-download-model" \
  "$work/sq/usr/local/bin/stickllm-vault" \
  "$work/sq/usr/local/bin/stickllm-persist" \
  "$work/sq/usr/local/bin/stickllm-status" \
  "$work/sq/usr/local/bin/stickllm-pair" \
  "$work/sq/usr/local/bin/stickllm-control" \
  "$work/sq/etc/systemd/system/"stickllm-*.service \
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
  "$work/sq/usr/local/bin/stickllm-openwebui" \
  "$work/sq/usr/local/bin/stickllm-openwebui-bootstrap" \
  "$work/sq/usr/local/bin/stickllm-nvidia-prep" \
  "$work/sq/usr/local/bin/stickllm-pick-gpus" \
  "$work/sq/usr/local/bin/stickllm-usb-claim" \
  "$work/sq/usr/local/bin/stickllm-model-probe" \
  "$work/sq/usr/local/bin/stickllm-download-model" \
  "$work/sq/usr/local/bin/stickllm-vault" \
  "$work/sq/usr/local/bin/stickllm-persist" \
  "$work/sq/usr/local/bin/stickllm-status" \
  "$work/sq/usr/local/bin/stickllm-pair" \
  "$work/sq/usr/local/bin/stickllm-control"
chmod 644 "$work/sq/etc/systemd/system/"stickllm-*.service
chmod 644 "$work/sq/etc/ssh/sshd_config.d/stickllm.conf"
chmod 644 "$work/sq/etc/modprobe.d/stickllm-nvidia-alias.conf"
chmod 644 "$work/sq/etc/modules-load.d/stickllm-nvidia.conf"
chmod 644 "$work/sq/etc/stickllm/runtime.env"
chmod 644 "$work/sq/etc/stickllm/models/catalog.toml"
chmod 440 "$work/sq/etc/sudoers.d/stickllm"

mkdir -p "$work/sq/etc/systemd/system/multi-user.target.wants"
# Enable core units. Open WebUI is ConditionPathExists — no-op until vendor bake.
# TLS oneshot is safe even when STICKLLM_TLS=0 (v0.2 HTTP bakes).
for u in stickllm-console-setup stickllm-usb stickllm-control stickllm-tls stickllm-nvidia stickllm-bootstatus stickllm-local stickllm-ssh stickllm-ui stickllm-llama stickllm-openwebui stickllm-openwebui-bootstrap; do
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
chroot "$work/sq" /bin/bash -c "set -e; export DEBIAN_FRONTEND=noninteractive; apt-get update -qq; apt-get install -y -qq openssh-server openssh-sftp-server parted e2fsprogs openssl; systemctl disable ssh.service 2>/dev/null || true; systemctl disable sshd.service 2>/dev/null || true; rm -f /etc/systemd/system/multi-user.target.wants/ssh.service"
umount "$work/sq/dev/pts" 2>/dev/null || true
umount "$work/sq/run" "$work/sq/sys" "$work/sq/proc" "$work/sq/dev"

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
