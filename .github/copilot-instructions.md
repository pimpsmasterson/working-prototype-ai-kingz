## Purpose

This file gives AI coding agents the minimal, high-value knowledge to be immediately productive in this repository.

**Big picture**
- Frontend: static pages and JS live in `assets/` and root HTML (`studio.html`, `admin-warm-pool.html`). See [studio.html](studio.html#L1).
- Server / API: Express proxy and warm-pool orchestration live under `server/` (entry: [server/vastai-proxy.js](server/vastai-proxy.js#L1)).
- Database: lightweight SQLite via `better-sqlite3` accessed in [server/db.js](server/db.js#L1).
- Tests: Mocha + Chai + NYC coverage in `tests/` and `package.json` scripts.

Key files and what to read first
- [server/vastai-proxy.js](server/vastai-proxy.js#L1) — main server, env var usage, admin endpoints.
- [server/warm-pool.js](server/warm-pool.js#L1) — GPU instance lifecycle and Vast.ai integration.
- [server/generation-handler.js](server/generation-handler.js#L1) — generation job orchestration.
- [server/db.js](server/db.js#L1) and [server/db_inspect.js](server/db_inspect.js#L1) — DB schema and inspection helpers.
- [README.md](README.md#L1) — project overview, endpoints, and quick start examples.

Developer workflows (practical commands)
- Install: `npm install` (root). See `package.json` for scripts.
- Run dev server: `npm start` (same as `node server/vastai-proxy.js`). Provide `VASTAI_API_KEY` and `ADMIN_API_KEY`.
  - PowerShell example: `$env:VASTAI_API_KEY='key'; $env:ADMIN_API_KEY='admin'; node server/vastai-proxy.js`
- Tests: `npm test` (runs `nyc mocha "tests/**/*.test.js" --exit`). Coverage: `npm run coverage`.
- E2E UI test: `npm run test:e2e:ui` (requires Chromium / Puppeteer environment).
- DB inspection: `npm run inspect-db` to run [server/db_inspect.js](server/db_inspect.js#L1).

Project-specific conventions & patterns
- Admin endpoints are guarded by `ADMIN_API_KEY` and some are restricted to localhost (see `/api/proxy/admin/*` in [server/vastai-proxy.js](server/vastai-proxy.js#L1)).
- Tokens: runtime token injection (non-persistent) via `POST /api/proxy/admin/set-tokens` — useful for local testing without storing secrets.
- Warm-pool: orchestration is optimistic and event-driven — check health checks (`/api/proxy/health`), warm-pool JSON files under `data/`, and audit logs for lifecycle tracing.
- Audit logging: HMAC-based fingerprints and an `AUDIT_SALT` env var; search `server/audit.js` for signing conventions.
- Frontend patterns: client-side JS in `assets/js/` follows imperative module files (e.g., `muse-manager-pro.js`)—use tests in `tests/` as canonical usage examples.

Integration points & external dependencies
- Vast.ai API — primary cloud GPU marketplace (see [server/warm-pool.js](server/warm-pool.js#L1)).
- Optional: Hugging Face, Civitai tokens for model downloads. Environment variables: `HUGGINGFACE_HUB_TOKEN`, `CIVITAI_TOKEN`.
- Uses `better-sqlite3` for simple, synchronous DB access — modifications are expected to be ACID but small-scale.

Debugging tips
- Health: GET `/api/proxy/health` returns quick server health. Use `curl` or PowerShell `Invoke-RestMethod`.
- Start with minimal env vars: `VASTAI_API_KEY` + `ADMIN_API_KEY` to exercise proxy endpoints locally.
- For stuck Node processes on Windows, use `taskkill /IM node.exe /F` and then restart with the correct env vars.
- Check `logs/` or run tests (`npm test`) to reproduce server behaviors; `nyc` will generate `coverage/` for failing locations.

What to avoid / not to change
- Do not change the audit hashing algorithm or `AUDIT_SALT` handling without understanding `server/audit.js` and tests that assert HMAC values.
- Warm-pool orchestration logic is sensitive to timing and Vast.ai API behaviors—prefer small, well-tested changes and simulate via `tests/`.

How to contribute a change
- Follow the repo README quick-start. Run `npm test` before pushing.
- When adding endpoints, update tests under `tests/` and include happy/failure cases that mock external APIs (see `nock` usage in tests).

If something is unclear
- Open an issue or ask for clarification and point to the specific file (example: [server/warm-pool.js](server/warm-pool.js#L1)).

---
Please review this draft and tell me which areas need more detail or additional file links.
