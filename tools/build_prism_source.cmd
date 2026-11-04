@echo off
setlocal
call "C:\Program Files (x86)\Microsoft Visual Studio\18\Insiders\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 exit /b 1
rem Optional project-local ATL extracted from hash-verified Microsoft VSIX packages.
set "FLACCESS_ATL=%CD%\.build\atl\extracted\Contents\VC\Tools\MSVC\14.51.36231\atlmfc"
if exist "%FLACCESS_ATL%\include\atlbase.h" set "INCLUDE=%FLACCESS_ATL%\include;%INCLUDE%"
if exist "%FLACCESS_ATL%\lib\x64\atls.lib" set "LIB=%FLACCESS_ATL%\lib\x64;%LIB%"
set "FLACCESS_CMAKE=C:\Program Files (x86)\Microsoft Visual Studio\18\Insiders\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
set "PATH=C:\Program Files (x86)\Microsoft Visual Studio\18\Insiders\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja;%PATH%"
"%FLACCESS_CMAKE%" -S reference/prism -B .build/prism020 -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS_DEBUG=/Z7 -DCMAKE_CXX_FLAGS_DEBUG=/Z7 -DBUILD_SHARED_LIBS=ON -DPRISM_ENABLE_TESTS=ON -DPRISM_ENABLE_DEMOS=OFF -DPRISM_ENABLE_SHIMS=OFF
if errorlevel 1 exit /b 1
"%FLACCESS_CMAKE%" --build .build/prism020 --parallel 4
if errorlevel 1 exit /b 1
"%FLACCESS_CMAKE%" --install .build/prism020 --prefix .build/prism020-install
