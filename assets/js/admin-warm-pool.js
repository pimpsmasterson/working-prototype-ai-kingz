(function(){
  const statusBox = document.getElementById('statusBox');
  const adminKeyInput = document.getElementById('adminKey');
  const btnRefresh = document.getElementById('btnRefresh');
  const btnSave = document.getElementById('btnSave');
  const desiredSizeInput = document.getElementById('desiredSize');
  const safeModeInput = document.getElementById('safeMode');
  const controls = document.getElementById('controls');
  const btnTerminate = document.getElementById('btnTerminate');

  function showStatus(text, danger) {
    statusBox.textContent = text;
    statusBox.className = 'status' + (danger ? ' danger' : '');
  }

  async function fetchStatus() {
    const key = adminKeyInput.value;
    if (!key) { showStatus('Provide admin key above', true); controls.style.display='none'; return; }
    try {
      const r = await fetch('/api/proxy/admin/warm-pool', { headers: { 'x-admin-key': key } });
      if (r.status === 403) { showStatus('Forbidden - invalid admin key', true); controls.style.display='none'; return; }
      const j = await r.json();
      showStatus(JSON.stringify(j, null, 2));
      desiredSizeInput.value = j.desiredSize || 0;
      safeModeInput.checked = !!j.safeMode;
      controls.style.display = 'block';
    } catch (e) { showStatus('Fetch failed: ' + e, true); controls.style.display='none'; }
  }

  async function saveSettings() {
    const key = adminKeyInput.value;
    const body = { desiredSize: Number(desiredSizeInput.value), safeMode: !!safeModeInput.checked };
    try {
      const r = await fetch('/api/proxy/admin/warm-pool', { method: 'POST', headers: { 'x-admin-key': key, 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
      const j = await r.json();
      showStatus('Saved: ' + JSON.stringify(j));
    } catch (e) { showStatus('Save failed: ' + e, true); }
  }

  async function terminateInstance() {
    const key = adminKeyInput.value;
    if (!confirm('Terminate current warm instance?')) return;
    try {
      const r = await fetch('/api/proxy/warm-pool/terminate', { method: 'POST', headers: { 'x-admin-key': key, 'Content-Type': 'application/json' }, body: '{}' });
      const j = await r.json();
      showStatus('Terminate: ' + JSON.stringify(j));
    } catch (e) { showStatus('Terminate failed: ' + e, true); }
  }

  btnRefresh.addEventListener('click', fetchStatus);
  btnSave.addEventListener('click', saveSettings);
  btnTerminate.addEventListener('click', terminateInstance);
})();
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
        const r = await fetch('/api/proxy/admin/logs?' + params.toString(), { headers: { 'x-admin-key': key } });
        if (r.status === 403) { showStatus('Forbidden - invalid admin key', true); logsSection.style.display='none'; return; }
        const j = await r.json();
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

    function escapeHtml(s) { return String(s).replace(/[&<>"']/g, function(m) { return ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'})[m]; }); }

    btnLoadLogs && btnLoadLogs.addEventListener('click', () => fetchLogs(1));
    logsPrev && logsPrev.addEventListener('click', () => { if (logsPage > 1) fetchLogs(logsPage - 1); });
    logsNext && logsNext.addEventListener('click', () => {
      const limit = Number(logsLimit.value || 50);
      const maxPage = Math.ceil((logsTotal || 0) / limit) || 1;
      if (logsPage < maxPage) fetchLogs(logsPage + 1);
    });

  })();