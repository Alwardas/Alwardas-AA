$sourcePath = "c:\Alwardas A A\frontend\build\app\outputs\flutter-apk\app-release.apk"
$destPath = "$env:USERPROFILE\Desktop\app-release.apk"
$timeoutSeconds = 1800 # 30 minutes
$intervalSeconds = 10
$elapsed = 0

Write-Host "Monitoring for APK at: $sourcePath"

while ($elapsed -lt $timeoutSeconds) {
    if (Test-Path $sourcePath) {
        Write-Host "APK found! Copying to Desktop..."
        Copy-Item -Path $sourcePath -Destination $destPath -Force
        Write-Host "Success: APK copied to $destPath"
        exit 0
    }
    
    Start-Sleep -Seconds $intervalSeconds
    $elapsed += $intervalSeconds
}

Write-Host "Timeout: APK was not found after 30 minutes."
exit 1
