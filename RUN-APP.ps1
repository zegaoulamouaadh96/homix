# 🚀 Quick Setup - تثبيت وتشغيل سريع

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Smart Home Security - Quick Setup" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

$projectPath = "c:\Users\ADMIN\Desktop\PFE\frontend"

# Check if Flutter is installed
Write-Host "🔍 Checking Flutter installation..." -ForegroundColor Yellow
$flutterInstalled = Get-Command flutter -ErrorAction SilentlyContinue

if (-not $flutterInstalled) {
    Write-Host "❌ Flutter not found in PATH!" -ForegroundColor Red
    Write-Host ""
    Write-Host "📥 Please install Flutter first:" -ForegroundColor Yellow
    Write-Host "   1. Download: https://docs.flutter.dev/get-started/install/windows" -ForegroundColor White
    Write-Host "   2. Extract to C:\flutter" -ForegroundColor White
    Write-Host "   3. Add C:\flutter\bin to PATH" -ForegroundColor White
    Write-Host "   4. Restart this script" -ForegroundColor White
    Write-Host ""
    Write-Host "Or install via Chocolatey:" -ForegroundColor Yellow
    Write-Host "   choco install flutter -y" -ForegroundColor White
    Write-Host ""
    
    $response = Read-Host "Do you want to open Flutter download page? (Y/N)"
    if ($response -eq 'Y' -or $response -eq 'y') {
        Start-Process "https://docs.flutter.dev/get-started/install/windows"
    }
    
    exit
}

Write-Host "✅ Flutter found!" -ForegroundColor Green
Write-Host ""

# Show Flutter version
Write-Host "📋 Flutter version:" -ForegroundColor Yellow
flutter --version
Write-Host ""

# Run Flutter Doctor
Write-Host "🏥 Running Flutter Doctor..." -ForegroundColor Yellow
flutter doctor
Write-Host ""

# Navigate to project
Write-Host "📂 Navigating to project: $projectPath" -ForegroundColor Yellow
Set-Location $projectPath
Write-Host ""

# Get packages
Write-Host "📦 Installing Flutter packages..." -ForegroundColor Yellow
flutter pub get
Write-Host ""

# Check for devices
Write-Host "📱 Available devices:" -ForegroundColor Yellow
flutter devices
Write-Host ""

# Ask user which device to use
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Select a device to run the app:" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "1. Chrome (Web) - Recommended for quick testing" -ForegroundColor White
Write-Host "2. Windows Desktop" -ForegroundColor White
Write-Host "3. Android Emulator (if available)" -ForegroundColor White
Write-Host "4. Exit" -ForegroundColor White
Write-Host ""

$choice = Read-Host "Enter your choice (1-4)"

switch ($choice) {
    "1" {
        Write-Host ""
        Write-Host "🌐 Running on Chrome..." -ForegroundColor Green
        flutter run -d chrome
    }
    "2" {
        Write-Host ""
        Write-Host "💻 Running on Windows Desktop..." -ForegroundColor Green
        flutter run -d windows
    }
    "3" {
        Write-Host ""
        Write-Host "📱 Running on Android Emulator..." -ForegroundColor Green
        flutter run
    }
    "4" {
        Write-Host ""
        Write-Host "👋 Goodbye!" -ForegroundColor Yellow
        exit
    }
    default {
        Write-Host ""
        Write-Host "❌ Invalid choice! Running on Chrome by default..." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        flutter run -d chrome
    }
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  App launched successfully!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
