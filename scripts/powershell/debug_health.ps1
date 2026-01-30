try {
    $r = Invoke-RestMethod -Uri 'http://localhost:3000/api/proxy/health' -TimeoutSec 5
    Write-Host 'HEALTH_OK'
    $r | ConvertTo-Json -Depth 5
} catch {
    Write-Host 'REQUEST_FAILED'
    $_ | Format-List * -Force
    if ($_.Exception -and $_.Exception.Response) {
        try {
            $stream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            Write-Host 'RESPONSE_BODY:'
            Write-Host ($reader.ReadToEnd())
        } catch { Write-Host 'FAILED_TO_READ_RESPONSE_BODY' }
    }
}