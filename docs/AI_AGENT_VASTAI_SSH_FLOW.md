# 🤖 AI Agent Guide: 100% Success SSH & Provisioning Flow for Vast.ai

This document defines the exact, fail-proof command flow that any AI agent should follow to connect to, diagnose, and provision a Vast.ai GPU instance.

---

## 🏗️ Phase 1: Key & Identity Verification
Before attempting any SSH command, the agent **MUST** verify the identity file.

1.  **Check Local Keys**:
    ```powershell
    Get-ChildItem $env:USERPROFILE\.ssh\id_vast*
    ```
    *   `id_vast` (ED25519) is preferred over older RSA keys.
    *   Verify the `.pub` file content.

2.  **Verify Vast.ai Registration**:
    Fetch the registered keys from Vast.ai API and compare the fingerprints.
    *   Endpoint: `https://console.vast.ai/api/v0/ssh/`
    *   Auth: `Authorization: Bearer <VASTAI_API_KEY>`

---

## 📡 Phase 2: Connectivity & Firewall Check
Vast.ai hosts often have firewalls. You must distinguish between a **Security Block** and a **Timing Issue**.

1.  **Port Ping**:
    ```powershell
    Test-NetConnection -ComputerName <SSH_HOST> -Port <SSH_PORT>
    ```
    *   **FAILED**: The host is likely behind a firewall. Move to Cloudflare Tunnel reporting or warn the USER.
    *   **SUCCESS**: The port is open. Proceed to Auth.

2.  **The "Timing" Window**:
    Instance `onstart` scripts take **60-120 seconds** to inject your SSH key.
    *   If you get `Permission denied (publickey)`, **WAIT**. Do not assume the key is wrong yet. Try every 15 seconds for 2 minutes.

---

## 🔑 Phase 3: The "Magic" SSH Command
Use these specific flags to prevent hangs and ensure the correct identity is used.

```powershell
ssh -i $env:USERPROFILE\.ssh\id_vast -p <PORT> -o StrictHostKeyChecking=no -o ConnectTimeout=10 root@<HOST> "<COMMAND>"
```

*   **`-i`**: Explicitly force the correct key.
*   **`-o StrictHostKeyChecking=no`**: Avoid prompts for host Fingerprints.
*   **`-o ConnectTimeout=10`**: Fail fast if the network is dead.

---

## 🛠️ Phase 4: Provisioning & Token Injection
If the instance is "Ready" but ComfyUI isn't starting, the `onstart` script likely failed due to missing tokens.

1.  **Verify Provisioner Log**:
    ```powershell
    ssh ... "tail -n 50 /workspace/provision_image.log"
    ```

2.  **Force Restart with Tokens**:
    If the script is missing tokens (Environment variables don't always persist in `onstart`), run this exact block:
    ```powershell
    ssh -i $env:USERPROFILE\.ssh\id_vast -p <PORT> root@<HOST> "export CIVITAI_TOKEN='<VALUE>'; export HUGGINGFACE_HUB_TOKEN='<VALUE>'; bash /tmp/provision.sh"
    ```

## ⚡ Phase 5: Systemd vs. Background Process
Most Vast.ai Docker images (like `vastai/comfy`) **DO NOT** support `systemd`. Attempting to use `systemctl` will fail.

1.  **Detection**:
    ```bash
    command -v systemctl >/dev/null 2>&1 && systemctl status >/dev/null 2>&1
    ```
    *   **FAILED**: You must use `setsid nohup <command> > log.txt 2>&1 < /dev/null &`.
    *   **SUCCESS**: You can use `systemctl enable --now <service>`.

2.  **Manual Background Start (The "Survival" Block)**:
    If things aren't starting, run this for both ComfyUI and Cloudflare:
    ```bash
    setsid nohup cloudflared tunnel --url http://localhost:8188 > /workspace/cloudflared.log 2>&1 < /dev/null &
    ```

---

## ⚠️ Common AI Pitfalls (Anti-Slop Check)
*   **Don't ignore the error type**: `Connection refused` = Port Closed. `Permission Denied` = Key wrong or still loading.
*   **Don't assume `/workspace` exists**: Check `/workspace` first; if it's missing, use `~/workspace`.
*   **Don't kill the shell**: When running a long provision, use a background command status checker or `tail -f`.

---

## ✅ Final Success Marker
An agent's job is not done until the **Tunnel URL** is retrieved:
```powershell
ssh ... "cat /workspace/tunnel_url.txt"
```
Once you have the `.trycloudflare.com` URL, provide it to the user immediately.
