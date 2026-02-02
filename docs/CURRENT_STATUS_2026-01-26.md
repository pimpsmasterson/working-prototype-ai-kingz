**Current Status — 2026-01-26**

- **Repository:** vastai-warm-pool-proxy (local workspace)
- **Author:** Automated status generated for presentation
- **Date:** 2026-01-26

---

**Summary (top line)**: Server runs under PM2 and responds on http://localhost:3000/; PM2 management endpoints and admin UI controls were added. Warm-pool had a stale instance (contractId "555"); database was reset and server restarted. Primary remaining risk: intermittent network errors to Vast.ai causing stale instance metadata and prewarm race conditions.

**Completed since last checkpoint**
- Integrated PM2 into the project and moved `pm2` to `dependencies`.
- Added `const pm2 = require('pm2')` and PM2 programmatic admin endpoints: `POST /api/proxy/admin/pm2/restart`, `POST /api/proxy/admin/pm2/stop`, `POST /api/proxy/admin/pm2/start`, and `GET /api/proxy/admin/pm2/status`.
- Added UI controls for PM2 in `pages/admin-warm-pool.html` and client handlers in `assets/js/admin-warm-pool.js`.
- Verified PM2 launched `vastai-proxy` (example PID: 108956) and health responded: `GET /api/proxy/health` returned OK.
- Found and manually cleared a stale warm-pool DB record; restarted the server to reload state.

**Current live state (verified)**
- PM2: online, `vastai-proxy` process running (use `pm2 status` or `pm2 list`).
- Proxy health endpoint: `curl http://localhost:3000/api/proxy/health`  returns JSON with `ok: true`.
- Warm-pool DB row: `id=1` should show `instance=null` and `isPrewarming=0` (verify via `node -e "const db=require('./server/db').db; console.log(db.prepare('SELECT * FROM warm_pool WHERE id = 1').get())"`).

**Observed issues / risks**
- Stale instance metadata (contractId 555) left in DB causing `isPrewarming` stuck. Root cause: warm-pool state persisted to DB but in-memory state not always refreshed by reset endpoints; reset endpoint did not clear both DB and in-memory state in current server run.
- Network errors contacting Vast.ai (FetchError: network) cause the warm-pool module to mark an instance as problematic while still present in DB.
- Admin UI initially receives `ERR_CONNECTION_REFUSED` when the proxy is down (expected). Starting PM2 fixes this.
- Some endpoints are localhost-restricted; remote admin attempts will fail unless proxied or called from the host.

**Immediate 6-hour plan (timeline + owner: you / dev)**

Hour 0 (Now, 0-30m)
- Verify PM2/process and health endpoint. Commands: 

  - `pm2 status`
  - `curl http://localhost:3000/api/proxy/health`
  - `node -e "const db=require('./server/db').db; console.log(db.prepare('SELECT * FROM warm_pool WHERE id = 1').get());"`

- If stale state present: run DB reset and restart service:

  - `node -e "const db=require('./server/db').db; db.prepare('UPDATE warm_pool SET instance = NULL, isPrewarming = 0 WHERE id = 1').run();"`
  - `pm2 restart vastai-proxy`

Hour 0.5	60m): Stabilize warm-pool behavior
- Add a short-term fix (will commit): ensure `POST /api/proxy/admin/reset-state` both clears DB and updates in-memory `warm-pool` state or triggers a module reload. Implementation: (a) call `warmPool.load()` after DB reset OR (b) restart process via PM2 automatically after reset.
- Test: hit `POST /api/proxy/warm-pool/prewarm` and watch logs.

Hour 1.5	30	60m): Hardening and retries
- Add retry/backoff on Vast.ai API calls in warm-pool to avoid marking instance permanently on transient network errors.
- Add a periodic health-check job (every 5m) that pings the `instance` record and clears stale entries older than X minutes or with repeated network failures (configurable threshold).

Hour 3	5	300m): Demo polish and automation
- Add visual status and logs to `admin-warm-pool.html` to show recent warm-pool actions and PM2 audit entries.
- Add small script to run the full demo sequence: start/health -> prewarm -> show instance -> terminate -> reset -> restart. Place script at `scripts/demo-run.sh` (or `.ps1` for Windows) so presenters can run a single command.

Hour 5	6	360m): Rehearse + contingency
- Run 2 full dry-runs of presentation flow, measure timings, note any flaky steps.
- Prepare contingency steps: how to manually reset DB, how to force-restart PM2, and how to revert any changes.

