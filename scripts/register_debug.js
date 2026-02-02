const vast = require('../lib/vastai-ssh');
(async ()=>{
  try {
    const key = vast.getKey();
    console.log('[DEBUG] Key length:', (key||'').length);
    console.log('[DEBUG] Key sample:', (key||'').slice(0,80));
    console.log('[DEBUG] Fingerprint:', vast.getKeyFingerprint(key));
    const apiKey = process.env.VASTAI_API_KEY || null;
    console.log('[DEBUG] VASTAI_API_KEY present:', !!apiKey);
    const ok = await vast.registerKey(apiKey);
    console.log('[DEBUG] registerKey returned:', ok);
  } catch (err) {
    console.error('[DEBUG] Error:', err && err.message ? err.message : err);
  }
})();