###############################################################################
# Project      : riscv-microarchitecture-lab
# Author       : Sharjeel Imtiaz
# Affiliation  : PhD Student, Tallinn University of Technology (TalTech)
# Year         : 2026
# Version      : v2.1 (pyuvm scoreboard -- comprehensive coverage program)
#
# Contact      : sharjeel.imtiaz@taltech.ee
#                sharjeelimtiazprof@gmail.com
#
# Description  :
# The scoreboard holds the golden reference model for the test program
# loaded from prog1.hex (v2.0). It compares the DUT register file against
# expected final register values after all 64 instructions have had time
# to execute. The check runs once, after CHECK_AFTER_CYCLES rising edges,
# and logs a per-register PASS or FAIL line for every entry in EXPECTED_REGS.
#
# Expected register values after prog1.hex (v2.0) executes:
#
#   x1  =   5       addi  x1,  x0,  5
#   x2  =   7       addi  x2,  x0,  7
#   x3  =  12       add   x3,  x1,  x2
#   x4  =  13       addi  x4,  x3,  1
#   x5  =   7       sub   x5,  x3,  x1      (12-5=7)
#   x6  =   4       and   x6,  x3,  x2      (12&7=4)
#   x7  =  15       or    x7,  x3,  x2      (12|7=15)
#   x8  =  11       xor   x8,  x3,  x2      (12^7=11)
#   x9  = 384       sll   x9,  x3,  x1      (12<<5=384)
#   x10 =   0       srl   x10, x3,  x1      (12>>5=0)
#   x11 =   0       sra   x11, x3,  x1      (12>>5 arith=0)
#   x12 =   1       slt   x12, x1,  x2      (5<7 signed)
#   x13 =   1       sltu  x13, x1,  x2      (5<7 unsigned)
#   x14 =   0       andi  x14, x3,  3       (12&3=0)
#   x15 =  12       ori   x15, x3,  4       (12|4=12)
#   x16 =   9       xori  x16, x3,  5       (12^5=9)
#   x17 =  24       slli  x17, x3,  1       (12<<1=24)
#   x18 =   6       srli  x18, x3,  1       (12>>1=6)
#   x19 =   6       srai  x19, x3,  1       (12>>1 arith=6)
#   x20 =   1       slti  x20, x1,  10      (5<10 signed)
#   x21 =   1       sltiu x21, x2,  10      (7<10 unsigned)
#   x22 =  12       lw    x22, 0(x30)       (mem[64]=x3=12)
#   x23 =  13       addi  x23, x4,  0       (copy of x4)
#   x24 =   7       addi  x24, x5,  0       (copy of x5)
#   x25 =   4       addi  x25, x6,  0       (copy of x6)
#   x26 =  15       addi  x26, x7,  0       (copy of x7)
#   x27 =  11       addi  x27, x8,  0       (copy of x8)
#   x28 = 384       addi  x28, x9,  0       (copy of x9)
#   x29 =   4       addi  x29, x12, 3       (1+3=4)
#   x30 = 168       addi  x30, x0,  168     (JALR base; overwrites x30=64)
#   x31 =   9       addi  x31, x13, 8       (1+8=9)
###############################################################################

from pyuvm import uvm_component
import cocotb


# Golden reference: register index -> expected value after full program execution.
# Only registers written by the program are listed; x0 is always 0 by definition.
EXPECTED_REGS = {
     1:   5,      # addi  x1,  x0,  5
     2:   7,      # addi  x2,  x0,  7
     3:  12,      # add   x3,  x1,  x2
     4:  13,      # addi  x4,  x3,  1
     5:   7,      # sub   x5,  x3,  x1  (12-5=7)
     6:   4,      # and   x6,  x3,  x2  (12&7=4)
     7:  15,      # or    x7,  x3,  x2  (12|7=15)
     8:  11,      # xor   x8,  x3,  x2  (12^7=11)
     9: 384,      # sll   x9,  x3,  x1  (12<<5=384)
    10:   0,      # srl   x10, x3,  x1  (12>>5=0)
    11:   0,      # sra   x11, x3,  x1  (12>>5 arith=0)
    12:   1,      # slt   x12, x1,  x2  (5<7 signed)
    13:   1,      # sltu  x13, x1,  x2  (5<7 unsigned)
    14:   0,      # andi  x14, x3,  3   (12&3=0)
    15:  12,      # ori   x15, x3,  4   (12|4=12)
    16:   9,      # xori  x16, x3,  5   (12^5=9)
    17:  24,      # slli  x17, x3,  1   (12<<1=24)
    18:   6,      # srli  x18, x3,  1   (12>>1=6)
    19:   6,      # srai  x19, x3,  1   (12>>1 arith=6)
    20:   1,      # slti  x20, x1,  10  (5<10 signed)
    21:   1,      # sltiu x21, x2,  10  (7<10 unsigned)
    22:  12,      # lw    x22, 0(x30)   (mem[64]=12)
    23:  13,      # addi  x23, x4,  0
    24:   7,      # addi  x24, x5,  0
    25:   4,      # addi  x25, x6,  0
    26:  15,      # addi  x26, x7,  0
    27:  11,      # addi  x27, x8,  0
    28: 384,      # addi  x28, x9,  0
    29:   4,      # addi  x29, x12, 3   (1+3=4)
    30: 168,      # addi  x30, x0,  168 (JALR target; overwrites x30=64)
    31:   9,      # addi  x31, x13, 8   (1+8=9)
}

# Number of clock cycles to wait before performing the final check.
# The program completes in 38 active cycles; 64 provides comfortable margin.
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
