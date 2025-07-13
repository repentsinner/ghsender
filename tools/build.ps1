# Cross-Platform Build Script for Windows
# Handles all platform-specific build tasks via CLI tools

param(
    [Parameter(Position=0)]
    [string]$Command = "help",
    
    [Parameter(Position=1)]
    [string]$Platform = ""
)

# Error handling
$ErrorActionPreference = "Stop"

# Get project root
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

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

Write-ColorOutput "=== ghSender Build Script ===" "Green"
Write-Host "Platform: Windows"
Write-Host "Architecture: $env:PROCESSOR_ARCHITECTURE"
Write-Host ""

# Check Flutter installation
function Test-Flutter {
    Write-Status "Checking Flutter installation..."
    
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
        Write-Error "Flutter not found. Please install Flutter first."
        exit 1
    }
    
    flutter --version
    Write-Host ""
}

# Get dependencies
function Get-Dependencies {
    Write-Status "Getting Flutter dependencies..."
    flutter pub get
    Write-Host ""
}

# Run tests
function Invoke-Tests {
    Write-Status "Running tests..."
    flutter analyze
    flutter test
    Write-Host ""
}

# Build for specific platform
function Build-Platform {
    param([string]$TargetPlatform)
    
    Write-Status "Building for $TargetPlatform..."
    
    switch ($TargetPlatform) {
        "windows" {
            flutter build windows --release
            Write-Status "Windows build completed: build\windows\x64\runner\Release\"
        }
        "android" {
            flutter build apk --release
            Write-Status "Android APK completed: build\app\outputs\flutter-apk\"
        }
        "web" {
            flutter build web --release
            Write-Status "Web build completed: build\web\"
        }
        default {
            Write-Error "Unknown platform: $TargetPlatform"
            Write-Host "Available platforms on Windows: windows, android, web"
            exit 1
        }
    }
}

# Main execution
switch ($Command) {
    "setup" {
        Write-Status "Setting up development environment..."
        Test-Flutter
        Get-Dependencies
    }
    
    "test" {
        Test-Flutter
        Get-Dependencies
        Invoke-Tests
    }
    
    "build" {
        if ([string]::IsNullOrEmpty($Platform)) {
            Write-Error "Please specify platform: windows, android, web"
            exit 1
        }
        Test-Flutter
        Get-Dependencies
        Invoke-Tests
        Build-Platform $Platform
    }
    
    "all" {
        Test-Flutter
        Get-Dependencies
        Invoke-Tests
        
        # Build all platforms available on Windows
        Build-Platform "windows"
        Build-Platform "android"
        Build-Platform "web"
    }
    
    "clean" {
        Write-Status "Cleaning build artifacts..."
        flutter clean
        if (Test-Path "build") {
            Remove-Item -Recurse -Force "build"
        }
    }
    
    default {
        Write-Host "Usage: .\tools\build.ps1 <command> [options]"
        Write-Host ""
        Write-Host "Commands:"
        Write-Host "  setup          - Setup development environment"
        Write-Host "  test           - Run tests and analysis"
        Write-Host "  build <platform> - Build for specific platform (windows, android, web)"
        Write-Host "  all            - Build for all available platforms"
        Write-Host "  clean          - Clean build artifacts"
        Write-Host "  help           - Show this help message"
        Write-Host ""
        Write-Host "Examples:"
        Write-Host "  .\tools\build.ps1 setup"
        Write-Host "  .\tools\build.ps1 test"
        Write-Host "  .\tools\build.ps1 build windows"
        Write-Host "  .\tools\build.ps1 build android"
        Write-Host "  .\tools\build.ps1 all"
    }
}