#!/usr/bin/env bash
# Fetch baked-default GGUFs into models/ (gitignored).
# Lite image: Qwen2.5-VL-3B + mmproj (GPU vision) and Qwen2.5-3B (CPU text).
# 7B and 27B are catalog downloads, not baked here.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fetch() {
  local repo="$1" file="$2"
  local dest="models/${file}"
  local url="https://huggingface.co/${repo}/resolve/main/${file}"
  if [[ -f "$dest" ]]; then
    echo "Already present: $dest"
    return 0
  fi
  echo "Downloading ${file}…"
  local tmp="${dest}.partial"
  curl -L --fail --progress-bar -C - -o "$tmp" "$url"
  mv "$tmp" "$dest"
}

mkdir -p models

fetch "ggml-org/Qwen2.5-VL-3B-Instruct-GGUF" "Qwen2.5-VL-3B-Instruct-Q4_K_M.gguf"
fetch "ggml-org/Qwen2.5-VL-3B-Instruct-GGUF" "mmproj-Qwen2.5-VL-3B-Instruct-Q8_0.gguf"
fetch "Qwen/Qwen2.5-3B-Instruct-GGUF" "qwen2.5-3b-instruct-q4_k_m.gguf"

verify() {
  local file="$1" expect="$2"
  local got
  if command -v sha256sum >/dev/null; then
    got="$(sha256sum "models/${file}" | awk '{print tolower($1)}')"
  elif command -v shasum >/dev/null; then
    got="$(shasum -a 256 "models/${file}" | awk '{print tolower($1)}')"
  else
    echo "WARN: no sha256 tool — skip verify for ${file}"
    return 0
  fi
  if [[ "$got" != "$expect" ]]; then
    echo "HASH MISMATCH: ${file}"
    echo "  expected ${expect}"
    echo "  got      ${got}"
    exit 5
  fi
  echo "OK sha256 ${file}"
}

verify "Qwen2.5-VL-3B-Instruct-Q4_K_M.gguf" "d02fe9b69ad8cadbbd228e387667af66612c44bed29ffc8eb1e7caf9ac486c12"
verify "mmproj-Qwen2.5-VL-3B-Instruct-Q8_0.gguf" "980c9b2f78c04e6cff93d277ada09e768394f112d75db3b4e9dea8a69f9fb904"
verify "qwen2.5-3b-instruct-q4_k_m.gguf" "626b4a6678b86442240e33df819e00132d3ba7dddfe1cdc4fbb18e0a9615c62d"

ls -lh \
  models/Qwen2.5-VL-3B-Instruct-Q4_K_M.gguf \
  models/mmproj-Qwen2.5-VL-3B-Instruct-Q8_0.gguf \
  models/qwen2.5-3b-instruct-q4_k_m.gguf
echo "OK — baked defaults: VL-3B+mmproj (GPU) / 3B text (CPU); 27B+mmproj via Models download"
