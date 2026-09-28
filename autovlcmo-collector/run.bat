@echo off
REM Chay collect.ps1 voi quyen Administrator.
REM Chuot phai file nay -> Run as administrator (hoac cu double-click, no se tu xin quyen).

setlocal
cd /d "%~dp0"

REM Neu chua co quyen admin thi tu xin nang quyen roi chay lai chinh minh.
net session >nul 2>&1
if %errorlevel% NEQ 0 (
    echo Dang xin quyen Administrator...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0collect.ps1" %*

endlocal
