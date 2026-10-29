@echo off
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do set "ESC=%%b"
<nul set /p "=%ESC%[8;30;90t"
mode con: cols=90 lines=30 >nul 2>nul
TITLE Launcher.DoECISORY
COLOR 0F
CLS

REM Lock working directory to project root
cd /d "%~dp0"

REM Environment Check: Verify Julia in PATH
WHERE julia >nul 2>nul
IF %ERRORLEVEL% NEQ 0 (
    set "t=%TIME: =0%"
    set "t=%t:,=.%0"
    echo [%t%] BOOT       : FAIL             Julia not found in system PATH.
    echo Please ensure Julia v1.10 or higher is installed and accessible via system PATH.
    echo Download Julia at: https://julialang.org/downloads/
    PAUSE
    EXIT /B 1
)

:MENU
CLS
COLOR 0F

set "t=%TIME: =0%"
set "t=%t:,=.%0"

echo.
echo ==========================================================================================
echo.
echo                                        DoECISORY.jl
echo                                  System Management Gateway
echo.
echo ==========================================================================================
echo.
echo         [1] STANDARD  MODE                                      [Sysimage Support]
echo         [2] CLEAN JIT MODE                                      [Without Sysimage]
echo         [3] DEVELOPER MODE                                      [Dev Watcher Mode]
echo         [4] BUILD SYSIMAGE                                      [Package Compiler]
echo         [5] RUN TEST SUITE                                      [Coverage Reports]
echo         [Q] QUIT
echo.
echo ==========================================================================================
echo.
echo Press ENTER to default to Standard Mode [1].
set "mode="
set /p mode="      Enter Routing Node (1/2/3/4/5/Q): "

IF "%mode%"=="" set "mode=1"
IF /I "%mode%"=="Q" EXIT /B 0
IF /I "%mode%"=="QUIT" EXIT /B 0
IF /I "%mode%"=="EXIT" EXIT /B 0

IF "%mode%"=="1" GOTO MODE1
IF "%mode%"=="2" GOTO MODE2
IF "%mode%"=="3" GOTO MODE3
IF "%mode%"=="4" GOTO MODE4
IF "%mode%"=="5" GOTO MODE5

echo.
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] GATEWAY    : ERROR            Invalid routing selection.
PAUSE
GOTO MENU

