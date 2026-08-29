@echo off
cd /d "%~dp0"
title PES Accessibility - Prism
set "PRISM_LOG=warn"
pes-a11y-prism-bridge.exe
if errorlevel 1 pause
