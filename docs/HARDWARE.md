# Known-good hardware matrix (v0.1)

Only one configuration is supported. Do not expect other GPUs/CPUs to work yet.

| Field | Required |
|---|---|
| Profile ID | `amd-rtx3090` |
| CPU | AMD desktop x86_64 (UEFI) |
| RAM | 32 GB minimum |
| GPU | NVIDIA GeForce RTX 3090 (24 GB VRAM) |
| Firmware | UEFI boot; **Secure Boot disabled** |
| Storage (host) | Not used; boot from USB only |
| USB stick | ≥ 32 GB (64 GB recommended; model + live image) |
| Network | Optional Ethernet/Wi-Fi for LAN phone clients |

## Why this profile first

- RTX 3090 (Ampere `sm_86`) has mature proprietary driver + CUDA support.
- 24 GB VRAM fits a 7B Q5 (default) with generous context headroom.
- 32 GB system RAM is enough for live OS + page cache without touching disks.

## Explicitly unsupported (for now)

- Intel / Apple Silicon hosts
- AMD GPUs, NVIDIA laptop GPUs, 8–16 GB cards
- Secure Boot enabled
- BIOS/legacy-only machines
- < 16 GB RAM

If your machine differs, wait for a later profile — do not file “won’t boot on
my 4060 laptop” as a v0.1 blocker.
