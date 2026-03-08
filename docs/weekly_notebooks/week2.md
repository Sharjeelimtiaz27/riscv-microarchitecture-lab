# Week 02 — Functional Verification with cocotb + pyuvm and Introduction to SVA

## Objectives

Week 02 focuses on building a modern verification environment for the RISC-V CPU using Python.

Goals for this week:

- Understand verification architecture
- Learn the role of cocotb
- Learn the role of pyuvm
- Build a simple functional verification environment
- Understand UVM component hierarchy
- Introduce SystemVerilog Assertions (SVA)
- Prepare the design for formal verification

---

## Why Functional Verification Matters

RTL simulation alone does not guarantee correctness.

A CPU must be verified against:

- Instruction correctness
- Register updates
- Memory behavior
- Corner cases
- Unexpected inputs

Functional verification ensures that the CPU behaves according to specification.

---

## Verification Stack

```
Python Verification Layer
         │
         ▼
pyuvm (UVM architecture in Python)
         │
         ▼
cocotb (Python <-> simulator interface)
         │
         ▼
Simulator (Xcelium / QuestaSim)
         │
         ▼
SystemVerilog RTL (CPU)
```

---

## Verification Architecture

```
                 Python world
 ┌─────────────────────────────────────────┐
 │                                         │
 │  pyuvm                                  │
 │  ├── Test                               │
 │  ├── Environment                        │
 │  │    ├── Agent                         │
 │  │    │    ├── Driver                   │
 │  │    │    ├── Sequencer                │
 │  │    │    └── Monitor                  │
 │  │    └── Scoreboard                    │
 │  │                                      │
 │  └── Sequence                           │
 │                                         │
 └─────────────────────────────────────────┘
                   │
                   │ built on
                   ▼
           cocotb framework
           ├── Clock generator
           ├── Reset control
           ├── Signal read/write
           └── Coroutine scheduling
                   │
                   │ communicates with
                   ▼
         Hardware simulator (Xcelium)
               command: xrun
                   │
                   ▼
        SystemVerilog RTL (RISC-V CPU)
```

---

## UVM Component Hierarchy

```
Test
│
▼
Environment
│
├── Agent
│    ├── Driver
│    ├── Sequencer
│    └── Monitor
│
└── Scoreboard
```

---

## Component Responsibilities

### Test

Top-level verification program.

Responsibilities:

- Create clock
- Apply reset
- Start environment
- Run sequences

---

### Environment

Container for the entire verification setup.

Responsibilities:

- Create components
- Connect components
- Manage simulation phases

---

### Agent

Represents an interface to the DUT.

Contains:

- Driver
- Sequencer
- Monitor

---

### Driver

Responsible for driving signals into the DUT.

```
instruction transaction
        ↓
driver writes instruction to instruction memory
```

---

### Sequencer

Controls transaction flow.

Responsibilities:

- Schedule sequences
- Send sequence items to the driver

---

### Sequence

Defines a test scenario.

Example sequence:

```
ADDI x1, x0, 5
ADDI x2, x0, 7
ADD  x3, x1, x2
```

---

### Monitor

Observes DUT signals.

Example observation:

```
rd   = 3
data = 12
```

The monitor sends observations to the scoreboard.

---

### Scoreboard

Compares expected results with DUT output.

Example:

```
expected : x3 = x1 + x2 = 12
observed : x3 = 12
result   : PASS
```

---

## Transaction Flow

```
Sequence
   │
   ▼
Sequencer
   │
   ▼
Driver
   │
   ▼
CPU RTL (DUT)
   │
   ▼
Monitor
   │
   ▼
Scoreboard
   │
   ▼
Pass / Fail Result
```

---

## Role of cocotb

cocotb provides the Python interface to the simulator.

Key features:

- Clock generation
- Reset control
- Signal read/write
- Asynchronous coroutines

Example:

```python
dut.clk.value = 1
await Timer(5, "ns")
dut.clk.value = 0
```

---

## Example Smoke Test

Program executed:

```
ADDI x1, x0, 5
ADDI x2, x0, 7
ADD  x3, x1, x2
```

Expected result:

```
x1 = 5
x2 = 7
x3 = 12
```

Simulation output:

```
SMOKE PASS
```

---

## Introduction to SystemVerilog Assertions

Assertions allow engineers to specify design properties formally within RTL code. They enable automatic bug detection during simulation and are the foundation for formal verification.

