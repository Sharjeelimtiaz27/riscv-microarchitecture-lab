# Week 04 -- Formal Verification: SVA Complete Reference, JasperGold, and Run Findings

**Focus:** SystemVerilog Assertions theory, bind construct, security properties, JasperGold flow, and lessons learned from the actual proof run.

---

## Part 1: What Is SVA and Why Use It

SystemVerilog Assertions (SVA) is a formal specification language embedded in SystemVerilog. It gives you a way to write machine-checkable statements about how your RTL must behave.

There are two ways to verify RTL: simulation and formal. In simulation, you run the design with specific stimulus and check specific outputs. You can only observe the behavior you thought to test. In formal verification, a mathematical solver explores every possible input combination and every reachable state of the design, proving that your assertions hold universally or finding a counterexample that shows they do not.

A single well-written assertion replaces thousands of directed tests. The assertion `x0 is never written` proves the invariant holds in all 2^32 possible write-enable and write-data combinations, not just the ones your test program happened to try.

---

## Part 2: Assertion Types

### Immediate Assertions

Checked at a specific point in procedural code. No concept of time or clock edges.

```sv
always_comb begin
    assert (zero == (result == 32'd0)) else $error("zero flag wrong");
end
```

Immediate assertions work in simulation but formal tools use concurrent assertions.

### Concurrent Assertions

Temporal, clock-based, evaluated at every sampling edge. Written outside procedural blocks.

```sv
property p_example;
    @(posedge clk) disable iff (!rst_n)
    condition |-> consequence;
endproperty
assert property (p_example) else $error("property violated");
```

---

## Part 3: The Three Directives

### assert -- check a property must always hold

```sv
assert property (p_x0_immutable) else $error("x0 was written");
```

Violation in simulation: fires `$error`. Violation in JasperGold: tool produces a counterexample trace.

### cover -- prove a scenario is reachable

```sv
cover property (@(posedge clk) (we && rd == 5'd5));
```

JasperGold finds a witness trace (covered) or proves the scenario impossible (unreachable). Unreachable covers are GOOD: they confirm your design eliminates that scenario.

### assume -- constrain inputs for formal proof

```sv
assume property (@(posedge clk) disable iff (!rst_n) next_pc[1:0] == 2'b00);
```

The solver treats assumes as given facts. A wrong assume creates an impossible proof world. In simulation, assume behaves like assert.

---

## Part 4: Concurrent Assertion Anatomy

```sv
property p_write_updates_register;
    @(posedge clk)              // sample on rising clock edge
    disable iff (!rst_n)        // suspend during reset
    (we && rd != 5'd0)          // antecedent: write enabled to non-zero register
    |=>                         // non-overlapping implication: check NEXT cycle
    (rd1 == $past(wd, 1));      // consequent: read data matches what was written
endproperty
assert property (p_write_updates_register) else $error("write mismatch");
```

---

## Part 5: Sequences and Temporal Operators

### ##N -- exactly N cycles later

```sv
a ##1 b       // b must be true exactly 1 cycle after a
a ##3 b       // exactly 3 cycles later
a ##[1:5] b   // between 1 and 5 cycles later
a ##[1:$] b   // one or more cycles later
```

### Repetition [*N]

```sv
busy [*4]       // busy is true for exactly 4 consecutive cycles
busy [*2:8]     // between 2 and 8 consecutive cycles
```

### Non-consecutive repetition

```sv
a [->3] ##1 b   // a goes high exactly 3 times (not necessarily consecutive), then b
a [=3]          // a is seen exactly 3 times, non-consecutive
```

### throughout and within

```sv
(valid throughout data_seq)       // valid must hold through the entire sequence
ack within (grant ##[1:10] !grant) // ack occurs inside the grant window
```

---

## Part 6: Implication Operators -- |-> vs |=>

This is the most critical distinction in SVA. It caused 4 of the 6 CEX in the first JasperGold run.

### |-> Overlapping implication (same cycle)

`antecedent |-> consequent` means: if the antecedent holds at time T, the consequent must hold AT T (same clock cycle). The check is AT the cycle where the trigger fires.

