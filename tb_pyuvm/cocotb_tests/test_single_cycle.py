###############################################################################
# Project      : riscv-microarchitecture-lab
# Author       : Sharjeel Imtiaz
# Affiliation  : PhD Student, Tallinn University of Technology (TalTech)
# Year         : 2026
# Version      : v2.0 (cocotb top-level test — proper UVM phase sequence)
#
# Contact      : sharjeel.imtiaz@taltech.ee
#                sharjeelimtiazprof@gmail.com
#
# Description  :
# Top-level cocotb entry point for the single-cycle RV32I UVM smoke test.
# This file is the only place that knows about cocotb test infrastructure.
# Everything else is standard UVM.
#
# Execution order:
#   1. Clock is started.
#   2. Reset is held low so the DUT does not fetch instructions yet.
#   3. The UVM environment is built and connected.
#   4. The driver's run_phase is started as a background coroutine.
#   5. The monitor's run_phase is started as a background coroutine.
#   6. ProgramSequence runs: loads all 32 instructions into IMEM via driver.
#   7. Reset is released — the processor starts executing.
#   8. We wait enough cycles for the full program to complete.
#   9. Scoreboard result is read and the test passes or fails.
###############################################################################

import cocotb
from cocotb.clock   import Clock
from cocotb.triggers import RisingEdge, Timer

from tb_pyuvm.pyuvm_env.env      import SingleCycleEnv
from tb_pyuvm.pyuvm_env.sequence import ProgramSequence


@cocotb.test()
async def run_pyuvm_smoke(dut):
    """
    Single-cycle RV32I smoke test using the full pyuvm environment.
    Loads prog1.hex into IMEM through the UVM sequence/driver flow,
    releases reset, waits for the program to complete, then checks
    all expected register values via the scoreboard.
    """

    # -------------------------------------------------------------------------
    # 1. Start the clock (10 ns period = 100 MHz).
    # -------------------------------------------------------------------------
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # -------------------------------------------------------------------------
    # 2. Assert reset. DUT is held in reset while IMEM is being loaded.
    #    This prevents the processor from fetching garbage instructions
    #    before the driver has finished writing the program.
    # -------------------------------------------------------------------------
    dut.rst_n.value = 0
    await Timer(20, units="ns")     # hold reset for two full clock periods

    # -------------------------------------------------------------------------
    # 3. Build and connect the UVM environment.
    # -------------------------------------------------------------------------
    env = SingleCycleEnv("env", dut)
    env.build_phase(None)
    env.connect_phase(None)

    # -------------------------------------------------------------------------
    # 4. Start driver and monitor run_phase coroutines in the background.
    #    They run concurrently with the rest of this test function.
    # -------------------------------------------------------------------------
    driver_task  = cocotb.start_soon(
        env.agent.driver.run_phase(_PhaseStub())
    )
    monitor_task = cocotb.start_soon(
        env.agent.monitor.run_phase(None)
    )

    # -------------------------------------------------------------------------
    # 5. Run the program sequence: sends all 32 instructions to the driver,
    #    which writes them into IMEM one word at a time.
    #    Reset is still asserted during this step.
    # -------------------------------------------------------------------------
    seq = ProgramSequence("prog_seq")
    await seq.start(env.agent.seqr)

    cocotb.log.info("TEST  IMEM loaded — releasing reset")

    # -------------------------------------------------------------------------
    # 6. Release reset. The processor starts fetching from PC=0x0.
    # -------------------------------------------------------------------------
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # -------------------------------------------------------------------------
    # 7. Wait for the program to complete.
    #    32 instructions x 1 cycle each + margin = 128 cycles.
    # -------------------------------------------------------------------------
    for _ in range(128):
        await RisingEdge(dut.clk)

    # -------------------------------------------------------------------------
    # 8. Read the scoreboard result and end the test.
    # -------------------------------------------------------------------------
    if env.scoreboard.passed:
        cocotb.log.info(
            f"TEST  SMOKE PASS  "
            f"x1={env.agent.monitor.last_regs[1]}  "
            f"x2={env.agent.monitor.last_regs[2]}  "
            f"x3={env.agent.monitor.last_regs[3]}"
        )
    else:
        assert False, "TEST  SMOKE FAIL — see SCOREBOARD lines above for detail"

    # Cancel background tasks cleanly.
    driver_task.cancel()
    monitor_task.cancel()


class _PhaseStub:
    """
    Minimal phase object passed to run_phase when driving phases manually.
    Provides raise_objection and drop_objection as no-ops so the driver
    code does not need to be aware it is running outside the full UVM
    phase manager.
    """
    def raise_objection(self, _):
        pass

    def drop_objection(self, _):
        pass
