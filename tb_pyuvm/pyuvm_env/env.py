###############################################################################
# Project      : riscv-microarchitecture-lab
# Author       : Sharjeel Imtiaz
# Affiliation  : PhD Student, Tallinn University of Technology (TalTech)
# Year         : 2026
# Version      : v2.0 (pyuvm environment — proper build/connect/run phases)
#
# Contact      : sharjeel.imtiaz@taltech.ee
#                sharjeelimtiazprof@gmail.com
#
# Description  :
# The environment is the top-level UVM container. It constructs all
# verification components in build_phase and wires them together in
# connect_phase. Nothing in this file touches DUT signals — that is
# exclusively the driver's and monitor's responsibility.
#
# Component hierarchy built here:
#
#   SingleCycleEnv
#   ├── Agent
#   │    ├── SingleCycleSequencer  (seqr)
#   │    ├── SingleCycleDriver     (driver)
#   │    └── SingleCycleMonitor    (monitor)
#   └── SingleCycleScoreboard      (scoreboard)
#
# Connections made in connect_phase:
#   driver.seqr      <- agent.seqr      (driver pulls items from sequencer)
#   monitor.scoreboard <- scoreboard     (monitor pushes snapshots to scoreboard)
###############################################################################

from pyuvm import UVMEnv, UVMComponent

from .driver     import SingleCycleDriver
from .monitor    import SingleCycleMonitor
from .scoreboard import SingleCycleScoreboard
from .sequencer  import SingleCycleSequencer


class Agent(UVMComponent):
    """
    Groups the active verification components: sequencer, driver, and monitor.
    The agent is the standard UVM packaging unit for one interface — in this
    case the single-cycle CPU's clock/reset/memory interface.
    """

    def __init__(self, name, parent, dut):
        super().__init__(name, parent)
        self.dut     = dut
        self.seqr    = None
        self.driver  = None
        self.monitor = None

    def build_phase(self, phase):
        """Construct all child components. No connections yet."""
        self.seqr    = SingleCycleSequencer("seqr",    self)
        self.driver  = SingleCycleDriver   ("driver",  self, self.dut)
        self.monitor = SingleCycleMonitor  ("monitor", self, self.dut)

    def connect_phase(self, phase):
        """Wire driver to sequencer so it can pull items."""
        self.driver.seqr = self.seqr


class SingleCycleEnv(UVMEnv):
    """
    Top-level verification environment. Owns the agent and the scoreboard.
    Responsible for constructing, connecting, and starting all components.
    The test instantiates this env, calls build and connect, then starts
    the program sequence on the agent sequencer.
    """

    def __init__(self, name, dut):
        super().__init__(name, None)
        self.dut        = dut
        self.agent      = None
        self.scoreboard = None

    def build_phase(self, phase):
        """Construct agent and scoreboard."""
        self.agent      = Agent                 ("agent",      self, self.dut)
        self.scoreboard = SingleCycleScoreboard ("scoreboard", self, self.dut)

        # Build agent children explicitly since pyuvm does not walk the
        # hierarchy automatically in this usage pattern.
        self.agent.build_phase(phase)

    def connect_phase(self, phase):
        """
        Wire all inter-component connections.
        After this phase every component has a valid handle to whatever
        it needs — no further wiring happens at runtime.
        """
        # Wire driver to sequencer (inside agent).
        self.agent.connect_phase(phase)

        # Wire monitor to scoreboard so every sample reaches the checker.
        self.agent.monitor.scoreboard = self.scoreboard