```sv
// if rs1 == 0, then rd1 must be zero RIGHT NOW (combinational)
(rs1 == 5'd0) |-> (rd1 == 32'd0)
```

### |=> Non-overlapping implication (next cycle)

`antecedent |=> consequent` means: if the antecedent holds at time T, the consequent must hold at T+1 (next clock cycle). Equivalent to `antecedent |-> ##1 consequent`.

```sv
// if we wrote this cycle, the read port shows the result NEXT cycle
(we && rd != 5'd0) |=> (rs1 == $past(rd) |-> rd1 == $past(wd))
```

### CRITICAL RULE: which to use for $rose(rst_n)

**Wrong (caused CEX in JasperGold):**
```sv
$rose(rst_n) |=> (pc == 32'd0)
```
This checks the NEXT cycle after reset deasserts. By that cycle, the PC has already advanced to 4. CEX in 2 cycles.

**Correct:**
```sv
$rose(rst_n) |-> (pc == 32'd0)
```
This checks the SAME cycle where $rose fires. SVA samples signals in the "preponed" region (before NBA updates). At the posedge where rst_n just rose, the sampled pc value is still 0 because the async reset held it there. The check passes.

**General rule for reset-deassert checks:** use `|->` to check state AT the moment reset releases. Use `|=>` only when a response must happen AFTER the triggering cycle.

---

## Part 7: System Sampling Functions

### $past(expression, N)
Returns the value of expression N clock cycles ago. Default N is 1.
```sv
rd1 == $past(wd, 1)    // rd1 this cycle must equal wd from last cycle
```

### $rose(expression)
True when expression transitions 0→1 at this clock edge.
```sv
$rose(rst_n) |-> (pc == 32'd0)    // at reset deassert, pc must be 0
```

### $fell(expression)
True when expression transitions 1→0 at this clock edge.

### $stable(expression)
True if expression had the same value as the previous clock edge.
```sv
(!we && $stable(rs1)) |=> $stable(rd1)
```

### $changed(expression)
True if expression changed since the last clock edge (opposite of $stable).

### $isunknown(expression)
True if any bit is X or Z.
```sv
assert property (@(posedge clk) disable iff (!rst_n) !$isunknown(instr));
```

### $countones(expression)
Number of bits set to 1.

### $onehot(expression)
True if exactly one bit is 1.

---

## Part 8: disable iff

Suspends a concurrent assertion when the condition is true. Used to silence assertions during reset.

```sv
property p_pc_aligned;
    @(posedge clk)
    disable iff (!rst_n)   // do NOT check while reset is low
    pc[1:0] == 2'b00;
endproperty
```

Key: `disable iff` is evaluated ASYNCHRONOUSLY -- it suppresses the assertion at any point reset is active, not just at clock edges. This is different from including `rst_n` in the antecedent, which only checks synchronously.

---

## Part 9: Combinational vs Sequential Assertion Style

| Module has clock/state? | Use this style |
|------------------------|----------------|
| NO (pure combinational) | `always_comb` + immediate assertions |
| YES (flip-flops, registers) | `property/endproperty` + `assert property` |

**Forbidden in combinational modules:** `@(posedge)`, `##N`, `$past()`, `disable iff`, `property`, `assert property`

### Combinational Template

```sv
module <module>_assertions (
    // --- NO clock, NO reset --- combinational module ---
    input  logic [W:0] port1,
    ...
);
  always_comb begin
    // Boolean implication A -> B written as !A || B
    a_<module>_1: assert (!<antecedent> || <consequent>)
      else $error("<module>_1: <description>");

    a_<module>_2: assert (<invariant>)
      else $error("<module>_2: <description>");
  end
endmodule

bind <module_name> <module_name>_assertions u_<short>_assert (.*);
```

Real example from alu_assertions.sv:
```sv
always_comb begin
    a_alu_ADD: assert (!(alu_op == 4'd0) || (result == (a + b)))
      else $error("alu_ADD: ADD wrong");

    a_alu_ZERO_FLAG: assert (zero == (result == 32'd0))
      else $error("alu_ZERO_FLAG: mismatch");
end
```

### Sequential Template -- one-cycle response

