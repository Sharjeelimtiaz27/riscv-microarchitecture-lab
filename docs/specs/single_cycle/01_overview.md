# Single-Cycle RV32I Processor -- Design Overview

**Project:** riscv-microarchitecture-lab
**Author:** Sharjeel Imtiaz
**Affiliation:** PhD Student, Tallinn University of Technology (TalTech)
**Version:** 1.0
**Status:** Complete -- RTL implemented and verified

---

## Purpose

This document provides a complete technical reference for the single-cycle RV32I processor implemented as Phase 0 of the riscv-microarchitecture-lab project. The design serves as the verified architectural baseline from which the five-stage RV64IM pipeline (Phase 2) is derived.

---

## Design Summary

| Attribute | Value |
|---|---|
| ISA | RISC-V RV32I Base Integer Instruction Set |
| Architecture | Single-cycle, non-pipelined |
| Privilege Levels | None (machine-mode RTL only) |
| Clock | Single synchronous clock domain |
| Reset | Active-low synchronous reset (rst_n) |
| Data Width | 32-bit |
| Address Width | 32-bit |
| Instruction Memory | 256 words (1 KB), initialized from hex file |
| Data Memory | 256 words (1 KB) |
| Register File | 32 x 32-bit, x0 hardwired to zero |
| Technology | Simulation-only (Cadence Xcelium 24.03) |
| RTL Language | SystemVerilog 2012 |
| Target Tool | Cadence Genus (synthesis), Cadence Innovus (P&R) |

---

## Implemented Instruction Classes

| Class | Instructions | Status |
|---|---|---|
| R-type ALU | ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU | Implemented |
| I-type ALU | ADDI, ANDI, ORI, XORI, SLLI, SRLI, SRAI, SLTI, SLTIU | Implemented |
| Load | LW | Implemented |
| Store | SW | Implemented |
| Branch | BEQ, BNE | Implemented and verified |
| Branch | BLT, BGE, BLTU, BGEU | Implemented (RTL present, not covered by test program) |
| Jump | JAL, JALR | Implemented |
| Upper Immediate | LUI, AUIPC | Implemented |
| System | ECALL, EBREAK | Not implemented |
| Memory Ordering | FENCE | Not implemented |

---

## Top-Level Block Diagram

```
                        Single-Cycle RV32I Processor
  +---------------------------------------------------------------------------+
  |                                                                           |
  |   clk ----+                                                               |
  |   rst_n --+                                                               |
  |           |                                                               |
  |    +------+------+                                                        |
  |    |     PC      |  pc_out                                                |
  |    +------+------+                                                        |
  |           |                                                               |
  |           v                                                               |
  |    +--------------+    instr[31:0]    +---------------+                   |
  |    | Inst Memory  |----------------->| Decode / Ctrl |                   |
  |    |  (256 words) |                  +-------+-------+                   |
  |    +--------------+                          |                           |
  |                                    control signals                       |
  |                              +------+---+---+---+---+                    |
  |                              |      |   |   |   |   |                    |
  |                         reg_write  alu_op  mem_read                     |
  |                                    |   |   |   |                        |
  |                 rs1_data           v   |   v   |                        |
  |    +----------+         +----------+   |   +----------+                 |
  |    |          |-------->|   ALU    |   |   |   Data   |                 |
  |    | Register |         +----+-----+   |   |  Memory  |                 |
  |    |   File   | rs2_data     |         |   +----+-----+                 |
  |    | (32 x 32)|-------->+   |         |        |                        |
  |    |          |<--------+   v         v        v                        |
  |    +----------+   rd    +---+----+----+--------+----+                   |
  |                         |  Write-back Mux (rd_data) |                   |
  |                         +----------------------------+                   |
  |                                                                          |
  +---------------------------------------------------------------------------+
```

---

## Design Files

| File | Module | Description |
|---|---|---|
| `rtl/common/pc.sv` | `pc` | Program counter register |
| `rtl/common/regfile.sv` | `regfile` | 32 x 32-bit register file |
| `rtl/common/alu.sv` | `alu` | Arithmetic and logic unit |
| `rtl/common/alu_ctrl.sv` | `alu_ctrl` | ALU operation decoder |
| `rtl/common/immgen.sv` | `immgen` | Immediate value generator |
| `rtl/common/inst_memory.sv` | `inst_memory` | Instruction memory |
| `rtl/common/data_memory.sv` | `data_memory` | Data memory |
| `rtl/single_cycle/single_cycle_top.sv` | `single_cycle_top` | Top-level integration |

---

## Verification Files

| File | Description |
|---|---|
| `tb/single_cycle_smoke_tb.sv` | SystemVerilog smoke testbench |
| `tb_pyuvm/pyuvm_env/` | Full pyuvm verification environment |
| `rtl/assertions/basic_props.sv` | SVA property checker |
| `simulation_results/single_cycle/pyuvm_week03.log` | Latest simulation log |

---

## Design Flow Status

| Phase | Description | Status |
|---|---|---|
| RTL | All eight modules implemented | Complete |
| Simulation | Smoke test and pyuvm environment passing | Complete |
| Functional Coverage | 100% on all implemented instruction bins | Complete |
| SVA Assertions | x0_immutable, opcode_nonzero properties defined | Defined |
| Formal Verification | JasperGold proof pending | Planned |
| Synthesis | Genus script pending | Planned |
| Place and Route | Innovus script pending | Planned |
