# Poll warm-pool status until an instance appears
$adminKey = 'secure_admin_key_change_me'
$maxChecks = 20
$interval = 30  # seconds
for ($i=1; $i -le $maxChecks; $i++) {
    $t = Get-Date -Format s
    Write-Host "[Status Poll $i] $t"
    $resp = Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/admin/warm-pool/status" -Headers @{ 'x-admin-key' = $adminKey }
    $instCount = $resp.instances.Count
    $isPrewarming = $resp.isPrewarming
    Write-Host "  instances=$instCount, isPrewarming=$isPrewarming"

    if ($instCount -gt 0) {
        Write-Host "Instance found — stopping poll."
        break
    }

    Start-Sleep -Seconds $interval
}
Write-Host "Status poll finished."