# Flashing StickLLM to USB

**Warning:** Flashing a hybrid ISO **erases** the target USB. Confirm the device
node / disk number before writing. On this PC the removable stick often appears
as Windows drive `E:` (label `PRIVACYAI`) — verify every time.

Built image path (after `./scripts/build.sh`): `out/stickllm-amd-rtx3090.hybrid.iso`

## Linux

```bash
# Identify the USB (look for size ~64G, not your NVMe)
lsblk -d -o NAME,SIZE,MODEL,TRAN

# Example: /dev/sdX — REPLACE sdX
sudo wipefs -a /dev/sdX
sudo dd if=out/stickllm-amd-rtx3090.hybrid.iso of=/dev/sdX bs=4M status=progress oflag=sync
sudo eject /dev/sdX
```

Helper: `./scripts/flash-linux.sh /dev/sdX`

## macOS

```bash
diskutil list   # find external physical disk, e.g. /dev/disk4
diskutil unmountDisk /dev/disk4
sudo dd if=out/stickllm-amd-rtx3090.hybrid.iso of=/dev/rdisk4 bs=4m status=progress
diskutil eject /dev/disk4
```

Helper: `./scripts/flash-macos.sh /dev/disk4`

## Windows (PowerShell as Administrator)

Prefer [Rufus](https://rufus.ie/) in **DD Image** mode:

1. Select the StickLLM `.iso`.
2. Select the USB (e.g. `E:` — confirm size/label).
3. Image mode: **DD** (not ISO mode).
4. Flash, then safely eject.

Or use the helper (requires admin; uses raw disk write via `dd` from Git/WSL if available):

```powershell
.\scripts\flash-windows.ps1 -Iso .\out\stickllm-amd-rtx3090.hybrid.iso -DriveLetter E
```

The PowerShell helper will refuse to continue unless the volume is removable and
you type the confirmation string.

## After flash

1. Eject the stick.
2. Follow [BOOT.md](BOOT.md).
3. Optional: create a second partition labeled `STICKLLM-DATA` later for
   **Persist config** / **Download model** (tools guide you; not automatic).