### Example Property

Register x0 must always remain zero.

```systemverilog
property x0_immutable;
  @(posedge clk)
  disable iff (!rst_n)
  !(reg_write && rd == 5'd0);
endproperty

assert property(x0_immutable);
```

---

## Types of Assertions

### Immediate Assertions

Executed at the current simulation time, like a standard conditional check.

```systemverilog
assert(a == b);
```

### Concurrent Assertions

Evaluated across clock cycles using temporal operators.

```systemverilog
a |-> b
```

Meaning: if `a` is true, then `b` must be true on the same or a subsequent clock cycle.

---

## Why Assertions Are Important

Assertions help detect:

- Illegal states
- Incorrect register writes
- Invalid memory access
- Pipeline hazards
- Security violations

They are also required as input properties for formal verification tools.

---

## Connection to Formal Verification

Formal verification tools such as JasperGold use assertions as properties to prove or disprove.

```
RTL + Assertions
       │
       ▼
Formal Tool (JasperGold)
       │
       ▼
Proof or Counterexample
```

If a property is violated, JasperGold produces a counterexample trace showing the exact condition under which the property fails.

### Example Formal Property

Property: register x0 must never change.

Formal proof checks:

```
∀ time : regfile[0] == 0
```

---

## Key Lessons from Week 02

- Verification architecture is separate from RTL design.
- Python can be used effectively for hardware verification.
- UVM architecture helps organize and scale complex test environments.
- cocotb provides signal-level interaction between Python and the simulator.
- Assertions enable automatic correctness checking during simulation.
- Assertions are the foundation for formal verification with tools like JasperGold.

---

## Questions and Answers

**Q1: What is pyuvm?**

pyuvm is a Python implementation of the UVM (Universal Verification Methodology) architecture. It replicates the standard UVM component hierarchy — Test, Environment, Agent, Driver, Sequencer, Monitor, and Scoreboard — entirely in Python, removing the need to write verification code in SystemVerilog.

---

**Q2: What does cocotb do?**

cocotb (Coroutine-Based Co-simulation Testbench) is a Python framework that provides a direct interface to an HDL simulator. It allows Python code to read and write DUT signals, generate clocks, apply resets, and schedule coroutines, all while the simulator executes the RTL in the background.

---

**Q3: Does cocotb replace the simulator?**

No. The RTL simulator (such as Xcelium or QuestaSim) still executes the SystemVerilog RTL. cocotb communicates with the simulator through a VPI or FLI interface, acting as a test controller rather than a simulation engine.

---

**Q4: What is a driver?**

A driver is a UVM component that converts abstract sequence items (transactions) into low-level signal activity on the DUT interface. For a CPU, this means writing instruction data and control signals into the design at the correct clock cycles.

---

**Q5: What is a monitor?**

A monitor is a passive UVM component that observes DUT output signals without driving them. It captures signal activity — such as register write-back data and destination register indices — and forwards these observations to the scoreboard for comparison.

---

**Q6: What is a scoreboard?**

A scoreboard is a UVM component that compares DUT output against the expected result generated by a reference model. If the observed output matches the expected value, the test passes. If not, the scoreboard flags a failure and reports the mismatch.

---

**Q7: Why use assertions?**

Assertions provide a formal, machine-checkable way to express design intent. They detect incorrect behavior — such as illegal register writes or invalid state transitions — automatically during simulation without requiring manual inspection of waveforms. They also serve as the input properties for formal verification tools such as JasperGold.

---

**Q8: What is the difference between simulation-based verification and formal verification?**

Simulation-based verification checks the design against a finite set of test inputs. It can miss corner cases that were not explicitly tested. Formal verification uses mathematical proof to check whether a property holds for all possible inputs and states, providing exhaustive coverage without requiring individual test cases.

---

**Q9: What happens when JasperGold cannot prove a property?**

If JasperGold cannot prove a property, it generates a counterexample — a sequence of inputs and states that causes the property to be violated. This counterexample can be loaded into a waveform viewer to investigate the root cause of the failure.

---

**Q10: Why is the UVM architecture used even in Python-based verification?**

The UVM architecture provides a structured, reusable framework for organizing verification components. It separates concerns cleanly — stimulus generation, signal driving, output observation, and result checking are each handled by dedicated components. This makes test environments easier to maintain, extend, and reuse across different designs and projects.