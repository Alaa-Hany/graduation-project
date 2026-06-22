# Deploy Kinder World Web to Firebase Hosting
# Usage: from the kinder_world_child_mode folder run:  ./deploy.ps1

$ErrorActionPreference = "Stop"
$ApiBaseUrl = "https://graduation-project-gnbb.onrender.com"

Write-Host "1/2 Building web with backend URL..." -ForegroundColor Cyan
flutter build web --release --dart-define=API_BASE_URL=$ApiBaseUrl
if ($LASTEXITCODE -ne 0) { Write-Host "Build failed" -ForegroundColor Red; exit 1 }

Write-Host "2/2 Deploying to Firebase..." -ForegroundColor Cyan
firebase deploy --only hosting
if ($LASTEXITCODE -ne 0) { Write-Host "Deploy failed" -ForegroundColor Red; exit 1 }

Write-Host "Deployed successfully -> https://kinder-world-bd9e3.web.app" -ForegroundColor Green
Write-Host "Open the site and press Ctrl+Shift+R" -ForegroundColor Yellow
