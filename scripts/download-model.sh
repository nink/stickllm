#!/usr/bin/env bash
# Fetch the sole v0.1 GGUF set into models/ (gitignored).
# Qwen ships Q5_K_M as a 2-shard GGUF; llama.cpp loads shard 1 and finds shard 2.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BASE_URL="https://huggingface.co/Qwen/Qwen2.5-7B-Instruct-GGUF/resolve/main"
SHARDS=(
  "qwen2.5-7b-instruct-q5_k_m-00001-of-00002.gguf"
  "qwen2.5-7b-instruct-q5_k_m-00002-of-00002.gguf"
)

mkdir -p models
for f in "${SHARDS[@]}"; do
  DEST="models/${f}"
  if [[ -f "$DEST" ]]; then
    echo "Already present: $DEST"
    continue
  fi
  echo "Downloading ${f}…"
  TMP="${DEST}.partial"
  curl -L --fail --progress-bar -o "$TMP" "${BASE_URL}/${f}"
  mv "$TMP" "$DEST"
done

# Convenience symlink / copy name used by services
PRIMARY="models/qwen2.5-7b-instruct-q5_k_m-00001-of-00002.gguf"
LINK="models/Qwen2.5-7B-Instruct-Q5_K_M.gguf"
rm -f "$LINK"
# Relative symlink so it works inside the live image too
ln -s "$(basename "$PRIMARY")" "$LINK" 2>/dev/null || cp -f "$PRIMARY" "$LINK"

if command -v sha256sum >/dev/null; then
  sha256sum models/qwen2.5-7b-instruct-q5_k_m-*.gguf | tee models/Qwen2.5-7B-Instruct-Q5_K_M.sha256
elif command -v shasum >/dev/null; then
  shasum -a 256 models/qwen2.5-7b-instruct-q5_k_m-*.gguf | tee models/Qwen2.5-7B-Instruct-Q5_K_M.sha256
fi

ls -lh models/*.gguf
echo "OK — point llama-server at models/Qwen2.5-7B-Instruct-Q5_K_M.gguf (shard 1)"
