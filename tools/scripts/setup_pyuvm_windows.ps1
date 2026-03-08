<#
===============================================================================
Project      : riscv-microarchitecture-lab
Author       : Sharjeel Imtiaz
Affiliation  : PhD Student, Tallinn University of Technology (TalTech)
Year         : 2026
Version      : v1.0 (Windows environment bootstrap for pyuvm + cocotb)

Contact      : sharjeel.imtiaz@taltech.ee
               sharjeelimtiazprof@gmail.com

Purpose      :
This PowerShell script helps prepare a Windows development environment for
cocotb + pyuvm based verification. It:
 - checks for Python in PATH
 - creates a virtual environment at %USERPROFILE%\pyuvm-env
 - attempts to upgrade pip and install cocotb, pyuvm, pytest
 - creates recommended repo folders (tb_pyuvm, tools/scripts, rtl/assertions)
 - prints helpful troubleshooting guidance if pip is blocked by Group Policy

Notes:
 - This script cannot bypass corporate Group Policy that blocks pip.exe.
 - If pip is blocked you may need admin assistance, or use the Python embeddable
   distribution (instructions printed below), or use Anaconda/Miniconda.
 - Run this script in PowerShell (Windows 10/11). If execution policy blocks it,
   run: Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
===============================================================================
#>