:MODE1
CLS
TITLE DoECISORY.jl
COLOR 0E
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] GATEWAY    : ROUTING          ...
IF EXIST "%~dp0tools\Sysimage.dll" (
    echo %ESC%[97m[%t%] BOOT       : IMAGE            Sysimage DETECTED: tools\Sysimage.dll%ESC%[0m
    echo %ESC%[93m[%t%] BOOT       : SETUP            Initialising Accelerated Mode...%ESC%[0m
    julia --sysimage="%~dp0tools\Sysimage.dll" --depwarn=no --threads auto -O1 --project=. -e "using DoECISORY; launch(; wait=true)"
) ELSE IF EXIST "%~dp0tools\Sysimage_Deps.dll" (
    echo %ESC%[97m[%t%] BOOT       : IMAGE            Sysimage DETECTED: tools\Sysimage_Deps.dll%ESC%[0m
    echo %ESC%[93m[%t%] BOOT       : SETUP            Initialising Accelerated Dependencies...%ESC%[0m
    julia --sysimage="%~dp0tools\Sysimage_Deps.dll" --depwarn=no --threads auto -O1 --project=. -e "using DoECISORY; launch(; wait=true)"
) ELSE (
    echo %ESC%[97m[%t%] BOOT       : IMAGE            No Sysimage found. JIT execution active.%ESC%[0m
    echo %ESC%[93m[%t%] BOOT       : SETUP            Initialising Core Architecture...%ESC%[0m
    julia --depwarn=no --threads auto -O1 --project=. -e "using DoECISORY; launch(; wait=true)"
)
echo.
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] SERVER     : SHUTDOWN         System halted.
PAUSE
EXIT /B 0

:MODE2
CLS
TITLE DoECISORY.jl [Clean JIT]
COLOR 0D
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] GATEWAY    : ROUTING          ...
echo %ESC%[97m[%t%] BOOT       : IMAGE            Sysimage bypassed. JIT compiler engaged.%ESC%[0m
echo %ESC%[95m[%t%] BOOT       : SETUP            Initialising server...%ESC%[0m
julia --depwarn=no --threads auto -O1 --project=. -e "using DoECISORY; launch(; wait=true)"
echo.
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] SERVER     : SHUTDOWN         System halted.
PAUSE
EXIT /B 0

:MODE3
CLS
TITLE DoECISORY.jl [Developer]
COLOR 09
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] GATEWAY    : ROUTING          ...
IF EXIST "%~dp0tools\Sysimage_Deps.dll" (
    echo %ESC%[97m[%t%] BOOT       : IMAGE            Sysimage DETECTED: tools\Sysimage_Deps.dll%ESC%[0m
) ELSE (
    echo %ESC%[97m[%t%] BOOT       : IMAGE            No _Deps found. JIT file watching engaged.%ESC%[0m
)
echo %ESC%[97m[%t%] BOOT       : SETUP            File Watcher active on src/.%ESC%[0m
echo %ESC%[94m[%t%] BOOT       : SETUP            Starting PowerShell Watcher Daemon...%ESC%[0m
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\Watcher.ps1"
echo.
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] GATEWAY    : RETURN           Press any key to return to System Gateway...
pause >nul
GOTO MENU

:MODE4
CLS
TITLE DoECISORY.jl [Compiler]
COLOR 0C
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo.
echo ==========================================================================================
echo   WARNING: PACKAGE COMPILER INITIATION
echo ==========================================================================================
echo   Building a Sysimage typically takes 10 to 15 minutes and
echo   consumes significant system CPU and memory resources.
echo ==========================================================================================
echo.
echo         [F] FULL    [Production: Includes DoECISORY]
echo         [D] DEV     [Development: Dependencies Only]
echo         [C] CANCEL  [Return to Menu]
echo.
echo ==========================================================================================
echo.
set "sys_choice="
set /p sys_choice="      Select Compilation Scope (F/D/C) [C]: "
IF /I "%sys_choice%"=="F" GOTO BUILD_FULL
IF /I "%sys_choice%"=="D" GOTO BUILD_DEV
echo.
echo [%t%] GATEWAY    : ABORT            Sysimage compilation cancelled.
TIMEOUT /T 2 >nul
GOTO MENU

:BUILD_FULL
echo.
echo [%t%] GATEWAY    : ROUTING          Launching Full Compiler (Target: Sysimage.dll)...
echo.
julia --threads auto --project=. "%~dp0tools\Compiler.jl" --full
echo.
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] GATEWAY    : RETURN           Press any key to return to System Gateway...
pause >nul
cls
"%~f0"
exit /b 0

:BUILD_DEV
echo.
echo [%t%] GATEWAY    : ROUTING          Launching Dev Compiler (Target: Sysimage_Deps.dll)...
echo.
julia --threads auto --project=. "%~dp0tools\Compiler.jl" --dev
echo.
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] GATEWAY    : RETURN           Press any key to return to System Gateway...
pause >nul
cls
"%~f0"
exit /b 0

:MODE5
CLS
TITLE DoECISORY.jl [Test Suite]
COLOR 0E
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo.
echo ==========================================================================================
echo   TEST SUITE EXECUTION CONFIRMATION
echo ==========================================================================================
echo   Running the full 100-test suite with coverage instrumentation may take several minutes.
echo ==========================================================================================
echo.
set "confirm_test="
set /p confirm_test="      Are you sure you want to run the Test Suite? (Y/N) [N]: "
IF /I NOT "%confirm_test%"=="Y" (
    echo.
    echo [%t%] GATEWAY    : ABORT            Test suite execution cancelled by user.
    TIMEOUT /T 2 >nul
    GOTO MENU
)
echo.
echo [%t%] GATEWAY    : ROUTING          Executing Test Suite ^& Coverage Report...
echo.
julia --depwarn=no --threads auto --project=. "%~dp0tools\Coverage.jl"
echo.
set "t=%TIME: =0%"
set "t=%t:,=.%0"
echo [%t%] GATEWAY    : RETURN           Press any key to return to System Gateway...
pause >nul
GOTO MENU
