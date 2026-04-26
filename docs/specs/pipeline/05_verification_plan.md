# Pipelined RV64IM -- Verification Plan

**Document:** Verification Plan
**Version:** 0.1
**Applies to:** Planned pipeline processor

---

## Verification Goals

The pipeline processor verification must demonstrate:

1. Correct execution of every RV64IM instruction
2. Correct hazard resolution (forwarding and stall) under all data hazard conditions
3. Correct branch and jump behaviour including the flush mechanism
4. Correct trap entry and return for all M-mode exception causes
5. No register corruption across long instruction sequences
6. Correct M-extension results including all corner cases (divide by zero, overflow)

---

## Verification Layers

| Layer | Tool | Purpose |
|---|---|---|
| Directed simulation | cocotb + pyuvm | Instruction correctness, hazard sequences |
| Functional coverage | CoverageCollector | Ensure all instruction classes and hazard scenarios are hit |
| SVA assertions | Xcelium / JasperGold | Pipeline invariants, register file properties |
| Formal verification | JasperGold | Prove key safety properties exhaustively |
| Random regression | pyuvm random sequences | Uncover corner cases missed by directed tests |

---

## Functional Coverage Model

### Group 1: Instruction Type

All RV64IM opcode classes. Target: 100% excluding FENCE.

### Group 2: Data Hazard Scenarios

| Bin | Description |
|---|---|
| EX_to_EX_rs1 | Forwarding from EX/MEM to EX stage, rs1 |
| EX_to_EX_rs2 | Forwarding from EX/MEM to EX stage, rs2 |
| MEM_to_EX_rs1 | Forwarding from MEM/WB to EX stage, rs1 |
| MEM_to_EX_rs2 | Forwarding from MEM/WB to EX stage, rs2 |
| load_use_stall | Load followed immediately by dependent instruction |
| no_hazard | Back-to-back independent instructions |

### Group 3: Branch Outcomes

| Bin | Description |
|---|---|
| branch_taken | Branch condition true, pipeline flushed |
| branch_not_taken | Branch condition false, sequential execution |
| jalr_indirect | JALR with computed target |

### Group 4: M-extension Corner Cases

| Bin | Description |
|---|---|
| div_by_zero_signed | DIV or REM with rs2 = 0 |
| div_by_zero_unsigned | DIVU or REMU with rs2 = 0 |
| div_overflow | Most negative integer divided by -1 |
| mul_zero | MUL with one operand = 0 |
| mul_max | MUL with both operands = maximum value |

### Group 5: Trap Scenarios

| Bin | Description |
|---|---|
| illegal_instruction | Undefined opcode |
| ecall_mmode | ECALL from M-mode |
| misaligned_load | Load to non-aligned address |
| misaligned_store | Store to non-aligned address |
| mret | Successful return from trap handler |

---

## Directed Test Plan

| Test | Description | Hazards Exercised |
|---|---|---|
| `test_rv64i_basic` | All RV64I instructions with independent operands | None |
| `test_forwarding_ex` | RAW hazard resolved by EX forwarding | EX_to_EX |
| `test_forwarding_mem` | RAW hazard resolved by MEM forwarding | MEM_to_EX |
| `test_load_use` | Load followed by dependent instruction | Load-use stall |
| `test_branch_taken` | Branch with condition true | Control flush |
| `test_branch_not_taken` | Branch with condition false | None |
| `test_mul` | All MUL variants including MULW | None |
| `test_div` | All DIV/REM variants, corner cases | None |
| `test_trap_ecall` | ECALL, check mepc and mcause | None |
| `test_trap_illegal` | Illegal instruction, check handler | None |
| `test_mret` | Full trap and return sequence | None |

---

## SVA Properties (Planned)

| Property | Description |
|---|---|
| `x0_immutable` | Register x0 never receives a write-back |
| `pc_aligned` | PC is always 4-byte aligned |
| `pipeline_no_deadlock` | The pipeline always makes forward progress unless stalling for a known reason |
| `forwarding_correct` | Forwarded value matches the value that would be read from the register file after write-back |
| `stall_duration` | A load-use stall lasts exactly one cycle |
| `branch_flush` | Exactly one instruction is flushed on a taken branch |
| `mepc_correct` | mepc holds the PC of the trapping instruction after any exception |

---

## Formal Verification Targets

| Property | Bound | Tool |
|---|---|---|
| `x0_immutable` | Unbounded | JasperGold |
| `pc_aligned` | Unbounded | JasperGold |
| `stall_duration` | 10 cycles | JasperGold BMC |
| `branch_flush` | 5 cycles | JasperGold BMC |

---

## Synthesis Verification

After synthesis, a gate-level simulation must be run with the same directed test suite. All register expected values must match the RTL simulation results exactly.
