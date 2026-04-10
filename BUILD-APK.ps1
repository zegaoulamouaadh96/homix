$ErrorActionPreference = 'Stop'

$projectRoot = "c:\Users\ADMIN\Desktop\PFE\frontend"
Set-Location $projectRoot

Write-Host "Building Flutter app for Android..." -ForegroundColor Cyan
Write-Host ""

# Ensure we're in the right place
if (-not (Test-Path "pubspec.yaml")) {
    Write-Host "ERROR: pubspec.yaml not found in $projectRoot" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Project found at: $(Get-Location)" -ForegroundColor Green
Write-Host ""

Write-Host "Step 1: Clean build..." -ForegroundColor Yellow
flutter clean

Write-Host ""
Write-Host "Step 2: Get dependencies..." -ForegroundColor Yellow
flutter pub get

Write-Host ""
Write-Host "Step 3: Building APK..." -ForegroundColor Yellow
flutter build apk --debug

Write-Host ""
Write-Host "Step 4: Installing on device..." -ForegroundColor Yellow
adb install -r build/app/outputs/apk/debug/app-debug.apk

Write-Host ""
Write-Host "Step 5: Launching app on device..." -ForegroundColor Yellow
adb shell am start -n com.homix.security/.MainActivity

Write-Host ""
Write-Host "✓ Build and deployment complete!" -ForegroundColor Green
