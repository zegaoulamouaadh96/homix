@echo off
SET PATH=C:\Windows\System32;C:\Windows;C:\Windows\System32\Wbem;C:\flutter\bin;%PATH%
cd /d "c:\Users\ADMIN\Desktop\PFE\frontend"
echo Starting Flutter app on Chrome...
echo.
C:\flutter\bin\flutter.bat run -d chrome
pause

