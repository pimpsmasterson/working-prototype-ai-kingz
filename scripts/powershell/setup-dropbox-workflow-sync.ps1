# Setup Dropbox Workflow Sync Helper
# Automatically configures Dropbox workflow sync for Vast.ai provisioning

param(
    [Parameter(Mandatory=$false)]
    [string]$DropboxFolderLink,

    [Parameter(Mandatory=$false)]
    [switch]$TestDownload,

    [Parameter(Mandatory=$false)]
    [switch]$ShowHelp
)

$ErrorActionPreference = "Stop"

# Configuration
$WorkflowsDir = Join-Path $PSScriptRoot "..\..\scripts\workflows"
$EnvFile = Join-Path $PSScriptRoot "..\..\\.env"
$EnvExampleFile = Join-Path $PSScriptRoot "..\..\\.env.example"

function Show-Help {
    Write-Host @"

╔════════════════════════════════════════════════════════════════╗
║   🔄 Dropbox Workflow Sync Setup Helper                       ║
╚════════════════════════════════════════════════════════════════╝

USAGE:
    .\setup-dropbox-workflow-sync.ps1 [-DropboxFolderLink URL] [-TestDownload] [-ShowHelp]

OPTIONS:
    -DropboxFolderLink    Your Dropbox shared folder link
    -TestDownload         Test downloading from the configured link
    -ShowHelp             Show this help message

EXAMPLES:
    # Interactive setup (will prompt for link):
    .\setup-dropbox-workflow-sync.ps1

    # Provide link directly:
    .\setup-dropbox-workflow-sync.ps1 -DropboxFolderLink "https://www.dropbox.com/sh/abc123/xyz?dl=0"

    # Test existing configuration:
    .\setup-dropbox-workflow-sync.ps1 -TestDownload

STEPS TO GET DROPBOX LINK:
    1. Open Dropbox
    2. Right-click on 'scripts/workflows' folder
    3. Click 'Share' → 'Create link'
    4. Copy the link (looks like: https://www.dropbox.com/sh/...)
    5. Run this script and paste the link

"@
}

function Test-DropboxLink {
    param([string]$Link)

    Write-Host "🔍 Testing Dropbox link..." -ForegroundColor Cyan

    # Convert to direct download URL
    $DownloadUrl = $Link -replace "dl=0", "dl=1"

    $TempFile = Join-Path $env:TEMP "test_workflows_$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"

    try {
        Write-Host "   📥 Downloading test file..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $TempFile -TimeoutSec 30 -ErrorAction Stop

        if (Test-Path $TempFile) {
            $FileSize = (Get-Item $TempFile).Length
            Write-Host "   ✅ Download successful! ($([math]::Round($FileSize / 1MB, 2)) MB)" -ForegroundColor Green

            # Try to peek inside (if 7zip or expand-archive available)
            try {
                $ZipContents = Get-ChildItem -Path (Join-Path $env:TEMP "test_extract_*") -Recurse -Filter "*.json" -ErrorAction SilentlyContinue
                if ($ZipContents) {
                    Write-Host "   📄 Found workflow files inside" -ForegroundColor Green
                }
            } catch {
                # Ignore extraction errors
            }

            Remove-Item $TempFile -Force
            return $true
        } else {
            Write-Host "   ❌ Download failed - no file created" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "   ❌ Download failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Add-ToEnvFile {
    param([string]$Link)

    Write-Host "📝 Adding to .env file..." -ForegroundColor Cyan

    # Ensure .env exists
    if (-not (Test-Path $EnvFile)) {
        if (Test-Path $EnvExampleFile) {
            Write-Host "   📋 Creating .env from .env.example..." -ForegroundColor Gray
            Copy-Item $EnvExampleFile $EnvFile
        } else {
            Write-Host "   📄 Creating new .env file..." -ForegroundColor Gray
            New-Item -ItemType File -Path $EnvFile -Force | Out-Null
        }
    }

    # Read existing .env content
    $EnvContent = Get-Content $EnvFile -Raw -ErrorAction SilentlyContinue

    # Check if DROPBOX_WORKFLOWS_URL already exists
    if ($EnvContent -match "DROPBOX_WORKFLOWS_URL=") {
        Write-Host "   ⚠️  DROPBOX_WORKFLOWS_URL already exists in .env" -ForegroundColor Yellow
        $Overwrite = Read-Host "   Do you want to overwrite it? (y/n)"

        if ($Overwrite -ne 'y') {
            Write-Host "   ⏭️  Skipping update" -ForegroundColor Gray
            return
        }

        # Replace existing value
        $EnvContent = $EnvContent -replace "DROPBOX_WORKFLOWS_URL=.*", "DROPBOX_WORKFLOWS_URL=$Link"
        $EnvContent | Set-Content $EnvFile -NoNewline
        Write-Host "   ✅ Updated DROPBOX_WORKFLOWS_URL" -ForegroundColor Green
    } else {
        # Add new entry
        $NewEntry = @"

# Dropbox Workflows Sync (Auto-configured $(Get-Date -Format 'yyyy-MM-dd HH:mm'))
DROPBOX_WORKFLOWS_URL=$Link
"@
        Add-Content -Path $EnvFile -Value $NewEntry
        Write-Host "   ✅ Added DROPBOX_WORKFLOWS_URL" -ForegroundColor Green
    }
}

function Show-CurrentConfig {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║   📋 Current Configuration                                     ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    if (Test-Path $EnvFile) {
        $EnvContent = Get-Content $EnvFile -Raw
        if ($EnvContent -match "DROPBOX_WORKFLOWS_URL=(.*)") {
            $CurrentUrl = $Matches[1].Trim()
            Write-Host "   Dropbox URL: " -NoNewline -ForegroundColor Gray
            Write-Host "$CurrentUrl" -ForegroundColor Green
        } else {
            Write-Host "   Dropbox URL: " -NoNewline -ForegroundColor Gray
            Write-Host "Not configured" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   .env file: " -NoNewline -ForegroundColor Gray
        Write-Host "Not found" -ForegroundColor Red
    }

    # Count local workflows
    if (Test-Path $WorkflowsDir) {
        $WorkflowCount = (Get-ChildItem -Path $WorkflowsDir -Filter "*.json").Count
        Write-Host "   Local workflows: " -NoNewline -ForegroundColor Gray
        Write-Host "$WorkflowCount files" -ForegroundColor Green
    }

    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN SCRIPT
# ═══════════════════════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   🔄 Dropbox Workflow Sync - Easy Setup                       ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Show help if requested
if ($ShowHelp) {
    Show-Help
    exit 0
}

# Show current configuration
Show-CurrentConfig

# Test download if requested
if ($TestDownload) {
    Write-Host "🧪 Testing current configuration..." -ForegroundColor Cyan
    Write-Host ""

    if (Test-Path $EnvFile) {
        $EnvContent = Get-Content $EnvFile -Raw
        if ($EnvContent -match "DROPBOX_WORKFLOWS_URL=(.*)") {
            $TestUrl = $Matches[1].Trim()
            if (Test-DropboxLink -Link $TestUrl) {
                Write-Host ""
                Write-Host "✅ Dropbox sync is configured correctly!" -ForegroundColor Green
                exit 0
            } else {
                Write-Host ""
                Write-Host "❌ Dropbox link test failed. Please check your URL." -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Host "❌ DROPBOX_WORKFLOWS_URL not found in .env" -ForegroundColor Red
            Write-Host "   Run this script without -TestDownload to configure it" -ForegroundColor Yellow
            exit 1
        }
    } else {
        Write-Host "❌ .env file not found" -ForegroundColor Red
        exit 1
    }
}

# Interactive setup
if (-not $DropboxFolderLink) {
    Write-Host "📋 Interactive Setup" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To get your Dropbox share link:" -ForegroundColor Gray
    Write-Host "  1. Open Dropbox" -ForegroundColor Gray
    Write-Host "  2. Right-click on 'scripts/workflows' folder" -ForegroundColor Gray
    Write-Host "  3. Click 'Share' → 'Create link'" -ForegroundColor Gray
    Write-Host "  4. Copy the link and paste it below" -ForegroundColor Gray
    Write-Host ""

    $DropboxFolderLink = Read-Host "Paste your Dropbox folder link here"

    if ([string]::IsNullOrWhiteSpace($DropboxFolderLink)) {
        Write-Host ""
        Write-Host "❌ No link provided. Exiting." -ForegroundColor Red
        exit 1
    }
}

# Validate link format
if ($DropboxFolderLink -notmatch "dropbox\.com") {
    Write-Host ""
    Write-Host "❌ Invalid Dropbox link. Must contain 'dropbox.com'" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "🔗 Link received: $DropboxFolderLink" -ForegroundColor Green
Write-Host ""

# Test the link
if (Test-DropboxLink -Link $DropboxFolderLink) {
    Write-Host ""

    # Add to .env
    Add-ToEnvFile -Link $DropboxFolderLink

    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║   ✅ Setup Complete!                                           ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Run: .\one-click-start-fixed.ps1" -ForegroundColor Gray
    Write-Host "  2. Provision will auto-download workflows from Dropbox" -ForegroundColor Gray
    Write-Host "  3. Update workflows in Dropbox anytime" -ForegroundColor Gray
    Write-Host "  4. Next provision will get the latest versions" -ForegroundColor Gray
    Write-Host ""

} else {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║   ❌ Setup Failed                                              ║" -ForegroundColor Red
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please check:" -ForegroundColor Yellow
    Write-Host "  • Is the Dropbox link public/shared?" -ForegroundColor Gray
    Write-Host "  • Can you access it in a browser?" -ForegroundColor Gray
    Write-Host "  • Is your internet connection working?" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Try accessing this URL in your browser:" -ForegroundColor Yellow
    Write-Host "  $($DropboxFolderLink -replace 'dl=0', 'dl=1')" -ForegroundColor Gray
    Write-Host ""
    exit 1
}