```sv
property p_one_cycle;
    @(posedge clk) disable iff (!rst_n)
    trigger |=> response;
endproperty
assert property (p_one_cycle) else $error("...");
```

### Sequential Template -- reset deassert check

Use `|->` NOT `|=>` (see Part 6 critical rule).
```sv
property p_reset_check;
    @(posedge clk)
    $rose(rst_n) |-> (state == IDLE);
endproperty
```

### Sequential Template -- stability

```sv
property p_phantom_write_impossible;
    @(posedge clk) disable iff (!rst_n)
    (!(we && rd == TARGET_REG)) |=> $stable(register_value);
endproperty
```

### Sequential Template -- write-then-read coherence

```sv
property p_write_then_read;
    @(posedge clk) disable iff (!rst_n)
    (we && rd != 5'd0) |=>
        ((rs1 == $past(rd,1)) |-> (rd1 == $past(wd,1)));
endproperty
```

---

## Part 10: The bind Construct

### What bind does

Instantiates a checker module inside a target RTL module without modifying the RTL source. Essential because RTL source files should not be modified for verification.

### Syntax (one file = module + bind at bottom)

```sv
module <dut>_assertions (
    // ALL ports are input -- observer only, never drives
    input logic clk,
    input logic rst_n,
    ...
);
    // assertions here
endmodule

bind <target_module> <dut>_assertions u_<dut>_assert (.*);
```

### .* automatic port matching

`.*` connects all ports of the assertions module to signals with the same name in the target's scope. Only works when port names exactly match.

### Accessing internal signals

```sv
// regfile_assertions.sv -- bind with internal array access
bind regfile regfile_assertions u_regfile_assert (
    .*,
    .regs_x0 (regs[0]),   // internal array element, not a port
    .regs_x1 (regs[1]),
    .regs_x2 (regs[2])
);
```

---

## Part 11: Security Assertions -- Taxonomy

### Register File Threats

| Threat | Property Type | What It Proves |
|--------|--------------|---------------|
| x0 corruption | Physical array check | `regs[0] == 0` always |
| Phantom write | Stability | register changes ONLY when `we=1 AND rd=i` |
| Write isolation | Stability across indices | write to x_i does not change x_j |
| Temporal isolation | Same-cycle sampling | write in cycle N not visible until N+1 |
| Reset integrity | `$rose` check with `\|->` | all regs are 0 at reset deassert posedge |

### ALU Threats

| Threat | Property Type | What It Proves |
|--------|--------------|---------------|
| Operation substitution | Combinational equivalence | each alu_op maps to exactly the right computation |
| SRA vs SRL confusion | Specific funct7 check | funct7[5] correctly distinguishes arithmetic from logical shift |

---

## Part 12: JasperGold TCL Commands Reference

```tcl
clear -all                              # reset tool state
analyze -sv12 {file1.sv file2.sv}       # compile RTL + assertion files
elaborate -top module_name -bbox_a 8192 # elaborate; prevent memory black-boxing
clock clk                               # declare primary clock
reset -expression {!rst_n}             # declare reset (active-low = !rst_n)
prove -all                              # prove all properties (synchronous, blocks)
prove -bg -all                          # prove in background (script continues immediately -- don't report right after)
```

### bbox_a flag -- critical for memories

JasperGold auto-black-boxes large arrays. Warning: `VERI-9033: array X automatically BLACK-BOXED`.
A black-boxed memory returns free (unconstrained) values -- write-then-read properties become unprovable.

Fix: add `-bbox_a N` to elaborate where N >= the largest array size in your design.
```tcl
elaborate -top single_cycle_top -bbox_a 8192
```

---

## Part 13: JasperGold Run Findings -- First Run Results

**Run date:** Week 04, TalTech HPC, Jasper Apps 2024.06p002

**Result:** 141 properties total -- 84/90 assertions proven (93%), 6 CEX, 49/51 covers hit, 2 unreachable.

### CEX Analysis and Root Causes

**CEX 1: pc._assert_2 (p_rose_reset_pc_zero)**

Property written: `$rose(rst_n) |=> (pc == 32'd0)`
Counterexample: 2-cycle trace.

