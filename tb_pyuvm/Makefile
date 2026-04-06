###############################################################################
# Project      : riscv-microarchitecture-lab
# Author       : Sharjeel Imtiaz
# Affiliation  : PhD Student, Tallinn University of Technology (TalTech)
# Year         : 2026
#
# Description  :
# cocotb 2.0 Makefile for the single-cycle RV32I pyuvm smoke test.
# Run from the tb_pyuvm/ directory after loading the Cadence environment:
#
#   cd tb_pyuvm
#   make
#
# To clean:
#   make clean
###############################################################################

# Simulator: Cadence Xcelium
SIM        = xcelium

# Top-level SystemVerilog module
TOPLEVEL   = single_cycle_top

# cocotb test module (Python dotted path from PYTHONPATH root)
MODULE     = cocotb_tests.test_single_cycle

# Language of the top-level HDL file
TOPLEVEL_LANG = verilog

# RTL source files — paths relative to repo root (one level up from here)
VERILOG_SOURCES  = $(realpath ../rtl/common/alu.sv)
VERILOG_SOURCES += $(realpath ../rtl/common/alu_ctrl.sv)
VERILOG_SOURCES += $(realpath ../rtl/common/regfile.sv)
VERILOG_SOURCES += $(realpath ../rtl/common/pc.sv)
VERILOG_SOURCES += $(realpath ../rtl/common/immgen.sv)
VERILOG_SOURCES += $(realpath ../rtl/common/inst_memory.sv)
VERILOG_SOURCES += $(realpath ../rtl/common/data_memory.sv)
VERILOG_SOURCES += $(realpath ../rtl/single_cycle/single_cycle_top.sv)

# Extra simulator flags: enable full signal access for hierarchical writes
COMPILE_ARGS = -access +rwc -sv

# PYTHONPATH must include the tb_pyuvm parent directory so that
# "from tb_pyuvm.pyuvm_env.env import ..." resolves correctly.
# We set it to the repo root (one level above this Makefile).
export PYTHONPATH := $(realpath ..):$(PYTHONPATH)

# Include cocotb's own Makefile which handles all VPI wiring
include $(shell cocotb-config --makefiles)/Makefile.sim
