###############################################################################
# Project      : riscv-microarchitecture-lab
# Author       : Sharjeel Imtiaz
# Affiliation  : PhD Student, Tallinn University of Technology (TalTech)
# Year         : 2026
# Version      : v2.0 (pyuvm scoreboard — full program expected values)
#
# Contact      : sharjeel.imtiaz@taltech.ee
#                sharjeelimtiazprof@gmail.com
#
# Description  :
# The scoreboard holds the golden reference model for the smoke test program
# loaded from prog1.hex. On every monitor sample it compares the DUT register
# file against the expected final register values. It checks only after enough
# cycles have elapsed for the full program to have executed, then reports a
# clear PASS or FAIL with per-register detail on any mismatch.
#
# Expected register values after prog1.hex executes (RV32I, signed arithmetic):
#
#   x1  =  5       ADDI x1, x0, 5
#   x2  =  7       ADDI x2, x0, 7
#   x3  = 12       ADD  x3, x1, x2
#   x4  = 13       ADDI x4, x3, 1
#   x5  =  7       SUB  x5, x3, x1
#   x6  = 12 & 7   AND  x6, x3, x2   -> 4
#   x7  = 12 | 7   OR   x7, x3, x2   -> 15
#   x8  = 12 ^ 7   XOR  x8, x3, x2   -> 11
#   x9  = 12 << 5  SLL  x9,  x3, x1  -> 384
#   x10 = 12 >> 5  SRL  x10, x3, x1  -> 0
#   x11 = 12 >> 5  SRA  x11, x3, x1  -> 0
#   x12 = 1        SLT  x12, x1, x2  (5 < 7 signed)
#   x13 = 1        SLTU x13, x1, x2  (5 < 7 unsigned)
#   x14 = 12 & 3   ANDI x14, x3, 3   -> 0
#   x15 = 12 | 4   ORI  x15, x3, 4   -> 12
#   x16 = 12 ^ 5   XORI x16, x3, 5   -> 9
#   x17 = 12 << 1  SLLI x17, x3, 1   -> 24
#   x18 = 12 >> 1  SRLI x18, x3, 1   -> 6
#   x19 = 12 >> 1  SRAI x19, x3, 1   -> 6
#   x20 = 12       LW   x20, 0(x30)  (loaded from mem[64] where x3 was stored)
#   x30 = 64       ADDI x30, x0, 64
###############################################################################

from pyuvm import uvm_component
import cocotb


# Golden reference: register index -> expected value after full program execution.
# Only registers written by the program are listed. x0 is always 0 by definition.
EXPECTED_REGS = {
     1:   5,      # ADDI x1, x0, 5
     2:   7,      # ADDI x2, x0, 7
     3:  12,      # ADD  x3, x1, x2
     4:  13,      # ADDI x4, x3, 1
     5:   7,      # SUB  x5, x3, x1
     6:   4,      # AND  x6, x3, x2   (12 & 7)
     7:  15,      # OR   x7, x3, x2   (12 | 7)
     8:  11,      # XOR  x8, x3, x2   (12 ^ 7)
     9: 384,      # SLL  x9,  x3, x1  (12 << 5)
    10:   0,      # SRL  x10, x3, x1  (12 >> 5 logical)
    11:   0,      # SRA  x11, x3, x1  (12 >> 5 arithmetic)
    12:   1,      # SLT  x12, x1, x2  (5 < 7)
    13:   1,      # SLTU x13, x1, x2  (5 < 7 unsigned)
    14:   0,      # ANDI x14, x3, 3   (12 & 3)
    15:  12,      # ORI  x15, x3, 4   (12 | 4)  -> 12 not 14, 0b1100|0b0100=0b1100
    16:   9,      # XORI x16, x3, 5   (12 ^ 5)
    17:  24,      # SLLI x17, x3, 1   (12 << 1)
    18:   6,      # SRLI x18, x3, 1   (12 >> 1 logical)
    19:   6,      # SRAI x19, x3, 1   (12 >> 1 arithmetic)
    20:  12,      # LW   x20, 0(x30)  (mem[64] = x3 = 12)
    30:  64,      # ADDI x30, x0, 64
}

# Number of clock cycles to wait before performing the final check.
# The program has 32 instructions; giving 64 cycles provides margin.
CHECK_AFTER_CYCLES = 64


class SingleCycleScoreboard(uvm_component):
    """
    Compares DUT register file against the golden reference after the program
    has had enough cycles to complete. Tracks cycle count internally and
    performs one definitive check, logging a per-register result for every
    entry in EXPECTED_REGS. Sets self.passed for the test to read at the end.
    """

    def __init__(self, name, parent, dut):
        super().__init__(name, parent)
        self.dut          = dut
        self.passed       = False
        self.checked      = False       # ensures the final check runs only once
        self.cycle_count  = 0
        self.last_regs    = [0] * 32
        self.last_pc      = 0
        self.last_instr   = 0

    def sample(self, regs, pc, instr):
        """
        Called by the monitor on every rising clock edge.
        Updates internal state and triggers the final check once
        CHECK_AFTER_CYCLES have elapsed.
        """
        self.last_regs  = regs
        self.last_pc    = pc
        self.last_instr = instr
        self.cycle_count += 1

        if self.cycle_count >= CHECK_AFTER_CYCLES and not self.checked:
            self._check()

    def _check(self):
        """
        Compares every expected register value against the DUT snapshot.
        Logs a per-register PASS or FAIL line and sets self.passed.
        """
        self.checked = True
        all_pass = True

        cocotb.log.info("SCOREBOARD  final register check after "
                        f"{self.cycle_count} cycles:")

        for reg_idx, expected in EXPECTED_REGS.items():
            actual = self.last_regs[reg_idx]
            if actual == expected:
                cocotb.log.info(
                    f"  PASS  x{reg_idx:<2d}  expected={expected:>6}  "
                    f"actual={actual:>6}"
                )
            else:
                cocotb.log.error(
                    f"  FAIL  x{reg_idx:<2d}  expected={expected:>6}  "
                    f"actual={actual:>6}  "
                    f"at PC=0x{self.last_pc:08X}  "
                    f"instr=0x{self.last_instr:08X}"
                )
                all_pass = False

        self.passed = all_pass

        if all_pass:
            cocotb.log.info("SCOREBOARD  SMOKE PASS - all registers correct")
        else:
            cocotb.log.error("SCOREBOARD  SMOKE FAIL - one or more registers wrong")
