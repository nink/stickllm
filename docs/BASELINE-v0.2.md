# StickLLM shipping baseline (v0.2)

## What boots the working pair screen

- **Samsung Type-C USB** — golden runtime image. Never wipe it.
- Image identity: hybrid ISO volume id `STICKLLM`, Drive **v0.2**.
- **ISO SHA-256:** `4914087d502d13327dbbd9196c9a4a7df46ee079d423ff4b0bc6280e1c7b1a48`
- Local copy path: `out/stickllm-amd-rtx3090.hybrid.iso` (must match that hash).

## Source code that matches that stick

The stick is a **baked ISO**, not a git checkout. Map runtime → source as:

- Git tag **`v0.2.0`** → commit **`c63fadc`**
- Branch tip for development: **`main`** restored to that product tree (plus docs/checksums)
- Exact tag pointer: branch **`stickllm-v0.2-base`**

Do **not** use unfinished v0.3 work as the base. Park experiments on **`wip/v0.3-broken`**.

## Flash other sticks

Prefer `dd`/raw write of the **hash-verified** hybrid ISO onto the spare stick (VendorCo).  
Do not flash NVMe or the Seagate backup drive. Do not flash Samsung when cloning outward—read Samsung only if the local ISO hash does not match Drive.

## Boot back to the pair screen

1. Plug the StickLLM USB (Samsung or VendorCo with v0.2).
2. Host firmware: USB boot, **Secure Boot off** (see `docs/BOOT.md`).
3. Boot menu entry for StickLLM live → wait for console **pair code**.
4. Open the LAN UI and enter the pair code.
