@echo off
setlocal
call "C:\Program Files (x86)\Microsoft Visual Studio\18\Insiders\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 exit /b 1
cd /d "%~dp0"
if not exist bin mkdir bin
cl /nologo /std:c++17 /EHsc /W4 /WX /MT /O2 /LD audio_master.cpp /Fobin\audio_master.obj /Febin\flaccess_audio_master.dll /link ole32.lib uuid.lib propsys.lib /IMPLIB:bin\flaccess_audio_master.lib
if errorlevel 1 exit /b 1
cl /nologo /std:c++17 /EHsc /W4 /WX /MT /O2 test_master_policy.cpp /Fobin\test_master_policy.obj /Febin\test_master_policy.exe
if errorlevel 1 exit /b 1
bin\test_master_policy.exe
if errorlevel 1 exit /b 1
cl /nologo /std:c++17 /EHsc /W4 /WX /MT /O2 test_master_sessions.cpp /Fobin\test_master_sessions.obj /Febin\test_master_sessions.exe /link ole32.lib uuid.lib propsys.lib
if errorlevel 1 exit /b 1
bin\test_master_sessions.exe
exit /b %errorlevel%
