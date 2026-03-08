# Simple runner for Windows + Xcelium + cocotb (edit simulator flags if needed)
# Usage: open PowerShell, activate venv, then:
#   & .\tools\scripts\run_pyuvm_xrun_windows.ps1
$env:PYTHONPATH = "C:\Users\shimti\OneDrive - Tallinna Tehnika?likool\Sharjeel\Taltech\PhD\RISC-V all you need\riscv-microarchitecture-lab\tb_pyuvm;"
# Remove old waves/logs
Remove-Item -ErrorAction SilentlyContinue -Force waves.vcd
Remove-Item -ErrorAction SilentlyContinue -Recurse artifacts,work,xcelium.d
New-Item -ItemType Directory -Path artifacts -Force | Out-Null

# Example xrun call (adjust simulator paths/flags for your environment)
# xrun -sv rtl/common/*.sv rtl/single_cycle/*.sv tb/single_cycle_smoke_tb_waves.sv -R -access +rwc -python3 -pythonpath "C:\Users\shimti\OneDrive - Tallinna Tehnika?likool\Sharjeel\Taltech\PhD\RISC-V all you need\riscv-microarchitecture-lab\tb_pyuvm" -l artifacts\xrun_pyuvm.log

Write-Host "run_pyuvm_xrun_windows.ps1 created. Edit the xrun line to match your simulator installation, then run it from PowerShell (with venv activated)."
