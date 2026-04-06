###############################################################################
# Project      : riscv-microarchitecture-lab
# Author       : Sharjeel Imtiaz
# Affiliation  : PhD Student, Tallinn University of Technology (TalTech)
# Year         : 2026
# Version      : v2.0 (pyuvm monitor — proper UVM run_phase flow)
#
# Contact      : sharjeel.imtiaz@taltech.ee
#                sharjeelimtiazprof@gmail.com
#
# Description  :
# The monitor is a passive observer. It never drives any DUT signal.
# On every rising clock edge it samples the register file through cocotb
# hierarchical access and forwards the snapshot to the scoreboard for
# checking. It also captures the current PC and the instruction word
# being executed, giving the scoreboard full visibility into DUT state.
###############################################################################

from pyuvm import uvm_component
from cocotb.triggers import RisingEdge
from .coverage import CoverageCollector
import cocotb


class SingleCycleMonitor(uvm_component):
    """
    Samples the DUT register file, PC, and current instruction on every
    rising clock edge. Forwards each snapshot to the scoreboard for
    correctness checking and to the coverage collector for functional
    coverage tracking. The monitor never writes to any DUT signal.
    """

    def __init__(self, name, parent, dut):
        super().__init__(name, parent)
        self.dut        = dut
        self.scoreboard = None              # assigned by env during connect_phase
        self.coverage   = CoverageCollector()
        self.last_regs  = [0] * 32
        self.last_pc    = 0
        self.last_instr = 0

    async def run_phase(self, phase):
        """
        Passive sampling loop. Runs for the duration of the simulation.
        On each rising edge, captures register file, PC, and instruction
        word, then forwards to the scoreboard and coverage collector.
        """
        while True:
            await RisingEdge(self.dut.clk)

            for i in range(32):
                self.last_regs[i] = int(self.dut.rf.regs[i].value)

            self.last_pc    = int(self.dut.pc.value)
            self.last_instr = int(self.dut.instr.value)

            cocotb.log.info(
                f"MONITOR  PC=0x{self.last_pc:08X}  "
                f"instr=0x{self.last_instr:08X}  "
                f"x1={self.last_regs[1]}  "
                f"x2={self.last_regs[2]}  "
                f"x3={self.last_regs[3]}"
            )

            # Forward snapshot to scoreboard for correctness checking.
            if self.scoreboard is not None:
                self.scoreboard.sample(
                    regs  = self.last_regs,
                    pc    = self.last_pc,
                    instr = self.last_instr,
                )

            # Sample current instruction into the coverage collector.
            self.coverage.sample(self.last_instr)
