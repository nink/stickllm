#!/usr/bin/env bash
# Save Open WebUI slim image tar for Linux ISO bake (prefer .ps1 on Windows).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${STICKLLM_OPENWEBUI_OUT:-$ROOT/vendor/open-webui}"
TAG="${STICKLLM_OPENWEBUI_TAG:-main-slim}"
IMAGE="ghcr.io/open-webui/open-webui:${TAG}"
TAR="$OUT/open-webui-slim.image.tar"

mkdir -p "$OUT/bin"
echo "[stickllm] Open WebUI slim -> $OUT (image $IMAGE)"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required to save the slim image." >&2
  exit 1
fi

docker pull "$IMAGE"
docker save -o "$TAR" "$IMAGE"

cat >"$OUT/bin/open-webui" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -x "$ROOT/app/backend/start.sh" ]]; then
  cd "$ROOT/app/backend"
  exec bash ./start.sh
fi
echo "open-webui not extracted yet" >&2
exit 1
EOF
chmod 755 "$OUT/bin/open-webui"
printf '%s\n' "$TAG" >"$OUT/VERSION"
printf '%s\n' "$IMAGE" >"$OUT/IMAGE"
ls -lh "$TAR"
echo "[stickllm] done — ISO patch extracts this into /opt/stickllm/open-webui"
echo "Backout: STICKLLM_CHAT_FRONTEND=native"
