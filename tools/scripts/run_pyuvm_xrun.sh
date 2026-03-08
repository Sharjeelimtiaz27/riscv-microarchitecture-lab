#!/usr/bin/env bash
# Minimal run script to launch Xcelium with cocotb + pyuvm
# Usage: ./tools/scripts/run_pyuvm_xrun.sh

set -euo pipefail
export PYTHONPATH="$PWD/tb_pyuvm:$PYTHONPATH"
# remove old artifacts
rm -rf artifacts work xcelium.d waves.vcd
mkdir -p artifacts

# xrun command - you might need to tweak flags based on local Xcelium/cocotb integration
xrun -sv rtl/common/*.sv rtl/single_cycle/*.sv tb/single_cycle_smoke_tb_waves.sv \
     -R -access +rwc \
     -python3 \
     -pythonpath "$PWD/tb_pyuvm" \
     -l artifacts/xrun_pyuvm.log

echo "Simulation finished. Logs in artifacts/xrun_pyuvm.log, waves.vcd generated (if TB requests)."