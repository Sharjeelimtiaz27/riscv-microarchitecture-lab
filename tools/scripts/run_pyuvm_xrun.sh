#!/usr/bin/env bash
###############################################################################
# Project      : riscv-microarchitecture-lab
# Author       : Sharjeel Imtiaz
# Affiliation  : PhD Student, Tallinn University of Technology (TalTech)
# Year         : 2026
#
# Description  :
# Launches the single-cycle RV32I pyuvm smoke test under Cadence Xcelium.
# Run this script from the repository root after loading the Cadence
# environment (cad && 1.3 on TalTech HPC).
#
# Usage:
#   cd /path/to/riscv-microarchitecture-lab
#   cad && 1.3
#   ./tools/scripts/run_pyuvm_xrun.sh
###############################################################################

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Set PYTHONPATH so Python can find tb_pyuvm package imports.
export PYTHONPATH="$REPO_ROOT/tb_pyuvm:${PYTHONPATH:-}"

# Set cocotb environment variables.
# MODULE points to the cocotb test file (dot-separated package path).
export MODULE="cocotb_tests.test_single_cycle"
export TOPLEVEL="single_cycle_top"
export TOPLEVEL_LANG="verilog"

# Clean previous run artifacts.
rm -rf artifacts work xcelium.d waves.vcd
mkdir -p artifacts

echo "Running pyuvm smoke test under Xcelium..."

xrun \
    -sv \
    rtl/common/alu.sv \
    rtl/common/alu_ctrl.sv \
    rtl/common/regfile.sv \
    rtl/common/pc.sv \
    rtl/common/immgen.sv \
    rtl/common/inst_memory.sv \
    rtl/common/data_memory.sv \
    rtl/single_cycle/single_cycle_top.sv \
    -top single_cycle_top \
    -access +rwc \
    -sv_lib $(cocotb-config --lib-name-path vpi xcelium) \
    -l artifacts/xrun_pyuvm.log

echo ""
echo "Simulation complete. Check artifacts/xrun_pyuvm.log for results."
echo "Search the log for: SMOKE PASS or SMOKE FAIL"
