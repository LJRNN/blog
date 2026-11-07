@echo off
setlocal
chcp 65001 >nul
title nan-dl install
set "DIR=C:\nan"
if not exist "%DIR%" mkdir "%DIR%"
cd /d "%DIR%"

echo [1/3] download nan-dl.js
curl -L --fail --retry 2 --connect-timeout 15 -o "%DIR%\nan-dl.js" "https://cdn.jsdelivr.net/gh/LJRNN/blog@main/nan/nan-dl.js"
if exist "%DIR%\nan-dl.js" goto gotjs
curl -L --fail --retry 2 --connect-timeout 15 -o "%DIR%\nan-dl.js" "https://raw.githubusercontent.com/LJRNN/blog/main/nan/nan-dl.js"
:gotjs

echo [2/3] download start-nan-dl.bat
curl -L --fail --retry 2 --connect-timeout 15 -o "%DIR%\start-nan-dl.bat" "https://cdn.jsdelivr.net/gh/LJRNN/blog@main/nan/start-nan-dl.bat"
if exist "%DIR%\start-nan-dl.bat" goto gotbat
curl -L --fail --retry 2 --connect-timeout 15 -o "%DIR%\start-nan-dl.bat" "https://raw.githubusercontent.com/LJRNN/blog/main/nan/start-nan-dl.bat"
:gotbat

if not exist "%DIR%\nan-dl.js" echo download failed, no nan-dl.js & pause & exit /b 1
for %%A in ("%DIR%\nan-dl.js") do echo   nan-dl.js size=%%~zA
if not exist "%DIR%\start-nan-dl.bat" echo warning: start-nan-dl.bat missing, run: wscript "%DIR%\nan-dl.js"

echo [3/3] first test run (one-shot)
cscript //nologo "%DIR%\nan-dl.js" once
echo.
echo ---- log ----
if exist "%DIR%\dl.log" type "%DIR%\dl.log"

echo.
echo starting background poller...
start "" wscript.exe "%DIR%\nan-dl.js"
echo ok. log: C:\nan\dl.log
pause
