###############################################################################
# Project      : riscv-microarchitecture-lab
# Author       : Sharjeel Imtiaz
# Affiliation  : PhD Student, Tallinn University of Technology (TalTech)
# Year         : 2026
# Version      : v2.0 (pyuvm driver — proper UVM run_phase flow)
#
# Contact      : sharjeel.imtiaz@taltech.ee
#                sharjeelimtiazprof@gmail.com
#
# Description  :
# The driver is the only UVM component that touches DUT signals directly.
# It runs a continuous loop in run_phase, pulling RVInstrItem transactions
# from the sequencer and writing each instruction word into the DUT
# instruction memory via cocotb hierarchical signal access. The driver
# must complete its IMEM writes before reset is released in the test, so
# that the processor fetches correct instructions from the first clock edge.
###############################################################################

from pyuvm import uvm_component
from cocotb.triggers import RisingEdge
import cocotb


class SingleCycleDriver(uvm_component):
    """
    Receives RVInstrItem transactions from the sequencer and writes each
    instruction word into the DUT instruction memory. Uses cocotb
    hierarchical access (dut.imem.mem[index]) to poke IMEM directly,
    which requires the simulator to be launched with -access +rwc.
    """

    def __init__(self, name, parent, dut):
        super().__init__(name, parent)
        self.dut  = dut
        self.seqr = None    # assigned by env during connect_phase

    async def run_phase(self, phase):
        """
        Main driver loop. Runs for the duration of the simulation.
        Pulls one item at a time from the sequencer, writes it into
        IMEM, then signals completion so the sequence can proceed.
        The loop exits naturally when the sequencer raises StopIteration
        (no more items), at which point the objection is dropped and the
        phase ends.
        """
        phase.raise_objection(self)

        try:
            while True:
                # Block until the sequence sends the next item.
                item = await self.seqr.get_next_item()

                # Write the instruction word into DUT instruction memory.
                # addr_word is the word index: word 0 = PC 0x0, word 1 = PC 0x4, etc.
                self.dut.imem.mem[item.addr_word].value = item.instr_word
                cocotb.log.info(
                    f"DRIVER  word[{item.addr_word:02d}] = 0x{item.instr_word:08X}"
                )

                # Wait one rising edge so the write settles before the next item.
                await RisingEdge(self.dut.clk)

                # Signal to the sequencer that this item is done.
                # This unblocks finish_item() in the sequence, allowing it
                # to send the next instruction.
                self.seqr.item_done()

        except StopIteration:
            pass

        finally:
            phase.drop_objection(self)
