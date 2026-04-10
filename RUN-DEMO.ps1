$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$cacheRoot = 'D:\homix-cache'
$tempRoot = Join-Path $cacheRoot 'temp'
$pipCache = Join-Path $cacheRoot 'pip'
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
New-Item -ItemType Directory -Force -Path $pipCache | Out-Null

$env:TEMP = $tempRoot
$env:TMP = $tempRoot
$env:PIP_CACHE_DIR = $pipCache
$env:HOME = $cacheRoot
$env:USERPROFILE = $cacheRoot
$env:INSIGHTFACE_HOME = Join-Path $cacheRoot '.insightface'

$venvPython = Join-Path $root 'backend\ai\insightface\.venv\Scripts\python.exe'
$fallbackPython = Join-Path $env:LocalAppData 'Programs\Python\Python311\python.exe'

if (Test-Path $venvPython) {
  $pythonExe = $venvPython
} elseif (Test-Path $fallbackPython) {
  $pythonExe = $fallbackPython
} else {
  Write-Host 'Python not found (venv or system path).' -ForegroundColor Red
  Write-Host 'Expected one of:' -ForegroundColor Yellow
  Write-Host " - $venvPython" -ForegroundColor Yellow
  Write-Host " - $fallbackPython" -ForegroundColor Yellow
  exit 1
}

Write-Host 'Installing AI dependencies (if needed)...' -ForegroundColor Cyan
& $pythonExe -m pip install --upgrade pip | Out-Null
& $pythonExe -m pip install --prefer-binary -r .\backend\ai\requirements.txt

Write-Host 'Starting Flask AI service on :5000 ...' -ForegroundColor Cyan
Start-Process -FilePath $pythonExe -ArgumentList 'app.py' -WorkingDirectory (Join-Path $root 'backend\ai') -WindowStyle Minimized

Write-Host 'Starting Node backend API ...' -ForegroundColor Cyan
Start-Process -FilePath 'npm' -ArgumentList '--prefix .\backend\server start' -WorkingDirectory $root -WindowStyle Minimized

Start-Sleep -Seconds 3

Write-Host 'Opening demo in browser: http://127.0.0.1:3003' -ForegroundColor Green
Start-Process 'http://127.0.0.1:3003'

Write-Host 'Demo services started.' -ForegroundColor Green
Write-Host 'To stop: close the launched terminal windows or end node/python processes.' -ForegroundColor Yellow
