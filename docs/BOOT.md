# Booting StickLLM

## Always prefer the USB (recommended)

Plugging the stick in does **not** force USB boot by itself. The PC firmware
boot order does.

On the AMD/ROMED8 host (`.70`):

1. Enter firmware setup (Del / F2).
2. Put the **Samsung / STICKLLM USB** above the NVMe (Ubuntu).
3. Save & exit.

Until that is set, Ubuntu’s GRUB will keep winning after Ctrl+Alt+Del. You can
still chainload StickLLM from Ubuntu GRUB, but USB-first is the reliable default.

## StickLLM boot menu

| # | Entry | What you get |
|---|---|---|
| **1** | **StickLLM** | LAN mode. Console shows **Loading LLM…** then **READY** with Chat UI + API URLs. Use a phone/browser. |
| **2** | **StickLLM local chat** | Same services + console chat on this screen/keyboard. |
| **3** | **StickLLM terminal + SSH** | Login on the console, or `ssh user@<ip>` — check `nvidia-smi`, `stickllm-status`. |
| **4** | **StickLLM failsafe** | NVIDIA blacklisted + SSH/terminal for diagnosis. |

Timeout is short (~5–8s); default is **1 StickLLM**.

### Terminal / SSH credentials (menu 3)

| | |
|---|---|
| User | `user` |
| Password | `stickllm` |
| Useful | `stickllm-status` · `nvidia-smi` · `curl -s localhost:8080/health` |

SSH is **off** unless you pick menu **3** (or failsafe).

## Boot sequence (expected)

1. Firmware boots the USB (or Ubuntu GRUB → StickLLM entry).
2. StickLLM menu → pick 1 / 2 / 3.
3. Console: **Loading LLM…** (3–6 min cold boot on a 3090 is normal).
4. **READY** with `http://<lan-ip>/` and API on port **8080**.
5. Blank cursor during NVIDIA load is normal; watch the status lines.

## First checks

```bash
stickllm-status
nvidia-smi
curl -s localhost:8080/health
```

Phone on the same LAN: open the Chat UI URL from the READY screen.

## If it fails

| Symptom | Likely cause |
|---|---|
| Lands in Ubuntu | Firmware boot order — USB not first |
| Firmware ignores USB | Wrong port; try USB2; Secure Boot |
| Black screen, no status | GPU init hang — reboot, pick **4 failsafe** |
| UI up, empty replies | Model missing — rebuild with model baked in |
| Phone cannot connect | Wrong IP / AP client isolation |

## Persist vs ephemeral

- Default: ephemeral (RAM; reboot wipes session).
- **Persist config** is explicit only (`stickllm-persist`).
