$sourcePath = "c:\Alwardas A A\frontend\build\app\outputs\flutter-apk\app-*-release.apk"
$destPath = "$env:USERPROFILE\Desktop\app-release.apk"
$timeoutSeconds = 1800 # 30 minutes
$intervalSeconds = 10
$elapsed = 0

Write-Host "Monitoring for APK at: $sourcePath"

while ($elapsed -lt $timeoutSeconds) {
    if (Test-Path $sourcePath) {
        $apks = Get-ChildItem $sourcePath
        if ($apks.Count -gt 0) {
            Write-Host "Found $($apks.Count) APK(s)! Copying to Desktop..."
            foreach ($apk in $apks) {
                $destFile = Join-Path "$env:USERPROFILE\Desktop" $apk.Name
                Copy-Item -Path $apk.FullName -Destination $destFile -Force
                Write-Host "Copied: $($apk.Name)"
            }
            exit 0
        }
    }
    
    Start-Sleep -Seconds $intervalSeconds
    $elapsed += $intervalSeconds
}

Write-Host "Timeout: APK was not found after 30 minutes."
exit 1
