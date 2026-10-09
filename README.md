# StickLLM

Bootable **Privacy AI USB** — plug in, boot a locked-down Debian live environment,
chat with a local LLM from the machine or a phone on the LAN. Nothing is written
to the USB or internal disks unless you explicitly approve a write.

**Consumer intent:** local-only inference. No cloud.

| | |
|---|---|
| Repo | [github.com/nink/stickllm](https://github.com/nink/stickllm) |
| Version | **v0.2** (shipping) · v0.3 in progress in-tree |
| Profile | **AMD desktop CPU · 32 GB RAM · NVIDIA RTX 3090 (24 GB)** only |

## Threat model (summary)

- Default session is **ephemeral** (RAM overlay; reboot clears chats/config).
- Inference is **local**; UI/API are **LAN HTTP + pair code** in v0.2 (TLS in v0.3) — no cloud API.
- **Persist config** and **Download model** require explicit confirmation.
- Local ≠ safe against LAN sniffers (v0.2), GPU/firmware vendors, phones, or physical access.
- **Journalists / gov / high-risk:** read limitations + **model trust** (closed & abliterated weights) in [docs/THREAT-MODEL.md](docs/THREAT-MODEL.md).

## Folder layout

```
stickllm/
├── config/profiles/amd-rtx3090.toml   # sole supported host profile
├── docs/                              # flash, boot, hardware, threat model
├── ui/                                # StickLLM chat UI (v0.2: HTTP :80)
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
| UI | v0.2: HTTP gateway :80 (pair) → StickLLM UI → llama. v0.3: TLS + optional Open WebUI |
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

| Endpoint (v0.2) | Purpose |
|---|---|
| `http://<lan-ip>/` | Chat UI (pair code required) |
| `http://<lan-ip>/v1/*` | OpenAI-compatible API via gateway (paired) |

Helpers on PATH: `stickllm-status`, `stickllm-persist`, `stickllm-download-model`, `stickllm-local-chat`.

## v0.2 on the stick

- **Pair code on console while loading** (and on READY) — no timer flicker  
- Models menu: claim USB DATA, probe VRAM, download pinned catalog entries  
- StickLLM native chat UI only (no Open WebUI in v0.2)  
- Catalog + SHA-256 for pinned Qwen2.5-7B  

## v0.3 (in progress — not in the Drive v0.2 ISO)

- **TLS** — self-signed HTTPS on :443  
- **Open WebUI trial** — optional; `STICKLLM_CHAT_FRONTEND=native` backout  
- Local kiosk browser (cage + Chromium) for on-box WebUI  
- **Vision** mmproj · multi-GPU · AMD/Intel profiles

## License

MIT — see [LICENSE](LICENSE). Third-party model weights and NVIDIA drivers remain
under their own licenses; the build scripts download them separately.
