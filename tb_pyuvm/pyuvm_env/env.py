###############################################################################
# Project      : riscv-microarchitecture-lab
# Author       : Sharjeel Imtiaz
# Affiliation  : PhD Student, Tallinn University of Technology (TalTech)
# Year         : 2026
# Version      : v1.0 (pyuvm env skeleton)
#
# Contact      : sharjeel.imtiaz@taltech.ee
#                sharjeelimtiazprof@gmail.com
#
# Description  :
# Minimal UVM environment wiring: agent with sequencer/driver/monitor and scoreboard.
###############################################################################

from pyuvm import *
from .driver import SingleCycleDriver
from .monitor import SingleCycleMonitor
from .scoreboard import SingleCycleScoreboard
from .sequencer import SingleCycleSequencer

class Agent(UVMComponent):
    def __init__(self, name, parent, dut):
        super().__init__(name, parent)
        self.dut = dut
        self.seqr = None
        self.driver = None
        self.monitor = None

    def build_phase(self, phase):
        self.seqr = SingleCycleSequencer("seqr", self)
        self.driver = SingleCycleDriver("driver", self, self.dut)
        self.monitor = SingleCycleMonitor("monitor", self, self.dut)

    def connect_phase(self, phase):
        # driver will obtain sequence items from sequencer in full UVM style,
        # for our simple skeleton we won't wire transaction-level ports here.
        pass

class SingleCycleEnv(UVMEnv):
    def __init__(self, name, dut):
        super().__init__(name, None)
        self.dut = dut
        self.agent = None
        self.scoreboard = None
        self.monitor = None

    def build_phase(self, phase):
        self.agent = Agent("agent", self, self.dut)
        self.scoreboard = SingleCycleScoreboard("scoreboard", self, self.dut)
        # connect monitor from agent to scoreboard
        self.agent.build_phase(phase)
        self.scoreboard.build_phase(phase)
        self.monitor = self.agent.monitor
        # give scoreboard handle to monitor
        self.monitor.scoreboard = self.scoreboard