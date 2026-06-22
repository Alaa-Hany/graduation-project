# نشر تطبيق Kinder World Web على Firebase Hosting
# الاستخدام: من مجلد kinder_world_child_mode اكتبي:  ./deploy.ps1

$ErrorActionPreference = "Stop"
$ApiBaseUrl = "https://graduation-project-gnbb.onrender.com"

Write-Host "1/2 بناء الويب مع عنوان الباك إند..." -ForegroundColor Cyan
flutter build web --release --dart-define=API_BASE_URL=$ApiBaseUrl
if ($LASTEXITCODE -ne 0) { Write-Host "فشل البناء" -ForegroundColor Red; exit 1 }

Write-Host "2/2 النشر على Firebase..." -ForegroundColor Cyan
firebase deploy --only hosting
if ($LASTEXITCODE -ne 0) { Write-Host "فشل النشر" -ForegroundColor Red; exit 1 }

Write-Host "تم النشر بنجاح -> https://kinder-world-bd9e3.web.app" -ForegroundColor Green
Write-Host "افتحي الموقع واعملي Ctrl+Shift+R" -ForegroundColor Yellow
