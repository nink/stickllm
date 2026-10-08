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
- Inference is **local**; UI/API are **LAN HTTP** (no TLS/auth in v0.1) — no cloud API.
- **Persist config** and **Download model** require explicit confirmation.
- Local ≠ safe against LAN sniffers, GPU/firmware vendors, phones, or physical access.
- **Journalists / gov / high-risk:** read limitations + **model trust** (closed & abliterated weights) in [docs/THREAT-MODEL.md](docs/THREAT-MODEL.md).

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
| Model | **Qwen2.5-7B-Instruct Q5_K_M** + optional **live web search** (DuckDuckGo) via gateway |
| UI | Chat page on :80 → gateway (web lookup) → llama :8080 |
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

Set the PC firmware to **boot the USB first** so StickLLM always wins when the
stick is plugged in (see [docs/BOOT.md](docs/BOOT.md)).

Boot menu:

| Entry | What you get |
|---|---|
| **1 StickLLM Server** | Console: Loading LLM… → READY with Chat UI + API URLs (phone/LAN). |
| **2 StickLLM Local** | Same + chat on this screen/keyboard. |
| **3 StickLLM Term** | Console login or `ssh user@<ip>` (password `stickllm`) — `nvidia-smi`, etc. |
| **4 StickLLM Failsafe** | No NVIDIA — recover from GPU/black-screen hangs (Term/SSH only). |

| Endpoint | Purpose |
|---|---|
| `http://<lan-ip>/` | Chat UI (phone-friendly) |
| `http://127.0.0.1/` | Same UI on the stick itself |
| `http://<lan-ip>:8080/v1/*` | OpenAI-compatible API (llama.cpp) |

Helpers on PATH: `stickllm-status`, `stickllm-persist`, `stickllm-download-model`, `stickllm-local-chat`.

## Future work (stubs only in v0.1)

- **Secure paired client** (iOS / Android): device pairing + encrypted tunnel to
  the stick so LAN sniffers can’t read chats. Stock phones can still peek on-device;
  **GrapheneOS** is the serious phone-side target. The StickLLM host must see
  plaintext to run inference — encryption is phone↔stick, not “hidden from the GPU box.”
- Tor / onion remote access
- Mesh networking
- Auto-update of image / models
- Secure Boot with signed NVIDIA modules
- Additional GPU profiles beyond RTX 3090 (AMD ROCm, Vulkan fallback, etc.)

## License

MIT — see [LICENSE](LICENSE). Third-party model weights and NVIDIA drivers remain
under their own licenses; the build scripts download them separately.
