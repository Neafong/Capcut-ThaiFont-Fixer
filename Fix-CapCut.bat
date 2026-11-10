@echo off
chcp 65001 >nul
title CapCut Thai Font Fixer
echo ========================================================
echo        CapCut PC Thai Font ^& Scale Fixer by Noob-Win
echo ========================================================
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\patch_capcut.ps1"
echo.
pause
