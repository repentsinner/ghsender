# Agent Tools Setup Script for Windows 11
# Installs development agent tools to user scope
# - nvm-windows (Node Version Manager for Windows)
# - Claude Code CLI (requires WSL)
# - Gemini CLI

param(
    [switch]$Force = $false
)

# Error handling
$ErrorActionPreference = "Stop"

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

Write-ColorOutput "=== Agent Tools Setup (Windows 11) ===" "Green"
Write-Host "Platform: Windows $(Get-ComputerInfo | Select-Object -ExpandProperty WindowsProductName)"
Write-Host "Installing agent development tools to user scope..."
Write-Host ""

# Check if command exists
function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Check if WSL is available
function Test-WSL {
    try {
        $wslOutput = wsl --status 2>$null
        return $true
    } catch {
        return $false
    }
}

# Install Chocolatey if not present
function Install-Chocolatey {
    Write-Step "Checking for Chocolatey package manager..."
    
    if (Test-Command "choco") {
        Write-Status "Chocolatey already installed"
        return
    }
    
    Write-Status "Installing Chocolatey package manager..."
    
    # Check execution policy
    $executionPolicy = Get-ExecutionPolicy
    if ($executionPolicy -eq "Restricted") {
        Write-Warning "Execution policy is Restricted. Setting to RemoteSigned for current process..."
        Set-ExecutionPolicy RemoteSigned -Scope Process -Force
    }
    
    # Install Chocolatey
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    
    # Refresh environment variables
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    
    if (Test-Command "choco") {
        Write-Status "Chocolatey installed successfully"
    } else {
        Write-Error "Chocolatey installation failed"
        throw "Chocolatey installation failed"
    }
}

# Install NVM for Windows
function Install-NVM {
    Write-Step "Installing NVM for Windows..."
    
    if (Test-Command "nvm") {
        Write-Status "NVM already installed"
        nvm version
        return
    }
    
    # Check if nvm is installed but not in PATH
    $nvmPath = "$env:APPDATA\nvm\nvm.exe"
    if (Test-Path $nvmPath) {
        Write-Status "NVM found but not in PATH, adding to environment..."
        $userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
        if ($userPath -notlike "*$env:APPDATA\nvm*") {
            [System.Environment]::SetEnvironmentVariable("PATH", "$env:APPDATA\nvm;$userPath", "User")
            $env:PATH = "$env:APPDATA\nvm;$env:PATH"
        }
        
        if (Test-Command "nvm") {
            Write-Status "NVM successfully added to PATH"
            nvm version
            return
        }
    }
    
    Write-Status "Installing NVM for Windows via Chocolatey..."
    
    try {
        choco install nvm -y
        
        # Refresh environment variables
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
        
        if (Test-Command "nvm") {
            Write-Status "NVM installed successfully"
            nvm version
        } else {
            Write-Error "NVM installation failed"
        }
    } catch {
        Write-Error "Failed to install NVM: $_"
        throw
    }
}

# Install Node.js LTS via NVM
function Install-Node {
    Write-Step "Installing Node.js LTS via NVM..."
    
    if (-not (Test-Command "nvm")) {
        Write-Error "NVM not available for Node.js installation"
        throw "NVM not available"
    }
    
    # Install and use latest LTS Node.js
    Write-Status "Installing Node.js LTS..."
    
    try {
        nvm install lts
        nvm use lts
        
        # Refresh environment to pick up Node.js
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
        
        if (Test-Command "node") {
            Write-Status "Node.js installed:"
            node --version
            npm --version
        } else {
            Write-Warning "Node.js may require a new terminal session to be available"
        }
    } catch {
        Write-Error "Failed to install Node.js: $_"
        throw
    }
}

# Check WSL status and provide guidance
function Check-WSL {
    Write-Step "Checking WSL availability for Claude Code CLI..."
    
    if (Test-WSL) {
        Write-Status "WSL is available and configured"
        
        try {
            $wslDistros = wsl --list --quiet
            if ($wslDistros) {
                Write-Status "Available WSL distributions:"
                $wslDistros | ForEach-Object { Write-Host "  - $_" }
            }
        } catch {
            Write-Warning "Could not list WSL distributions"
        }
        
        return $true
    } else {
        Write-Warning "WSL is not available or not configured"
        Write-Warning "Claude Code CLI requires WSL on Windows 11"
        Write-Host ""
        Write-Host "To install WSL:"
        Write-Host "1. Run as Administrator: wsl --install"
        Write-Host "2. Restart your computer"
        Write-Host "3. Set up a Linux distribution (Ubuntu recommended)"
        Write-Host "4. Re-run this script after WSL setup"
        Write-Host ""
        return $false
    }
}

