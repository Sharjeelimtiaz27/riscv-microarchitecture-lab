# Week 01 — Why Microarchitecture Needs Formal Verification  
## + Single-Cycle RV32I Foundation & Simulation Setup

---

# 🎯 Week 01 Objectives

- Establish professional GitHub repository structure
- Implement modular Single-Cycle RV32I processor
- Successfully simulate design using Cadence Xcelium
- Generate waveform (VCD)
- Reflect deeply on why formal verification is critical in CPU design
- Identify knowledge gaps to improve in upcoming weeks

---

# 🧠 Why Microarchitecture Needs Formal Verification

## Deeper Reasoning

In a CPU, many bugs are:

- Not simple functional mismatches  
- Not easily triggered by random simulation  
- Not visible in small directed tests  

They are often:

- Corner-case pipeline bugs  
- Rare hazard interactions  
- Deadlock conditions  
- Incorrect instruction ordering  
- Subtle security leaks  

Simulation typically answers:

> “Does this sequence work?”

Formal verification answers:

> “Can this ever break?”

That difference is critical.

---

## Microarchitectural Complexity

Unlike simple blocks (e.g., an ALU), a CPU contains:

- Multiple pipeline stages  
- Speculation  
- Forwarding logic  
- Flush mechanisms  
- Commit ordering rules  
- Architectural state consistency requirements  

Many of these are **invariants**, not just input-output relationships.

### Example Invariant

> If an instruction commits, it must have been previously decoded and not flushed.

Simulation may never generate the exact timing sequence that violates such an invariant.

Formal verification, however, explores all legal behaviors (within given assumptions and bounds) and can prove whether such violations are possible.

---

## The Security Angle

Security vulnerabilities in CPUs often arise from:

- Speculative execution behavior  
- Microarchitectural state leaks  
- Incorrect privilege enforcement  
- Unintended data propagation  

These are not simple functional bugs.

They are violations of **global microarchitectural invariants**.

Formal verification is powerful in this context because:

- You can assert **information-flow properties**  
- You can assert **privilege isolation invariants**  
- You can prove certain classes of leakage are impossible (within defined assumptions)  

This is fundamentally different from running random or directed simulation tests.

---

## Interview-Level Answer

If asked:

**Why use formal in CPU design?**

A strong answer would be:

> CPUs contain complex interacting state machines and ordering constraints that are difficult to exhaustively verify with simulation. Formal verification allows us to assert microarchitectural invariants — such as correct instruction commit ordering, absence of deadlock, and privilege isolation — and prove they hold for all possible legal input sequences within given bounds. This is especially important for security-critical functionality where rare corner cases can lead to exploitable vulnerabilities.

---

# 🏗 What Was Built in Week 01

### RTL Modules Implemented

- ALU
- ALU Control
- Register File (x0 immutable)
- Immediate Generator
- Program Counter
- Instruction Memory
- Data Memory
- `single_cycle_top` integration

All modules structured under:
    rtl/common/
    rtl/single_cycle/


Modular structure chosen to:

- Enable reuse in future pipelined design
- Support clean assertion binding
- Prepare for formal verification

---

# 🖥 Simulation Achieved

Simulation executed using Cadence Xcelium.

Program tested:

    ADDI x1, x0, 5
    ADDI x2, x0, 7
    ADD x3, x1, x2

Result:
    x1 = 5
    x2 = 7
    x3 = 12
    SMOKE PASS

Waveform generated:
    waves.vcd


Signals inspected:

- pc
- instr
- alu_res
- wb_data
- rf.regs[1..3]

---

# 📚 What I Learned in Week 01

### 1️⃣ Environment Matters

Most failures were not RTL bugs but:

- Missing module compilation
- Tool environment not loaded
- Path issues
- Wave generation flags

Lesson:
Hardware engineering includes toolchain mastery.

---

### 2️⃣ Clean Structure Is Critical

Separating:

- common modules
- top-level integration
- testbench
- documentation

makes the design scalable and professional.

---

### 3️⃣ Simulation ≠ Proof

Even though simulation passed, it only validated:

- One specific program
- One specific sequence
- One specific path

It does NOT prove:

- x0 can never change
- Decoder never outputs illegal ALU operation
- Control logic never misfires
- State transitions are safe

Formal verification is needed next.

---

# 📈 What Needs to Be Learned More (Next Focus Areas)

## Immediate Technical Improvements

- Write SystemVerilog Assertions (SVA)
- Prove x0 immutability
- Prove correct writeback behavior
- Add decoder validity checks

---

## Architecture-Level Learning Needed

- Complete RV32I instruction coverage
- Understand sign-extension corner cases
- Branch encoding and PC-relative logic
- Control signal minimization

---

## Verification Knowledge to Improve

- Immediate vs concurrent assertions
- $past usage
- Implication operators (|->)
- Bounded model checking
- Safety vs liveness properties

---

## Security Thinking to Develop

- How could x0 corruption lead to exploit?
- What microarchitectural state is externally visible?
- Where could information leak?
- How speculation might affect security?

---

# 🔍 Reflection

Week 01 established:

- Working Single-Cycle RV32I core
- Clean research-grade project structure
- Successful Cadence simulation
- Waveform inspection workflow

But more importantly:

It revealed how much deeper CPU verification truly is.

Formal verification shifts the mindset from:

> “Does this test pass?”

to:

> “Is this failure fundamentally impossible?”

That mindset shift is the real beginning of microarchitectural maturity.

---

End of Week 01.