**Commands & checks (copyable)**
- Start under PM2: `npm run start:pm2`
- Restart process: `pm2 restart vastai-proxy`
- Stop process: `pm2 stop vastai-proxy`
- Check PM2 status: `pm2 status` or `pm2 show vastai-proxy`
- Health check: `curl http://localhost:3000/api/proxy/health`
- Clear warm-pool DB (immediate reset):

  - `node -e "const db=require('./server/db').db; db.prepare('UPDATE warm_pool SET instance = NULL, isPrewarming = 0 WHERE id = 1').run(); console.log('reset');"`

**Presentation checklist (short)**
- Ensure `pm2 status`  `vastai-proxy` is `online`.
- Open admin UI and show `Server Management (PM2)` status.
- Demonstrate `Restart` (click) and show health: expect brief connection drop, then return to `ok`.
- Demonstrate `Prewarm GPU Now`: show warm-pool state changes and logs (if the live renting flow is used, warn about costs; alternatively use mock/simulated prewarm in tests).
- Show DB reset and recovery (reset button  pm2 restart if required).

**Rollback / emergency steps**
- If the proxy becomes unavailable and cannot be restarted via UI: `pm2 restart vastai-proxy` (host terminal).
- If warm-pool state is stuck: run the DB reset command above, then `pm2 restart vastai-proxy`.
- If PM2 daemon is misbehaving: `pm2 kill` then `pm2 resurrect` or re-run `npm run start:pm2`.

**Notes & follow-up items (post-presentation)**
- Implement in-code safe-reset that clears both DB and in-memory warm-pool state without full restart.
- Implement robust Vast.ai API error handling and automatic clearing for long-stale instances.
- Add unit / integration tests for warm-pool reset and prewarm flows.

---

## Update (chat activity, 2026-01-26 ~15:22 local)

**What I did during the session**
- Implemented PM2 integration and moved `pm2` into `dependencies`.
- Added `pm2` programmatic admin endpoints in `server/vastai-proxy.js` (`/api/proxy/admin/pm2/{status,start,stop,restart}`) and required admin key + localhost restrictions where appropriate.
- Added PM2 Server Management UI to `pages/admin-warm-pool.html` and client handlers in `assets/js/admin-warm-pool.js` (status, start, stop, restart buttons).
- Ran `npm install` (PM2 installed) and started the service with `npm run start:pm2`.
- Verified service health: `curl http://localhost:3000/api/proxy/health` returned OK; PM2 shows `vastai-proxy` online (example PID: 108956).
- Observed warm-pool prewarm failures due to a stale instance with `contractId: "555"` reporting network errors; manually cleared DB and restarted PM2 so in-memory state matched DB.

**Current live verification**
- PM2: online and managing `vastai-proxy`.
- Health endpoint: returns `ok: true`.
- Warm-pool DB: manual reset applied (`instance=NULL`, `isPrewarming=0`) and server restarted to reload state.

**Known remaining issues discovered in-session**
- `POST /api/proxy/admin/reset-state` did not refresh in-memory warm-pool state reliably — manual DB reset + `pm2 restart` was applied as workaround. We need an in-code fix so the reset endpoint also updates the module state (call `warmPool.load()` or directly set state and save).
- Prewarm flows sometimes return `status: already_present` or `already_prewarming` because residual DB or in-memory state wasn't cleared quickly enough. We'll add safe guards and clearer messages.
- Vast.ai network errors still surface (FetchError: network); add transient retry/backoff and an automatic clear-after-N-failures rule.

**Actions completed now**
- PM2 integration + endpoints + UI controls ✅
- `npm install` performed and PM2 process launched ✅
- Manual DB reset applied and PM2 restart to reload in-memory state ✅

**Next immediate options (pick one)**
1. Implement the **in-code safe-reset** now (30–60 minutes): update `POST /api/proxy/admin/reset-state` to clear DB and call `warmPool.load()` (or set `state` values and save), add a test, and verify via UI.
2. Add a **demo script** (`scripts/demo-run.ps1`) that runs the presentation flow automatically (start, health check, prewarm, show status, reset) — ~30 minutes.
3. Implement **auto-terminate rule** for extraction failures (`status_msg` contains "no space left on device") and add an admin alert — ~60–90 minutes.

Which should I do next? Reply with the number (1, 2, or 3) and I will start immediately.

---

File location: [docs/CURRENT_STATUS_2026-01-26.md](docs/CURRENT_STATUS_2026-01-26.md)

## Update (2026-01-31)

- **Embedded Dropbox links**: To make provisioning deterministic and reduce failures during prewarm, the known Dropbox model links were embedded directly into the provisioning scripts (`scripts/provision-core.sh` and `scripts/provision.sh`) on **2026-01-31**. The local file `data/dropbox_links.txt` was also generated and is used for overrides if present. See `docs/DROPBOX_INTEGRATION.md` for details and a list of the added models.

