###############################################################################
# Project      : riscv-microarchitecture-lab
# Author       : Sharjeel Imtiaz
# Affiliation  : PhD Student, Tallinn University of Technology (TalTech)
# Year         : 2026
# Version      : v2.0 (pyuvm sequence — data-driven from hex file)
#
# Contact      : sharjeel.imtiaz@taltech.ee
#                sharjeelimtiazprof@gmail.com
#
# Description  :
# Defines the sequence item and program sequence for the single-cycle RV32I
# verification environment. The sequence reads a RISC-V hex program file and
# sends one RVInstrItem per instruction word through the UVM sequencer to the
# driver, which writes each word into the DUT instruction memory before
# execution begins.
#
# Using a hex file rather than hardcoded encodings makes the sequence
# data-driven: swapping programs requires no changes to testbench code.
###############################################################################

import os
from pyuvm import uvm_sequence_item, uvm_sequence


# Default path to the smoke test program, relative to this file's location.
# The driver writes these words into DUT IMEM before reset is released.
_DEFAULT_HEX = os.path.join(
    os.path.dirname(__file__),
    "..", "..", "rtl", "common", "programs", "prog1.hex"
)


class RVInstrItem(uvm_sequence_item):
    """
    One transaction: a single 32-bit RV32I instruction word and the IMEM
    word address it should occupy. Word address 0 maps to PC=0x0, word
    address 1 maps to PC=0x4, and so on. The driver receives this item
    and writes it directly into the DUT instruction memory via cocotb
    hierarchical signal access.
    """
    def __init__(self, name="RVInstrItem"):
        super().__init__(name)
        self.addr_word  = 0    # IMEM word index (0, 1, 2, ...)
        self.instr_word = 0    # 32-bit instruction encoding


class ProgramSequence(uvm_sequence):
    """
    Loads a complete RV32I program from a hex file into the DUT instruction
    memory. Each line of the hex file is one 32-bit instruction word in
    plain hex (no address prefix, as produced by objcopy --output-target ihex
    or a simple bin2hex script). One RVInstrItem is created per line and
    sent to the driver through the standard UVM start_item / finish_item
    handshake.

    Usage:
        seq = ProgramSequence()                          # uses default prog1.hex
        seq = ProgramSequence(hex_path="/path/to/prog.hex")  # custom program
        await seq.start(sequencer_handle)
    """
    def __init__(self, name="ProgramSequence", hex_path=None):
        super().__init__(name)
        self.hex_path = hex_path or os.path.normpath(_DEFAULT_HEX)

    def _load_hex(self):
        """Read the hex file and return a list of (word_index, int) tuples."""
        words = []
        with open(self.hex_path, "r") as f:
            for idx, line in enumerate(f):
                line = line.strip()
                if not line or line.startswith("//") or line.startswith("#"):
                    continue
                words.append((idx, int(line, 16)))
        return words

    async def body(self):
        program = self._load_hex()

        for addr, instr in program:
            item = RVInstrItem()
            item.addr_word  = addr
            item.instr_word = instr
            await self.start_item(item)   # request a slot from the sequencer
            await self.finish_item(item)  # send to driver; block until driver calls item_done()
