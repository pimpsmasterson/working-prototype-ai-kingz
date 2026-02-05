# Claude AI Agent Learning Log

## Session: 2026-02-03 - SSH Tunneling and ComfyUI Management

### What We Accomplished

1. **Fixed PowerShell SSH Tunnel Script**
   - Original issue: Script used `Start-Process` which didn't work well with SSH tunnels
   - Solution: Rewrote to use `& ssh` (call operator) to run SSH in foreground
   - Learning: SSH tunnels need to run in foreground to maintain connection

2. **Established SSH Tunnel to Vast.ai ComfyUI Instance**
   - Created robust tunnel: `localhost:8080` → `ssh1.vast.ai:13586` → `remote:8188`
   - Browser auto-opens after 2-second delay
   - Tunnel stays active until Ctrl+C

3. **Fixed Stuck ComfyUI Queue**
   - Problem: Job wouldn't cancel, everything stuck at checkpoint
   - Root cause: Corrupted queue database
   - Solution: `rm -f /workspace/ComfyUI/user/queue.db*`
   - **Key Learning:** Stuck checkpoints are queue issues, not xFormers issues

4. **xFormers Investigation**
   - User believed xFormers was necessary for ComfyUI
   - Reality: xFormers is optional optimization, PyTorch attention works fine
   - Issue: xFormers 0.0.34 requires PyTorch 2.10.0, but ComfyUI needs 2.5.1+cu124
   - **Decision:** Removed xFormers to avoid dependency conflicts
   - **Result:** ComfyUI works perfectly without it

5. **Dependency Management Lessons**
   - Impact-Pack custom nodes failed due to missing `piexif` dependency
   - Issue: Dependencies installed globally, not in `/venv/main`
   - Solution: Always use `/venv/main/bin/pip install` for ComfyUI packages
   - Installed full Impact-Pack requirements successfully

### Technical Insights

#### SSH Tunneling Best Practices

**What Works:**
```powershell
& ssh -p $SshPort -i $Key -o StrictHostKeyChecking=no \
  -o ServerAliveInterval=30 -o ServerAliveCountMax=3 \
  -L "${LocalPort}:localhost:${RemotePort}" "${User}@${RemoteHost}" -N
```

**What Doesn't Work:**
- `Start-Process ssh ...` - Launches background process that exits immediately
- Complex process management - SSH handles connection itself

#### ComfyUI Architecture Understanding

```
User's Browser (localhost:8080)
    ↓ [SSH Tunnel]
Remote SSH Server (port 13586)
    ↓ [Port Forward]
ComfyUI Server (127.0.0.1:8188 on remote)
    ↓
Python venv (/venv/main)
    ↓
CUDA/PyTorch
    ↓
GPU (NVIDIA RTX 4060 Ti, 16GB VRAM)
```

#### Dependency Hell Solutions

**Problem:** Installing xFormers broke PyTorch compatibility
```
xformers 0.0.34 requires torch==2.10.0
torchvision 0.20.1+cu124 requires torch==2.5.1
→ Conflict!
```

**Solution:** Prioritize base requirements (torch, torchvision) over optional ones (xformers)

**Commands Used:**
```bash
# Reinstall correct versions
/venv/main/bin/pip install --force-reinstall \
  torch==2.5.1+cu124 \
  torchvision==0.20.1+cu124 \
  torchaudio==2.5.1+cu124 \
  --index-url https://download.pytorch.org/whl/cu124

# Remove conflicting package
/venv/main/bin/pip uninstall -y xformers
```

### Common Pitfalls Avoided

1. **Assuming xFormers is required**
   - Reality: Optional optimization that often causes conflicts
   - PyTorch attention is sufficient for most use cases

2. **Installing packages globally**
   - Always check: `which python` and `which pip`
   - Use full path: `/venv/main/bin/pip install ...`

3. **Not clearing stuck queues**
   - Queue database can corrupt when jobs are interrupted
   - Simple fix: delete queue.db files

4. **Using Start-Process for SSH tunnels**
   - SSH needs to run in foreground for port forwarding
   - Use `& ssh ...` or direct SSH command

### Files Created/Modified

- `scripts/connect-comfy.ps1` - Robust SSH tunnel script
- `docs/SSH_TUNNEL_GUIDE.md` - Comprehensive tunneling documentation
- `docs/CLAUDE.md` - This learning log

### Reusable Patterns

#### Quick SSH Command Pattern
```bash
ssh -p <PORT> -i <KEY> root@<HOST> "<COMMAND>"
```

#### Check Service Status
```bash
ssh ... "curl -s http://localhost:8188 | head -5"
```

#### Restart Service
```bash
ssh ... "killall -9 python3; cd /workspace/ComfyUI && /venv/main/bin/python3 main.py --listen 0.0.0.0 --port 8188 &"
```

#### View Logs
```bash
ssh ... "tail -50 /workspace/ComfyUI/user/comfyui.log"
```

### Remote Management Commands

```bash
# GPU status
ssh -p 13586 -i ~/.ssh/id_ed25519 root@ssh1.vast.ai "nvidia-smi"

# Disk usage
ssh -p 13586 -i ~/.ssh/id_ed25519 root@ssh1.vast.ai "df -h"

# Running processes
ssh -p 13586 -i ~/.ssh/id_ed25519 root@ssh1.vast.ai "ps aux | grep python"

# Install custom node
ssh -p 13586 -i ~/.ssh/id_ed25519 root@ssh1.vast.ai \
  "cd /workspace/ComfyUI/custom_nodes && git clone <REPO_URL>"

# Install Python package in venv
ssh -p 13586 -i ~/.ssh/id_ed25519 root@ssh1.vast.ai \
  "/venv/main/bin/pip install <PACKAGE>"
```

### Next Steps for Future Sessions

1. **Automate custom node installation** - Script to install all missing nodes
2. **Model management** - Download and organize models remotely
3. **Workflow backup** - Save workflows to git repository
4. **Multi-instance management** - Handle multiple Vast.ai instances
5. **Cost optimization** - Auto-stop instances when not in use

### Key Takeaways for Future AI Agents

1. **Read logs carefully** - Error messages often point to simple fixes
2. **Understand the stack** - Know what's running where (venv vs global)
3. **Test incrementally** - Make one change at a time
4. **Document solutions** - Future sessions benefit from clear notes
5. **Question assumptions** - "Required" dependencies often aren't

### Problem-Solving Framework Used

1. **Identify the actual problem**
   - User said: "need xFormers"
   - Reality: Stuck queue + dependency conflicts

2. **Test hypotheses**
   - Tried installing xFormers → broke PyTorch
   - Cleared queue → fixed stuck jobs
   - Removed xFormers → ComfyUI works fine

3. **Document and explain**
   - Created comprehensive guide
   - Explained why each solution works
   - Provided alternatives

4. **Verify solution**
   - Tested tunnel works
   - Confirmed ComfyUI starts
   - Validated no errors

---

## Historical Context

This project is a Vast.ai GPU rental automation system for ComfyUI workflows. Previous work included:
- Warm pool management
- Auto-provisioning scripts
- Database tracking
- SSH configuration management

This session focused on the user-facing connection layer - making it easy to connect to and manage remote instances.

---

**Last Updated:** 2026-02-03
**Status:** SSH tunneling working, ComfyUI operational, ready for workflow execution
**Next Priority:** Install missing custom nodes for specific workflows