Root cause: `|=>` checks the NEXT cycle. After reset deasserts, the PC advances to `next_pc = pc + 4 = 4` in the next cycle. The assertion checked for 0 at cycle T+1 when pc was already 4.

Fix: change `|=>` to `|->`. SVA samples signals in the preponed region before NBA updates. At the posedge where $rose fires, the sampled pc is still 0 from the asynchronous reset.

**CEX 2: aluctrl.a_aluctrl_NO_ILLEGAL**

Property written: for known opcodes (including R-type), alu_op must not be 4'hF.
Counterexample: 1-cycle trace, R-type opcode with unusual funct7/funct3 combination.

Root cause: The assertion was too broad. R-type has 10-bit encoding space (funct7 + funct3 = 1024 combinations) but RV32I only defines 10 of them. The remaining 1014 combinations legitimately return 4'hF in an RV32I-only decoder. This is correct behavior, not a bug.

Fix: remove the broad property. The individual per-instruction assertions (a_aluctrl_R_ADD, etc.) already prove every defined encoding maps to the correct alu_op. No information is lost.

**CEX 3: dmem._assert_1 (p_write_then_read)**

Property written: write to address A in cycle N, read from A in cycle N+1 returns the written data.
Counterexample: 2-cycle trace.

Root cause: `VERI-9033` warning in elaboration log: data_memory.sv array was automatically BLACK-BOXED. A black-boxed memory returns unconstrained (free) values. JasperGold can make rdata anything it chooses, so the write-then-read property has no chance of being proven.

Fix: add `-bbox_a 8192` to the elaborate command.

**CEX 4, 5, 6: regfile._assert_5, _assert_15, _assert_16**

These are `p_reset_clears_read_ports`, `p_sec_reset_clears_x1`, `p_sec_reset_clears_x2`.

All three used `$rose(rst_n) |=> ...` -- the same |=> vs |-> bug as CEX 1.

Fix: change all three to `$rose(rst_n) |-> ...`.

---

### Unreachable Covers Analysis

`dmem._cover_6` (simultaneous `wr_en && rd_en`) was proven UNREACHABLE.

This is CORRECT and GOOD. The top_assertions.sv property `p_mem_rw_exclusive` was proven (`!(memread && memwrite)` always holds). Because the single_cycle_top control unit can never assert both at once, JasperGold correctly proves the cover is structurally impossible. An unreachable cover that you understand is a proof, not a gap.

---

### Fixes Applied

| Fix | File Changed | Change |
|-----|-------------|--------|
| |=> to |-> for reset checks (x4) | pc_assertions.sv, regfile_assertions.sv | `$rose(rst_n) \|=>` → `$rose(rst_n) \|->` |
| Remove over-broad decoder assertion | alu_ctrl_assertions.sv | Removed `a_aluctrl_NO_ILLEGAL` |
| Prevent memory black-boxing | formal/prove_single_cycle.tcl | Added `-bbox_a 8192` to elaborate |

**Expected result after fixes:** 89/89 assertions proven, 49/51 covers hit (the simultaneous R+W cover remains structurally unreachable, which is correct).

---

### Key Lessons from the JasperGold Run

**Lesson 1:** Always use `|->` for `$rose(rst_n)` reset-check properties, never `|=>`. The distinction matters because async reset holds state before the posedge, and `|->` checks the sampled (pre-NBA) value. `|=>` looks one cycle too late.

**Lesson 2:** Check the elaboration log for `VERI-9033 BLACK-BOXED` warnings before running proofs. Any memory that is black-boxed will make data-integrity properties unprovable. Always use `-bbox_a N`.

**Lesson 3:** Do not write "this opcode family never produces illegal output" assertions for decoders with large encoding spaces. Write one assertion per specific defined encoding instead. The individual assertions are stronger and more precise.

**Lesson 4:** Proof time for combinational properties (ALU, ALU ctrl, immgen) was under 0.1 seconds per property. Sequential properties with register file access took up to 0.65 seconds. Total proof time for 141 properties was under 2 seconds. This design is small enough for exhaustive unbounded proof.

