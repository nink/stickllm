# Known-good hardware matrix

## v0.2 (current)

| Field | Required |
|---|---|
| Profile ID | `amd-rtx3090` |
| CPU | AMD desktop x86_64 |
| RAM | 32 GB minimum (62 GB class OK) |
| GPU | NVIDIA GeForce RTX 3090 (24 GB VRAM) |
| Firmware | USB-first boot recommended; Secure Boot off for NVIDIA modules |
| Storage (host) | Not used by default |
| USB stick | **16 GB** OK for base; **32–64 GB** recommended so first-boot can claim free space as `STICKLLM-DATA` for model downloads |
| Network | Optional LAN for phone clients; needed for model upgrades |

Default baked model today: **Qwen2.5-7B Instruct Q5_K_M** (text). First boot claims USB free space; catalog-pinned downloads verify SHA-256.

## Target model tiers (by VRAM)

See [MODELS.md](MODELS.md). Planned defaults:

| VRAM | Qwen series | Role |
|---|---|---|
| RAM-only / failsafe | 3.5 lite | Survival / slow CPU |
| 8 GB | 3.5 ~8B | Small GPU |
| 12 GB | 3.5 ~14B | Mid |
| 16 GB | 3.8 (compact quant) | Large |
| **24 GB** | **3.8-27B Q4_K_M + vision** | **Default multipurpose** |

## Why 3090 first

- Mature CUDA path (`sm_86`)
- 24 GB fits 27B Q4 + vision with headroom
- Dual-3090 machines need careful `CUDA_VISIBLE_DEVICES` (single large GPU by default)

## Explicitly unsupported (for now)

- Intel / Apple Silicon hosts as first-class profiles  
- AMD GPUs (ROCm profile later)  
- Secure Boot with signed NVIDIA modules  
- Automatic use of internal disks (SSD cache is future **opt-in** only)  
