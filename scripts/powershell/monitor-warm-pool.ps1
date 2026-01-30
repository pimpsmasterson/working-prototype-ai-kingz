# Monitor warm-pool health until healthy or timeout
$adminKey = 'secure_admin_key_change_me'
$maxChecks = 20
$interval = 30  # seconds
for ($i=1; $i -le $maxChecks; $i++) {
    $t = Get-Date -Format s
    Write-Host "[Check $i] $t"
    try {
        $resp = Invoke-RestMethod -Uri "http://localhost:3000/api/proxy/admin/warm-pool/health" -Headers @{ 'x-admin-key' = $adminKey } -ErrorAction Stop
    } catch {
        Write-Host "  Fetch failed: $($_.Exception.Message)"
        Start-Sleep -Seconds $interval
        continue
    }

    $healthy = $resp.healthy
    $errors = @($resp.healthReport.errors) -join '; '
    Write-Host "  healthy=$healthy, errors=$errors"

    if ($healthy -eq $true) {
        Write-Host "✅ Instance is healthy. Exiting monitor."
        break
    }

    Start-Sleep -Seconds $interval
}
Write-Host "Monitor finished."