# helper function: write in color
function Info { param($m) Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Warn { param($m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Err  { param($m) Write-Host "[ERROR] $m" -ForegroundColor Red }

# 1) check for Python
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
    Warn "Python not found in PATH."
    Write-Host ""
    Write-Host " -> Please install Python 3.8+ from https://www.python.org/downloads/"
    Write-Host " -> Or run tools/scripts/open_python_download.bat to open the download page."
    Write-Host ""
    exit 0
} else {
    $pyVer = & python --version 2>&1
    Info "Found Python: $pyVer"
}

# 2) create virtualenv path
$venv = Join-Path $env:USERPROFILE "pyuvm-env"
if (-not (Test-Path $venv)) {
    Info "Creating Python virtual environment at: $venv"
    & python -m venv $venv
    if ($LASTEXITCODE -ne 0) {
        Err "Failed to create venv. You may need to run PowerShell as Administrator or install venv support."
        exit 1
    }
} else {
    Info "Virtualenv already exists at $venv"
}

# 3) activate venv for this script session
$activate = Join-Path $venv "Scripts\Activate.ps1"
if (Test-Path $activate) {
    Info "Activating virtualenv..."
    # dot-source the activate script in current session
    . $activate
} else {
    Err "Activate script not found at $activate. Virtualenv creation probably failed."
    exit 1
}

# 4) try to upgrade pip and install packages
Info "Checking pip availability..."
try {
    $pipPath = Get-Command pip -ErrorAction Stop
    Info "pip found: $($pipPath.Path)"
} catch {
    Warn "pip not found or blocked. Attempting to use python -m pip..."
}

# Use python -m pip to avoid calling pip.exe directly
Info "Upgrading pip using python -m pip (may require connectivity and permission)..."
& python -m pip install --upgrade pip
if ($LASTEXITCODE -ne 0) {
    Warn "pip upgrade failed. This may be due to corporate policy (pip.exe blocked) or network restrictions."
    Write-Host ""
    Write-Host "  Possible remedies:"
    Write-Host "   - Run PowerShell as Administrator and retry."
    Write-Host "   - Ask IT to allow pip.exe or install Python for your user."
    Write-Host "   - Use the Python embeddable distribution (instructions below)."
    Write-Host ""
    # continue: try user install of packages (best-effort)
}

# install cocotb, pyuvm, pytest into venv
Info "Installing cocotb, pyuvm, pytest into venv (this may take a minute)..."
& python -m pip install cocotb pyuvm pytest
if ($LASTEXITCODE -ne 0) {
    Warn "Package install failed. See notes below for alternatives."
    Write-Host ""
    Write-Host "If you see 'blocked by group policy', you must either:"
    Write-Host "  1) Ask your sysadmin to allow pip installs for your account, OR"
    Write-Host "  2) Use Miniconda/Anaconda (install for user) and run 'conda create -n pyuvm python=3.10' then 'conda activate pyuvm' and 'pip install ...', OR"
    Write-Host "  3) Use the Python embeddable zip and pip wheel files (advanced)."
    Write-Host ""
}

# 5) create repo helper dirs (if not present)
$repoRoot = Get-Location
$paths = @("tb_pyuvm\cocotb_tests", "tb_pyuvm\pyuvm_env", "tools\scripts", "rtl\assertions", "docs\weekly_notebooks")
foreach ($p in $paths) {
    $full = Join-Path $repoRoot $p
    if (-not (Test-Path $full)) {
        New-Item -ItemType Directory -Path $full | Out-Null
        Info "Created: $p"
    } else {
        Info "Exists: $p"
    }
}

# 6) create a small run script hint for Windows (PowerShell)
$runShPath = Join-Path $repoRoot "tools\scripts\run_pyuvm_xrun_windows.ps1"
if (-not (Test-Path $runShPath)) {
    @"
# Simple runner for Windows + Xcelium + cocotb (edit simulator flags if needed)
# Usage: open PowerShell, activate venv, then:
#   & .\tools\scripts\run_pyuvm_xrun_windows.ps1
`$env:PYTHONPATH = "$PWD\tb_pyuvm;$env:PYTHONPATH"
# Remove old waves/logs
Remove-Item -ErrorAction SilentlyContinue -Force waves.vcd
Remove-Item -ErrorAction SilentlyContinue -Recurse artifacts,work,xcelium.d
New-Item -ItemType Directory -Path artifacts -Force | Out-Null

# Example xrun call (adjust simulator paths/flags for your environment)
# xrun -sv rtl/common/*.sv rtl/single_cycle/*.sv tb/single_cycle_smoke_tb_waves.sv -R -access +rwc -python3 -pythonpath "$PWD\tb_pyuvm" -l artifacts\xrun_pyuvm.log

Write-Host "run_pyuvm_xrun_windows.ps1 created. Edit the xrun line to match your simulator installation, then run it from PowerShell (with venv activated)."
"@ | Out-File -Encoding ASCII $runShPath
    Info "Created helper: tools\scripts\run_pyuvm_xrun_windows.ps1"
} else {
    Info "Helper run script already exists: tools\scripts\run_pyuvm_xrun_windows.ps1"
}

# 7) final message and next steps
Write-Host ""
Info "Bootstrap finished (best-effort)."
Write-Host ""
Write-Host "Next recommended steps (copy-paste):"
Write-Host "  # start fresh PowerShell (recommended) and enable scripts for current user if blocked"
Write-Host "  Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned"
Write-Host "  # activate venv"
Write-Host "  & `"$venv\Scripts\Activate.ps1`""
Write-Host "  # test pip"
Write-Host "  python -m pip --version"
Write-Host "  # try running the run script (edit xrun line if necessary)"
Write-Host "  & .\tools\scripts\run_pyuvm_xrun_windows.ps1"
Write-Host ""
Write-Host "If pip is blocked by Group Policy, read below for fallback options."
Write-Host ""
Write-Host "Fallback options if pip is blocked:"
Write-Host "  - Use Miniconda/Anaconda (install for user) and run: conda create -n pyuvm python=3.10; conda activate pyuvm; pip install cocotb pyuvm pytest"
Write-Host "  - Use Python Embeddable zip: https://www.python.org/downloads/windows/  (download 'Embeddable zip file'), extract to a folder, and follow 'pip in embeddable' instructions in Python docs"
Write-Host "  - Ask your IT to allow pip for your account or install Python for you."
Write-Host ""
Info "If you want, run the appended batch to open Python download page:"
Write-Host "  .\tools\scripts\open_python_download.bat"