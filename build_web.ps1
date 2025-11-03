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
$LibsPath = Join-Path $ScriptRoot "libs"
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

# Always recreate web folder
if (Test-Path $WebPath) {
    Write-InfoMsg "Removing existing web folder at $WebPath..."
    Remove-Item -Recurse -Force $WebPath
}
Write-InfoMsg "Creating web folder at $WebPath..."
New-Item -ItemType Directory -Path $WebPath | Out-Null

# Build with Odin
Write-InfoMsg "Building project in `"$Folder`" with Odin..."
Push-Location $SrcPath
& odin.exe build . -target:js_wasm32 -collection:libs=$LibsPath -out:web/program.wasm -o:size `
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
Copy-Item "$LibsPath/io_utils/io_utils.js" "$WebPath/io_utils.js" -Force
if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Failed to copy io_utils.js!"
    Pop-Location
    exit 1
}

# Copy assets folder from repo root into web folder
$AssetsSrc = Join-Path $ScriptRoot 'assets'
$AssetsDst = Join-Path $WebPath 'assets'

if (Test-Path $AssetsSrc -PathType Container) {
    Write-CopyMsg "Copying assets folder to web/assets..."
    Copy-Item -Path $AssetsSrc -Destination $AssetsDst -Recurse -Force
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Failed to copy assets folder!"
        Pop-Location
        exit 1
    }
} else {
    Write-InfoMsg "No assets folder was found at project root. Skipping assets copy."
}

# Copy central index.html template into web folder
$IndexTemplate = Join-Path $SrcPath 'index.html'
$IndexTarget   = Join-Path $WebPath 'index.html'

if (Test-Path $IndexTemplate) {
    Write-CopyMsg "Copying index.html template into web folder..."
    Copy-Item $IndexTemplate $IndexTarget -Force
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Failed to copy index.html template!"
        Pop-Location
        exit 1
    }
} else {
    Write-ErrorMsg "index.html template was not found at $IndexTemplate!"
    Pop-Location
    exit 1
}

Write-SuccessMsg "Build and copy tasks completed successfully for `"$Folder`"!"
Pop-Location
