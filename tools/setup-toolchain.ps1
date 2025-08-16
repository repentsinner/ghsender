# Local Toolchain Setup for Windows 11
# Container-style development for desktop GUI software
# Installs all project dependencies in local toolchain\ directory

param(
    [switch]$Force = $false
)

# Error handling
$ErrorActionPreference = "Stop"

# Get project root
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot
$ToolchainDir = Join-Path $ProjectRoot "toolchain"

# Color output functions
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Status {
    param([string]$Message)
    Write-ColorOutput "[INFO] $Message" "Green"
}

function Write-Warning {
    param([string]$Message)
    Write-ColorOutput "[WARN] $Message" "Yellow"
}

function Write-Error {
    param([string]$Message)
    Write-ColorOutput "[ERROR] $Message" "Red"
}

function Write-Step {
    param([string]$Message)
    Write-ColorOutput "[STEP] $Message" "Blue"
}

Write-ColorOutput "=== Local Toolchain Setup (Windows 11) ===" "Green"
Write-Host "Project: ghSender"
Write-Host "Toolchain Directory: $ToolchainDir"
Write-Host "Platform: Windows $(Get-ComputerInfo | Select-Object -ExpandProperty WindowsProductName)"
Write-Host ""

# Load version configuration
$VersionsFile = Join-Path $ProjectRoot "tools" "versions.sh"
if (Test-Path $VersionsFile) {
    # Parse shell script format for environment variables
    Get-Content $VersionsFile | Where-Object { $_ -match "^export\s+\w+=" } | ForEach-Object {
        if ($_ -match "^export\s+(\w+)=(.*)$") {
            $key = $matches[1]
            $value = $matches[2].Trim('"')
            Set-Variable -Name $key -Value $value -Scope Script
        }
    }
} else {
    Write-Error "versions.sh file not found at $VersionsFile"
    exit 1
}

# Create toolchain directory structure
function Setup-Directories {
    Write-Step "Setting up toolchain directory structure..."
    
    $dirs = @("flutter", "scripts", "cache", "config")
    foreach ($dir in $dirs) {
        $fullPath = Join-Path $ToolchainDir $dir
        if (-not (Test-Path $fullPath)) {
            New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
        }
    }
    
    Write-Status "Created toolchain directories"
}

# Download and install Flutter SDK locally
function Install-Flutter {
    Write-Step "Installing Flutter SDK locally..."
    
    $FlutterDir = Join-Path $ToolchainDir "flutter"
    $FlutterExe = Join-Path $FlutterDir "bin" "flutter.bat"
    
    # Check if Flutter is already installed with correct version
    if ((Test-Path $FlutterExe) -and (Test-Path (Join-Path $FlutterDir "bin" "flutter"))) {
        try {
            $CurrentVersion = & $FlutterExe --version 2>$null | Select-String "Flutter" | ForEach-Object { ($_ -split " ")[1] }
            if ($CurrentVersion -eq $Script:FLUTTER_VERSION) {
                Write-Status "Flutter $Script:FLUTTER_VERSION already installed"
                return
            } else {
                Write-Warning "Found Flutter $CurrentVersion, but need $Script:FLUTTER_VERSION"
                if ($Force) {
                    Remove-Item -Recurse -Force $FlutterDir -ErrorAction SilentlyContinue
                } else {
                    Write-Warning "Use -Force to reinstall"
                    return
                }
            }
        } catch {
            Write-Warning "Found incomplete Flutter installation, removing..."
            Remove-Item -Recurse -Force $FlutterDir -ErrorAction SilentlyContinue
        }
    } elseif (Test-Path $FlutterDir) {
        Write-Warning "Found incomplete Flutter installation, removing..."
        Remove-Item -Recurse -Force $FlutterDir -ErrorAction SilentlyContinue
    }
    
    # Download Flutter for Windows
    $FlutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_$($Script:FLUTTER_VERSION)-stable.zip"
    $TempDir = [System.IO.Path]::GetTempPath()
    $ZipFile = Join-Path $TempDir "flutter_windows_$($Script:FLUTTER_VERSION)-stable.zip"
    
    Write-Status "Downloading Flutter $Script:FLUTTER_VERSION for Windows..."
    
    try {
        # Download with progress
        $WebClient = New-Object System.Net.WebClient
        $WebClient.DownloadFile($FlutterUrl, $ZipFile)
        $WebClient.Dispose()
        
        Write-Status "Extracting Flutter to $FlutterDir..."
        
        # Extract Flutter using Windows built-in zip support
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, $TempDir)
        
        # Move Flutter to toolchain directory
        $ExtractedFlutter = Join-Path $TempDir "flutter"
        if (Test-Path $ExtractedFlutter) {
            Move-Item $ExtractedFlutter $FlutterDir
            Write-Status "Moved Flutter to $FlutterDir"
        } else {
            Write-Error "Flutter directory not found after extraction"
            exit 1
        }
        
        # Cleanup
        Remove-Item $ZipFile -ErrorAction SilentlyContinue
        
    } catch {
        Write-Error "Failed to download or extract Flutter: $_"
        exit 1
    }
    
    # Verify installation
    $FlutterExe = Join-Path $FlutterDir "bin" "flutter.bat"
    if (Test-Path $FlutterExe) {
        Write-Status "Flutter $Script:FLUTTER_VERSION installed successfully"
    } else {
        Write-Error "Flutter installation failed - binary not found"
        exit 1
    }
}

