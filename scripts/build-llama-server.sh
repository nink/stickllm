#!/usr/bin/env bash
# Build llama-server with CUDA (sm_86 / RTX 3090) inside Docker — no GPU required to compile.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TAG="${STICKLLM_LLAMA_TAG:-b4690}"
OUT_BIN="overlay/opt/stickllm/bin/llama-server"
OUT_LIB="overlay/opt/stickllm/lib"
mkdir -p overlay/opt/stickllm/bin "$OUT_LIB"

if [[ -x "$OUT_BIN" && "${STICKLLM_FORCE_LLAMA_BUILD:-}" != "1" ]]; then
  echo "llama-server already built: $OUT_BIN"
  exit 0
fi

echo "Building llama.cpp ${TAG} with CUDA arch 86 (RTX 3090)…"

# Git Bash on Windows rewrites /work → a host path; disable that for Docker.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL='*'

docker run --rm \
  -v "${ROOT}:/work" \
  -w //work \
  nvidia/cuda:12.4.1-devel-ubuntu22.04 \
  bash -lc "
    set -euo pipefail
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      git cmake build-essential curl ca-certificates
    rm -rf /tmp/llama.cpp
    git clone --depth 1 --branch '${TAG}' https://github.com/ggerganov/llama.cpp.git /tmp/llama.cpp \
      || git clone --depth 1 https://github.com/ggerganov/llama.cpp.git /tmp/llama.cpp
    cmake -S /tmp/llama.cpp -B /tmp/llama.cpp/build \
      -DGGML_CUDA=ON \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_CUDA_ARCHITECTURES=86
    cmake --build /tmp/llama.cpp/build --target llama-server -j\"\$(nproc)\"
    install -m 755 /tmp/llama.cpp/build/bin/llama-server /work/${OUT_BIN}
    # Bundle CUDA runtime libs commonly needed beside the binary
    for lib in libcudart.so.12 libcublas.so.12 libcublasLt.so.12 libcuda.so.1; do
      p=\$(ldconfig -p | awk -v l=\"\$lib\" '\$1==l {print \$NF; exit}')
      if [[ -n \"\${p:-}\" && -f \"\$p\" ]]; then
        cp -aL \"\$p\" /work/${OUT_LIB}/ || true
      fi
    done
    # Also copy from CUDA toolkit paths
    cp -a /usr/local/cuda/lib64/libcudart.so* /work/${OUT_LIB}/ 2>/dev/null || true
    cp -a /usr/local/cuda/lib64/libcublas.so* /work/${OUT_LIB}/ 2>/dev/null || true
    cp -a /usr/local/cuda/lib64/libcublasLt.so* /work/${OUT_LIB}/ 2>/dev/null || true
    ldconfig -n /work/${OUT_LIB} || true
    /work/${OUT_BIN} --version || true
  "

echo "OK → $OUT_BIN"
ls -lh "$OUT_BIN" "$OUT_LIB" || true
