###############################################################################
# Project      : riscv-microarchitecture-lab
# Author       : Sharjeel Imtiaz
# Affiliation  : PhD Student, Tallinn University of Technology (TalTech)
# Year         : 2026
# Version      : v1.0 (pyuvm sequence)
#
# Contact      : sharjeel.imtiaz@taltech.ee
#                sharjeelimtiazprof@gmail.com
#
# Description  :
# A small pyuvm sequence interface for our smoke test. For the initial smoke
# we rely on pre-loaded IMEM (prog1.hex), so the sequence does not need to
# write IMEM; it simply waits for the DUT to progress. Later we will extend
# the sequence to randomize instructions and to write the IMEM via driver.
###############################################################################

from pyuvm import *
from pyuvm.base.uvm_sequence import UVMSequence

class SmokeSequence(UVMSequence):
    def __init__(self, name="SmokeSequence"):
        super().__init__(name)
    def body(self):
        # for this simple skeleton the sequence body is managed by cocotb top test
        pass