###############################################################################
# Project      : riscv-microarchitecture-lab
# Author       : Sharjeel Imtiaz
# Affiliation  : PhD Student, Tallinn University of Technology (TalTech)
# Year         : 2026
# Version      : v1.0 (pyuvm sequencer skeleton)
#
# Contact      : sharjeel.imtiaz@taltech.ee
#                sharjeelimtiazprof@gmail.com
#
# Description  :
# Minimal sequencer placeholder for compatibility. The top-level sequence will
# call into driver directly in our simple flow.
###############################################################################

from pyuvm import uvm_sequencer

class SingleCycleSequencer(uvm_sequencer):
    def __init__(self, name, parent):
        super().__init__(name, parent)