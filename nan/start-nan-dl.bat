@echo off
chcp 65001 >nul
title nan-dl
cd /d "%~dp0"
if /i "%~1"=="test" goto test
:cscript-start
start "" wscript.exe "%~dp0nan-dl.js"
echo started nan-dl (background). log: C:\nan\dl.log
timeout /t 2 >nul
exit /b 0

:test
cscript //nologo "%~dp0nan-dl.js" once
echo ---- log ----
if exist "C:\nan\dl.log" type "C:\nan\dl.log"
pause
exit /b 0