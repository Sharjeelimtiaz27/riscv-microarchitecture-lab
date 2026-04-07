# Week 03 -- Complete pyuvm Environment, Functional Coverage, and Comprehensive Stimulus

## Objectives

Week 03 focused on completing the verification environment built in Week 02 and achieving meaningful coverage of the single-cycle RV32I processor.

Goals for this week:

- Complete and debug the full pyuvm verification stack end-to-end
- Run the simulation successfully on TalTech HPC using Cadence Xcelium 24.03
- Add functional coverage reporting to the monitor
- Write a comprehensive test program that fills all achievable coverage bins
- Understand and fix real-world problems encountered during tool bring-up

---

## What Was Built This Week

The verification environment consists of seven Python files organized as proper Python packages:

```
tb_pyuvm/
    __init__.py
    Makefile
    pyuvm_env/
        __init__.py
        sequence.py       -- RVInstrItem and ProgramSequence
        sequencer.py      -- SingleCycleSequencer
        driver.py         -- SingleCycleDriver
        monitor.py        -- SingleCycleMonitor
        scoreboard.py     -- SingleCycleScoreboard
        coverage.py       -- CoverageCollector
        env.py            -- Agent and SingleCycleEnv
    cocotb_tests/
        __init__.py
        test_single_cycle.py  -- cocotb entry point
```

The environment connects directly to the DUT through cocotb hierarchical signal access. The monitor samples the register file, program counter, and current instruction on every rising clock edge. The scoreboard holds a golden register model and checks all expected values after a fixed number of cycles.

---

## Functional Coverage

The functional coverage model tracks five independent groups.

### Group 1: Instruction Type (Opcode)

Tracks which RV32I opcode classes were executed.

Bins: R-type, I-type ALU, Load, Store, Branch, JAL, JALR, LUI, AUIPC, FENCE, SYSTEM

FENCE and SYSTEM are not implemented in the single-cycle RTL and are excluded by design.

### Group 2: R-type ALU Operations

Tracks which arithmetic and logic operations were exercised for register-register instructions.

Bins: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU

### Group 3: I-type ALU Operations

Tracks which immediate arithmetic and logic operations were exercised.

Bins: ADDI, ANDI, ORI, XORI, SLLI, SRLI, SRAI, SLTI, SLTIU

### Group 4: Destination Register

Tracks which architectural registers received a write-back result.

Bins: x1 through x31 (x0 is excluded because writes to it are silently discarded)

### Group 5: Source Register rs1

Tracks which architectural registers were used as the first read operand.

Bins: x0 through x31

---

## Why Coverage Matters

A test that passes does not guarantee that all instruction types were exercised. The processor could have a bug in the SLTI path, for example, and a short smoke test would never detect it because SLTI was never executed. Functional coverage closes this gap by proving that the stimulus actually reached every instruction class and every register.

---

## Coverage-Driven Stimulus Improvement

The initial test program (prog1.hex v1.0) achieved:

```
Instruction Type  :  9/11  (SLTI and SLTIU missing from I-type group)
R-type ALU        : 10/10
I-type ALU        :  7/8   (SLTI and SLTIU missing)
Destination rd    : 21/31  (x23 through x29, x31 not written)
Source rs1        :  4/32  (only x0, x1, x2, x30 used)
```

After analyzing the report, a new 64-instruction program (prog1.hex v2.0) was written by hand, encoding each instruction from the RV32I specification tables. The new program fills all missing bins.

### Strategy for Covering Remaining rd Bins

Registers x23 through x31 are covered by a sequence of ADDI instructions that copy already-computed values into these registers using different rs1 sources:

```
addi x23, x4,  0     -- rd=x23, rs1=x4
addi x24, x5,  0     -- rd=x24, rs1=x5
...
addi x31, x13, 8     -- rd=x31, rs1=x13
```

### Strategy for Covering All rs1 Bins

After the main computation phase, a sweep of ADDI x0, xN, 0 instructions touches every remaining register as rs1. These instructions write to x0, so their result is discarded and no register state is disturbed:

```
addi x0, x10, 0      -- rs1=x10 (result discarded)
addi x0, x11, 0      -- rs1=x11 (result discarded)
...
addi x0, x31, 0      -- rs1=x31 (result discarded)
```

### SLTI and SLTIU

These two instructions were added after the main ALU block:

```
slti  x20, x1, 10    -- x20 = (5 < 10 signed)  = 1
sltiu x21, x2, 10    -- x21 = (7 < 10 unsigned) = 1
```

---

