# Save Open WebUI slim image for Linux bake (do not extract rootfs on Windows).
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Out = if ($env:STICKLLM_OPENWEBUI_OUT) { $env:STICKLLM_OPENWEBUI_OUT } else { Join-Path $Root "vendor\open-webui" }
$Tag = if ($env:STICKLLM_OPENWEBUI_TAG) { $env:STICKLLM_OPENWEBUI_TAG } else { "main-slim" }
$Image = "ghcr.io/open-webui/open-webui:$Tag"
$Tar = Join-Path $Out "open-webui-slim.image.tar"

New-Item -ItemType Directory -Force -Path $Out | Out-Null
Write-Host "[stickllm] Open WebUI slim -> $Out (image $Image)"

docker pull $Image
if ($LASTEXITCODE -ne 0) { throw "docker pull failed for $Image" }

if (Test-Path $Tar) { Remove-Item -Force $Tar }
docker save -o $Tar $Image
if ($LASTEXITCODE -ne 0) { throw "docker save failed" }

# Marker + wrapper used after Linux extract into /opt/stickllm/open-webui
$bin = Join-Path $Out "bin"
New-Item -ItemType Directory -Force -Path $bin | Out-Null
@'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -x "$ROOT/app/backend/start.sh" ]]; then
  cd "$ROOT/app/backend"
  exec bash ./start.sh "$@"
fi
if [[ -x "$ROOT/usr/local/bin/open-webui" ]]; then
  exec "$ROOT/usr/local/bin/open-webui" "$@"
fi
echo "open-webui entrypoint not found under $ROOT (run ISO patch extract first)" >&2
exit 1
'@ | Set-Content -Path (Join-Path $bin "open-webui") -Encoding utf8

Set-Content -Path (Join-Path $Out "VERSION") -Value $Tag -Encoding ascii
Set-Content -Path (Join-Path $Out "IMAGE") -Value $Image -Encoding ascii
$mb = [math]::Round((Get-Item $Tar).Length / 1MB, 0)
Write-Host "[stickllm] saved $mb MB -> $Tar"
Write-Host "ISO patch extracts this on Linux into /opt/stickllm/open-webui"
Write-Host "Backout: STICKLLM_CHAT_FRONTEND=native"
