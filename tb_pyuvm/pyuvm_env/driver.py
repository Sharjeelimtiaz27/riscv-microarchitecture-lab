###############################################################################
# Project      : riscv-microarchitecture-lab
# Author       : Sharjeel Imtiaz
# Affiliation  : PhD Student, Tallinn University of Technology (TalTech)
# Year         : 2026
# Version      : v1.0 (pyuvm driver skeleton)
#
# Contact      : sharjeel.imtiaz@taltech.ee
#                sharjeelimtiazprof@gmail.com
#
# Description  :
# Minimal driver: for single-cycle smoke we simply expose a small API so Python
# sequences can poke hierarchical memory if needed. For this lab we leverage
# preloaded inst_memory; driver left as placeholder for later randomized tests.
###############################################################################

from pyuvm import *
import cocotb

class SingleCycleDriver(UVMComponent):
    def __init__(self, name, parent, dut):
        super().__init__(name, parent)
        self.dut = dut

    async def write_imem_word(self, addr_word_index, data_word):
        """Write directly to DUT instruction memory (word-index)."""
        # hierarchical access via cocotb: set mem element
        # caution: this requires -access +r in sim flags earlier
        self.dut.imem.mem[addr_word_index].value = int(data_word)