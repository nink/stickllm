# Building the ISO

## Host requirements

- Docker Desktop (Linux containers) with ≥ 20 GB free disk
- Bash (Git Bash on Windows, or Linux/macOS)
- Network (first build pulls Debian packages, CUDA devel image, GGUF ~5.4 GB)

WSL2 Ubuntu is optional. On this workstation the preferred path is **Git Bash + Docker Desktop**.

## One-shot

```bash
./scripts/verify-host.sh
./scripts/download-model.sh      # ~5.4 GB Q5_K_M (2 shards)
./scripts/build-llama-server.sh  # CUDA sm_86 llama-server in nvidia/cuda container
./scripts/build.sh               # Debian live-build → out/stickllm-amd-rtx3090.hybrid.iso
```

Or: `./scripts/build.sh` (calls the above as needed).

## What the ISO contains

- Debian Bookworm live (UEFI hybrid)
- Proprietary NVIDIA driver stack for RTX 3090
- `/opt/stickllm/bin/llama-server` + CUDA runtime libs
- Bundled Qwen2.5-7B-Instruct Q5_K_M GGUF
- Chat UI on `:80`, API on `:8080`
- Default boot: **ephemeral** (`nopersistence`)

## Timing (rough)

| Step | Time |
|---|---|
| Model download | 5–30 min (bandwidth) |
| llama-server CUDA compile | 15–40 min |
| live-build ISO | 30–90 min |

## Windows note

If Ubuntu WSL is broken, do not repair it just for StickLLM — use Git Bash:

`"C:\Program Files\Git\bin\bash.exe" -lc "./scripts/build.sh"`

`live-build` **must** run on a Docker named volume (`stickllm-lb-work`), not on a
OneDrive/NTFS bind mount. `scripts/build.sh` already does this. Building on the
Windows filesystem fails during debootstrap with
`Tried to extract package, but file already exists`.
