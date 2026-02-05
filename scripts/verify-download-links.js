#!/usr/bin/env node
const fetch = require('node-fetch');

const links = [
    { name: 'ponyRealism VAE', url: 'https://civitai.com/api/download/models/105924' },
    { name: 'RIFE 4.26', url: 'https://github.com/hzwer/Practical-RIFE/releases/download/v4.26/flownet-v4.26.pkl' },
    { name: 'AnimateDiff SDXL Beta', url: 'https://huggingface.co/camenduru/AnimateDiff-sdxl-beta/resolve/main/mm_sdxl_v10_beta.ckpt' },
    { name: 'UMT5 Scaled', url: 'https://huggingface.co/Comfy-Org/LTX-2/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors' },
    { name: 'Lumina AE', url: 'https://huggingface.co/Comfy-Org/Lumina_Image_2.0_Repackaged/resolve/main/split_files/vae/ae.safetensors' },
    { name: 'SDXL Base', url: 'https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors' },
    { name: 'SDXL Refiner', url: 'https://huggingface.co/stabilityai/stable-diffusion-xl-refiner-1.0/resolve/main/sd_xl_refiner_1.0.safetensors' },
];

(async () => {
    console.log('Verifying download links...\n');
    
    for (const link of links) {
        try {
            const response = await fetch(link.url, {
                method: 'HEAD',
                redirect: 'manual',
                timeout: 15000
            });
            
            const size = response.headers.get('content-length');
            const sizeGB = size ? (parseInt(size) / 1024 / 1024 / 1024).toFixed(2) + 'GB' : 'unknown';
            
            if (response.status === 200) {
                console.log(`✅ ${link.name}: Valid (${sizeGB})`);
            } else if (response.status >= 300 && response.status < 400) {
                console.log(`🔄 ${link.name}: Redirect (${response.status}) - will work with wget/aria2c`);
            } else {
                console.log(`⚠️  ${link.name}: Status ${response.status}`);
            }
        } catch (error) {
            console.log(`❌ ${link.name}: ${error.message}`);
        }
    }
    
    console.log('\n✅ Link verification complete');
})();
