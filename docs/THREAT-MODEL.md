# Threat model (v0.1) — local-only

## What StickLLM is for

A bootable USB that turns a known-good desktop (AMD CPU + RTX 3090) into a
**local** LLM chat appliance. Prompts and completions stay on the machine and
LAN. No cloud inference.

## Assets

| Asset | Sensitivity |
|---|---|
| Chat prompts / completions | High (user private) |
| Model weights on USB | Low–medium (public GGUF) |
| LAN API (HTTP) | Medium (anyone on LAN can query) |
| Host internal disks | High — must not be written by default |
| USB stick contents | Medium — only mutate on explicit persist/download |

## Trust boundaries

1. **Boot host hardware** — you trust the AMD + 3090 machine firmware/CPU/GPU.
2. **USB image** — you trust the ISO you built/flashed from this repo.
3. **LAN clients** — phones/laptops on the same network can hit the HTTP API.
   Treat the LAN as trusted for v0.1 (no TLS, no auth).
4. **Internet** — not required at runtime. Model download is an explicit action.

## Default posture: ephemeral

- Live root and session state live in RAM overlays.
- Reboot → chats, runtime config, and temp files are gone.
- StickLLM does **not** mount/write internal disks for chat storage.
- Nothing is written to the USB unless the user runs **Persist config** or
  **Download model** (and confirms).

## Out of scope (v0.1)

- Tor / onion routing
- Mesh networking
- GrapheneOS / hardened phone client
- Auto-update of OS, drivers, or models
- Multi-user auth, TLS, or remote (WAN) exposure
- Secure Boot with signed NVIDIA modules
- Protecting against a malicious LAN peer (use a trusted network)

## Residual risks

- **Physical access** to the booted machine can read RAM/session.
- **Compromised USB build host** can inject malware into the ISO.
- **HTTP on LAN** is plaintext; shoulder-surf / Wi-Fi attacker on same LAN can
  read prompts if the network is hostile.
- **Proprietary NVIDIA driver** increases attack surface vs nouveau (required
  for 3090 CUDA performance).

## Future stubs

See README → *Future work* for Tor, mesh, Graphene client, signed Secure Boot,
and auto-update — none are implemented in v0.1.