# Install Claude Code CLI (requires WSL)
function Install-ClaudeCode {
    Write-Step "Installing Claude Code CLI..."
    
    if (-not (Check-WSL)) {
        Write-Warning "Skipping Claude Code CLI installation - WSL required"
        return
    }
    
    # Check if Claude Code is already installed in WSL
    try {
        $claudeCheck = wsl bash -c "command -v claude" 2>$null
        if ($claudeCheck) {
            Write-Status "Claude Code CLI already installed in WSL"
            wsl bash -c "claude --version" 2>$null
            return
        }
    } catch {
        # Continue with installation
    }
    
    Write-Status "Installing Claude Code CLI in WSL..."
    Write-Status "This requires WSL with a Linux distribution..."
    
    try {
        # Install Node.js and npm in WSL if not present
        Write-Status "Ensuring Node.js is available in WSL..."
        wsl bash -c "
            if ! command -v node >/dev/null 2>&1; then
                curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
                sudo apt-get install -y nodejs
            fi
        "
        
        # Install Claude Code CLI via npm in WSL
        Write-Status "Installing Claude Code CLI via npm in WSL..."
        wsl bash -c "npm install -g @anthropics/claude-code"
        
        # Verify installation
        $claudeInstalled = wsl bash -c "command -v claude" 2>$null
        if ($claudeInstalled) {
            Write-Status "Claude Code CLI installed successfully in WSL"
            wsl bash -c "claude --version" 2>$null
        } else {
            Write-Error "Claude Code CLI installation in WSL failed"
        }
        
    } catch {
        Write-Error "Failed to install Claude Code CLI in WSL: $_"
        Write-Warning "You may need to install it manually in WSL:"
        Write-Host "  wsl bash -c 'npm install -g @anthropics/claude-code'"
    }
}

# Install Gemini CLI
function Install-GeminiCLI {
    Write-Step "Installing Gemini CLI..."
    
    if (Test-Command "gemini") {
        Write-Status "Gemini CLI already installed"
        try {
            gemini --version 2>$null
        } catch {
            Write-Status "Gemini CLI found"
        }
        return
    }
    
    Write-Status "Installing Gemini CLI for Windows..."
    
    # Try installing via npm first
    if (Test-Command "npm") {
        try {
            Write-Status "Attempting to install Gemini CLI via npm..."
            npm install -g @google/generative-ai-cli 2>$null
            
            if (Test-Command "gemini") {
                Write-Status "Gemini CLI installed successfully via npm"
                return
            }
        } catch {
            Write-Warning "npm installation failed, trying alternative method..."
        }
    }
    
    # Try Chocolatey installation
    try {
        Write-Status "Attempting to install Gemini CLI via Chocolatey..."
        choco install gemini-cli -y 2>$null
        
        # Refresh environment variables
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
        
        if (Test-Command "gemini") {
            Write-Status "Gemini CLI installed successfully via Chocolatey"
            return
        }
    } catch {
        Write-Warning "Chocolatey installation failed"
    }
    
    # Manual installation guidance
    Write-Warning "Automatic Gemini CLI installation failed"
    Write-Warning "Please install manually:"
    Write-Host "1. Visit the official Gemini CLI documentation"
    Write-Host "2. Download the Windows binary"
    Write-Host "3. Add to your PATH"
    Write-Host ""
    
    # Create local bin directory for manual installation
    $localBin = "$env:USERPROFILE\.local\bin"
    if (-not (Test-Path $localBin)) {
        New-Item -ItemType Directory -Path $localBin -Force | Out-Null
        Write-Status "Created directory for manual installation: $localBin"
    }
    
    # Add to user PATH if not already there
    $userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    if ($userPath -notlike "*$localBin*") {
        [System.Environment]::SetEnvironmentVariable("PATH", "$localBin;$userPath", "User")
        Write-Status "Added $localBin to user PATH"
    }
}

