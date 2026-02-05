const fetch = require('node-fetch');
const links = [
    { name: 'RIFE 4.26', url: 'https://huggingface.co/r3gm/RIFE/resolve/main/RIFEv4.26_0921.zip' },
    { name: 'AnimateDiff SDXL', url: 'https://huggingface.co/guoyww/animatediff/resolve/main/mm_sdxl_v10_beta.ckpt' }
];

(async () => {
    for (const link of links) {
        try {
            const r = await fetch(link.url, { method: 'HEAD', redirect: 'manual' });
            console.log(link.name + ': ' + r.status + (r.headers.get('content-length') ? ' (' + (r.headers.get('content-length')/1024/1024).toFixed(1) + 'MB)' : ''));
        } catch (e) {
            console.log(link.name + ': ERROR - ' + e.message);
        }
    }
})();
