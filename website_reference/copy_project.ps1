$src = "c:\laragon\www\shadcn\web-billing-mikrotik"
$dst = "c:\laragon\www\websitemonitoringbaru"
$exclude = @("node_modules", ".git", "pppoe_monitor (14).sql", "out.json", "out2.json")

Get-ChildItem -Path $src | Where-Object { $exclude -notcontains $_.Name } | ForEach-Object {
    if ($_.PSIsContainer) {
        $destPath = Join-Path $dst $_.Name
        Copy-Item -Path $_.FullName -Destination $destPath -Recurse -Force
        Write-Host "Copied folder: $($_.Name)"
    } else {
        Copy-Item -Path $_.FullName -Destination $dst -Force
        Write-Host "Copied file: $($_.Name)"
    }
}
Write-Host "=== SELESAI ==="
