#Requires -Version 5.0

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ArgumentCompleter({
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

        $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
        $srcPath = Join-Path $scriptRoot 'src'
        if (Test-Path $srcPath) {
            Get-ChildItem -Path $srcPath -Directory |
                    Where-Object { $_.Name -like "$wordToComplete*" } |
                    ForEach-Object { $_.Name }
        }
    })]
    [string]$Folder
)

function Write-ErrorMsg($msg) {
    Write-Host "❌  $msg" -ForegroundColor Red
}
function Write-SuccessMsg($msg) {
    Write-Host "✅  $msg" -ForegroundColor Green
}
function Write-InfoMsg($msg) {
    Write-Host "ℹ️ $msg" -ForegroundColor Cyan
}
function Write-FolderMsg($msg) {
    Write-Host "📁 $msg" -ForegroundColor Yellow
}
function Write-CopyMsg($msg) {
    Write-Host "📦 $msg" -ForegroundColor Magenta
}

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$SrcPath = Join-Path $ScriptRoot "src\$Folder"
$WebPath = Join-Path $SrcPath "web"

# Validate folder
if (!(Test-Path $SrcPath -PathType Container)) {
    Write-ErrorMsg "The folder `"$Folder`" does not exist in `"$($ScriptRoot)\src`"."
    Write-ErrorMsg "Please provide a valid relative folder name under the `src` directory."
    exit 1
}

# Show folder selection
Write-FolderMsg "Selected build folder: $SrcPath"

# Configurable values (keep in sync with index.html)
$INITIAL_MEMORY_PAGES = 2000
$MAX_MEMORY_PAGES     = 65536
$PAGE_SIZE            = 65536

# Calculate memory (bytes)
$INITIAL_MEMORY_BYTES = $INITIAL_MEMORY_PAGES * $PAGE_SIZE
$MAX_MEMORY_BYTES     = $MAX_MEMORY_PAGES * $PAGE_SIZE

# Build with Odin
Write-InfoMsg "Building project in `"$Folder`" with Odin..."
Push-Location $SrcPath
& odin.exe build . -target:js_wasm32 -out:web/program.wasm -o:size `
    -extra-linker-flags:"--export-table --import-memory --initial-memory=$INITIAL_MEMORY_BYTES --max-memory=$MAX_MEMORY_BYTES"

if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Odin build failed!"
    Pop-Location
    exit 1
}

# Locate Odin root
Write-InfoMsg "Getting Odin root path..."
$ODIN_ROOT = (& odin.exe root).Trim()

if (!(Test-Path "$ODIN_ROOT/vendor/wgpu/wgpu.js")) {
    Write-ErrorMsg "wgpu.js not found in `"$ODIN_ROOT/vendor/wgpu/`""
    Pop-Location
    exit 1
}
if (!(Test-Path "$ODIN_ROOT/core/sys/wasm/js/odin.js")) {
    Write-ErrorMsg "odin.js not found in `"$ODIN_ROOT/core/sys/wasm/js/`""
    Pop-Location
    exit 1
}

# Copy dependencies
Write-CopyMsg "Copying dependencies to web folder..."
if (!(Test-Path $WebPath)) {
    New-Item -ItemType Directory -Path $WebPath | Out-Null
}

Copy-Item "$ODIN_ROOT/vendor/wgpu/wgpu.js" "$WebPath/wgpu.js" -Force
if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Failed to copy wgpu.js!"
    Pop-Location
    exit 1
}
Copy-Item "$ODIN_ROOT/core/sys/wasm/js/odin.js" "$WebPath/odin.js" -Force
if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Failed to copy odin.js!"
    Pop-Location
    exit 1
}

Write-SuccessMsg "Build and copy tasks completed successfully for `"$Folder`"!"
Pop-Location

