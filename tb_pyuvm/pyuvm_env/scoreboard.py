###############################################################################
# Project      : riscv-microarchitecture-lab
# Author       : Sharjeel Imtiaz
# Affiliation  : PhD Student, Tallinn University of Technology (TalTech)
# Year         : 2026
# Version      : v1.0 (pyuvm scoreboard)
#
# Contact      : sharjeel.imtiaz@taltech.ee
#                sharjeelimtiazprof@gmail.com
#
# Description  :
# A minimal scoreboard that checks the smoke test expected values.
###############################################################################

from pyuvm import *

class SingleCycleScoreboard(UVMComponent):
    def __init__(self, name, parent, dut):
        super().__init__(name, parent)
        self.dut = dut
        self.passed = True
        self.last_snapshot = None

    def sample(self, regs_snapshot):
        self.last_snapshot = regs_snapshot
        # smoke-check expectations: x1==5, x2==7, x3==12
        if regs_snapshot[1] == 5 and regs_snapshot[2] == 7 and regs_snapshot[3] == 12:
            self.passed = True
        else:
            # don't immediately fail — let test decide timing; keep flag false
            self.passed = False