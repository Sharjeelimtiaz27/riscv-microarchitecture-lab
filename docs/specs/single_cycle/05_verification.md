# Single-Cycle RV32I -- Verification Reference

**Document:** Verification Reference
**Version:** 1.0
**Applies to:** `single_cycle_top` v1.0
**Simulator:** Cadence Xcelium 24.03-s004

---

## Verification Strategy

The single-cycle processor is verified through three complementary methods:

1. Directed simulation using a comprehensive RV32I test program
2. Functional coverage measurement using a pyuvm environment
3. SystemVerilog Assertions (SVA) for property checking

Formal verification with JasperGold is planned as the final step.

---

## Verification Environment Architecture

```
cocotb_tests/test_single_cycle.py   -- cocotb test entry point
        |
        +-- SingleCycleMonitor      -- samples DUT on every clock edge
        |       |
        |       +-- SingleCycleScoreboard   -- compares against golden model
        |       +-- CoverageCollector       -- records functional coverage bins
        |
        pyuvm_env/
            sequence.py     -- RVInstrItem, ProgramSequence
            sequencer.py    -- SingleCycleSequencer
            driver.py       -- SingleCycleDriver
            monitor.py      -- SingleCycleMonitor
            scoreboard.py   -- SingleCycleScoreboard
            coverage.py     -- CoverageCollector
            env.py          -- Agent, SingleCycleEnv
```

### Tool Versions

| Tool | Version |
|---|---|
| Cadence Xcelium | 24.03-s004 |
| cocotb | 2.0.1 |
| pyuvm | 4.0 |
| Python | 3.13 (Miniconda3) |

---

## Test Program (prog1.hex v2.0)

The test program is a 64-instruction hand-encoded RV32I program stored in `rtl/common/programs/prog1.hex`. The assembly source is in `rtl/common/programs/test_rv32i.S`.

### Program Structure

| Instructions | Description |
|---|---|
| 1-19 | Base register initialisation and all R-type and standard I-type ALU operations |
| 20-21 | SLTI and SLTIU |
| 22-24 | SW and LW memory round-trip |
| 25-32 | ADDI to x23-x31 covering remaining rd bins |
| 33-34 | LUI and AUIPC for opcode coverage (rd = x0) |
| 35-36 | BEQ (not taken) and JAL (forward jump) |
| 37-38 | NOP (skipped by JAL) |
| 39-40 | ADDI x30 for JALR target, JALR |
| 41-42 | NOP (skipped by JALR) |
| 43-61 | ADDI x0, xN, 0 sweep covering all rs1 bins |
| 62-64 | NOP padding |

### Expected Register Values

| Register | Value | Instruction that sets it |
|---|---|---|
| x1 | 5 | addi x1, x0, 5 |
| x2 | 7 | addi x2, x0, 7 |
| x3 | 12 | add x3, x1, x2 |
| x4 | 13 | addi x4, x3, 1 |
| x5 | 7 | sub x5, x3, x1 |
| x6 | 4 | and x6, x3, x2 |
| x7 | 15 | or x7, x3, x2 |
| x8 | 11 | xor x8, x3, x2 |
| x9 | 384 | sll x9, x3, x1 |
| x10 | 0 | srl x10, x3, x1 |
| x11 | 0 | sra x11, x3, x1 |
| x12 | 1 | slt x12, x1, x2 |
| x13 | 1 | sltu x13, x1, x2 |
| x14 | 0 | andi x14, x3, 3 |
| x15 | 12 | ori x15, x3, 4 |
| x16 | 9 | xori x16, x3, 5 |
| x17 | 24 | slli x17, x3, 1 |
| x18 | 6 | srli x18, x3, 1 |
| x19 | 6 | srai x19, x3, 1 |
| x20 | 1 | slti x20, x1, 10 |
| x21 | 1 | sltiu x21, x2, 10 |
| x22 | 12 | lw x22, 0(x30) |
| x23 | 13 | addi x23, x4, 0 |
| x24 | 7 | addi x24, x5, 0 |
| x25 | 4 | addi x25, x6, 0 |
| x26 | 15 | addi x26, x7, 0 |
| x27 | 11 | addi x27, x8, 0 |
| x28 | 384 | addi x28, x9, 0 |
| x29 | 4 | addi x29, x12, 3 |
| x30 | 168 | addi x30, x0, 168 |
| x31 | 9 | addi x31, x13, 8 |

---

## Functional Coverage Results

Results from simulation run on TalTech HPC, 2026-04-07.

| Coverage Group | Bins Hit | Total Bins | Coverage |
|---|---|---|---|
| Instruction Type (opcode) | 9 | 11 | 81.8% |
| R-type ALU Operations | 10 | 10 | 100.0% |
| I-type ALU Operations | 8 | 8 | 100.0% |
| Destination Register rd | 31 | 31 | 100.0% |
| Source Register rs1 | 32 | 32 | 100.0% |

**Note:** The two missed opcode bins are FENCE and SYSTEM, which are not implemented in this design. All implemented instruction classes are at 100% coverage.

### Log File

`simulation_results/single_cycle/pyuvm_week03.log`

---

## SVA Properties

Defined in `rtl/assertions/basic_props.sv`. The checker module is `basic_props_checker`.

| Property | Description | Status |
|---|---|---|
| `x0_immutable` | Register x0 must never receive a write-back | Defined |
| `opcode_nonzero_after_fetch` | Instruction word must not be all-zero after reset | Defined |

Formal proof with JasperGold is planned. See `formal/` directory.

---

## Running the Simulation

### Prerequisites on TalTech HPC

```tcsh
cad
1.3
unsetenv PYTHONHOME
unsetenv PYTHONPATH
setenv PATH /home/sharjeel/miniconda3/bin:$PATH
```

### Run

```tcsh
cd riscv-microarchitecture-lab/tb_pyuvm
make |& tee ../simulation_results/single_cycle/pyuvm_run.log
```

### Expected Result

```
TESTS=1 PASS=1 FAIL=0
```

---

## Scoreboard Check

The scoreboard samples register file state on every rising clock edge and performs a single definitive check after 64 cycles. All 31 expected register values must match exactly. A per-register PASS or FAIL line is logged for each entry.

`CHECK_AFTER_CYCLES = 64`

The test program completes all meaningful register writes within 38 active execution cycles, providing 26 cycles of margin before the check.
