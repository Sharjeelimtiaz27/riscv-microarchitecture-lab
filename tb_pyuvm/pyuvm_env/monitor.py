###############################################################################
# Project      : riscv-microarchitecture-lab
# Author       : Sharjeel Imtiaz
# Affiliation  : PhD Student, Tallinn University of Technology (TalTech)
# Year         : 2026
# Version      : v1.0 (pyuvm monitor)
#
# Contact      : sharjeel.imtiaz@taltech.ee
#                sharjeelimtiazprof@gmail.com
#
# Description  :
# The monitor samples register file periodically and informs scoreboard.
# For simplicity the monitor records the latest snapshot of regs.
###############################################################################

from pyuvm import *
import cocotb
from cocotb.triggers import RisingEdge

class SingleCycleMonitor(UVMComponent):
    def __init__(self, name, parent, dut):
        super().__init__(name, parent)
        self.dut = dut
        self.scoreboard = None
        self.last_regs = [0]*32
        self.passed = True

    async def run_phase(self, phase):
        # continuously sample at posedge
        while True:
            await RisingEdge(self.dut.clk)
            # sample the register file via hierarchical access
            for i in range(32):
                # some sims require int() conversion
                self.last_regs[i] = int(self.dut.rf.regs[i].value)
            # forward snapshot to scoreboard
            if self.scoreboard is not None:
                self.scoreboard.sample(self.last_regs)