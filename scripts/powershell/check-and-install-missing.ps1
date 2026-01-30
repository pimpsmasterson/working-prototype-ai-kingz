# Check and download all missing models
$SSH_KEY = "$env:USERPROFILE\.ssh\id_rsa_vast"
$SSH_HOST = "ssh1.vast.ai"
$SSH_PORT = 12910

Write-Host "=== Checking Missing Models ===" -ForegroundColor Cyan

# Check what's missing
$checkCmd = @"
echo '=== Checking Files ==='
cd /workspace/ComfyUI/models

echo 'CHECKPOINTS:'
ls -1 checkpoints/ 2>/dev/null | wc -l
ls -1 checkpoints/ 2>/dev/null

echo 'LORAS:'
ls -1 loras/ 2>/dev/null | wc -l

echo 'ANIMATEDIFF:'
ls -1 animatediff_models/ 2>/dev/null

echo 'VFI:'
ls -1 vfi/ 2>/dev/null

echo 'DEPTHANYTHING:'
ls -1 depthanything/ 2>/dev/null

echo 'TEXT_ENCODERS:'
ls -1 text_encoders/ 2>/dev/null

echo 'VAE:'
ls -1 vae/ 2>/dev/null

echo 'DIFFUSION_MODELS:'
ls -1 diffusion_models/ 2>/dev/null
"@

Write-Host "`nChecking current files..." -ForegroundColor Yellow
ssh -o StrictHostKeyChecking=no -i $SSH_KEY -p $SSH_PORT root@$SSH_HOST $checkCmd

Write-Host "`n=== Downloading Missing Files ===" -ForegroundColor Cyan

# Download all missing files
$downloadCmd = @"
cd /workspace/ComfyUI/models

# Checkpoint 2602579 if missing
if [ ! -f 'checkpoints/checkpoint_2602579.safetensors' ]; then
    echo 'Downloading checkpoint_2602579.safetensors...'
    cd checkpoints && wget -c -O checkpoint_2602579.safetensors 'https://civitai.com/api/download/models/2602579?token=11a72963b7f26eae7794381206a763dc' && cd ..
fi

# AnimateDiff SDXL beta if missing
if [ ! -f 'animatediff_models/mm_sdxl_v1_beta.ckpt' ]; then
    echo 'Downloading mm_sdxl_v1_beta.ckpt...'
    cd animatediff_models && wget -c -O mm_sdxl_v1_beta.ckpt 'https://huggingface.co/guoyww/animatediff/resolve/main/mm_sdxl_v1_beta.ckpt' && cd ..
fi

# RIFE if missing
if [ ! -f 'vfi/rife47.pth' ]; then
    echo 'Downloading rife47.pth...'
    cd vfi && wget -c -O rife47.pth 'https://github.com/hzwer/Practical-RIFE/releases/download/v4.7/rife47.pth' && cd ..
fi

# DepthAnything if missing
if [ ! -f 'depthanything/depth_anything_v2_vitl.safetensors' ]; then
    echo 'Downloading depth_anything_v2_vitl.safetensors...'
    cd depthanything && wget -c -O depth_anything_v2_vitl.safetensors 'https://huggingface.co/Kijai/depth-anything-2-safetensors/resolve/main/depth_anything_v2_vitl.safetensors' && cd ..
fi

# UMT5 text encoder if missing
if [ ! -f 'text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors' ]; then
    echo 'Downloading umt5_xxl_fp8_e4m3fn_scaled.safetensors...'
    cd text_encoders && wget -c -O umt5_xxl_fp8_e4m3fn_scaled.safetensors 'https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn.safetensors' && cd ..
fi

# Wan 2.1 VAE if missing
if [ ! -f 'vae/wan_2.1_vae.safetensors' ]; then
    echo 'Downloading wan_2.1_vae.safetensors...'
    cd vae && wget -c -O wan_2.1_vae.safetensors 'https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan2.1_vae.safetensors' && cd ..
fi

# Wan 2.5 I2V model if missing
if [ ! -f 'diffusion_models/wan25_i2v_14b_fp8_high_scaled.safetensors' ]; then
    echo 'Downloading wan25_i2v_14b_fp8_high_scaled.safetensors...'
    cd diffusion_models && wget -c -O wan25_i2v_14b_fp8_high_scaled.safetensors 'https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/wan25_i2v_14b_fp8_high_scaled.safetensors' && cd ..
fi

# Wan 2.5 VAE if missing
if [ ! -f 'vae/wan2.5_vae.safetensors' ]; then
    echo 'Downloading wan2.5_vae.safetensors...'
    cd vae && wget -c -O wan2.5_vae.safetensors 'https://huggingface.co/wangkanai/wan25-vae/resolve/main/diffusion_pytorch_model.safetensors' && cd ..
fi

echo 'All downloads complete!'
"@

Write-Host "`nStarting downloads..." -ForegroundColor Yellow
ssh -o StrictHostKeyChecking=no -i $SSH_KEY -p $SSH_PORT root@$SSH_HOST $downloadCmd

Write-Host "`n=== Verifying Files ===" -ForegroundColor Cyan
ssh -o StrictHostKeyChecking=no -i $SSH_KEY -p $SSH_PORT root@$SSH_HOST $checkCmd

Write-Host "`n=== Restarting ComfyUI ===" -ForegroundColor Yellow
$restartCmd = "pkill -f 'main.py' 2>/dev/null || true; sleep 3; cd /workspace/ComfyUI && source /venv/main/bin/activate && nohup python main.py --listen 0.0.0.0 --disable-auto-launch --port 8188 --enable-cors-header > /workspace/comfyui_restart.log 2>&1 &; sleep 5; tail -20 /workspace/comfyui_restart.log"
ssh -o StrictHostKeyChecking=no -i $SSH_KEY -p $SSH_PORT root@$SSH_HOST $restartCmd

Write-Host "`n✅ Complete!" -ForegroundColor Green
Write-Host "Access ComfyUI at: http://localhost:8188 (via SSH tunnel)" -ForegroundColor Cyan
