@echo off
setlocal
call "C:\Program Files (x86)\Microsoft Visual Studio\18\Insiders\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 exit /b 1
cd /d "%~dp0"
cl /nologo /std:c++17 /EHsc /W4 /WX /wd4191 /MT /O2 test_windows_silent.cpp /Fobin\test_windows_silent.obj /Febin\test_windows_silent.exe /link ole32.lib uuid.lib propsys.lib
exit /b %errorlevel%
