# Clean Vast.ai Provision Checklist

This document is an operator-focused checklist and quick reference for provisioning Vast.ai instances for ComfyUI-style workloads. It consolidates best practices, fixes, and commands to recover common failures (SSH, authorized_keys, ComfyUI health).

## Quick checklist
- [ ] Set environment: `VASTAI_API_KEY` and `ADMIN_API_KEY` (local server admin key).
- [ ] Ensure local SSH keypair exists: `%USERPROFILE%\.ssh\id_rsa_vast` (private) and `id_rsa_vast.pub` (public).
- [ ] Register public key with Vast.ai (console or `node scripts/register_vastai_ssh_key.js`).
- [ ] Trigger a prewarm: POST to `http://localhost:3000/api/proxy/admin/warm-pool/prewarm` with header `x-admin-key: <ADMIN_API_KEY>`.
- [ ] Poll `http://localhost:3000/api/proxy/warm-pool` until `instance` is populated and `ssh_host`/`ssh_port` appear.
- [ ] SSH test and collect logs with `scripts/collect_provision_logs.js`.
- [ ] Verify ComfyUI at `http://<IP>:8188/system_stats` and UI root.

## Common fixes (exact commands)
- Fix `authorized_keys` permissions (resolves "bad ownership or modes"):

```bash
chown -R root:root /root/.ssh
chmod 700 /root/.ssh
chown root:root /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
systemctl restart sshd || service ssh restart || /etc/init.d/ssh restart
```

- Normalize line endings (if keys were uploaded from Windows):

```bash
dos2unix /root/.ssh/authorized_keys || sed -i 's/\r$//' /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
systemctl restart sshd
```

## ComfyUI health checks
- Root UI check (quick):

```bash
curl -I --max-time 5 http://<IP>:8188/
```

- JSON health check (recommended):

```bash
curl --max-time 5 -sSf http://<IP>:8188/system_stats | jq .
```

- API probe:

```bash
curl --max-time 5 -sSf http://<IP>:8188/api/jobs || true
```

## Provisioning strategy (operator notes)
- Use Ubuntu 22.04 LTS images where possible. Avoid images that replace the SSH entrypoint.
- Ensure disk size is sufficient for models (recommended >= 120 GB; many templates use >= 400 GB).
- Use network bandwidth >= 100 Mbps (higher is better for model downloads).
- Avoid running the server from OneDrive-synced folders—use a local path to prevent locking/CRLF issues.
- Use PM2 with `pm2 update` and `pm2 restart <app> --update-env` after code/config changes.

## Quick links
- Vast.ai Quickstart: https://docs.vast.ai/documentation/get-started/quickstart
- Vast.ai Connecting to Instances: https://docs.vast.ai/documentation/instances/connect/overview
- Vast CLI (examples): https://github.com/vast-ai/vast-cli
- ComfyUI repo: https://github.com/Comfy-Org/ComfyUI
- PM2 docs: https://pm2.keymetrics.io/docs/usage/quick-start/
- OpenSSH FAQ: https://www.openssh.com/faq.html
- Ubuntu SSH keys: https://help.ubuntu.com/community/SSH/OpenSSH/Keys

---

If you want this checklist adjusted (more verbosity, add distro-specific steps, or include exact `vast-cli` commands for searching offers), tell me and I will update the file.