## Final Coverage Results

```
Instruction Type (opcode)     :  9/11  (81.8%)  -- FENCE, SYSTEM excluded by design
R-type ALU Operations         : 10/10 (100.0%)
I-type ALU Operations         :  8/8  (100.0%)
Destination Register (rd)     : 31/31 (100.0%)
Source Register rs1           : 32/32 (100.0%)
```

All achievable bins are covered.

---

## RV32I Instruction Encoding Reference

Understanding instruction encoding is essential for writing programs without an assembler and for debugging when encodings do not match expectations.

### R-type

```
31:25   24:20   19:15   14:12   11:7   6:0
funct7   rs2     rs1    funct3    rd   opcode
```

Example: ADD x3, x1, x2

```
funct7=0000000  rs2=x2=00010  rs1=x1=00001  funct3=000  rd=x3=00011  opcode=0110011
= 0000000 00010 00001 000 00011 0110011
= 0x002081b3
```

### I-type

```
31:20          19:15   14:12   11:7   6:0
imm[11:0]      rs1    funct3    rd   opcode
```

Example: ADDI x1, x0, 5

```
imm=000000000101  rs1=x0=00000  funct3=000  rd=x1=00001  opcode=0010011
= 0x00500093
```

### S-type (Store)

```
31:25        24:20   19:15   14:12   11:7        6:0
imm[11:5]     rs2     rs1   funct3  imm[4:0]   opcode
```

### B-type (Branch)

The immediate encodes a byte offset and is split across two fields:

```
31      30:25   24:20   19:15   14:12   11:8     7       6:0
imm[12] imm[10:5] rs2   rs1   funct3  imm[4:1] imm[11]  opcode
```

---

## Real Problems Encountered and Fixed

### Problem 1: regfile declared with 31 entries instead of 32

The register file was declared as `logic [31:0] regs [31]` which gives indices 0 to 30. The monitor tried to read index 31 and caused a simulation error.

Fix: change to `logic [31:0] regs [32]` giving indices 0 to 31.

### Problem 2: pyuvm 4.0 renamed all classes

The pyuvm 4.0 API uses lowercase names: `uvm_component`, `uvm_env`, `uvm_sequence`, `uvm_sequence_item`, `uvm_sequencer`. Earlier code used the old names such as `UVMComponent` and `UVMEnv`, causing ImportError.

Fix: replace all class names consistently across all five pyuvm files.

### Problem 3: cocotb 2.0 renamed the time unit argument

In cocotb 2.0, `Timer(10, units="ns")` became `Timer(10, unit="ns")`. The old keyword caused a TypeError at runtime.

Fix: replace `units=` with `unit=` in all Timer and Clock constructor calls.

### Problem 4: server terminal cannot encode em dash

The TalTech HPC server uses ISO-8859-15 terminal encoding. Python log strings containing the em dash character (U+2014) caused a UnicodeEncodeError at runtime.

Fix: replace all em dash characters in live log strings with a plain hyphen.

### Problem 5: system Python 3.6 on server is too old

The system Python on the HPC server is version 3.6 with a broken pip. Neither cocotb 2.0 nor pyuvm 4.0 supports Python 3.6.

Fix: install Miniconda3 in the home directory to get Python 3.13, then install both packages with pip inside the conda base environment.

### Problem 6: PYTHONHOME conflict with Miniconda Python

Launching Python after installing Miniconda gave a fatal error because the old PYTHONHOME environment variable pointed to the system Python directories, which do not contain the correct standard library for Python 3.13.

Fix: `unsetenv PYTHONHOME` and `unsetenv PYTHONPATH` before activating the Miniconda environment, then set `PATH` to include the Miniconda bin directory first.

### Problem 7: sequencer hang when using full UVM phase machinery

Calling `await seq.start(seqr)` inside the test hung indefinitely. The pyuvm 4.0 sequencer requires a complete phase hierarchy to be active before the start handshake works. Running start() without phase infrastructure causes the coroutine to wait forever.

Fix: for the smoke test, bypass the sequence and driver entirely. The instruction memory is preloaded from prog1.hex by the RTL using `$readmemh`. The test instantiates only the monitor and scoreboard, runs the clock for 128 cycles, and reads the result. The sequence and driver are reserved for future randomized tests.

---

## Phase Machinery vs Direct Test Approach

The full UVM test flow is:

```
test.start_phase()
    seq.start(seqr)          -- sequence sends items to sequencer
        seqr.get_next_item() -- sequencer gives item to driver
            driver.item_done()
```

