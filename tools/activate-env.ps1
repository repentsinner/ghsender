# Activate local toolchain environment for Windows
# Usage: . .\tools\activate-env.ps1

# Get project root
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ToolchainDir = Join-Path $ProjectRoot "toolchain"

# Add Flutter to PATH
$FlutterHome = Join-Path $ToolchainDir "flutter"
$FlutterBin = Join-Path $FlutterHome "bin"
$env:FLUTTER_HOME = $FlutterHome
$env:FLUTTER_ROOT = $FlutterHome

# Add CMake to PATH
$CmakeHome = Join-Path $ToolchainDir "cmake"
$CmakeBin = Join-Path $CmakeHome "bin"

# Set Flutter/Dart cache directories to local toolchain
$CacheDir = Join-Path $ToolchainDir "cache"
$PubCache = Join-Path $CacheDir "pub"
$env:PUB_CACHE = $PubCache

# Create cache directories if they don't exist
if (-not (Test-Path $PubCache)) {
    New-Item -ItemType Directory -Path $PubCache -Force | Out-Null
}

# Update PATH - Add Flutter and CMake
$env:PATH = "$FlutterBin;$CmakeBin;$env:PATH"

# Display activation message
Write-Host "✅ Activated local toolchain environment" -ForegroundColor Green
Write-Host "   Project Root: $ProjectRoot"
Write-Host "   Flutter Home: $FlutterHome"

# Check if Flutter is available
$FlutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if ($FlutterCmd) {
    Write-Host "   Flutter: $($FlutterCmd.Source)" -ForegroundColor Green
} else {
    Write-Host "   Flutter: not found in PATH" -ForegroundColor Yellow
}

# Check if Dart is available
$DartCmd = Get-Command dart -ErrorAction SilentlyContinue
if ($DartCmd) {
    Write-Host "   Dart: $($DartCmd.Source)" -ForegroundColor Green
} else {
    Write-Host "   Dart: not found in PATH" -ForegroundColor Yellow
}

# Check if CMake is available
$CmakeCmd = Get-Command cmake -ErrorAction SilentlyContinue
if ($CmakeCmd) {
    Write-Host "   CMake: $($CmakeCmd.Source)" -ForegroundColor Green
} else {
    Write-Host "   CMake: not found in PATH" -ForegroundColor Yellow
}

Write-Host "   Pub Cache: $PubCache"
Write-Host ""
Write-Host "Note: Run ./tools/setup-toolchain.ps1 if tools are not found" -ForegroundColor Cyan