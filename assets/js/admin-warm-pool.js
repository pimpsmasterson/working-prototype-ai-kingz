(function () {
  const statusBox = document.getElementById('statusBox');
  const adminKeyInput = document.getElementById('adminKey');
  const btnRefresh = document.getElementById('btnRefresh');
  const btnSave = document.getElementById('btnSave');
  const desiredSizeInput = document.getElementById('desiredSize');
  const safeModeInput = document.getElementById('safeMode');
  const controls = document.getElementById('controls');
  const btnTerminate = document.getElementById('btnTerminate');
  const btnPrewarm = document.getElementById('btnPrewarm');
  const prewarmStatus = document.getElementById('prewarmStatus');
  const currentInstance = document.getElementById('currentInstance');
  const instanceStatus = document.getElementById('instanceStatus');
  const gpuSpecs = document.getElementById('gpuSpecs');
  const gpuCost = document.getElementById('gpuCost');
  const setupProgress = document.getElementById('setupProgress');
  const progressFill = document.getElementById('progressFill');

  // New elements for enhanced UI
  const poolSection = document.getElementById('poolSection');
  const configSection = document.getElementById('configSection');
  const btnShowPool = document.getElementById('btnShowPool');
  const btnShowConfig = document.getElementById('btnShowConfig');
  const btnShowLogs = document.getElementById('btnShowLogs');
  const btnHealthCheck = document.getElementById('btnHealthCheck');
  const healthCheckResults = document.getElementById('healthCheckResults');
  const healthStatus = document.getElementById('healthStatus');
  const healthDetails = document.getElementById('healthDetails');
  const btnLoadConfig = document.getElementById('btnLoadConfig');
  const btnUpdateConfig = document.getElementById('btnUpdateConfig');
  const configForm = document.getElementById('configForm');
  const configDisplay = document.getElementById('configDisplay');
  const configJson = document.getElementById('configJson');
  const hfToken = document.getElementById('hfToken');
  const civitaiToken = document.getElementById('civitaiToken');
  const provisionScript = document.getElementById('provisionScript');
  const minCudaCap = document.getElementById('minCudaCap');
  const btnSaveConfig = document.getElementById('btnSaveConfig');
  const btnCancelConfig = document.getElementById('btnCancelConfig');

  const btnResetState = document.getElementById('btnResetState');
  const proxyStatusDot = document.getElementById('proxyStatusDot');
  const proxyStatusText = document.getElementById('proxyStatusText');

  // PM2 Server Management elements
  const btnPm2Status = document.getElementById('btnPm2Status');
  const btnPm2Restart = document.getElementById('btnPm2Restart');
  const btnPm2Stop = document.getElementById('btnPm2Stop');
  const btnPm2Start = document.getElementById('btnPm2Start');
  const pm2StatusText = document.getElementById('pm2StatusText');
  const pm2StatusDisplay = document.getElementById('pm2StatusDisplay');
  const pm2Result = document.getElementById('pm2Result');

  // API base - ensure admin page works even when served from a static server (e.g., port 5501)
  const API_BASE = (window.__API_BASE__ || 'http://localhost:3000');

  async function parseJsonOrThrow(res) {
    const ct = res.headers.get('content-type') || '';
    if (ct.includes('application/json')) return await res.json();
    const text = await res.text();
    throw new Error('Unexpected server response: ' + text);
  }

  let prewarmInterval = null;

  function showStatus(text, danger) {
    statusBox.textContent = text;
    statusBox.className = 'status' + (danger ? ' danger' : '');
  }

  function showPrewarmStatus(text, type = 'info') {
    prewarmStatus.textContent = text;
    prewarmStatus.className = 'status ' + type;
    prewarmStatus.style.display = 'block';
  }

  async function fetchStatus() {
    const key = adminKeyInput.value;
    if (!key) { showStatus('Provide admin key above', true); poolSection.style.display = 'none'; return; }
    try {
      const r = await fetch(API_BASE + '/api/proxy/admin/warm-pool', { headers: { 'x-admin-key': key } });
      if (r.status === 403) { showStatus('Forbidden - invalid admin key', true); poolSection.style.display = 'none'; return; }
      const j = await parseJsonOrThrow(r);
      showStatus(JSON.stringify(j, null, 2));
      desiredSizeInput.value = j.desiredSize || 0;
      safeModeInput.checked = !!j.safeMode;
      poolSection.style.display = 'block';

      // Update GPU status cards
      updateGpuStatus(j);
    } catch (e) {
      showStatus('Fetch failed: ' + e, true);
      poolSection.style.display = 'none';
      updateProxyStatus(false);
    }
  }

  async function checkProxyStatus() {
    try {
      const res = await fetch(API_BASE + '/api/proxy/health', { method: 'GET' });
      updateProxyStatus(res.ok);
    } catch (err) {
      updateProxyStatus(false);
    }
  }

  function updateProxyStatus(isUp) {
    if (isUp) {
      proxyStatusDot.textContent = '🟢';
      proxyStatusText.textContent = 'Running';
      proxyStatusText.style.color = 'green';
    } else {
      proxyStatusDot.textContent = '🔴';
      proxyStatusText.textContent = 'Down (Failed to fetch)';
      proxyStatusText.style.color = 'red';
    }
  }

  async function resetProxyState() {
    const key = adminKeyInput.value;
    if (!key) { alert('Enter admin key first'); return; }

    if (!confirm('This will clear the cached instance state in the proxy database. It will NOT terminate real GPUs, but the proxy will "forget" about them until they are found during next prewarm or health check. Proceed?')) return;

    try {
      btnResetState.disabled = true;
      btnResetState.textContent = 'Resetting...';

      const r = await fetch(API_BASE + '/api/proxy/admin/reset-state', {
        method: 'POST',
        headers: { 'x-admin-key': key, 'Content-Type': 'application/json' }
      });

      const j = await r.json();
      if (r.ok) {
        alert('✅ ' + (j.message || 'State reset successfully.'));
        fetchStatus();
      } else {
        alert('❌ Error: ' + (j.error || 'Failed to reset'));
      }
    } catch (err) {
      alert('❌ Fetch error: ' + err.message);
    } finally {
      btnResetState.disabled = false;
      btnResetState.textContent = 'Reset WarmPool State (Clear Cache)';
    }
  }

  function updateGpuStatus(data) {
    if (data.instance) {
      currentInstance.textContent = `Contract ${data.instance.contractId}`;
      instanceStatus.textContent = data.instance.status;
      instanceStatus.className = 'status ' + (data.instance.status === 'ready' ? 'success' : 'warning');
      gpuSpecs.textContent = data.instance.gpuName || 'Unknown';
      gpuCost.textContent = `Cost: $${(data.instance.dph || 0).toFixed(3)}/hr`;

      if (data.instance.status === 'loading') {
        setupProgress.textContent = 'Provisioning ComfyUI and models...';
        progressFill.style.width = '50%';
      } else if (data.instance.status === 'ready') {
        setupProgress.textContent = 'Ready for NSFW generation!';
        progressFill.style.width = '100%';
      } else {
        setupProgress.textContent = data.instance.status;
        progressFill.style.width = '25%';
      }
    } else {
      currentInstance.textContent = 'None';
      instanceStatus.textContent = 'No active instance';
      instanceStatus.className = 'status';
      gpuSpecs.textContent = 'N/A';
      gpuCost.textContent = 'Cost: $0/hr';
      setupProgress.textContent = 'Not started';
      progressFill.style.width = '0%';
    }
  }

  async function prewarmGpu() {
    const key = adminKeyInput.value;
    if (!key) { showPrewarmStatus('Provide admin key first', 'danger'); return; }

    btnPrewarm.disabled = true;
    btnPrewarm.textContent = 'Starting...';
    showPrewarmStatus('Initiating GPU rental...', 'info');

    try {
      const r = await fetch(API_BASE + '/api/proxy/warm-pool/prewarm', {
        method: 'POST',
        headers: { 'x-admin-key': key, 'Content-Type': 'application/json' },
        body: '{}'
      });

      if (r.status === 403) {
        showPrewarmStatus('Forbidden - invalid admin key', 'danger');
        return;
      }

      const j = await parseJsonOrThrow(r);
      if (j.status === 'started') {
        showPrewarmStatus('GPU rental initiated! Monitoring setup progress...', 'success');
        startPrewarmPolling(key);
      } else {
        showPrewarmStatus('Failed to start: ' + JSON.stringify(j), 'danger');
      }
    } catch (e) {
      showPrewarmStatus('Prewarm failed: ' + e, 'danger');
    } finally {
      btnPrewarm.disabled = false;
      btnPrewarm.textContent = 'Prewarm GPU Now';
    }
  }

  function startPrewarmPolling(key) {
    if (prewarmInterval) clearInterval(prewarmInterval);
    prewarmInterval = setInterval(async () => {
      try {
        const r = await fetch(API_BASE + '/api/proxy/admin/warm-pool', { headers: { 'x-admin-key': key } });
        if (r.ok) {
          const j = await parseJsonOrThrow(r);
          updateGpuStatus(j);
          if (j.instance && j.instance.status === 'ready') {
            showPrewarmStatus('GPU is ready for NSFW generation!', 'success');
            clearInterval(prewarmInterval);
            prewarmInterval = null;
          } else if (j.instance && j.instance.status === 'failed') {
            showPrewarmStatus('GPU setup failed', 'danger');
            clearInterval(prewarmInterval);
            prewarmInterval = null;
          }
        }
      } catch (e) {
        console.error('Polling error:', e);
      }
    }, 10000); // Poll every 10 seconds
  }

  async function saveSettings() {
    const key = adminKeyInput.value;
    const body = { desiredSize: Number(desiredSizeInput.value), safeMode: !!safeModeInput.checked };
    try {
      const r = await fetch(API_BASE + '/api/proxy/admin/warm-pool', { method: 'POST', headers: { 'x-admin-key': key, 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
      const j = await parseJsonOrThrow(r);
      showStatus('Saved: ' + JSON.stringify(j));
    } catch (e) { showStatus('Save failed: ' + e, true); }
  }

  async function terminateInstance() {
    const key = adminKeyInput.value;
    if (!confirm('Terminate current warm instance?')) return;
    try {
      const r = await fetch(API_BASE + '/api/proxy/warm-pool/terminate', { method: 'POST', headers: { 'x-admin-key': key, 'Content-Type': 'application/json' }, body: '{}' });
      const j = await parseJsonOrThrow(r);
      showStatus('Terminate: ' + JSON.stringify(j));
      updateGpuStatus({}); // Clear status
    } catch (e) { showStatus('Terminate failed: ' + e, true); }
  }

  btnRefresh.addEventListener('click', fetchStatus);
  btnSave.addEventListener('click', saveSettings);
  btnTerminate.addEventListener('click', terminateInstance);
  btnPrewarm.addEventListener('click', prewarmGpu);

  // Navigation handlers
  btnShowPool.addEventListener('click', () => showSection('pool'));
  btnShowConfig.addEventListener('click', () => showSection('config'));
  btnShowLogs.addEventListener('click', () => showSection('logs'));

  // Health check handler
  btnHealthCheck.addEventListener('click', runHealthCheck);

  // Config handlers
  btnLoadConfig.addEventListener('click', loadConfig);
  btnUpdateConfig.addEventListener('click', showConfigForm);
  btnSaveConfig.addEventListener('click', saveConfig);
  btnCancelConfig.addEventListener('click', hideConfigForm);

  function showSection(section) {
    poolSection.style.display = section === 'pool' ? 'block' : 'none';
    configSection.style.display = section === 'config' ? 'block' : 'none';
    document.getElementById('logsSectionContainer').style.display = section === 'logs' ? 'block' : 'none';
  }

  async function runHealthCheck() {
    const key = adminKeyInput.value;
    if (!key) { showStatus('Provide admin key first', true); return; }

    healthCheckResults.style.display = 'block';
    healthStatus.textContent = 'Running comprehensive health check...';
    healthStatus.className = 'status info';
    healthDetails.textContent = '';

    try {
      const r = await fetch(API_BASE + '/api/proxy/admin/warm-pool/health', {
        headers: { 'x-admin-key': key }
      });

      if (r.status === 403) {
        healthStatus.textContent = 'Forbidden - invalid admin key';
        healthStatus.className = 'status danger';
        return;
      }

      const health = await parseJsonOrThrow(r);

      // Check if all critical health checks passed
      const criticalChecks = ['comfyui_api', 'gpu_available', 'gpu_functional', 'models_loaded'];
      const allPassed = criticalChecks.every(check => health[check]);

      healthStatus.textContent = allPassed ?
        '✅ All health checks passed!' :
        '❌ Some health checks failed';
      healthStatus.className = 'status ' + (allPassed ? 'success' : 'danger');

      // Display detailed results
      healthDetails.textContent = JSON.stringify(health, null, 2);

    } catch (e) {
      healthStatus.textContent = 'Health check failed: ' + e.message;
      healthStatus.className = 'status danger';
      healthDetails.textContent = e.stack || '';
    }
  }

  async function loadConfig() {
    const key = adminKeyInput.value;
    if (!key) { showStatus('Provide admin key first', true); return; }

    try {
      const r = await fetch(API_BASE + '/api/proxy/admin/config', {
        headers: { 'x-admin-key': key }
      });

      if (r.status === 403) {
        showStatus('Forbidden - invalid admin key', true);
        return;
      }

      const config = await parseJsonOrThrow(r);
      configJson.textContent = JSON.stringify(config, null, 2);
      configDisplay.style.display = 'block';
      showStatus('Configuration loaded successfully');

    } catch (e) {
      showStatus('Failed to load config: ' + e.message, true);
    }
  }

  function showConfigForm() {
    configForm.style.display = 'block';
    configDisplay.style.display = 'none';
    // Pre-populate with current values if available
    // Note: tokens are masked in the API response for security
  }

  function hideConfigForm() {
    configForm.style.display = 'none';
  }

  async function saveConfig() {
    const key = adminKeyInput.value;
    if (!key) { showStatus('Provide admin key first', true); return; }

    const configData = {
      huggingface_token: hfToken.value || undefined,
      civitai_token: civitaiToken.value || undefined,
      provision_script_url: provisionScript.value || undefined,
      min_cuda_capability: minCudaCap.value ? parseFloat(minCudaCap.value) : undefined
    };

    // Remove undefined values
    Object.keys(configData).forEach(k => {
      if (configData[k] === undefined) delete configData[k];
    });

    try {
      const r = await fetch(API_BASE + '/api/proxy/admin/config', {
        method: 'POST',
        headers: {
          'x-admin-key': key,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(configData)
      });

      const result = await parseJsonOrThrow(r);

      if (r.ok) {
        showStatus('Configuration updated successfully');
        hideConfigForm();
        // Reload config display
        loadConfig();
      } else {
        showStatus('Failed to update config: ' + JSON.stringify(result), true);
      }

    } catch (e) {
      showStatus('Failed to save config: ' + e.message, true);
    }
  }

  btnSaveConfig.addEventListener('click', saveConfig);
  btnCancelConfig.addEventListener('click', hideConfigForm);
  btnResetState.addEventListener('click', resetProxyState);

  // PM2 Server Management Functions
  async function checkPm2Status() {
    const key = adminKeyInput.value;
    if (!key) {
      showPm2Result('Provide admin key first', 'danger');
      return;
    }

    try {
      pm2StatusText.textContent = 'Checking...';
      const r = await fetch(API_BASE + '/api/proxy/admin/pm2/status', {
        headers: { 'x-admin-key': key }
      });

      if (r.status === 403) {
        showPm2Result('Forbidden - invalid admin key', 'danger');
        pm2StatusText.textContent = 'Auth failed';
        return;
      }

      const j = await parseJsonOrThrow(r);

      if (j.managed) {
        pm2StatusText.textContent = j.status + ' (PID: ' + j.pid + ', Restarts: ' + j.restarts + ')';
        pm2StatusDisplay.className = 'status ' + (j.status === 'online' ? 'success' : 'warning');

        let details = 'Process: ' + j.name + '\n';
        details += 'Status: ' + j.status + '\n';
        details += 'PID: ' + j.pid + '\n';
        details += 'Restarts: ' + j.restarts + '\n';
        if (j.uptime) details += 'Uptime: ' + Math.floor(j.uptime / 1000) + 's\n';
        if (j.memory) details += 'Memory: ' + Math.round(j.memory / 1024 / 1024) + ' MB\n';
        if (j.cpu !== null) details += 'CPU: ' + j.cpu + '%';

        showPm2Result(details, 'info');
      } else {
        pm2StatusText.textContent = 'Not managed by PM2';
        pm2StatusDisplay.className = 'status warning';
        showPm2Result(j.message || 'Process not running under PM2. Start with: npm run start:pm2', 'warning');
      }
    } catch (e) {
      pm2StatusText.textContent = 'Error';
      showPm2Result('Failed to check PM2 status: ' + e.message, 'danger');
    }
  }

  async function pm2Action(action) {
    const key = adminKeyInput.value;
    if (!key) {
      showPm2Result('Provide admin key first', 'danger');
      return;
    }

    const actionNames = { restart: 'Restart', stop: 'Stop', start: 'Start' };
    const confirmMsg = action === 'stop'
      ? 'This will stop the server. You will lose connection to this admin panel. Continue?'
      : (action === 'restart' ? 'This will restart the server. The page may briefly lose connection. Continue?' : null);

    if (confirmMsg && !confirm(confirmMsg)) return;

    try {
      const btn = document.getElementById('btnPm2' + action.charAt(0).toUpperCase() + action.slice(1));
      if (btn) {
        btn.disabled = true;
        btn.textContent = actionNames[action] + 'ing...';
      }

      showPm2Result('Sending ' + action + ' command...', 'info');

      const r = await fetch(API_BASE + '/api/proxy/admin/pm2/' + action, {
        method: 'POST',
        headers: { 'x-admin-key': key, 'Content-Type': 'application/json' }
      });

      if (r.status === 403) {
        showPm2Result('Forbidden - invalid admin key or not localhost', 'danger');
        return;
      }

      const j = await parseJsonOrThrow(r);

      if (j.success) {
        showPm2Result(j.message, 'success');
        // After action, wait a moment and check status again
        if (action !== 'stop') {
          setTimeout(checkPm2Status, 2000);
        }
      } else {
        showPm2Result('Failed: ' + (j.error || JSON.stringify(j)), 'danger');
      }
    } catch (e) {
      // If stop succeeded, we expect connection to fail
      if (action === 'stop') {
        showPm2Result('Server stopped (connection lost as expected)', 'warning');
      } else {
        showPm2Result('Action failed: ' + e.message, 'danger');
      }
    } finally {
      const btn = document.getElementById('btnPm2' + action.charAt(0).toUpperCase() + action.slice(1));
      if (btn) {
        btn.disabled = false;
        btn.textContent = actionNames[action] + ' Server';
      }
    }
  }

  function showPm2Result(text, type = 'info') {
    pm2Result.textContent = text;
    pm2Result.className = 'status ' + type;
    pm2Result.style.display = 'block';
  }

  // PM2 Event Listeners
  if (btnPm2Status) btnPm2Status.addEventListener('click', checkPm2Status);
  if (btnPm2Restart) btnPm2Restart.addEventListener('click', () => pm2Action('restart'));
  if (btnPm2Stop) btnPm2Stop.addEventListener('click', () => pm2Action('stop'));
  if (btnPm2Start) btnPm2Start.addEventListener('click', () => pm2Action('start'));

  // Initial status check and periodic ping
  checkProxyStatus();
  setInterval(checkProxyStatus, 10000);

  // Auto-refresh status every 30 seconds if authenticated
  setInterval(() => {
    if (adminKeyInput.value && poolSection.style.display !== 'none') {
      fetchStatus();
    }
  }, 30000);

  // Check proxy health every 5 seconds to update the status dot
  setInterval(checkProxyStatus, 10000);
  checkProxyStatus(); // Also run immediately



  // --- Admin Logs UI & fetch ---
  const btnLoadLogs = document.getElementById('btnLoadLogs');
  const logsSince = document.getElementById('logsSince');
  const logsAction = document.getElementById('logsAction');
  const logsLimit = document.getElementById('logsLimit');
  const logsSection = document.getElementById('logsSection');
  const logsTableBody = document.querySelector('#logsTable tbody');
  const logsStatus = document.getElementById('logsStatus');
  const logsPrev = document.getElementById('logsPrev');
  const logsNext = document.getElementById('logsNext');
  const logsPageInfo = document.getElementById('logsPageInfo');

  let logsPage = 1;
  let logsTotal = 0;

  function isoFromDatetimeLocal(val) {
    if (!val) return null;
    const d = new Date(val);
    return d.toISOString();
  }

  async function fetchLogs(page = 1) {
    const key = adminKeyInput.value;
    if (!key) { showStatus('Provide admin key above to load logs', true); return; }
    const limit = Number(logsLimit.value || 50);
    const offset = (page - 1) * limit;
    const sinceVal = isoFromDatetimeLocal(logsSince.value);
    const params = new URLSearchParams();
    params.set('limit', String(limit));
    params.set('offset', String(offset));
    if (sinceVal) params.set('since', sinceVal);
    if (logsAction.value) params.set('action', logsAction.value);

    try {
      const r = await fetch(API_BASE + '/api/proxy/admin/logs?' + params.toString(), { headers: { 'x-admin-key': key } });
      if (r.status === 403) { showStatus('Forbidden - invalid admin key', true); logsSection.style.display = 'none'; return; }
      const j = await parseJsonOrThrow(r);
      logsTotal = j.total || 0;
      logsPage = page;
      renderLogs(j.rows || []);
      logsSection.style.display = 'block';
      logsPageInfo.textContent = `Page ${logsPage} (showing ${j.rows.length} of ${logsTotal})`;
      logsStatus.textContent = '';
    } catch (e) {
      logsStatus.textContent = 'Fetch logs failed: ' + e;
      logsSection.style.display = 'none';
    }
  }

  function renderLogs(rows) {
    logsTableBody.innerHTML = '';
    if (!rows || rows.length === 0) {
      const tr = document.createElement('tr');
      tr.innerHTML = '<td colspan="6">No logs</td>';
      logsTableBody.appendChild(tr);
      return;
    }
    for (const r of rows) {
      const tr = document.createElement('tr');
      const details = (r.details && typeof r.details === 'object') ? JSON.stringify(r.details) : (r.details || '');
      tr.innerHTML = `<td>${r.ts || ''}</td>
                        <td>${r.action || ''}</td>
                        <td>${r.route || ''}</td>
                        <td>${r.ip || ''}</td>
                        <td>${r.outcome || ''}</td>
                        <td style="max-width:320px;overflow:auto">${escapeHtml(details)}</td>`;
      logsTableBody.appendChild(tr);
    }
  }

  function escapeHtml(s) { return String(s).replace(/[&<>"']/g, function (m) { return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[m]; }); }

  btnLoadLogs && btnLoadLogs.addEventListener('click', () => fetchLogs(1));
  logsPrev && logsPrev.addEventListener('click', () => { if (logsPage > 1) fetchLogs(logsPage - 1); });
  logsNext && logsNext.addEventListener('click', () => {
    const limit = Number(logsLimit.value || 50);
    const maxPage = Math.ceil((logsTotal || 0) / limit) || 1;
    if (logsPage < maxPage) fetchLogs(logsPage + 1);
  });

})();