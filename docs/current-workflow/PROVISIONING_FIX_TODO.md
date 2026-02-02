# Provisioning Failure Audit & Fix TODO

## Issue Summary
The ComfyUI provisioning on Vast.ai instance was failing during model downloads. Custom nodes installed successfully, but multiple model downloads were failing due to URL mismatches, gated access, and Python syntax errors.

## Root Cause Analysis (COMPLETED)

### 1. URL Filename Mismatches
- **Symptom**: Downloads failing due to incorrect filenames in URLs
- **Affected Models**:
  - UMT5: `umt5_xxl_fp8_e4m3fn.safetensors` → `umt5_xxl_fp8_e4m3fn_scaled.safetensors`
  - Wan VAE: `wan2.1_vae.safetensors` → `wan_2.1_vae.safetensors`
  - AnimateDiff: `mm_sdxl_v1_beta.ckpt` → `mm_sdxl_v10_beta.ckpt`

### 2. Gated Model Access
- **Symptom**: FLUX models require access approval on HuggingFace
- **Affected Models**: flux1-dev.safetensors, flux1-schnell.safetensors, flux_ae.safetensors
- **Solution**: Commented out FLUX downloads to avoid failures

### 3. Python Syntax Error
- **Symptom**: IndentationError in update_workflow_outputs() heredoc
- **Cause**: Leading spaces in Python code within bash heredoc
- **Solution**: Removed leading indentation from Python code

### 4. ComfyUI Process Termination
- **Symptom**: ComfyUI killed by cleanup_on_exit despite PID preservation
- **Cause**: Cleanup killing processes by name/command instead of checking PID file
- **Solution**: Enhanced cleanup to preserve ComfyUI PID from ${WORKSPACE}/comfyui.pid

## Implementation Status (COMPLETED)

### ✅ Phase 1: URL Corrections
- Fixed UMT5, Wan VAE, and AnimateDiff URLs
- Verified filename matches in HuggingFace repositories

### ✅ Phase 2: Model Access Fixes
- Commented out FLUX model arrays and download calls
- Preserved other model downloads (HuggingFace, Civitai, Dropbox)

### ✅ Phase 3: Python Syntax Fix
- Removed leading spaces from Python heredoc in update_workflow_outputs()
- Script now passes bash -n syntax validation

### ✅ Phase 4: Process Management Enhancement
- Modified cleanup_on_exit() to better preserve ComfyUI PID
- Added logic to avoid killing processes with preserved PIDs

### ✅ Phase 5: Code Quality
- Committed changes to git with detailed commit message
- Script syntax validated and ready for testing

## Testing Phase (IN PROGRESS)

### Next Steps
1. **Deploy to GPU Instance**
   - Run updated provision-reliable.sh on Vast.ai GPU instance
   - Monitor ${WORKSPACE}/provision_errors.log for remaining failures

2. **Validate Fixes**
   - Check that previously failing downloads now succeed
   - Verify ComfyUI process survives script completion
   - Confirm PID preservation works correctly

3. **Monitor Remaining Issues**
   - Check RIFE model (rife426.pth) download status
   - Verify example_pose.png URL accessibility
   - Assess overall download success rate

## Success Criteria (Updated)
- ✅ Script passes syntax validation
- ⏳ All critical downloads succeed (UMT5, Wan VAE, AnimateDiff fixed)
- ⏳ ComfyUI starts and survives provisioning completion
- ⏳ At least 80% of models download successfully
- ⏳ WanVideoWrapper and AnimateDiff work for video generation

## Risk Assessment (Updated)
- **Low Risk**: URL corrections should resolve filename mismatches
- **Low Risk**: FLUX removal eliminates access gating issues
- **Low Risk**: Python fix resolves syntax error
- **Medium Risk**: PID preservation may need further tuning
- **Mitigation**: Test incrementally, monitor logs closely

## Current Status
- **Implementation**: ✅ COMPLETE
- **Testing**: 🔄 IN PROGRESS (Ready for GPU instance deployment)
- **Validation**: ⏳ PENDING (Requires Vast.ai GPU instance)

## Deployment Instructions
1. Copy updated `scripts/provision-reliable.sh` to Vast.ai instance
2. Run provisioning: `bash scripts/provision-reliable.sh`
3. Check logs: `cat ${WORKSPACE}/provision_errors.log`
4. Verify ComfyUI: `ps aux | grep comfyui` and check `${WORKSPACE}/comfyui.pid`</content>
<parameter name="filePath">c:\Users\samsc\OneDrive\Desktop\working protoype\PROVISIONING_FIX_TODO.md