@echo off
chcp 65001 >nul
title Kuzgun Iletisim CRM - Kurulum
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Kurulum.ps1" %*
echo.
echo  (Devam icin bir tusa basin)
pause >nul
exit /b %ERRORLEVEL%
