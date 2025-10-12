@ECHO off
setlocal enabledelayedexpansion

REM Change to the folder where this script lives
cd /d "%~dp0"

REM --- CONFIGURABLE VALUES ---
REM NOTE: changing this requires changing the same values in the `web/index.html`.
set "INITIAL_MEMORY_PAGES=2000"
set "MAX_MEMORY_PAGES=65536"
set "PAGE_SIZE=65536"

REM --- CALCULATE MEMORY (BYTES) ---
set /a INITIAL_MEMORY_BYTES=%INITIAL_MEMORY_PAGES% * %PAGE_SIZE%
set /a MAX_MEMORY_BYTES=%MAX_MEMORY_PAGES% * %PAGE_SIZE%

REM --- BUILD WITH ODIN ---
ECHO [INFO] Building project with Odin...
call odin.exe build . -target:js_wasm32 -out:web/tutorial.wasm -o:size -extra-linker-flags:"--export-table --import-memory --initial-memory=%INITIAL_MEMORY_BYTES% --max-memory=%MAX_MEMORY_BYTES%"
if errorlevel 1 (
    ECHO [ERROR] Odin build failed!
    goto end
)

REM --- LOCATE ODIN ROOT ---
ECHO [INFO] Getting Odin root path...
for /f "delims=" %%i in ('odin.exe root') do set "ODIN_ROOT=%%i"

if not exist "%ODIN_ROOT%vendor\wgpu\wgpu.js" (
    ECHO [ERROR] wgpu.js not found in "%ODIN_ROOT%vendor\wgpu\"
    goto end
)
if not exist "%ODIN_ROOT%core\sys\wasm\js\odin.js" (
    ECHO [ERROR] odin.js not found in "%ODIN_ROOT%core\sys\wasm\js\"
    goto end
)

REM --- COPY DEPENDENCIES ---
ECHO [INFO] Copying dependencies to web folder...
copy /Y "%ODIN_ROOT%vendor\wgpu\wgpu.js" "web\wgpu.js"
if errorlevel 1 (
    ECHO [ERROR] Failed to copy wgpu.js!
    goto end
)
copy /Y "%ODIN_ROOT%core\sys\wasm\js\odin.js" "web\odin.js"
if errorlevel 1 (
    ECHO [ERROR] Failed to copy odin.js!
    goto end
)

ECHO [SUCCESS] Build and copy tasks completed successfully.

:end
REM Pause only if run from GUI (double-click)
if "%cmdcmdline:~0,1%"=="" pause

endlocal
