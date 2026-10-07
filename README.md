# StickLLM

Bootable **Privacy AI USB** — plug in, boot a locked-down Debian live environment,
chat with a local LLM from the machine or a phone on the LAN. Nothing is written
to the USB or internal disks unless you explicitly approve a write.

**Consumer intent:** local-only inference. No cloud.

| | |
|---|---|
| Repo | [github.com/nink/stickllm](https://github.com/nink/stickllm) |
| Version | v0.1 MVP |
| Profile | **AMD desktop CPU · 32 GB RAM · NVIDIA RTX 3090 (24 GB)** only |

## Threat model (summary)

- Default session is **ephemeral** (RAM overlay; reboot clears chats/config).
- Inference and UI are **local / LAN HTTP** — no telemetry, no cloud API.
- **Persist config** and **Download model** require explicit confirmation.
- Full write-up: [docs/THREAT-MODEL.md](docs/THREAT-MODEL.md).

## Folder layout

```
stickllm/
├── config/profiles/amd-rtx3090.toml   # sole supported host profile
├── docs/                              # flash, boot, hardware, threat model
├── ui/                                # static chat web UI (served on :80)
├── overlay/                           # files copied into the live rootfs
├── live-build/                        # Debian live-build hooks & package lists
├── scripts/                           # build, model fetch, flash helpers
├── models/                            # GGUF cache (not in git)
└── out/                               # ISO output (not in git)
```

## Build toolchain

| Piece | Choice (v0.1) |
|---|---|
| Live OS | Debian Bookworm via **live-build** |
| Reproducible host | **Docker** (preferred) or **WSL2 Ubuntu** |
| GPU | Proprietary **NVIDIA** driver (CUDA path for 3090) |
| Inference | **llama.cpp** `llama-server` (OpenAI-compatible HTTP) |
| Model | One small **GGUF** (Qwen2.5-7B-Instruct Q5_K_M) preloaded on the stick |
| UI | Static chat page → LAN API |
| Persistence | Off by default; explicit tools only |

```bash
# On Linux or WSL2 (Docker recommended)
./scripts/verify-host.sh
./scripts/download-model.sh          # fetches GGUF into models/
./scripts/build.sh                   # produces out/stickllm-amd-rtx3090.hybrid.iso
```

Build details: [docs/BUILD.md](docs/BUILD.md) · Flash: [docs/FLASH.md](docs/FLASH.md) ·
Boot: [docs/BOOT.md](docs/BOOT.md) · Hardware: [docs/HARDWARE.md](docs/HARDWARE.md)

## Runtime (on the stick)

| Endpoint | Purpose |
|---|---|
| `http://<lan-ip>/` | Chat UI (phone-friendly) |
| `http://<lan-ip>:8080/v1/*` | OpenAI-compatible API (llama.cpp) |

Helpers on PATH: `stickllm-status`, `stickllm-persist`, `stickllm-download-model`.

## Future work (stubs only in v0.1)

- Tor / onion remote access
- Mesh networking
- GrapheneOS-hardened phone client
- Auto-update of image / models
- Secure Boot with signed NVIDIA modules
- Additional GPU profiles beyond RTX 3090

## License

MIT — see [LICENSE](LICENSE). Third-party model weights and NVIDIA drivers remain
under their own licenses; the build scripts download them separately.
