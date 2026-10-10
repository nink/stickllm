#!/usr/bin/env bash
# Reproducible StickLLM live ISO build (Debian live-build in Docker).
# Profile: amd-rtx3090 only.
#
# Important on Windows: live-build/debootstrap must run on a Docker named
# volume (Linux fs). Building directly on a OneDrive/NTFS bind mount fails
# with "Tried to extract package, but file already exists".
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PROFILE="amd-rtx3090"
ISO_NAME="stickllm-${PROFILE}.hybrid.iso"
MODEL_VL="Qwen2.5-VL-3B-Instruct-Q4_K_M.gguf"
MODEL_VL_MMPROJ="mmproj-Qwen2.5-VL-3B-Instruct-Q8_0.gguf"
MODEL_3B="qwen2.5-3b-instruct-q4_k_m.gguf"
VOL_WORK="stickllm-lb-work"

echo "=== StickLLM build (${PROFILE}) ==="
./scripts/verify-host.sh

if [[ ! -f "models/${MODEL_VL}" || ! -f "models/${MODEL_VL_MMPROJ}" || ! -f "models/${MODEL_3B}" ]]; then
  echo "Baked model files missing — fetching…"
  ./scripts/download-model.sh
fi

./scripts/build-llama-server.sh

mkdir -p out

# Git Bash on Windows rewrites Unix-style Docker paths; disable conversion.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL='*'

docker volume create "$VOL_WORK" >/dev/null

echo "Assembling live-build tree on Docker volume ${VOL_WORK}…"

docker run --rm --privileged --network host \
  -e "STICKLLM_DEBIAN_MIRROR=${STICKLLM_DEBIAN_MIRROR:-}" \
  -e "STICKLLM_DEBIAN_SECURITY_MIRROR=${STICKLLM_DEBIAN_SECURITY_MIRROR:-}" \
  -v "${ROOT}:/stickllm:ro" \
  -v "${ROOT}/out:/stickllm-out" \
  -v "${VOL_WORK}:/work" \
  -w //work \
  debian:bookworm \
  bash //stickllm/scripts/lib/docker-build-live.sh

# Prefer hybrid iso name in out/
if [[ -f "out/${ISO_NAME}" ]]; then
  :
elif compgen -G "out/*.hybrid.iso" >/dev/null; then
  shopt -s nullglob
  for f in out/*.hybrid.iso; do cp -f "$f" "out/${ISO_NAME}"; break; done
elif compgen -G "out/*.iso" >/dev/null; then
  shopt -s nullglob
  for f in out/*.iso; do cp -f "$f" "out/${ISO_NAME}"; break; done
else
  echo "ERROR: no ISO in out/"
  ls -la out/ || true
  exit 1
fi

ls -lh "out/${ISO_NAME}"
echo "=== Build complete: out/${ISO_NAME} ==="
echo "Flash with docs/FLASH.md (Windows: .\\scripts\\flash-windows.ps1 -DriveLetter E)"
