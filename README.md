# StickLLM

Bootable **Privacy AI USB** — plug in, boot a locked-down Debian live environment,
chat with a local LLM from the machine or a phone on the LAN. Nothing is written
to the USB or internal disks unless you explicitly approve a write.

**Consumer intent:** local-only inference. No cloud.

| | |
|---|---|
| Repo | [github.com/nink/stickllm](https://github.com/nink/stickllm) |
| Version | **v0.2** (shipping) · **v0.3** in progress |
| Profile | **AMD desktop CPU · 32 GB RAM · NVIDIA RTX 3090 (24 GB)** only |
| Release | [v0.2.0](https://github.com/nink/stickllm/releases/tag/v0.2.0) |

## Download v0.2 ISO (verify this hash)

ISO is on **Google Drive** (GitHub asset limit is 2 GB):  
https://drive.google.com/drive/folders/1sTgvoyQi3aU-sauolWd35bKTLGynNEd-?usp=sharing  

File: `stickllm-amd-rtx3090-v0.2.hybrid.iso`

**SHA-256** (canonical copy in [`checksums/v0.2.sha256`](checksums/v0.2.sha256)):

```
4914087d502d13327dbbd9196c9a4a7df46ee079d423ff4b0bc6280e1c7b1a48
```

```powershell
(Get-FileHash .\stickllm-amd-rtx3090-v0.2.hybrid.iso -Algorithm SHA256).Hash
```

```bash
sha256sum stickllm-amd-rtx3090-v0.2.hybrid.iso
```

If the digest does not match, do not flash — re-download or ask in the release thread.

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
| Model | **Bake:** Qwen2.5-VL-3B + mmproj (GPU) and Qwen2.5-3B (CPU). **Preferred:** Qwen3.8-27B + mmproj when VRAM ≥ 20 GB (download). 7B is download-only. Probe highlights optimum; hashes on USB. Optional web search (DuckDuckGo) via gateway |
| UI | Native StickLLM UI via gateway (pair on LAN). v0.3: TLS + vision + multi-NVIDIA + local browser |
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
| **1 StickLLM Server** | Console READY + pair code; phone/LAN browser chat (HTTPS). |
| **2 StickLLM Local (browser)** | Same-box UI (cage + cog/Chromium) — **no pair** on loopback. |
| **3 StickLLM Term** | Console login or `ssh user@<ip>` (password `stickllm`). |
| **4 StickLLM Failsafe** | No NVIDIA — recover from GPU/black-screen hangs. |

| Endpoint | Purpose |
|---|---|
| `https://<lan-ip>/` | Chat UI (pair code required on LAN) |
| `https://127.0.0.1/` | Local browser (trusted, no pair) |
| `https://<lan-ip>/v1/*` | OpenAI-compatible API (Bearer after `/api/pair`) |

Helpers on PATH: `stickllm-status`, `stickllm-persist`, `stickllm-download-model`, `stickllm-local-chat`.

## v0.2 / v0.3 on the stick

- **Native StickLLM UI only** (Open WebUI removed from the product path)  
- **Pair code** on console for LAN; same-box loopback trusted (`STICKLLM_LOCAL_TRUST`)  
- Models menu: USB DATA, probe, download, last-model restore  
- Catalog + SHA-256: VL-3B+mmproj, 27B+mmproj, 7B, 3B  

## v0.3

- **TLS** — self-signed HTTPS on :443; HTTP :80 redirects  
- **Vision** — mmproj models + image paste in native UI  
- **Local browser** — boot menu **2**: cage + cog (or Chromium) → gateway; no pair on this box  
- **Multi-NVIDIA** — `STICKLLM_MULTI_GPU=auto` uses all ≥16 GB cards with tensor split  
- Next: AMD/Intel profiles

## License

MIT — see [LICENSE](LICENSE). Third-party model weights and NVIDIA drivers remain
under their own licenses; the build scripts download them separately.
