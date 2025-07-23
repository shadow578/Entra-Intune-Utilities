@echo off
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0\msi2win32.ps1' -MSIFile '%~1'"
pause
