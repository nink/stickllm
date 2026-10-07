#!/usr/bin/env bash
# Fetch the sole v0.1 GGUF into models/ (gitignored).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MODEL_NAME="Qwen2.5-7B-Instruct-Q5_K_M.gguf"
HF_FILE="qwen2.5-7b-instruct-q5_k_m.gguf"
URL="https://huggingface.co/Qwen/Qwen2.5-7B-Instruct-GGUF/resolve/main/${HF_FILE}"
DEST="models/${MODEL_NAME}"

mkdir -p models
if [[ -f "$DEST" ]]; then
  echo "Already present: $DEST"
  ls -lh "$DEST"
  exit 0
fi

echo "Downloading ~5.4 GB GGUF (Qwen2.5-7B-Instruct Q5_K_M)…"
echo "URL: $URL"
TMP="${DEST}.partial"
curl -L --fail --progress-bar -o "$TMP" "$URL"
mv "$TMP" "$DEST"

if command -v sha256sum >/dev/null; then
  sha256sum "$DEST" | tee "models/${MODEL_NAME}.sha256"
elif command -v shasum >/dev/null; then
  shasum -a 256 "$DEST" | tee "models/${MODEL_NAME}.sha256"
fi

echo "OK → $DEST"