# Create environment activation script
function Create-ActivationScript {
    Write-Step "Creating environment activation script..."
    
    $ScriptsDir = Join-Path $ToolchainDir "scripts"
    $ActivationScript = Join-Path $ScriptsDir "activate-env.ps1"
    
    $ScriptContent = @"
# Activate local toolchain environment for Windows 11
# Usage: . .\toolchain\scripts\activate-env.ps1

# Set toolchain directory
`$ToolchainDir = "$ToolchainDir"
`$ProjectRoot = "$ProjectRoot"

# Add Flutter to PATH
`$FlutterHome = Join-Path `$ToolchainDir "flutter"
`$FlutterBin = Join-Path `$FlutterHome "bin"
`$env:FLUTTER_HOME = `$FlutterHome
`$env:FLUTTER_ROOT = `$FlutterHome

# Set Flutter/Dart cache directories to local toolchain
`$PubCache = Join-Path `$ToolchainDir "cache" "pub"
`$env:PUB_CACHE = `$PubCache

# Create cache directories if they don't exist
if (-not (Test-Path `$PubCache)) {
    New-Item -ItemType Directory -Path `$PubCache -Force | Out-Null
}

# Update PATH
`$env:PATH = "`$FlutterBin;" + `$env:PATH

Write-Host "✅ Activated local toolchain environment" -ForegroundColor Green
Write-Host "   Flutter Home: `$FlutterHome"
Write-Host "   Flutter: `$(if (Get-Command flutter -ErrorAction SilentlyContinue) { (Get-Command flutter).Source } else { 'not found in PATH' })"
Write-Host "   Dart: `$(if (Get-Command dart -ErrorAction SilentlyContinue) { (Get-Command dart).Source } else { 'not found in PATH' })"
Write-Host "   Pub Cache: `$PubCache"
"@

    Set-Content -Path $ActivationScript -Value $ScriptContent -Encoding UTF8
    Write-Status "Created activation script: $ActivationScript"
}

# Create convenience activation script in tools/
function Create-ToolsActivationScript {
    Write-Step "Creating tools/activate-env.ps1 convenience script..."
    
    $ToolsScript = Join-Path $ProjectRoot "tools" "activate-env.ps1"
    
    $ScriptContent = @"
# Convenience script to activate local toolchain for Windows 11
# Usage: . .\tools\activate-env.ps1

`$ProjectRoot = Split-Path -Parent `$PSScriptRoot
`$ActivationScript = Join-Path `$ProjectRoot "toolchain" "scripts" "activate-env.ps1"

if (Test-Path `$ActivationScript) {
    . `$ActivationScript
} else {
    Write-Error "Activation script not found at `$ActivationScript"
    Write-Error "Run .\tools\setup-toolchain.ps1 first"
}
"@
    
    Set-Content -Path $ToolsScript -Value $ScriptContent -Encoding UTF8
    Write-Status "Created convenience script: $ToolsScript"
}

# Update build scripts to use local toolchain
function Update-BuildScripts {
    Write-Step "Build script (build.ps1) already configured for local toolchain"
    # The existing build.ps1 already has the right structure
    Write-Status "PowerShell build script ready"
}

# Create VS Code configuration for Windows
function Create-VSCodeConfig {
    Write-Step "Creating VS Code configuration for local toolchain..."
    
    $VSCodeDir = Join-Path $ProjectRoot ".vscode"
    if (-not (Test-Path $VSCodeDir)) {
        New-Item -ItemType Directory -Path $VSCodeDir -Force | Out-Null
    }
    
    $SettingsFile = Join-Path $VSCodeDir "settings.json"
    
    if (-not (Test-Path $SettingsFile)) {
        $Settings = @{
            "dart.flutterSdkPath" = "./toolchain/flutter"
            "dart.sdkPath" = "./toolchain/flutter/bin/cache/dart-sdk"
            "dart.debugExternalPackageLibraries" = $false
            "dart.debugSdkLibraries" = $false
            "flutter.hotReloadOnSave" = $true
            "flutter.hotRestartOnSave" = $false
            "editor.formatOnSave" = $true
            "editor.codeActionsOnSave" = @{
                "source.fixAll" = $true
            }
            "files.associations" = @{
                "*.arb" = "json"
            }
            "terminal.integrated.env.windows" = @{
                "PATH" = "`${workspaceFolder}/toolchain/flutter/bin;`${env:PATH}"
                "PUB_CACHE" = "`${workspaceFolder}/toolchain/cache/pub"
                "FLUTTER_ROOT" = "`${workspaceFolder}/toolchain/flutter"
            }
        }
        
        $Settings | ConvertTo-Json -Depth 10 | Set-Content -Path $SettingsFile -Encoding UTF8
        Write-Status "Created VS Code settings.json"
    } else {
        Write-Status "VS Code settings.json already exists"
    }
}

# Run Flutter doctor to check system dependencies
function Check-SystemDependencies {
    Write-Step "Checking system dependencies with Flutter doctor..."
    
    # Temporarily add Flutter to PATH for this check
    $FlutterBin = Join-Path $ToolchainDir "flutter" "bin"
    $env:PATH = "$FlutterBin;$env:PATH"
    
    Write-Host ""
    Write-Host "=== Flutter Doctor Output ===" -ForegroundColor Cyan
    try {
        & flutter doctor
    } catch {
        Write-Warning "Flutter doctor failed to run: $_"
    }
    Write-Host "=== End Flutter Doctor ===" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Warning "Review Flutter doctor output above for any missing system dependencies"
    Write-Status "Note: Some warnings are expected since we're using a local toolchain"
}

# Main execution
function Main {
    Write-Status "Starting local toolchain setup for Windows 11..."
    Write-Status "This will install all development tools in: $ToolchainDir"
    Write-Host ""
    
    try {
        Setup-Directories
        Install-Flutter
        Create-ActivationScript
        Create-ToolsActivationScript
        Update-BuildScripts
        Create-VSCodeConfig
        
        Write-Host ""
        Write-Status "✅ Local toolchain setup complete!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps:"
        Write-Host "1. Activate the environment:"
        Write-Host "   . .\tools\activate-env.ps1"
        Write-Host ""
        Write-Host "2. Verify installation:"
        Write-Host "   flutter --version"
        Write-Host "   flutter doctor"
        Write-Host ""
        Write-Host "3. Start development:"
        Write-Host "   flutter create test_app"
        Write-Host "   cd test_app"
        Write-Host "   flutter run"
        Write-Host ""
        
        # Run system dependency check
        Check-SystemDependencies
        
    } catch {
        Write-Error "Setup failed: $_"
        exit 1
    }
}

# Run main function
Main