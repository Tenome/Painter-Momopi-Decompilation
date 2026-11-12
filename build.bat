@echo off
rem ============================================================================================================================
rem  Painter Momopie - build everything from your own ROM.
rem
rem  1. Put your Painter Momopie ROM (a .gb file) in the same folder as this file. Its SHA-1 must be
rem     193901223ffc89cf4f42a19e57447249affcc843 (the Japanese original).
rem  2. Double-click build.bat. The first run downloads the tools it needs (RGBDS, ~1 MB, and a C compiler, ~190 MB) into the
rem     .buildtools folder; Python 3.9 or newer (from python.org, with "tcl/tk" and "Add to PATH") must already be installed.
rem  3. The finished folder is PainterMomopie\ next to this file: game_win.exe (the game), settings.exe (every option),
rem     level_editor.exe (the level editor), the example and tutorial level packs, textures, docs.
rem
rem  The programs contain data from your ROM: keep them for yourself, do not publish them.
rem ============================================================================================================================
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title Painter Momopie - build

set "WANT_SHA1=193901223FFC89CF4F42A19E57447249AFFCC843"
set "RGBDS_URL=https://github.com/gbdev/rgbds/releases/download/v1.0.4/rgbds-win64.zip"
set "RGBDS_SHA256=BD1D7E386F290AFD57F4EA9A7353BFCD4AE10884A94C5C1F2FC42A75DB7F97E6"
set "LLVM_NAME=llvm-mingw-20261104-ucrt-x86_64"
set "LLVM_URL=https://github.com/mstorsjo/llvm-mingw/releases/download/20261104/%LLVM_NAME%.zip"
set "LLVM_SHA256=552191B5754C49A5A20723276A6FC56541EA1922C4C50B7B669022333FC1B40F"
set "TOOLS=%CD%\.buildtools"
set "OUT=%CD%\PainterMomopie"

echo.
echo  Painter Momopie - building the PC port
echo  ======================================
echo.

rem ---------------------------------------------------------------- 1. the ROM
echo [1/8] Looking for the ROM...
set "ROM="
set "FOUND_ANY="
for %%f in (*.gb) do (
    if not defined ROM (
        set "FOUND_ANY=1"
        call :hash SHA1 "%%f" H
        if /i "!H!"=="%WANT_SHA1%" (
            set "ROM=%%f"
        ) else (
            echo       %%f does not match: SHA-1 !H!
        )
    )
)
if not defined ROM (
    if exist "orig\painter_momopie.gb" (
        call :hash SHA1 "orig\painter_momopie.gb" H
        if /i "!H!"=="%WANT_SHA1%" set "ROM=orig\painter_momopie.gb"
    )
)
if not defined ROM (
    echo.
    if defined FOUND_ANY (
        echo  The .gb file in this folder is not the right ROM. It must be the Japanese original of Painter Momopie
        echo  with the SHA-1 %WANT_SHA1%.
    ) else (
        echo  No ROM found. Copy your Painter Momopie ROM ^(a .gb file^) into this folder, next to build.bat, and run it again.
    )
    goto :fail
)
echo       found %ROM% ^(SHA-1 matches^)
if not exist "orig" mkdir "orig"
if /i not "%ROM%"=="orig\painter_momopie.gb" copy /y "%ROM%" "orig\painter_momopie.gb" >nul

rem ---------------------------------------------------------------- 2. Python
echo [2/8] Looking for Python...
set "PY="
py -3 -c "import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)" >nul 2>&1
if not errorlevel 1 set "PY=py -3"
if not defined PY (
    python -c "import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)" >nul 2>&1
    if not errorlevel 1 set "PY=python"
)
if not defined PY (
    echo.
    echo  Python 3.9 or newer was not found. Install it from https://www.python.org/downloads/ ^(tick "Add python.exe to PATH"
    echo  and keep "tcl/tk and IDLE" selected^), or run:  winget install Python.Python.3.12
    echo  Then run build.bat again.
    goto :fail
)
%PY% -c "import tkinter" >nul 2>&1
if errorlevel 1 (
    echo.
    echo  This Python has no tkinter ^(needed for the level editor^). Re-run the Python installer, choose Modify and tick "tcl/tk and IDLE".
    goto :fail
)
echo       using %PY%

rem ---------------------------------------------------------------- 3. RGBDS
echo [3/8] Looking for RGBDS ^(the Game Boy assembler^)...
if not exist "%TOOLS%\rgbds\rgbasm.exe" (
    echo       downloading RGBDS...
    call :download "%RGBDS_URL%" "%RGBDS_SHA256%" "%TOOLS%\rgbds.zip"
    if errorlevel 1 goto :fail
    mkdir "%TOOLS%\rgbds" >nul 2>&1
    tar -xf "%TOOLS%\rgbds.zip" -C "%TOOLS%\rgbds"
    if errorlevel 1 (
        echo  Could not unpack RGBDS.
        goto :fail
    )
    del "%TOOLS%\rgbds.zip" >nul 2>&1
)
if not exist "%TOOLS%\rgbds\rgbasm.exe" (
    echo  RGBDS did not unpack as expected: "%TOOLS%\rgbds\rgbasm.exe" is missing.
    goto :fail
)
echo       RGBDS ready

