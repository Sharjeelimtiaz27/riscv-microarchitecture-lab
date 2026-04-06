###############################################################################
# Project      : riscv-microarchitecture-lab
# Author       : Sharjeel Imtiaz
# Affiliation  : PhD Student, Tallinn University of Technology (TalTech)
# Year         : 2026
# Version      : v2.1 (cocotb top-level test — preloaded IMEM smoke test)
#
# Contact      : sharjeel.imtiaz@taltech.ee
#                sharjeelimtiazprof@gmail.com
#
# Description  :
# Top-level cocotb entry point for the single-cycle RV32I UVM smoke test.
# The DUT instruction memory is preloaded from prog1.hex via $readmemh in
# the RTL, so no driver IMEM writes are needed for this test. The monitor
# and scoreboard run against the live DUT and check all expected register
# values after the program has had enough cycles to complete.
#
# The sequence/driver flow (loading IMEM via UVM transactions) is reserved
# for the randomized test phase where different programs need to be loaded
# dynamically without changing the RTL hex file path.
#
# Execution order:
#   1. Clock is started.
#   2. Reset is released after two clock periods.
#   3. Monitor samples every rising edge and forwards to scoreboard.
#   4. After 128 cycles the scoreboard result is read.
#   5. Test passes or fails based on all expected register values.
###############################################################################

import cocotb
from cocotb.clock    import Clock
from cocotb.triggers import RisingEdge, Timer

from tb_pyuvm.pyuvm_env.monitor    import SingleCycleMonitor
from tb_pyuvm.pyuvm_env.scoreboard import SingleCycleScoreboard


@cocotb.test()
async def run_pyuvm_smoke(dut):
    """
    Single-cycle RV32I smoke test. IMEM is preloaded from prog1.hex by the
    RTL. The monitor observes every clock cycle and the scoreboard checks all
    expected register values after the full program has executed.
    """

    # Start the clock: 10 ns period = 100 MHz.
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    # Hold reset for two full clock periods so the DUT initialises cleanly.
    dut.rst_n.value = 0
    await Timer(20, unit="ns")

    # Instantiate and connect monitor and scoreboard directly.
    # No UVM phase machinery needed — we drive phases manually.
    scoreboard = SingleCycleScoreboard("scoreboard", None, dut)
    monitor    = SingleCycleMonitor   ("monitor",    None, dut)
    monitor.scoreboard = scoreboard

    # Start the monitor as a background coroutine.
    cocotb.start_soon(monitor.run_phase(None))

    # Release reset — the processor starts fetching from PC=0x0.
    dut.rst_n.value = 1
    cocotb.log.info("TEST  reset released — processor running")

    # Wait 128 cycles: 32 instructions x 1 cycle each plus margin.
    # The scoreboard performs its check internally after 64 cycles.
    for _ in range(128):
        await RisingEdge(dut.clk)

    # Read the scoreboard result.
    if scoreboard.passed:
        cocotb.log.info(
            f"TEST  SMOKE PASS  "
            f"x1={monitor.last_regs[1]}  "
            f"x2={monitor.last_regs[2]}  "
            f"x3={monitor.last_regs[3]}"
        )
    else:
        assert False, "TEST  SMOKE FAIL — see SCOREBOARD lines above for detail"
