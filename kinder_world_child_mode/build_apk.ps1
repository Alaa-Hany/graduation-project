# Build Kinder World Android APK connected to the backend server
# Usage: from the kinder_world_child_mode folder run:  ./build_apk.ps1

$ErrorActionPreference = "Stop"
$ApiBaseUrl = "https://graduation-project-gnbb.onrender.com"

# Fix for "Unable to establish loopback connection" when the Windows
# username contains non-ASCII (Arabic) characters. Points Java's AF_UNIX
# socket files to a pure-ASCII folder.
if (-not (Test-Path 'C:\Temp')) { New-Item -ItemType Directory -Path 'C:\Temp' | Out-Null }
$env:JAVA_TOOL_OPTIONS = "-Djdk.net.unixdomain.tmpdir=C:/Temp"

Write-Host "Building APK with backend URL: $ApiBaseUrl" -ForegroundColor Cyan
flutter build apk --release --dart-define=API_BASE_URL=$ApiBaseUrl
if ($LASTEXITCODE -ne 0) { Write-Host "Build failed" -ForegroundColor Red; exit 1 }

$apk = "build\app\outputs\flutter-apk\app-release.apk"
Write-Host ""
Write-Host "Build succeeded!" -ForegroundColor Green
Write-Host "APK location: $((Resolve-Path $apk).Path)" -ForegroundColor Green
Write-Host "Transfer this file to your phone, uninstall the old app, then install it." -ForegroundColor Yellow
