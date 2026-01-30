# Operations and Runbook

## Starting the server (development)
- Create a `.env` from `.env.example` and fill in required tokens.
- Run in foreground:

```powershell
$env:ADMIN_API_KEY='your_key'; $env:VASTAI_API_KEY='your_vast_key'; node server/vastai-proxy.js
```

## Using pm2 (recommended for Node)
- Install pm2:

```powershell
npm i -g pm2
```

- Start with the ecosystem file:

```powershell
pm2 start ecosystem.config.js --env development
pm2 save
```

- Install log rotation with pm2:

```powershell
pm2 install pm2-logrotate
pm2 set pm2-logrotate:max_size 10M
pm2 set pm2-logrotate:retain 14
```

## Using NSSM on Windows (service)
- Download NSSM from https://nssm.cc/download and extract.
- Install service (PowerShell example):

```powershell
& 'C:\tools\nssm\win64\nssm.exe' install VastAIProxy 'C:\Program Files\nodejs\node.exe' 'C:\Users\<you>\OneDrive\Desktop\working protoype\server\vastai-proxy.js'
& 'C:\tools\nssm\win64\nssm.exe' set VastAIProxy AppEnvironmentExtra "VASTAI_API_KEY=...\nADMIN_API_KEY=..."
& 'C:\tools\nssm\win64\nssm.exe' start VastAIProxy
```

## Log rotation (PowerShell)
- `scripts/powershell/rotate-logs.ps1` rotates and prunes `logs/*.log` older than 14 days.
- To schedule daily rotate at 03:00:

```powershell
schtasks /Create /SC DAILY /TN "RotateVastProxyLogs" /TR "powershell -ExecutionPolicy Bypass -File \"C:\path\to\repo\scripts\powershell\rotate-logs.ps1\" /ST 03:00 /F
```

## Running tests
- Install dev deps (already included): `npm install`
- Run unit tests: `npm test` (uses `mocha` and `nock`)

## Running safe bundle search (no billing)
- POST `/api/proxy/bundles` with a minimal body (or no body) to list offers. The warm-pool will apply client-side filters if needed.

## Running a real prewarm
- This will create a real Vast.ai instance and may incur charges. Confirm explicitly before running.

