# Pipelined RV64IM -- Microarchitecture Specification

**Document:** Microarchitecture Specification
**Version:** 0.1
**Applies to:** Planned pipeline processor

---

## Pipeline Overview

The processor implements a classic five-stage in-order pipeline. Each instruction passes through five stages separated by pipeline registers. The clock period is determined by the slowest stage rather than the entire datapath, enabling a significantly higher operating frequency than the single-cycle baseline.

```
Cycle:    1       2       3       4       5       6       7
Instr 1:  IF   |  ID   |  EX   | MEM   |  WB   |       |
Instr 2:        IF   |  ID   |  EX   | MEM   |  WB   |
Instr 3:               IF   |  ID   |  EX   | MEM   |  WB
```

---

## Stage Descriptions

### Stage 1 -- Instruction Fetch (IF)

Responsibilities:
- Read the instruction at the current PC from instruction memory
- Compute PC+4 for sequential execution
- Select the next PC from: PC+4, branch target, or JALR target
- Latch PC and instruction into the IF/ID pipeline register

```
PC_reg --> IMEM --> instr
       \-> PC+4
       \-> branch_target (from EX stage)
       \-> jalr_target   (from EX stage)
            |
           mux --> IF/ID register
```

### Stage 2 -- Instruction Decode and Register Fetch (ID)

Responsibilities:
- Decode opcode, funct3, funct7, rs1, rs2, rd
- Generate all control signals
- Read rs1 and rs2 from the register file
- Generate the sign-extended immediate
- Detect load-use hazard and assert stall signal
- Latch decoded signals into the ID/EX pipeline register

### Stage 3 -- Execute (EX)

Responsibilities:
- Select ALU operands from forwarding muxes (forwarded data or register data)
- Execute ALU operation (64-bit integer)
- Execute multiply or divide (M extension, multi-cycle stall)
- Compute branch target address: ID/EX.PC + ID/EX.imm_ext
- Evaluate branch condition: ALU zero flag
- Assert branch_taken signal to flush IF/ID and redirect PC
- Latch results into the EX/MEM pipeline register

### Stage 4 -- Memory Access (MEM)

Responsibilities:
- Drive data memory address (EX/MEM.alu_result)
- Drive write data (EX/MEM.rs2_data, after forwarding)
- Assert read or write enable based on control signals
- Support all access widths: byte, halfword, word, doubleword
- Latch results into the MEM/WB pipeline register

### Stage 5 -- Write Back (WB)

Responsibilities:
- Select write-back data: ALU result, memory read data, or PC+4 (for JAL/JALR)
- Write to the register file if reg_write is asserted and rd is not x0

---

## Pipeline Register Contents

### IF/ID

| Field | Width | Description |
|---|---|---|
| `pc` | 64 | PC of fetched instruction |
| `pc_plus4` | 64 | PC + 4 |
| `instr` | 32 | Fetched instruction word |
| `valid` | 1 | 0 when flushed by branch or stall |

### ID/EX

| Field | Width | Description |
|---|---|---|
| `pc` | 64 | PC of decoded instruction |
| `pc_plus4` | 64 | PC + 4 |
| `rs1_data` | 64 | Register file read data 1 |
| `rs2_data` | 64 | Register file read data 2 |
| `imm_ext` | 64 | Sign-extended immediate |
| `rs1` | 5 | Source register 1 index |
| `rs2` | 5 | Source register 2 index |
| `rd` | 5 | Destination register index |
| `reg_write` | 1 | Write-back enable |
| `alu_src` | 1 | ALU B operand select |
| `mem_write` | 1 | Memory write enable |
| `mem_read` | 1 | Memory read enable |
| `mem_width` | 3 | Access width (byte/half/word/dword) |
| `branch` | 1 | Branch instruction |
| `jump` | 1 | JAL or JALR |
| `result_src` | 2 | Write-back source select |
| `alu_ctrl` | 4 | ALU operation |

### EX/MEM

| Field | Width | Description |
|---|---|---|
| `alu_result` | 64 | ALU output |
| `rs2_data` | 64 | Store data (after forwarding) |
| `pc_plus4` | 64 | PC + 4 (for JAL/JALR write-back) |
| `rd` | 5 | Destination register index |
| `reg_write` | 1 | Write-back enable |
| `mem_write` | 1 | Memory write enable |
| `mem_read` | 1 | Memory read enable |
| `mem_width` | 3 | Access width |
| `result_src` | 2 | Write-back source select |

### MEM/WB

| Field | Width | Description |
|---|---|---|
| `alu_result` | 64 | Passed through from EX/MEM |
| `mem_rdata` | 64 | Memory read data |
| `pc_plus4` | 64 | PC + 4 |
| `rd` | 5 | Destination register index |
| `reg_write` | 1 | Write-back enable |
| `result_src` | 2 | Write-back source select |

---

## Hazard Unit

### Data Hazard: Forwarding

The forwarding unit detects when an instruction in EX or MEM produces a result needed by the current EX stage instruction. It selects the forwarded value instead of the stale register file output.

Forwarding conditions (evaluated in EX stage):

```
Forward A from EX/MEM:
    EX/MEM.reg_write == 1
    EX/MEM.rd != 0
    EX/MEM.rd == ID/EX.rs1

Forward A from MEM/WB:
    MEM/WB.reg_write == 1
    MEM/WB.rd != 0
    MEM/WB.rd == ID/EX.rs1
    (and EX/MEM condition not active)

Same logic applies for Forward B (rs2).
```

### Data Hazard: Load-Use Stall

When a load instruction is in the EX stage and its destination register matches rs1 or rs2 of the following instruction, one stall cycle is inserted.

Stall condition:

```
ID/EX.mem_read == 1
AND (ID/EX.rd == IF/ID.rs1 OR ID/EX.rd == IF/ID.rs2)
```

Stall action:
- Hold PC (do not update)
- Hold IF/ID register
- Insert bubble (NOP) into ID/EX register

### Control Hazard: Branch

A branch outcome is resolved at the end of the EX stage. One instruction has already been fetched into IF/ID during this time.

On branch taken:
- Flush IF/ID register (insert bubble)
- Redirect PC to branch target

On branch not taken:
- No action required (PC+4 is already correct)

---

## Multiply and Divide

The M extension units reside in the EX stage. Both are iterative implementations.

| Unit | Latency | Stall Mechanism |
|---|---|---|
| Multiplier (MUL/MULH/MULHU/MULHSU) | TBD cycles | Pipeline stall until done signal |
| Divider (DIV/DIVU/REM/REMU) | TBD cycles | Pipeline stall until done signal |

A multicycle_stall signal from the EX stage holds the PC and all upstream pipeline registers until the unit asserts done.

---

## Critical Path Estimate

With the datapath split across five stages the critical path is reduced to approximately one stage. The expected critical path in each stage:

| Stage | Critical Path |
|---|---|
| IF | IMEM read latency |
| ID | Register file read |
| EX | 64-bit ALU (adder chain) |
| MEM | DMEM read latency |
| WB | Mux + register file write setup |

Target operating frequency will be established after synthesis.
