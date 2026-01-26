const fs = require('fs');
const path = require('path');
const fetch = require('node-fetch');

const VAST_BASE = process.env.VASTAI_BASE_URL || 'https://console.vast.ai/api/v0';

// Prefer environment key, then file on disk, fallback to embedded repo key (the one generated for this session)
const DEFAULT_KEY_REPRO = 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDO+Hc8lVMrOJJYwySaMN6d+SqyuMCsZ5ASM6SDz1zHb7dUrnREX/5ngWsnuop2xenISPm1/jOSWgBtJdGV4rWvDBTdwhBNpWrXrinj6GNN/jFOq4BgPcjmasr4c6WaOTKur3lo15++qR932JMUtr2/lFENNnHx+1/WcQUpBssv324cKE+Wo3o7BZSEeOs5fvE5iJO7dGruW6G5bQSMLJIb1/YvUM3zlqm2pK/ASQZDMeBITrIM4aeaiGjrSaok1929ZsIsPP0q2Hb8addsJ3BLezqavPVgHRDcxd3nC+oVF27CwXXK/Mf1oOZCBVmHiC40yYO92yxjYRAEcdrAQ4bA+h1GcY/zwBkJjH7LmzYWtQR3EI0DvWgJUt4j9XJV6SN/wqn7iJOHrsP8hmIWK8pE/MVwMVgwJAhPhHb+azrrrM5NViTTw/3owRGjG6JNpLvJlnDUH7jKqgfcTiIfzYo/NQNGwqHFpcwUwCN6wl2MjCOqbpqJlNtCEmLjbpFyVTOrNACFFb+BEQOHu83ajz7iNulIEvEZCI18NI96rno19yGPV1b6TGfIa4MM13XzV+n10ku3yo8J3MV9qedPOOEjoo99ZFv563JDfmrFGFtc618tyegl+f9M0ko3gyyVI50GfhROBNhoHdoh/cogshEaa11/sBCoN2GQA0MS/S+S0Q== samsc@LAPTOP-V36LII1N';

function getKey() {
    if (process.env.VASTAI_SSH_KEY) return process.env.VASTAI_SSH_KEY;
    
    // Check for the generated key file
    const home = process.env.HOME || process.env.USERPROFILE || '';
    const keyPath = path.join(home, '.ssh', 'id_rsa_vast.pub');
    if (fs.existsSync(keyPath)) {
        try {
            return fs.readFileSync(keyPath, 'utf8').trim();
        } catch (e) {}
    }
    
    return DEFAULT_KEY_REPRO;
}

async function registerKey(apiKey) {
    if (!apiKey) {
        // nothing to do
        return false;
    }

    try {
        const res = await fetch(`${VAST_BASE}/ssh/`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${apiKey}`
            },
            body: JSON.stringify({ ssh_key: getKey() })
        });

        let j = null;
        try { j = await res.json(); } catch (e) { j = null; }

        if (res.ok) {
            console.log('vastai-ssh: SSH key registered');
            return true;
        }

        const msg = j ? JSON.stringify(j) : `status ${res.status}`;
        if (String(msg).toLowerCase().includes('already exists') || String(msg).toLowerCase().includes('already')) {
            console.log('vastai-ssh: SSH key already present');
            return true;
        }

        console.warn('vastai-ssh: failed to register key:', msg);
        return false;
    } catch (e) {
        console.error('vastai-ssh: error registering key:', e && e.message ? e.message : e);
        return false;
    }
}

module.exports = { getKey, registerKey };
