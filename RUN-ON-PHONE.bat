@echo off
SET PATH=C:\Windows\System32;C:\Windows;C:\Windows\System32\Wbem;C:\flutter\bin;%PATH%
cd /d "c:\Users\ADMIN\Desktop\PFE\frontend"

echo ============================================
echo   Smart Home Security - Mobile Access
echo ============================================
echo.
echo Your local IP addresses:
C:\Windows\System32\ipconfig.exe | C:\Windows\System32\findstr.exe /i "IPv4"
echo.
echo ============================================
echo   Starting Flutter on web server...
echo ============================================
echo.
echo The app will be accessible from your phone at:
echo   http://192.168.100.30:8080
echo.
echo Make sure your phone is connected to the same WiFi!
echo.
echo Press Ctrl+C to stop the server
echo ============================================
echo.

C:\flutter\bin\flutter.bat run -d web-server --web-port=8080 --web-hostname=0.0.0.0

pause
