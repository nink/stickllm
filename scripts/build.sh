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
MODEL_SHARD1="qwen2.5-7b-instruct-q5_k_m-00001-of-00002.gguf"
MODEL_SHARD2="qwen2.5-7b-instruct-q5_k_m-00002-of-00002.gguf"
VOL_WORK="stickllm-lb-work"

echo "=== StickLLM build (${PROFILE}) ==="
./scripts/verify-host.sh

if [[ ! -f "models/${MODEL_SHARD1}" || ! -f "models/${MODEL_SHARD2}" ]]; then
  echo "Model shards missing — fetching…"
  ./scripts/download-model.sh
fi

./scripts/build-llama-server.sh

mkdir -p out

# Git Bash on Windows rewrites Unix-style Docker paths; disable conversion.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL='*'

docker volume create "$VOL_WORK" >/dev/null

echo "Assembling live-build tree on Docker volume ${VOL_WORK}…"

docker run --rm --privileged \
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
