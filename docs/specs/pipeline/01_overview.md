# Pipelined RV64IM Processor -- Design Overview

**Project:** riscv-microarchitecture-lab
**Author:** Sharjeel Imtiaz
**Affiliation:** PhD Student, Tallinn University of Technology (TalTech)
**Version:** 0.1 (specification phase)
**Status:** Planned -- RTL not yet started

---

## Purpose

This document specifies the five-stage pipelined RV64IM processor that constitutes Phase 2 of the riscv-microarchitecture-lab project. The design extends the verified single-cycle RV32I baseline to a 64-bit machine with the M (integer multiply/divide) extension and a classic in-order five-stage pipeline.

---

## Design Summary

| Attribute | Value |
|---|---|
| ISA | RISC-V RV64IM |
| Architecture | 5-stage in-order pipeline |
| Pipeline Stages | IF / ID / EX / MEM / WB |
| Privilege Levels | Machine mode (M-mode) baseline; S/U planned |
| Data Width | 64-bit |
| Address Width | 64-bit |
| Register File | 32 x 64-bit, x0 hardwired to zero |
| Instruction Width | 32-bit (standard RISC-V encoding) |
| Reset Vector | 0x0000000000000000 |
| Endianness | Little-endian |
| Clock | Single synchronous clock domain |
| Reset | Active-low synchronous reset (rst_n) |
| RTL Language | SystemVerilog 2012 |

---

## ISA Coverage Plan

| Extension | Description | Status |
|---|---|---|
| RV64I | Base 64-bit integer | Planned Phase 2 |
| M | Integer multiply and divide | Planned Phase 2 |
| A | Atomic operations | Planned Phase 3+ |
| F | Single-precision floating point | Planned Phase 3+ |
| D | Double-precision floating point | Planned Phase 3+ |
| C | Compressed instructions | Planned Phase 3+ |
| Zicsr | CSR instructions | Planned with privilege levels |

---

## Pipeline Architecture

```
      +----------+    +----------+    +----------+    +----------+    +----------+
      |    IF    |    |    ID    |    |    EX    |    |   MEM    |    |    WB    |
      |          |--->|          |--->|          |--->|          |--->|          |
      | Fetch    |    | Decode   |    | Execute  |    | Memory   |    | Write    |
      | Instr    |    | Regs     |    | ALU      |    | Access   |    | Back     |
      |          |    | Ctrl     |    | MUL/DIV  |    | Load/    |    | to regs  |
      +----------+    +----------+    +----------+    | Store    |    +----------+
                                                      +----------+
```

Pipeline registers separate each stage:

- `IF/ID` register: holds PC and instruction word
- `ID/EX` register: holds decoded control signals, register data, immediate
- `EX/MEM` register: holds ALU result, branch target, rs2 data
- `MEM/WB` register: holds memory read data, ALU result, control signals

---

## Key Design Decisions

### Hazard Handling

Data hazards are resolved by forwarding wherever possible. A stall is inserted only when a load-use hazard is detected (the cycle immediately after a load instruction when the destination register is used by the next instruction).

Control hazards from branches are resolved by flushing the IF/ID stage when a branch is taken. A static not-taken predictor is used as the baseline.

### Multiply and Divide

The M extension introduces MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU (32-bit variants: MULW, DIVW, DIVUW, REMW, REMUW for RV64). Multi-cycle multiply and divide units are placed in the EX stage. The pipeline stalls until the result is ready.

### Memory Interface

In this phase, instruction and data memories are separate on-chip SRAMs. A unified cache interface is planned for the Linux-capable phase.

---

## Module Plan

| Module | File | Description |
|---|---|---|
| `fetch` | `rtl/pipeline/fetch.sv` | PC update, IMEM interface, branch mux |
| `decode` | `rtl/pipeline/decode.sv` | Instruction decode, register file read |
| `control` | `rtl/pipeline/control.sv` | Full control signal generation |
| `execute` | `rtl/pipeline/execute.sv` | ALU, multiplier, divider, branch resolve |
| `mem_access` | `rtl/pipeline/mem_access.sv` | Data memory interface |
| `writeback` | `rtl/pipeline/writeback.sv` | Write-back mux |
| `hazard_unit` | `rtl/pipeline/hazard_unit.sv` | Forwarding and stall logic |
| `regfile` | `rtl/common/regfile.sv` | 32 x 64-bit (reused from single-cycle) |
| `alu` | `rtl/pipeline/alu64.sv` | 64-bit ALU |
| `mul_unit` | `rtl/pipeline/mul_unit.sv` | 64-bit multiplier (iterative or DSP) |
| `div_unit` | `rtl/pipeline/div_unit.sv` | 64-bit divider (iterative) |
| `csr_file` | `rtl/pipeline/csr_file.sv` | Machine-mode CSR file |
| `pipeline_top` | `rtl/pipeline/pipeline_top.sv` | Top-level integration |

---

## Design Flow Status

| Phase | Description | Status |
|---|---|---|
| Specification | This document | In progress |
| RTL | All pipeline stages | Not started |
| Simulation | cocotb/pyuvm environment | Not started |
| Functional Coverage | Coverage model | Not started |
| Formal Verification | JasperGold properties | Not started |
| Synthesis | Genus script | Not started |
| Place and Route | Innovus script | Not started |
