# StickLLM

Bootable **Privacy AI USB** — plug in, boot a locked-down Debian live environment,
chat with a local LLM from the machine or a phone on the LAN. Nothing is written
to the USB or internal disks unless you explicitly approve a write.

**Consumer intent:** local-only inference. No cloud.

| | |
|---|---|
| Repo | [github.com/nink/stickllm](https://github.com/nink/stickllm) |
| Version | v0.2 |
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
| Model | **Base stick:** small/lite GGUF (target **16 GB** USB). **Upgrade:** VRAM + free-space probe → Hugging Face allow-list download (optimum highlighted; 30s auto). Hashes on USB. v0.1 still ships Qwen2.5-7B Q5. Optional web search (DuckDuckGo) via gateway |
| UI | Chat page on :80 → gateway (web lookup) → llama :8080 |
| Persistence | Off by default; explicit tools only |

```bash
# On Linux or WSL2 (Docker recommended)
./scripts/verify-host.sh
./scripts/download-model.sh          # fetches GGUF into models/
./scripts/build.sh                   # produces out/stickllm-amd-rtx3090.hybrid.iso
```

Build: [docs/BUILD.md](docs/BUILD.md) · Flash: [docs/FLASH.md](docs/FLASH.md) ·
Boot: [docs/BOOT.md](docs/BOOT.md) · Hardware: [docs/HARDWARE.md](docs/HARDWARE.md) ·
Models: [docs/MODELS.md](docs/MODELS.md)

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

## v0.2 on the stick

- **Pair code** on the stick screen → unlocks browser chat + Models menu (no SSH/sudo)  
- Models menu: claim USB DATA, probe VRAM, download pinned catalog entries  
- Catalog + SHA-256 for pinned Qwen2.5-7B; larger Qwen3.x entries awaiting pins  
- Optional **vault** stub; SSD cache later  
- Pairing is session/token over LAN HTTP (TLS hardening next)

## Later (v0.3+)

- **Multi-GPU** — use more than one large NVIDIA card (v0.2 defaults to one ≥16 GB GPU)  
- **AMD** (ROCm) and **Intel** GPU profiles  
- **Secure paired client** (iOS / Android) · **Tor / onion** (not a bundled commercial VPN) · mesh  
- Pin Qwen3.5 lite + Qwen3.8-27B+vision hashes · SSD cache · vault crypto  
- Secure Boot  
- Broader NVIDIA feedback on v0.2: 3090 / 4090 / 5090 class (best-effort beyond the ROMED8 3090 profile)

## License

MIT — see [LICENSE](LICENSE). Third-party model weights and NVIDIA drivers remain
under their own licenses; the build scripts download them separately.
