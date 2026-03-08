###############################################################################
# Project      : riscv-microarchitecture-lab
# Author       : Sharjeel Imtiaz
# Affiliation  : PhD Student, Tallinn University of Technology (TalTech)
# Year         : 2026
# Version      : v1.0 (pyuvm + cocotb single-cycle smoke)
#
# Contact      : sharjeel.imtiaz@taltech.ee
#                sharjeelimtiazprof@gmail.com
#
# Description  :
# Cocotb entry test that instantiates a tiny pyuvm-based env. The DUT's
# instruction memory is expected to be preloaded (rtl/common/programs/prog1.hex).
#
# This script is intentionally minimal: the "env" observes registers and
# performs a smoke check for the 3-instruction program (x1=5, x2=7, x3=12).
###############################################################################

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from pyuvm import *

from tb_pyuvm.pyuvm_env.env import SingleCycleEnv
from tb_pyuvm.pyuvm_env.sequence import SmokeSequence

@cocotb.test()
async def run_pyuvm_smoke(dut):
    """Top-level cocotb test: create clock, reset, create pyuvm env and run a smoke seq."""
    # create a clock (10ns period)
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # reset
    dut.rst_n.value = 0
    await Timer(12, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    # create & build UVM env
    env = SingleCycleEnv("env", dut)
    env.build_phase(None)
    env.connect_phase(None)
    env.start_phase(None)

    # run a sequence (pyuvm style)
    seq = SmokeSequence("smoke_seq")
    seq.start(env.agent.seqr)   # start sequence on the sequencer

    # wait for sequence to finish or a few cycles
    await Timer(300, units="ns")

    # check scoreboard outcome (scoreboard sets uvm_reporter on failure)
    passed = env.scoreboard.passed
    if not passed:
        # dump debug info
        print(f"[COCOTB] Scoreboard reports FAIL; DUT regs: x1={env.monitor.last_regs[1]}, x2={env.monitor.last_regs[2]}, x3={env.monitor.last_regs[3]}")
        raise cocotb.result.TestFailure("Smoke test failed")
    else:
        print(f"[COCOTB] SMOKE PASS: x1={env.monitor.last_regs[1]}, x2={env.monitor.last_regs[2]}, x3={env.monitor.last_regs[3]}")