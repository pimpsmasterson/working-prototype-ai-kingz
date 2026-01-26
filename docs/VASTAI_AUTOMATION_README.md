# Vast.ai ComfyUI Automation

This project provides fully automated deployment of ComfyUI instances on Vast.ai cloud GPUs using your SSH key for secure access.

## Features

- **Automated SSH Key Setup**: Automatically adds your SSH key to Vast.ai for secure instance access
- **Smart GPU Selection**: Finds the best available GPUs (RTX 30/40 series, A100, H100) under $1/hour
- **One-Click ComfyUI Deployment**: Launches instances with ComfyUI pre-installed and configured
- **Status Monitoring**: Real-time monitoring of instance startup and health
- **Connection Management**: Saves connection details for easy access

## Quick Start

### Method 1: Command Line (Recommended for Automation)

```bash
# Launch a new automated ComfyUI instance
node vastai-auto.js launch

# Check status of running instance
node vastai-auto.js status <contract_id>

# Stop an instance
node vastai-auto.js stop <contract_id>
```

### Method 2: Web Interface

1. Open `vastai-test.html` in your browser
2. Click "🚀 Full Automation" to launch everything automatically
3. Or use individual buttons for step-by-step control

## What Happens Automatically

1. **SSH Key Setup**: Your provided SSH key is added to your Vast.ai account
2. **GPU Discovery**: Searches for verified GPUs with good performance/cost ratio
3. **Instance Launch**: Creates instance with ComfyUI installation script
4. **Setup Process**: Instance automatically installs ComfyUI and starts the web interface
5. **Connection Info**: Provides SSH and web access details when ready

## Files

- `vastai-auto.js` - Command-line automation tool
- `vastai-test.js` - Browser-based interface and testing
- `vastai-test.html` - Web interface for manual control
- `vastai-instance.json` - Auto-generated connection details (after launch)

## SSH Access

Once your instance is ready, connect using:

```bash
ssh -i ~/.ssh/vast_ai_comfyui root@<instance_ip>
```

Make sure your SSH key is saved as `~/.ssh/vast_ai_comfyui` (private key).

## ComfyUI Access

Access the ComfyUI web interface at:
```
http://<instance_ip>:8188
```

## Cost Management

- Instances are launched as interruptible (cheaper)
- Monitor costs in your Vast.ai dashboard
- Use `node vastai-auto.js stop <id>` to terminate instances when done

## Troubleshooting

- **Connection Issues**: Ensure your SSH key is properly formatted
- **Launch Failures**: Check Vast.ai dashboard for error messages
- **Timeout**: Instance startup can take 5-15 minutes depending on GPU availability
- **Cost Too High**: The script filters for offers under $1/hour

## Security Notes

- Your API key and SSH key are embedded in the code
- For production use, consider environment variables or secure key management
- SSH keys provide root access to instances - use responsibly

## API Reference

The automation uses these Vast.ai API endpoints:
- `POST /api/v0/ssh/` - Add SSH key
- `GET /api/v0/bundles/` - Search offers
- `PUT /api/v0/asks/{id}/` - Create instance
- `GET /api/v0/instances/{id}/` - Check status
- `DELETE /api/v0/instances/{id}/` - Stop instance