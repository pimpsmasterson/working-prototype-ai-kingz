# Vast.ai ComfyUI Automation - Smart GPU Selection

This project provides fully automated deployment of ComfyUI instances on Vast.ai cloud GPUs using your SSH key for secure access. The system intelligently selects optimal GPU configurations based on your task complexity and performance requirements.

## 🚀 Key Features

- **Smart GPU Selection**: Automatically chooses GPUs based on task complexity and multiple performance metrics
- **Multi-Factor Optimization**: Considers network speed, reliability, boot performance, and value per dollar
- **Complexity-Aware**: Adapts GPU power to your specific needs (low/medium/high/ultra)
- **Automated SSH Key Setup**: Automatically adds your SSH key to Vast.ai for secure instance access
- **One-Click ComfyUI Deployment**: Launches instances with ComfyUI pre-installed and configured
- **Status Monitoring**: Real-time monitoring of instance startup and health

## 🎯 Complexity Levels

The system automatically detects complexity from your task description:

- **Low** ($0.50/hr max): Basic tasks, simple images, sketches
  - Examples: "simple sketch", "basic icon", "quick draft"
  
- **Medium** ($1.00/hr max): Standard quality workflows  
  - Examples: "create an image", "standard portrait", "normal quality"

- **High** ($2.00/hr max): Detailed, complex work
  - Examples: "high quality", "detailed scene", "photorealistic", "complex composition"

- **Ultra** ($5.00/hr max): 4K/8K video, animations, professional work
  - Examples: "4K video", "8K animation", "professional render", "complex scene"

## ⚡ Performance Optimization

The system evaluates offers using multiple criteria with weighted scoring:

```
Final Score = (Performance × 0.4) + (Network × 0.3) + (Reliability × 0.2) + (Value × 0.1)
```

**Performance Factors:**
- TFLOPs (computational power)
- DLPerf (deep learning performance)
- Memory bandwidth
- VRAM capacity

**Network Factors:**
- Download speed (>50 MB/s preferred)
- Upload speed (>10 MB/s preferred)
- Bandwidth cost efficiency

**Reliability Factors:**
- Machine uptime (>95% preferred)
- Historical stability

**Value Factors:**
- Performance per dollar
- Overall efficiency metrics

## 🛠️ Usage Methods

### 1. Command Line (Recommended)

```bash
# Auto-detect complexity from description
node vastai-auto.js launch "create a photorealistic portrait"

# Manual complexity selection
node vastai-auto.js search high    # Preview high-end options
node vastai-auto.js launch --complexity ultra

# Management
node vastai-auto.js status <contract_id>
node vastai-auto.js stop <contract_id>
```

### 2. Windows Batch File
```batch
# Edit launch-comfyui.bat to include your task description
launch-comfyui.bat
```

### 3. Web Interface
1. Open `vastai-test.html` in browser
2. Enter task description (e.g., "generate 4K animation")
3. Select complexity or use auto-detect
4. Click "🚀 Full Automation"

## 📋 CLI Examples

```bash
# Different complexity levels
node vastai-auto.js launch "simple sketch"              # → Low complexity
node vastai-auto.js launch "professional portrait"     # → High complexity  
node vastai-auto.js launch "8K video animation"        # → Ultra complexity

# Preview options without launching
node vastai-auto.js search low     # Show budget options
node vastai-auto.js search ultra   # Show high-end options
```

## 💰 Cost Optimization

- **Interruptible instances** for maximum cost savings
- **Budget caps** per complexity level prevent overspending
- **Value prioritization** selects best performance per dollar
- **Automatic filtering** removes overpriced options

## 📁 Files Overview

- `vastai-auto.js` - Main CLI automation with smart selection
- `vastai-test.js` - Browser interface with complexity detection
- `vastai-test.html` - Web control panel with task input
- `launch-comfyui.bat` - Windows batch launcher
- `launch-comfyui.ps1` - PowerShell launcher with parameters

## 🔐 Access Information

**SSH Access:**
```bash
ssh -i ~/.ssh/vast_ai_comfyui root@<instance_ip>
```

**ComfyUI Web Interface:**
```
http://<instance_ip>:8188
```

## 🔧 Troubleshooting

- **No GPUs found**: Try lower complexity or check account balance
- **Launch failures**: Verify API key and Vast.ai account status
- **Connection issues**: Ensure SSH key format is correct
- **Timeout**: Ultra instances may take 10-15 minutes to start

## ⚠️ Security Notes

- API key and SSH key embedded (use env vars for production)
- SSH provides root access - use responsibly
- Interruptible instances may be paused if outbid

## 🎉 Example Output

```
🔍 Searching for GPU instances optimized for high complexity...
✅ Found 8 optimized GPU offers for high complexity:
1. RTX 4090 (1x) - $1.25/hr
   ↳ Perf: 2.340, Network: 0.850 MB/s, Reliability: 98.5%, US East
2. A100 (1x) - $1.80/hr  
   ↳ Perf: 3.120, Network: 0.920 MB/s, Reliability: 97.2%, EU West
...

🎯 Selected: RTX 4090 (1x) for $1.25/hr
   ↳ Network: 950↓/150↑ MB/s
   ↳ Performance: 82 TFLOPs, 24576MB VRAM
   ↳ Reliability: 98.5%

✅ Instance launched! Contract ID: 1234567
🎉 Instance is ready!
SSH: ssh -i ~/.ssh/vast_ai_comfyui root@203.0.113.42
ComfyUI: http://203.0.113.42:8188
```