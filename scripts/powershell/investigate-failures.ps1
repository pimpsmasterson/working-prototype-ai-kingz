# Deep diagnosis of ComfyUI issues
$SSH_KEY = "$env:USERPROFILE\.ssh\id_rsa_vast"
$SSH_HOST = "ssh1.vast.ai"
$SSH_PORT = 12910

Write-Host "=== DEEP INVESTIGATION OF COMFYUI FAILURES ===" -ForegroundColor Cyan

$investigateCmd = @"
echo '════════════════════════════════════════════════════════════════'
echo '1. PROVISIONING LOG - Last 100 lines with errors'
echo '════════════════════════════════════════════════════════════════'
tail -100 /workspace/comfyui.log | grep -B 2 -A 5 -i 'error\|failed\|warning\|cannot'

echo ''
echo '════════════════════════════════════════════════════════════════'
echo '2. COMFYUI STARTUP LOG - Node loading'
echo '════════════════════════════════════════════════════════════════'
if [ -f /workspace/comfyui_restart.log ]; then
    tail -150 /workspace/comfyui_restart.log
else
    tail -150 /workspace/comfyui.log
fi

echo ''
echo '════════════════════════════════════════════════════════════════'
echo '3. CUSTOM NODES DIRECTORY STRUCTURE'
echo '════════════════════════════════════════════════════════════════'
ls -la /workspace/ComfyUI/custom_nodes/

echo ''
echo '════════════════════════════════════════════════════════════════'
echo '4. PYTHON ENVIRONMENT CHECK'
echo '════════════════════════════════════════════════════════════════'
source /venv/main/bin/activate
which python
python --version
pip --version

echo ''
echo '════════════════════════════════════════════════════════════════'
echo '5. CHECKING EACH NODE FOR REQUIREMENTS.TXT'
echo '════════════════════════════════════════════════════════════════'
cd /workspace/ComfyUI/custom_nodes
for dir in */; do
    if [ -f "\${dir}requirements.txt" ]; then
        echo ">>> \${dir}"
        cat "\${dir}requirements.txt"
        echo ''
    else
        echo ">>> \${dir} - NO requirements.txt"
    fi
done

echo ''
echo '════════════════════════════════════════════════════════════════'
echo '6. CHECKING INSTALLED PACKAGES IN VENV'
echo '════════════════════════════════════════════════════════════════'
pip list | grep -i 'opencv\|torch\|numpy\|pillow\|kornia\|insightface\|onnx'

echo ''
echo '════════════════════════════════════════════════════════════════'
echo '7. TEST IMPORT OF CRITICAL MODULES'
echo '════════════════════════════════════════════════════════════════'
python -c "import cv2; print('✅ cv2 OK')" 2>&1
python -c "import torch; print('✅ torch OK')" 2>&1
python -c "import numpy; print('✅ numpy OK')" 2>&1
python -c "import insightface; print('✅ insightface OK')" 2>&1 || echo '❌ insightface MISSING'
python -c "import onnxruntime; print('✅ onnxruntime OK')" 2>&1 || echo '❌ onnxruntime MISSING'
python -c "import kornia; print('✅ kornia OK')" 2>&1

echo ''
echo '════════════════════════════════════════════════════════════════'
echo '8. CHECKING COMFYUI MAIN IMPORTS'
echo '════════════════════════════════════════════════════════════════'
cd /workspace/ComfyUI
python -c "import sys; sys.path.insert(0, '/workspace/ComfyUI'); import folder_paths; print('✅ folder_paths OK')" 2>&1
python -c "import sys; sys.path.insert(0, '/workspace/ComfyUI'); import nodes; print('✅ nodes OK')" 2>&1

echo ''
echo '════════════════════════════════════════════════════════════════'
echo '9. CHECK IF COMFYUI IS RUNNING'
echo '════════════════════════════════════════════════════════════════'
ps aux | grep -i 'python.*main.py' | grep -v grep

echo ''
echo '════════════════════════════════════════════════════════════════'
echo '10. DISK SPACE CHECK'
echo '════════════════════════════════════════════════════════════════'
df -h /workspace
"@

Write-Host "`nExecuting comprehensive diagnostics..." -ForegroundColor Yellow
ssh -o StrictHostKeyChecking=no -i $SSH_KEY -p $SSH_PORT root@$SSH_HOST $investigateCmd | Out-File -FilePath "comfyui_diagnosis.txt"

Write-Host "`n✅ Diagnosis complete - saved to comfyui_diagnosis.txt" -ForegroundColor Green
Write-Host "`nOpening file for review..." -ForegroundColor Cyan
notepad comfyui_diagnosis.txt
