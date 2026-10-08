# Booting StickLLM (UEFI)

## Before you boot

1. Flash the ISO (see [FLASH.md](FLASH.md)).
2. On the AMD + RTX 3090 desktop (e.g. LAN host `.70`):
   - Enter firmware setup (Del / F2 / F10 — vendor specific).
   - **Disable Secure Boot** (required for v0.1 proprietary NVIDIA modules).
   - Prefer **UEFI** boot; disable CSM/Legacy if the board allows.
   - Use the one-time boot menu (F11 / F12 / F8 / Esc) and pick the entry that
     looks like **UEFI: Samsung…** / **UEFI USB Hard Disk** — not a plain
     “USB” legacy entry and not the internal Windows disk.
   - Try a rear **USB2** port if USB3 ports are ignored.
3. Leave internal disks alone — StickLLM will not use them for storage by default.

If Windows on the internal disk comes back up, the firmware never selected the
stick (or Secure Boot blocked it). That is a firmware/boot-menu issue, not a
missing ISO.

## Boot sequence (expected)

1. UEFI loads GRUB from the stick.
2. Select **StickLLM (ephemeral)** — default.
3. Debian live boots to a minimal desktop/console session.
4. NVIDIA driver loads; `nvidia-smi` shows the RTX 3090.
5. `llama-server` starts with the bundled GGUF.
6. Chat UI listens on `http://<lan-ip>/` and API on `http://<lan-ip>:8080/`.

## First checks on the stick

```bash
stickllm-status          # services, GPU, model path, LAN URL
nvidia-smi               # must list RTX 3090
curl -s localhost:8080/health
```

From a phone on the same LAN, open the URL printed by `stickllm-status`.

## If it fails

| Symptom | Likely cause |
|---|---|
| Firmware ignores USB | Secure Boot still on; wrong USB port; legacy boot |
| Black screen after GRUB | GPU init; try `nomodeset` only for diagnosis — CUDA needs proprietary driver |
| `nvidia-smi` missing GPU | Driver package mismatch; confirm profile `amd-rtx3090` image |
| UI up, empty replies | Model file missing — run **Download model** with network, or reflash with model baked in |
| Phone cannot connect | Firewall / wrong IP / AP client isolation |

## Persist vs ephemeral

- Default menu entry: ephemeral (RAM overlay; reboot wipes session).
- **Persist config** (explicit): enables a labeled data partition for config only.
- Chats still default to non-durable unless you export them (v0.1 has no chat DB sync).