# Create WSL wrapper for Claude Code
function Create-ClaudeWrapper {
    if (-not (Test-WSL)) {
        return
    }
    
    Write-Step "Creating Windows wrapper for Claude Code CLI..."
    
    $wrapperDir = "$env:USERPROFILE\.local\bin"
    if (-not (Test-Path $wrapperDir)) {
        New-Item -ItemType Directory -Path $wrapperDir -Force | Out-Null
    }
    
    $wrapperPath = Join-Path $wrapperDir "claude.bat"
    
    $wrapperContent = @"
@echo off
wsl bash -c "claude %*"
"@
    
    Set-Content -Path $wrapperPath -Value $wrapperContent -Encoding ASCII
    Write-Status "Created Windows wrapper for Claude Code CLI: $wrapperPath"
    
    # Add wrapper directory to PATH
    $userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    if ($userPath -notlike "*$wrapperDir*") {
        [System.Environment]::SetEnvironmentVariable("PATH", "$wrapperDir;$userPath", "User")
        $env:PATH = "$wrapperDir;$env:PATH"
        Write-Status "Added wrapper directory to PATH"
    }
}

# Verify installations
function Test-Installations {
    Write-Step "Verifying agent tool installations..."
    
    Write-Host ""
    Write-Host "=== Installation Verification ===" -ForegroundColor Cyan
    
    # Test Chocolatey
    if (Test-Command "choco") {
        Write-Host "✅ Chocolatey: $(choco --version)" -ForegroundColor Green
    } else {
        Write-Host "❌ Chocolatey: Not found" -ForegroundColor Red
    }
    
    # Test NVM
    if (Test-Command "nvm") {
        Write-Host "✅ NVM: $(nvm version)" -ForegroundColor Green
    } else {
        Write-Host "❌ NVM: Not found" -ForegroundColor Red
    }
    
    # Test Node.js
    if (Test-Command "node") {
        Write-Host "✅ Node.js: $(node --version)" -ForegroundColor Green
    } else {
        Write-Host "❌ Node.js: Not found" -ForegroundColor Red
    }
    
    # Test npm
    if (Test-Command "npm") {
        Write-Host "✅ npm: $(npm --version)" -ForegroundColor Green
    } else {
        Write-Host "❌ npm: Not found" -ForegroundColor Red
    }
    
    # Test Claude Code (Windows wrapper)
    if (Test-Command "claude") {
        try {
            $claudeVersion = claude --version 2>$null
            Write-Host "✅ Claude Code CLI: $claudeVersion" -ForegroundColor Green
        } catch {
            Write-Host "✅ Claude Code CLI: Installed (via WSL)" -ForegroundColor Green
        }
    } else {
        Write-Host "❌ Claude Code CLI: Not found" -ForegroundColor Red
    }
    
    # Test Gemini CLI
    if (Test-Command "gemini") {
        try {
            $geminiVersion = gemini --version 2>$null
            Write-Host "✅ Gemini CLI: $geminiVersion" -ForegroundColor Green
        } catch {
            Write-Host "✅ Gemini CLI: Installed" -ForegroundColor Green
        }
    } else {
        Write-Host "❌ Gemini CLI: Not found" -ForegroundColor Red
    }
    
    # Test WSL
    if (Test-WSL) {
        Write-Host "✅ WSL: Available" -ForegroundColor Green
    } else {
        Write-Host "❌ WSL: Not available (required for Claude Code)" -ForegroundColor Red
    }
    
    Write-Host "=== End Verification ===" -ForegroundColor Cyan
    Write-Host ""
}

# Main execution
function Main {
    Write-Status "Starting agent tools installation for Windows 11..."
    Write-Host ""
    
    try {
        Install-Chocolatey
        Install-NVM
        Install-Node
        Install-ClaudeCode
        Install-GeminiCLI
        Create-ClaudeWrapper
        
        Write-Host ""
        Write-Status "✅ Agent tools setup complete!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps:"
        Write-Host "1. Restart PowerShell or refresh environment:"
        Write-Host "   refreshenv  # if using Chocolatey"
        Write-Host ""
        Write-Host "2. Verify installation:"
        Write-Host "   nvm version"
        Write-Host "   node --version"
        Write-Host "   claude --version"
        Write-Host "   gemini --version"
        Write-Host ""
        Write-Host "3. Configure Claude Code (if not already done):"
        Write-Host "   claude auth"
        Write-Host ""
        Write-Host "4. Configure Gemini CLI (if not already done):"
        Write-Host "   gemini auth  # or similar command"
        Write-Host ""
        
        # Special WSL notes
        if (-not (Test-WSL)) {
            Write-Warning "IMPORTANT: WSL is required for Claude Code CLI on Windows"
            Write-Host "Install WSL first, then re-run this script:"
            Write-Host "  wsl --install"
            Write-Host ""
        }
        
        # Run verification
        Test-Installations
        
        Write-Warning "Note: You may need to restart PowerShell for all changes to take effect"
        
    } catch {
        Write-Error "Setup failed: $_"
        exit 1
    }
}

# Run main function
Main