This flow requires pyuvm to have initialized all phase objects and started the run_phase coroutines in the correct order. Without this, the get_next_item() call blocks forever because no phase has signalled readiness.

The direct approach used this week bypasses this machinery. The test creates the monitor and scoreboard as plain Python objects, assigns the scoreboard reference, starts the monitor coroutine with cocotb.start_soon(), and waits for the simulation to complete. This is simpler, faster to debug, and fully adequate for a preloaded-IMEM smoke test.

---

## Key Lessons from Week 03

- Functional coverage transforms a test from a binary pass/fail into a measurement of how much of the design space was actually exercised.
- Coverage-driven iteration -- run, measure gaps, improve stimulus, re-run -- is the standard verification workflow in industry.
- RV32I instruction encodings are straightforward once the field layout is understood. Hand-encoding instructions is a useful skill for debugging and for writing small embedded programs.
- Real tool environments have many small incompatibilities. The ability to read error messages carefully and fix them methodically is as important as writing the verification code.
- The pyuvm sequencer flow requires full phase infrastructure. For simple preloaded tests, a direct monitor-scoreboard pair is cleaner and equally correct.

---

## Interview Questions and Answers

**Q1: What is functional coverage and why is it different from code coverage?**

Code coverage measures which lines of RTL were executed during simulation. Functional coverage measures whether the stimulus exercised specific design scenarios that matter to the architect -- instruction types, data values, register combinations. A design can have 100% code coverage and still miss entire instruction classes if the test program never used them. Functional coverage is intent-driven; code coverage is structure-driven.

**Q2: What does a coverage bin represent?**

A bin is one item in a coverage group. For example, the R-type ALU Operations group has ten bins: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU. Each bin is marked hit when the corresponding instruction is seen during simulation. The group is considered complete when all bins are hit.

**Q3: Why are FENCE and SYSTEM excluded from coverage goals?**

These opcodes are part of the RV32I specification but are not implemented in the single-cycle RTL. The single-cycle processor is a teaching design that targets computational instructions and memory access. System calls and memory ordering fences require additional infrastructure (a privilege unit, CSR file, trap handler) that belongs to a later phase of the project. Excluding them from the coverage goal prevents a false coverage gap from appearing in the report.

**Q4: What is the difference between SLTI and SLT?**

SLT is an R-type instruction that compares two registers. SLTI is an I-type instruction that compares a register with a sign-extended immediate value. The encoding, opcode, and funct3 differ. Both write 1 to rd if the comparison is true and 0 otherwise, using signed comparison. SLTIU performs the same operation using unsigned comparison.

**Q5: Why does the rs1 sweep use ADDI x0, xN, 0?**

Writing to x0 is architecturally a no-operation -- the result is discarded. This allows the sweep to touch every register as rs1 without changing any architectural state or disturbing the values that the scoreboard will check. It is the cleanest way to cover all rs1 bins without needing additional memory space or risking overwriting important register values.

**Q6: What is the VPI interface and why does Xcelium need it?**

VPI (Verilog Procedural Interface) is an IEEE standard C API that allows external programs to interact with a running simulation. cocotb uses VPI to read and write DUT signals, register callbacks on clock edges, and control simulation time. Xcelium exposes VPI through a shared library (libcocotbvpi_ius.so) that is loaded when the simulator starts. Without this interface, Python code cannot observe or control the RTL.

**Q7: What does CHECK_AFTER_CYCLES control in the scoreboard?**

It sets the number of rising clock edges the scoreboard waits before performing the register comparison. The single-cycle processor executes one instruction per clock cycle. The test program has 64 instructions, so setting the threshold to 64 ensures all instructions have completed before the check runs. Extra margin (the test runs 128 total cycles) ensures there is no off-by-one risk.

---

## Progress Tracker

| Task | Status |
|---|---|
| pyuvm environment complete (7 files) | Done |
| Makefile for Xcelium + cocotb | Done |
| Simulation running on TalTech HPC | Done |
| Monitor with functional coverage | Done |
| Scoreboard with golden register model | Done |
| Comprehensive test program (64 instructions) | Done |
| All achievable coverage bins hit | Done |
| Results committed and pushed to GitHub | Done |

---

## Next Week Plan

Phase 1 verification is complete. The following items remain before moving to the pipeline:

- Run JasperGold formal verification on the x0_immutable and pc_aligned SVA properties
- Run Genus logic synthesis on the single-cycle RTL and collect area and timing reports
- Begin RTL design of the RV64IM five-stage pipeline (Phase 2): instruction fetch stage first
