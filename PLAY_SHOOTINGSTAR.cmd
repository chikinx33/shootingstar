@echo off
title Shootingstar - Local Web Game
cd /d "%~dp0"
where python >nul 2>nul
if errorlevel 1 (
  echo Python was not found. Please install Python or use tools\run.ps1 web.
  pause
  exit /b 1
)
python tools\play_web.py %*
if errorlevel 1 pause
