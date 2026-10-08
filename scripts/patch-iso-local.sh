#!/usr/bin/env bash
# Inject StickLLM local console mode + short menus into existing hybrid ISO.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

IN="${1:-out/stickllm-amd-rtx3090.hybrid.iso}"
OUT="${2:-out/stickllm-amd-rtx3090.hybrid.iso}"
TMP_OUT="out/stickllm-amd-rtx3090.local.iso"

export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL='*'

test -f "$IN"
test -f boot/grub.cfg
test -f boot/isolinux/live.cfg
test -f overlay/usr/local/bin/stickllm-local-chat
test -f overlay/etc/systemd/system/stickllm-local.service

VOL="stickllm-iso-local-patch"
docker volume create "$VOL" >/dev/null
docker run --rm --privileged --network host \
  -v "${ROOT}:/stickllm:ro" \
  -v "${ROOT}/out:/host-out" \
  -v "${VOL}:/work" \
  debian:bookworm \
  bash -lc "
    set -e
    cp /host-out/$(basename "$IN") /work/in.iso
    bash /stickllm/scripts/lib/docker-patch-iso-local.sh /work/in.iso /work/out.iso /stickllm
    cp -f /work/out.iso /host-out/$(basename "$TMP_OUT")
  "

mv -f "$TMP_OUT" "$OUT"
ls -lh "$OUT"
echo "Patched (local mode): $OUT"