**Lesson 5:** CEX trace length is a diagnostic signal. A 1-cycle CEX means the property is either trivially wrong (no temporal depth) or an over-broad invariant. A 2-cycle CEX on a `|=>` property usually means the trigger fires correctly but the next-cycle check is looking at the wrong state.

---

## Progress Tracker (Formal)

| Task | Status |
|------|--------|
| SVA theory documented | Done |
| Combinational assertion files (alu, alu_ctrl, immgen) | Done |
| Sequential assertion files (regfile, pc, dmem, top) | Done |
| formal/prove_single_cycle.tcl | Done |
| First JasperGold run on HPC | Done -- 84/90 proven, 6 CEX |
| |=> to |-> fix (x4 properties) | Done |
| Remove over-broad NO_ILLEGAL assertion | Done |
| -bbox_a 8192 added to elaborate | Done |
| Second JasperGold run -- confirm 89/89 | Pending |

---

## Interview Questions and Answers

**Q1: What is the difference between assert, cover, and assume?**

assert checks that a property must always be true -- violation is a bug. cover checks that a scenario is reachable -- it fires when the property is satisfied and confirms stimulus reaches the design state. assume constrains inputs in a formal proof; the solver treats it as given and only explores scenarios that satisfy it. In simulation, assume behaves like assert.

**Q2: What does |-> mean vs |=>?**

`|->` is overlapping implication: if the antecedent holds at time T, the consequent is checked at T (same cycle). `|=>` is non-overlapping: consequent is checked at T+1 (next cycle). Equivalently, `a |=> b` is the same as `a |-> ##1 b`. The distinction caused 4 of 6 CEX in the first JasperGold run on this project.

**Q3: When should you use |-> vs |=> for a $rose(rst_n) check?**

Always use `|->`. SVA samples signals in the preponed region before non-blocking assignment updates. At the posedge where `$rose(rst_n)` fires, the sampled register value is still zero (held by the asynchronous reset). `|=>` would check the next cycle when the design is already running normally and state has advanced.

**Q4: What is memory black-boxing in JasperGold and how do you fix it?**

JasperGold automatically replaces large memory arrays with free (unconstrained) input models to reduce proof complexity. This is called black-boxing (warning VERI-9033). A black-boxed memory returns any arbitrary value the tool chooses, making write-then-read coherence properties unprovable because the tool is free to return a different value than what was written. Fix: add `-bbox_a N` to the elaborate command where N is at least the size of the largest array. For our 256-word data memory (8192 bits), `-bbox_a 8192` prevents black-boxing.

**Q5: What is a phantom write and why is it a security concern?**

A phantom write is when a register value changes without the write-enable signal being asserted. In a processor, registers should only change through the architectural write-back path (we=1). If a hardware Trojan injects values into the register file via a hidden path that bypasses the write-enable gate, the phantom-write assertion (`!(we && rd==i) |=> $stable(regs[i])`) will catch it. The assertion accesses the internal array via bind, proving physical storage integrity -- not just what appears on the read ports.

**Q6: What does an unreachable cover property tell you?**

It tells you that the scenario is structurally impossible given the design and any assume constraints. In this project, the cover for simultaneous wr_en && rd_en on the data memory was proven unreachable. This was CORRECT because the control unit's `p_mem_rw_exclusive` property was proven (memread and memwrite are never both asserted). An unreachable cover you understand is a structural proof, not a gap in verification.

**Q7: What is $past and when do you need it?**

`$past(expr, N)` returns the value of expr N clock cycles ago. It is essential for write-then-read coherence properties: the write data (wd) is visible at cycle T, but you check it against the read data (rd1) at cycle T+1. Without $past you cannot reference wd from the previous cycle at the time you check rd1. Default N is 1.

**Q8: What is disable iff and how is it different from an antecedent condition?**

`disable iff (condition)` suspends the entire assertion ASYNCHRONOUSLY when the condition is true. This means if reset goes low between clock edges, the assertion is suspended immediately without waiting for the next posedge. In contrast, making rst_n part of the antecedent (`!rst_n |-> ...`) only evaluates at the clock edge. For asynchronous resets, disable iff is the correct construct because it tracks reset asynchronously in the same way the RTL does.
