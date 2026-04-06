###############################################################################
# Project      : riscv-microarchitecture-lab
# Author       : Sharjeel Imtiaz
# Affiliation  : PhD Student, Tallinn University of Technology (TalTech)
# Year         : 2026
# Version      : v1.0 (functional coverage collector)
#
# Contact      : sharjeel.imtiaz@taltech.ee
#                sharjeelimtiazprof@gmail.com
#
# Description  :
# Functional coverage collector for the single-cycle RV32I processor.
# Called by the monitor on every rising clock edge with the current
# instruction word. Tracks which instruction types, ALU operations,
# funct3 encodings, and destination registers have been exercised.
# Reports a coverage summary at the end of simulation.
#
# Coverage groups implemented:
#
#   1. Instruction type (opcode)
#      Tracks which of the major RV32I opcode classes were seen.
#
#   2. ALU funct3 for R-type instructions
#      Tracks which R-type ALU operations (ADD/SUB/AND/OR/XOR/SLL/SRL/SRA/SLT/SLTU)
#      were executed.
#
#   3. ALU funct3 for I-type immediate instructions
#      Tracks which I-type ALU operations (ADDI/ANDI/ORI/XORI/SLTI/SLTIU/SLLI/SRLI/SRAI)
#      were executed.
#
#   4. Destination register (rd)
#      Tracks which of the 32 architectural registers were written.
#
#   5. Source register rs1
#      Tracks which registers were used as the first source operand.
###############################################################################

import cocotb


# ---- Opcode definitions (RV32I) ----

OPCODES = {
    0b0110011: "R-type",
    0b0010011: "I-type ALU",
    0b0000011: "Load",
    0b0100011: "Store",
    0b1100011: "Branch",
    0b1101111: "JAL",
    0b1100111: "JALR",
    0b0110111: "LUI",
    0b0010111: "AUIPC",
    0b0001111: "FENCE",
    0b1110011: "SYSTEM",
}

# ---- R-type funct3 definitions ----

RTYPE_FUNCT3 = {
    (0b000, 0b0000000): "ADD",
    (0b000, 0b0100000): "SUB",
    (0b111, 0b0000000): "AND",
    (0b110, 0b0000000): "OR",
    (0b100, 0b0000000): "XOR",
    (0b001, 0b0000000): "SLL",
    (0b101, 0b0000000): "SRL",
    (0b101, 0b0100000): "SRA",
    (0b010, 0b0000000): "SLT",
    (0b011, 0b0000000): "SLTU",
}

# ---- I-type ALU funct3 definitions ----

ITYPE_FUNCT3 = {
    0b000: "ADDI",
    0b111: "ANDI",
    0b110: "ORI",
    0b100: "XORI",
    0b010: "SLTI",
    0b011: "SLTIU",
    0b001: "SLLI",
    0b101: "SRLI/SRAI",
}


class CoverageCollector:
    """
    Functional coverage collector. Wired into the monitor so it receives
    the current instruction word on every clock cycle. Maintains hit sets
    for each coverage group and reports a summary when report() is called.
    """

    def __init__(self):
        # Group 1: opcode coverage — which instruction types were seen
        self.opcodes_seen     = set()
        self.opcodes_goal     = set(OPCODES.keys())

        # Group 2: R-type ALU operation coverage
        self.rtype_ops_seen   = set()
        self.rtype_ops_goal   = set(RTYPE_FUNCT3.keys())

        # Group 3: I-type ALU operation coverage
        self.itype_ops_seen   = set()
        self.itype_ops_goal   = set(ITYPE_FUNCT3.keys())

        # Group 4: destination register coverage (rd field)
        # x0 is excluded because writes to it are silently discarded
        self.rd_seen          = set()
        self.rd_goal          = set(range(1, 32))   # x1 through x31

        # Group 5: source register rs1 coverage
        self.rs1_seen         = set()
        self.rs1_goal         = set(range(0, 32))   # x0 through x31

    def sample(self, instr):
        """
        Called by the monitor with the 32-bit instruction word seen on
        the current clock cycle. Decodes the instruction and updates all
        coverage groups. NOP (0x00000013) and zero words are skipped.
        """
        if instr == 0x00000000 or instr == 0x00000013:
            return   # NOP or empty memory — not an interesting instruction

        opcode = instr & 0x7F
        rd     = (instr >> 7)  & 0x1F
        funct3 = (instr >> 12) & 0x07
        rs1    = (instr >> 15) & 0x1F
        funct7 = (instr >> 25) & 0x7F

        # Group 1: opcode
        if opcode in OPCODES:
            self.opcodes_seen.add(opcode)

        # Group 2: R-type operation
        if opcode == 0b0110011:
            key = (funct3, funct7)
            if key in RTYPE_FUNCT3:
                self.rtype_ops_seen.add(key)

        # Group 3: I-type ALU operation
        if opcode == 0b0010011:
            if funct3 in ITYPE_FUNCT3:
                self.itype_ops_seen.add(funct3)

        # Group 4: destination register
        if opcode not in (0b0100011, 0b1100011):  # Store and Branch have no rd
            if rd != 0:
                self.rd_seen.add(rd)

        # Group 5: source register rs1
        if opcode not in (0b0110111, 0b0010111, 0b1101111):  # LUI/AUIPC/JAL have no rs1
            self.rs1_seen.add(rs1)

    def report(self):
        """
        Logs a full coverage report. For each group, lists the hit count,
        total bins, percentage, and which bins were missed.
        """
        cocotb.log.info("=" * 72)
        cocotb.log.info("COVERAGE REPORT")
        cocotb.log.info("=" * 72)

        self._report_group(
            name    = "Instruction Type (opcode)",
            seen    = self.opcodes_seen,
            goal    = self.opcodes_goal,
            labels  = {k: v for k, v in OPCODES.items()},
        )

        self._report_group(
            name    = "R-type ALU Operations",
            seen    = self.rtype_ops_seen,
            goal    = self.rtype_ops_goal,
            labels  = {k: v for k, v in RTYPE_FUNCT3.items()},
        )

        self._report_group(
            name    = "I-type ALU Operations",
            seen    = self.itype_ops_seen,
            goal    = self.itype_ops_goal,
            labels  = {k: v for k, v in ITYPE_FUNCT3.items()},
        )

        self._report_group(
            name    = "Destination Register (rd)",
            seen    = self.rd_seen,
            goal    = self.rd_goal,
            labels  = {i: f"x{i}" for i in range(1, 32)},
        )

        self._report_group(
            name    = "Source Register rs1",
            seen    = self.rs1_seen,
            goal    = self.rs1_goal,
            labels  = {i: f"x{i}" for i in range(0, 32)},
        )

        cocotb.log.info("=" * 72)

    def _report_group(self, name, seen, goal, labels):
        hit   = len(seen & goal)
        total = len(goal)
        pct   = (hit / total * 100) if total > 0 else 0.0
        missed = goal - seen

        cocotb.log.info(f"  {name}: {hit}/{total} bins hit ({pct:.1f}%)")

        if missed:
            missed_names = ", ".join(
                str(labels.get(m, m)) for m in sorted(missed, key=str)
            )
            cocotb.log.info(f"    missed: {missed_names}")
        else:
            cocotb.log.info("    all bins covered")
