# How We Push to Gist and Run Fresh Start

**Use this every time you change `scripts/provision-reliable.sh` and want remote instances to use the new script, then start a fresh instance.**

---

## 1. Push provision-reliable.sh to Gist

**Easiest: run the push script (tries API first, then git from Gist clone):**

```powershell
cd "c:\Users\samsc\OneDrive\Desktop\working protoype"
.\scripts\push-provision-to-gist.ps1
```

- **API method:** Set `GITHUB_TOKEN` or `GH_TOKEN` in `.env` (GitHub PAT with **Gists** scope; fine-grained: Gists write). The script uses `Bearer` and GitHub’s recommended headers. On success it prints the raw URL; put that in `COMFYUI_PROVISION_SCRIPT`.
- **Git method:** If the API fails or no token, the script copies `scripts/provision-reliable.sh` into the Gist clone, clears `http.proxy` / `url.insteadOf` in that repo (so push doesn’t hit 127.0.0.1:9), then `git add` / `commit` / `push` and prints the commit hash and the line to add to `.env`.

**Manual (Gist clone at `%TEMP%\gist-c3f61f20067d498b6699d1bdbddea395`):**

```powershell
Copy-Item "c:\Users\samsc\OneDrive\Desktop\working protoype\scripts\provision-reliable.sh" -Destination "$env:TEMP\gist-c3f61f20067d498b6699d1bdbddea395\provision-reliable.sh" -Force
cd "$env:TEMP\gist-c3f61f20067d498b6699d1bdbddea395"
git config --local http.proxy ""; git config --local https.proxy ""
git add provision-reliable.sh
git commit -m "Sync provision-reliable.sh: latest updates from workspace"
git push origin main
$commitHash = git log -1 --format="%H"; Write-Host "COMFYUI_PROVISION_SCRIPT=.../raw/$commitHash/provision-reliable.sh"
```

**Gist details:**
- **Gist ID:** `c3f61f20067d498b6699d1bdbddea395`
- **Raw script URL pattern:** `https://gist.githubusercontent.com/pimpsmasterson/c3f61f20067d498b6699d1bdbddea395/raw/<COMMIT_HASH>/provision-reliable.sh`

---

## 2. Update .env with the new commit

Edit [.env](.env) and set:

```env
COMFYUI_PROVISION_SCRIPT=https://gist.githubusercontent.com/pimpsmasterson/c3f61f20067d498b6699d1bdbddea395/raw/<COMMIT_HASH>/provision-reliable.sh
```

Replace `<COMMIT_HASH>` with the value from step 1 (e.g. `b4ff81a405d15a0a54d24bd186f81ee3f07ffac3`).

---

## 3. Run fresh start (prewarm)

So the **proxy uses the new .env** and rents a **new instance** that will run the script you just pushed.

**Important:** If you already terminated the previous instance (e.g. in Vast.ai dashboard) but the proxy was restarted, the proxy’s DB may still think an instance exists. Prewarm then returns `already_present` and **does not rent a new machine**. So for a true fresh start you must **reset state first**, then prewarm.

```powershell
# Restart proxy to load new COMFYUI_PROVISION_SCRIPT
cd "c:\Users\samsc\OneDrive\Desktop\working protoype"
pm2 restart vastai-proxy --update-env

# REQUIRED when you want a new instance after deleting the old one: clear warm pool state
$adminKey = "64d94046-d1b0-447d-9b2d-55b2d5bf0744"  # from .env ADMIN_API_KEY
Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/admin/reset-state" -Method POST -Headers @{ "x-admin-key" = $adminKey; "Content-Type" = "application/json" } -Body "{}"

# Start a new instance (prewarm)
Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/admin/warm-pool/prewarm" -Method POST -Headers @{ "x-admin-key" = $adminKey; "Content-Type" = "application/json" } -Body "{}" -TimeoutSec 120
```

If the proxy was stopped, start it first:

```powershell
npm run start:pm2
```

Then run the prewarm request above.

---

## One-shot summary (after editing provision-reliable.sh)

1. Push script to Gist (copy → git add → commit → push).
2. Put the new commit hash into `.env` → `COMFYUI_PROVISION_SCRIPT`.
3. Restart proxy: `pm2 restart vastai-proxy --update-env`.
4. Trigger prewarm: `POST .../api/proxy/admin/warm-pool/prewarm` with admin key.

---

## Access ComfyUI when Cloudflare tunnel failed

If provisioning completed but the tunnel step failed (e.g. **429 Too Many Requests**), use an **SSH tunnel** so your browser can reach ComfyUI.

**Option A – By instance ID (if vastai CLI is installed):**

```powershell
cd "c:\Users\samsc\OneDrive\Desktop\working protoype"
.\scripts\open-comfy-vastai.ps1 -InstanceId 30957355
```

Replace `30957355` with your instance ID from the [Vast.ai dashboard](https://cloud.vast.ai/instances/). The script will open http://localhost:8080 when the tunnel is ready. Leave the PowerShell window open; press Ctrl+C to close the tunnel.

**Option B – Manual (SSH host + port from dashboard):**

1. Open [Vast.ai Instances](https://cloud.vast.ai/instances/), click your instance.
2. Note **SSH Addr** (e.g. `ssh2.vast.ai`) and **SSH Port** (e.g. `19860`).
3. Run:

```powershell
cd "c:\Users\samsc\OneDrive\Desktop\working protoype"
.\scripts\connect-comfy.ps1 -RemoteHost ssh2.vast.ai -SshPort 19860 -Key "$env:USERPROFILE\.ssh\id_rsa_vast" -LocalPort 8080
```

4. Open **http://localhost:8080** in your browser.

---

## Why no instance was rented?

1. **Stale warm pool state (most common)**  
   You terminated the instance on Vast.ai, but the proxy’s `warm_pool.db` still has that contract. Prewarm sees “instance already present” and returns without calling the rent API.  
   **Fix:** Call `POST .../api/proxy/admin/reset-state` (with admin key) before prewarm.

2. **No offers pass filters**  
   Requirements (e.g. `WARM_POOL_DISK_GB=600`, verified host, 16GB VRAM, max price) may leave zero offers.  
   **Fix:** Check `pm2 logs vastai-proxy` for “bundle search attempt … found X total, Y matching”. If Y is 0, relax disk/price in `.env` or try again later.

3. **Rent API errors**  
   Vast.ai can return no_such_ask, rate limit, or other errors.  
   **Fix:** Same logs; look for “Attempting to rent offer” and any error lines after it.

---

**Reference:** [.env](.env) (ADMIN_API_KEY, COMFYUI_PROVISION_SCRIPT), [scripts/provision-reliable.sh](scripts/provision-reliable.sh).