rem ---------------------------------------------------------------- 4. C compiler
echo [4/8] Looking for a C compiler...
set "CC="
if exist "%TOOLS%\%LLVM_NAME%\bin\clang.exe" set "CC=%TOOLS%\%LLVM_NAME%\bin\clang.exe"
if not defined CC (
    for %%c in (clang gcc) do (
        if not defined CC (
            where %%c >nul 2>&1
            if not errorlevel 1 call :trycc %%c
        )
    )
)
if not defined CC (
    echo       none found: downloading a compiler ^(llvm-mingw, about 190 MB, only the first time^)...
    call :download "%LLVM_URL%" "%LLVM_SHA256%" "%TOOLS%\llvm.zip"
    if errorlevel 1 goto :fail
    echo       unpacking it ^(a minute or two^)...
    tar -xf "%TOOLS%\llvm.zip" -C "%TOOLS%"
    if errorlevel 1 (
        echo  Could not unpack the compiler.
        goto :fail
    )
    del "%TOOLS%\llvm.zip" >nul 2>&1
    set "CC=%TOOLS%\%LLVM_NAME%\bin\clang.exe"
)
if not exist "%CC%" (
    where "%CC%" >nul 2>&1
    if errorlevel 1 (
        echo  The compiler "%CC%" was not found.
        goto :fail
    )
)
echo       using %CC%

rem ---------------------------------------------------------------- 5. the sources and assets from the ROM
echo [5/8] Extracting the game data from your ROM...
%PY% tools\gb_dis.py --write --rom "orig\painter_momopie.gb"
if errorlevel 1 goto :fail

echo [6/8] Rebuilding the ROM from the sources ^(must be byte-identical^)...
%PY% tools\build.py --rgbds "%TOOLS%\rgbds"
if errorlevel 1 goto :fail

rem ---------------------------------------------------------------- 7. the PC port
echo [7/8] Building the PC port ^(game, settings window, test runner^)...
%PY% tools\build_port.py --rgbds "%TOOLS%\rgbds" --cc "%CC%"
if errorlevel 1 goto :fail

rem ---------------------------------------------------------------- 8. the level editor and the final folder
echo [8/8] Building the level editor and packaging...
%PY% -m pip install --disable-pip-version-check --quiet pillow pyinstaller
if errorlevel 1 (
    echo  Could not install Pillow and PyInstaller with pip ^(is there an internet connection?^).
    goto :fail
)
%PY% tools\build_editor.py
if errorlevel 1 goto :fail
%PY% tools\package.py --out "%OUT%"
if errorlevel 1 goto :fail

echo.
echo  ======================================
echo  Done. Your folder: %OUT%
echo    game_win.exe      the game
echo    settings.exe      every option in a window
echo    level_editor.exe  the level editor
echo  It contains data from your ROM: for your own use only, do not publish it.
echo  ======================================
echo.
if /i not "%PM_NOPAUSE%"=="1" (
    if exist "%OUT%\game_win.exe" explorer "%OUT%"
    pause
)
exit /b 0

:fail
echo.
echo  The build stopped. Read the message above; fix it and run build.bat again ^(finished steps are skipped or quick^).
echo.
if /i not "%PM_NOPAUSE%"=="1" pause
exit /b 1

rem ---------------------------------------------------------------- subroutines
:hash
rem  call :hash ALGORITHM "file" VARIABLE
set "PM_FILE=%~2"
for /f "usebackq delims=" %%h in (`powershell -NoProfile -Command "(Get-FileHash -Algorithm %~1 -LiteralPath $env:PM_FILE).Hash"`) do set "%~3=%%h"
exit /b 0

:download
rem  call :download URL SHA256 target
if not exist "%TOOLS%" mkdir "%TOOLS%"
curl.exe -L --fail --retry 3 -o "%~3" "%~1"
if errorlevel 1 (
    echo  The download failed: %~1
    echo  Check the internet connection and run build.bat again.
    exit /b 1
)
call :hash SHA256 "%~3" DLHASH
if /i not "!DLHASH!"=="%~2" (
    echo  The downloaded file does not have the expected checksum, so it is not used.
    echo  expected %~2
    echo  got      !DLHASH!
    del "%~3" >nul 2>&1
    exit /b 1
)
exit /b 0

:trycc
rem  a compiler on the PATH is used when it can build a small Windows program
if not exist "%TOOLS%" mkdir "%TOOLS%"
> "%TOOLS%\cc_test.c" echo #include ^<windows.h^>
>> "%TOOLS%\cc_test.c" echo int main^(void^) { return GetTickCount^(^) ^& 0; }
%~1 -O1 -w "%TOOLS%\cc_test.c" -o "%TOOLS%\cc_test.exe" -luser32 -lwinmm >nul 2>&1
if not errorlevel 1 set "CC=%~1"
del "%TOOLS%\cc_test.c" "%TOOLS%\cc_test.exe" >nul 2>&1
exit /b 0
