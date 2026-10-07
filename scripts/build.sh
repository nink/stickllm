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

echo "=== StickLLM build (${PROFILE}) ==="
./scripts/verify-host.sh

if [[ ! -f "models/${MODEL_SHARD1}" || ! -f "models/${MODEL_SHARD2}" ]]; then
  echo "Model shards missing — fetching…"
  ./scripts/download-model.sh
fi

./scripts/build-llama-server.sh

mkdir -p out
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
  bash //stickllm/scripts/lib/docker-build-live.sh

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
