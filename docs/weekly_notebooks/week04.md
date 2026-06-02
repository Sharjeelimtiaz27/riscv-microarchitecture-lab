# Week 04 -- SystemVerilog Assertions: Complete Reference, Bind Files, and Security Verification

## Objectives

Week 04 builds the full assertion-based verification layer on top of the single-cycle RV32I RTL.

Goals for this week:

- Master every SVA construct: assert, cover, assume, sequences, properties, temporal operators
- Learn the bind construct and why it is the correct way to attach checkers to RTL
- Write functional and security assertions for every module in the design
- Prove properties formally using JasperGold
- Run Genus logic synthesis and produce a gate-level netlist
- Begin the Innovus place and route flow

---

## Part 1: What Is SVA and Why Use It

SystemVerilog Assertions (SVA) is a formal specification language embedded in SystemVerilog. It gives you a way to write machine-checkable statements about how your RTL must behave.

There are two ways to verify RTL: simulation and formal. In simulation, you run the design with specific stimulus and check specific outputs. You can only observe the behavior you thought to test. In formal verification, a mathematical solver explores every possible input combination and every reachable state of the design, proving that your assertions hold universally or finding a counterexample that shows they do not.

SVA properties are used in both flows:

- In simulation, assertion failures fire as runtime errors when the condition is violated.
- In JasperGold formal verification, the tool proves or disproves each property exhaustively.

A single well-written assertion replaces thousands of directed tests. The assertion `x0 is never written` proves the invariant holds in all 2^32 possible write-enable and write-data combinations, not just the ones your test program happened to try.

---

## Part 2: Assertion Types

### Immediate Assertions

An immediate assertion is checked at a specific point in procedural code, like an `if` statement. It fires once, at the moment of execution, without any concept of clock edges or time sequences.

```sv
always_comb begin
    // fires whenever inputs change
    assert (zero == (result == 32'd0)) else $error("zero flag wrong");
end
```

Immediate assertions are useful for quick sanity checks in simulation but cannot be used by formal tools for exhaustive proof.

### Deferred Immediate Assertions

A deferred immediate assertion uses the `final` keyword to postpone the check to the end of the simulation time step. This avoids false failures caused by race conditions in delta cycles.

```sv
always_comb begin
    assert final (zero == (result == 32'd0)) else $error("zero flag wrong");
end
```

### Concurrent Assertions

Concurrent assertions are the primary SVA construct for formal verification. They describe behavior that spans multiple clock cycles and are evaluated at every sampling edge (typically posedge clk). They are written outside procedural blocks using the `property` and `assert property` syntax.

```sv
property p_example;
    @(posedge clk) disable iff (!rst_n)
    condition |-> consequence;
endproperty
assert property (p_example) else $error("property violated");
```

This is the form used throughout this project.

---

## Part 3: The Three Directives -- assert, cover, assume

### assert

`assert` checks that a property is always true. If the property is violated, it is an error. This is the primary directive for catching bugs.

In simulation, a failed assert fires `$error` (or `$fatal`, `$warning` depending on what you specify in the `else` clause).

In JasperGold, a failed assert means the tool found a counterexample -- a sequence of inputs that reaches a state where the property is false. The tool reports the counterexample trace so you can debug.

```sv
assert property (p_x0_immutable) else $error("SVA FAIL: x0 was written");
```

### cover

`cover` checks that a property is reachable -- that some sequence of events can actually happen. This is a coverage point, not a bug check. If a `cover` never fires, it means either the stimulus never exercised that scenario or the design makes it structurally impossible.

```sv
// Has the design ever seen a write to register x5?
cover property (@(posedge clk) (we && rd == 5'd5));
```

In JasperGold, `cover` properties are proven reachable (the tool finds a witness trace) or unreachable (the tool proves the scenario can never happen). An unreachable cover in a formal flow can mean either that the scenario is correctly excluded by design or that the stimulus constraints are too tight.

### assume

`assume` constrains the environment of the design under proof. It tells the formal tool: this property is a constraint on inputs, not a property to be proven.

```sv
// Tell JasperGold: assume the PC is always aligned when rst_n is high
// This lets the tool skip unaligned-PC cases when proving other properties
assume property (@(posedge clk) disable iff (!rst_n) next_pc[1:0] == 2'b00);
```

`assume` properties are not checked -- the tool takes them as given. If you write a wrong assume, you can prove properties true in an impossible world. Use assume only to model what the environment guarantees.

In simulation, `assume` behaves like `assert` in most tools (it fires an error if violated). This is useful for catching when your testbench drives inputs that violate the assumed constraint.

---

## Part 4: Concurrent Assertion Anatomy

Every concurrent assertion has the same structure:

```
<directive> property ( <property_expression> ) [else $error("msg")];
```

A property expression looks like:

```
@(<clocking_event>) [disable iff (<reset_condition>)] <sequence_or_property>
```

Breaking down a complete example:

```sv
property p_write_updates_register;
    @(posedge clk)              // sample on rising clock edge
    disable iff (!rst_n)        // suspend during reset
    (we && rd != 5'd0)          // antecedent: write enabled to non-zero register
    |=>                         // non-overlapping implication: check on NEXT cycle
    (rd1 == $past(wd, 1));      // consequent: read data matches what was written
endproperty
assert property (p_write_updates_register) else $error("write mismatch");
```

Each part is explained in the sections below.

---

## Part 5: Sequences

A sequence describes a pattern of signal values over one or more clock cycles.

### Basic sequence

```sv
// signal a is high for exactly one cycle
sequence s_a_high;
    @(posedge clk) a;
endsequence
```

### Consecutive repetition with ##

`##N` means exactly N clock cycles later. It is the most important SVA temporal operator.

```sv
// a is high now, and b is high exactly one cycle later
a ##1 b

// a is high now, and b is high exactly three cycles later
a ##3 b

// a is high now, b is high between one and five cycles later
a ##[1:5] b
```

`##0` means "at the same clock edge" (useful for combining simultaneous conditions).

### Bounded range ##[m:n]

```sv
// request followed by acknowledge between 2 and 10 cycles later
req ##[2:10] ack

// any number of cycles (0 or more) -- the * means unbounded
req ##[*] ack

// one or more cycles
req ##[1:$] ack
```

### Consecutive repetition of a condition [*N]

```sv
// busy is high for exactly 4 consecutive cycles
busy [*4]

// busy is high for between 2 and 8 consecutive cycles
busy [*2:8]

// busy is high forever (liveness -- be careful with formal)
busy [*]
```

### Non-consecutive repetition [->N] and [=N]

```sv
// a goes high exactly 3 times, non-consecutively, eventually followed by b
a [->3] ##1 b

// a is seen exactly 3 times at any point, non-consecutively
a [=3]
```

### throughout

`expression throughout sequence` means the expression must be true at every cycle while the sequence is happening.

```sv
// valid must stay high throughout the entire data transfer
(valid throughout data_transfer_seq)
```

### within

`s1 within s2` means sequence s1 is contained entirely within sequence s2.

```sv
// the ack pulse happens somewhere within the grant window
ack within (grant ##[1:10] !grant)
```

---

## Part 6: Properties and Implication

### Overlap implication |->

`antecedent |-> consequent` means: if the antecedent holds at time T, then the consequent must hold starting at time T (same cycle).

```sv
// if rd is x0, then rd1 must be zero in the same cycle
(rs1 == 5'd0) |-> (rd1 == 32'd0)
```

If the antecedent is false (vacuous match), the property passes automatically. This is correct behavior -- the property only makes a claim when its precondition is met.

### Non-overlapping implication |=>

`antecedent |=> consequent` means: if the antecedent holds at time T, then the consequent must hold starting at time T+1 (next cycle). This is equivalent to `antecedent |-> ##1 consequent`.

```sv
// if we wrote this cycle, the read port shows the new value next cycle
(we && rd != 5'd0) |=> (rs1 == $past(rd) |-> rd1 == $past(wd))
```

### Multi-cycle implication

```sv
// after reset deasserts, the PC must be zero within 2 cycles
$rose(rst_n) |-> ##[0:2] (pc == 32'd0)
```

### Property operators

```sv
// both properties must hold
assert property (p_a and p_b);

// at least one must hold
assert property (p_a or p_b);

// negation: the sequence must NOT occur
assert property (not (bad_sequence));

// conditional
assert property (
    @(posedge clk) if (mode == SECURE) p_secure else p_normal
);
```

### Safety vs Liveness

A **safety property** says "nothing bad ever happens." All assert properties in this project are safety properties.

```sv
// bad thing: x0 is written -- this must never happen
!(we && rd == 5'd0)
```

A **liveness property** says "something good eventually happens." Liveness requires the `s_eventually` operator and typically needs special treatment in formal tools.

```sv
// good thing: the request is eventually acknowledged
req |-> s_eventually(ack)
```

Bounded liveness is more practical for formal:

```sv
// the request is acknowledged within 16 cycles
req |-> ##[1:16] ack
```

---

## Part 7: System Sampling Functions

These functions let you observe signal values at specific points in time relative to the current clock edge.

### $past(expression, N)

Returns the value of `expression` N clock cycles ago. Default N is 1.

```sv
// rd1 this cycle must equal what wd was last cycle
rd1 == $past(wd, 1)

// same as above with default N=1
rd1 == $past(wd)

// value from 3 cycles ago
result == $past(operand, 3)
```

### $rose(expression)

True if the expression transitioned from 0 to 1 at this clock edge (was 0 last cycle, is 1 now).

```sv
// after reset deasserts, check initial conditions
$rose(rst_n) |=> (pc == 32'd0)
```

### $fell(expression)

True if the expression transitioned from 1 to 0 at this clock edge.

```sv
// when reset is asserted, flush the pipeline
$fell(rst_n) |=> $stable(wb_data)
```

### $stable(expression)

True if the expression had the same value at this clock edge as at the previous edge.

```sv
// if not writing, the read output should not change (given same read address)
(!we && $stable(rs1)) |=> $stable(rd1)
```

### $changed(expression)

True if the expression changed value since the last clock edge. The opposite of $stable.

```sv
// detect when a register value actually changes
cover property (@(posedge clk) $changed(pc));
```

### $onehot(expression)

True if exactly one bit of the expression is 1.

```sv
// only one ALU operation should be active
assert property (@(posedge clk) $onehot(alu_op_onehot_encoding));
```

### $onehot0(expression)

True if at most one bit is 1 (also true when all bits are 0).

### $isunknown(expression)

True if any bit of the expression is X or Z. Useful for catching uninitialized logic.

```sv
// no X or Z values on the instruction bus after reset
assert property (@(posedge clk) disable iff (!rst_n) !$isunknown(instr));
```

### $countones(expression)

Returns the number of bits set to 1. Returns an integer.

```sv
// ALU opcode has at most 2 bits set (all opcodes 0-9 are valid)
assert property (@(posedge clk) $countones(alu_op) <= 3);
```

### $sampled(expression)

Returns the sampled value of the expression at the active clock edge. Used inside sequences to force sampling semantics explicitly.

---

## Part 8: disable iff

`disable iff (condition)` suspends an assertion when the condition is true. This is used to silence assertions during reset, when the design is not in a defined state.

```sv
property p_pc_aligned;
    @(posedge clk)
    disable iff (!rst_n)   // do not check while reset is low
    pc[1:0] == 2'b00;
endproperty
```

The key point: `disable iff` is evaluated asynchronously. It is checked at the point the property would fire, not at the clock edge. This is different from making `rst_n` part of the antecedent.

---

## Part 9: Choosing Between Combinational and Sequential Assertion Style

This is the most important structural decision when writing SVA. The rule is strict:

| Module has clock/state? | Use this style |
|------------------------|----------------|
| NO (pure combinational) | `always_comb` + immediate assertions |
| YES (flip-flops, registers) | `property/endproperty` + `assert property` |

**Forbidden in combinational modules:** `@(posedge)`, `##N`, `$past()`, `disable iff`, `property`, `assert property`

**Forbidden in sequential modules when not needed:** none -- use all constructs freely

---

## Part 9a: Combinational Module Template

Use this for any module with no clock and no state: ALU, ALU control, immediate generator, any pure decoder.

```sv
module <module>_assertions (
    // --- NO clock, NO reset --- combinational module ---
    input  logic [W:0] port1,
    input  logic [W:0] port2,
    ...
);

  always_comb begin

    // Boolean implication A -> B written as !A || B
    a_<module>_SEC_1: assert (!<antecedent> || <consequent>)
      else $error("<module>_SEC_1: <description of what was violated>");

    // Simple invariant (no antecedent)
    a_<module>_SEC_2: assert (<invariant>)
      else $error("<module>_SEC_2: <description>");

    // ... one block per assertion ...

  end

endmodule

bind <module_name> <module_name>_assertions u_<module_short>_assert (.*);
```

**Real example from this project -- ALU zero flag:**

```sv
always_comb begin
    a_alu_ZERO_FLAG: assert (zero == (result == 32'd0))
      else $error("alu_ZERO_FLAG: zero=%b but result=%h", zero, result);

    a_alu_ADD: assert (!(alu_op == 4'd0) || (result == (a + b)))
      else $error("alu_ADD: ADD wrong -- a=%h b=%h result=%h", a, b, result);
end
```

The assertion label (`a_alu_ZERO_FLAG:`) is a SystemVerilog assertion label. It:
- Appears in simulation error messages identifying exactly which assertion fired
- Appears in JasperGold proof output identifying which property was proven/falsified
- Follows the naming convention `a_<module_short>_<DESCRIPTION>`

---

## Part 9b: Sequential Module Templates

### Template 1: Sequential one-cycle response (|=>)

### Template 2: One-cycle response (|=>)

Use when a stimulus in cycle N must produce a specific response in cycle N+1.

```sv
property p_one_cycle_response;
    @(posedge clk) disable iff (!rst_n)
    trigger |=> response;
endproperty
```

Example (register write then read):

```sv
property p_write_then_read;
    @(posedge clk) disable iff (!rst_n)
    (we && rd != 5'd0) |=> (rs1 == $past(rd) |-> rd1 == $past(wd));
endproperty
```

### Template 3: Multi-cycle sequence with ##

Use when a protocol spans multiple clock cycles.

```sv
property p_handshake;
    @(posedge clk) disable iff (!rst_n)
    (req) |-> ##[1:8] (ack);
endproperty
```

### Template 4: Stability (signal must not change)

Use to prove that something is constant while a condition holds.

```sv
property p_stable_during_busy;
    @(posedge clk) disable iff (!rst_n)
    (busy) |-> $stable(addr);
endproperty
```

### Template 5: Reset behavior

Use to prove that reset correctly initializes all state.

```sv
property p_reset_clears_state;
    @(posedge clk)
    $rose(rst_n) |=> (state == IDLE);
endproperty
```

### Template 6: Value range check

Use to constrain an output to a legal range.

```sv
property p_result_in_range;
    @(posedge clk) disable iff (!rst_n)
    (condition) |-> (output inside {0, 1});
endproperty
```

### Template 7: Security phantom write

Use to prove that a register changes ONLY under the expected write condition.

```sv
property p_phantom_write_impossible;
    @(posedge clk) disable iff (!rst_n)
    (!(we && rd == TARGET_REG)) |=> $stable(register_value);
endproperty
```

---

## Part 10: The bind Construct

### What bind does

The `bind` construct instantiates a checker module inside a target RTL module without modifying the RTL source code. This is essential in a professional flow because:

- RTL source files are owned by design engineers and should not be modified for verification
- Checker code can be enabled or disabled without recompiling RTL
- The same checker can be bound to multiple instances of the same module
- JasperGold and other formal tools natively support bind

### Syntax

```sv
bind <target_module> <checker_module> <instance_name> (
    .<port_of_checker> (<signal_in_target>),
    ...
);
```

The bind statement is placed in a separate file. It creates an instance of the checker inside every instantiation of the target module.

### Example: binding to a clocked module

When the target module has its own clock and reset, the bind is straightforward:

```sv
// rtl/assertions/regfile_bind.sv
bind regfile regfile_props_checker regfile_chk_i (
    .clk  (clk),
    .rst_n(rst_n),
    .we   (we),
    .rd   (rd),
    .wd   (wd),
    .rd1  (rd1),
    .rd2  (rd2)
);
```

### Example: binding a combinational module at the parent scope

When the target module is purely combinational (no clock), the checker needs a clock from the parent. Bind the checker at the top level instead of the module level:

```sv
// rtl/assertions/alu_bind.sv
bind single_cycle_top alu_props_checker alu_chk_i (
    .clk   (clk),       // top-level clock
    .a     (alu_a),     // internal signal in single_cycle_top
    .b     (alu_b),
    .alu_op(alu_op),
    .result(alu_res),
    .zero  (alu_i.zero) // hierarchical access to unconnected port
);
```

### Accessing internal signals via bind

The bind statement has access to all signals visible in the target module's scope, including internal signals that are not ports. This is how the security checker accesses the internal `regs` array of the register file:

```sv
bind regfile regfile_props_checker regfile_chk_i (
    .clk     (clk),
    .regs_x0 (regs[0]),   // internal array element -- visible in bind
    .regs_x1 (regs[1]),
    ...
);
```

This is one of the most powerful features of bind: the checker can observe internal state that is invisible to the DUT's ports, enabling deep security and correctness checking.

---

## Part 11: Security Assertions -- Taxonomy and Motivation

Security assertions are a category of formal properties specifically targeting hardware security vulnerabilities. For a RISC-V processor, the critical security-sensitive components are:

### Register File Security Threats

**x0 corruption**: If x0 can be written to a non-zero value through a bug or hardware Trojan, instructions that rely on x0 as a zero source (ADDI x1, x0, 5) or as a discard register (SW x3, x0, 0) will behave incorrectly. In a trusted execution environment, this could allow privilege escalation.

**Write isolation violation**: If writing to register x5 also silently modifies register x10, an attacker who controls the write data path can corrupt registers they should not be able to reach.

**Phantom write**: A register value changes without the write-enable signal being asserted. This is the signature of a hardware Trojan that injects values into the register file without going through the normal control path.

**Temporal isolation failure**: The write-before-read architecture guarantees that a write in cycle N is not visible on the read port until cycle N+1. If this barrier breaks, side-channel timing analysis becomes possible.

**Reset integrity failure**: After system reset, all registers must be exactly zero. A register that contains a non-zero value after reset could leak information from a previous computation.

### ALU Security Threats

**Operation substitution**: A hardware Trojan could substitute one ALU operation for another under specific input conditions. For example, performing ADD instead of SUB only when operand A equals a specific key value.

**Result overflow to controlled value**: Under specific inputs, an arithmetic overflow might produce a value that an attacker can exploit for control flow hijacking.

### Control Unit Threats

**Control signal injection**: A Trojan could assert memwrite for an instruction that should not write memory, causing a controlled memory corruption.

**Decoder inconsistency**: The decoder maps one opcode to two different control signal combinations depending on a hidden trigger. The formal checker proves the mapping is bijective.

---

## Part 12: Module-by-Module Assertion Summary

### ALU (alu_props.sv, alu_bind.sv)

The ALU is purely combinational. All properties are invariants checked at every clock edge.

Key assertions:
- `p_zero_flag_correct`: zero == (result == 0), always
- `p_add_correct` through `p_sra_correct`: each operation produces the correct result
- `p_slt_one_hot` / `p_sltu_one_hot`: comparison operations produce only 0 or 1

### ALU Control (alu_ctrl_props.sv, alu_ctrl_bind.sv)

The ALU control is also combinational. Properties prove the decoder is correct.

Key assertions:
- `p_r_add` through `p_branch_sub`: each opcode/funct3/funct7 combination maps to the correct alu_op
- `p_known_opcode_no_illegal`: no known opcode produces the illegal code 4'hF
- `p_sra_vs_srl`: funct7 bit distinguishes arithmetic from logical right shift

### Register File (regfile_props.sv, regfile_bind.sv)

The register file is sequential. Both functional and security properties are included.

Functional:
- `p_x0_rd1_zero` / `p_x0_rd2_zero`: x0 reads always return 0
- `p_write_then_read`: write-then-read coherence
- `p_reset_clears_outputs`: after reset, outputs are 0

Security:
- `p_sec_x0_internal_zero`: the physical regs[0] is always 0
- `p_sec_x0_write_ignored`: write to x0 has no effect on the internal array
- `p_sec_no_phantom_write_x1` / `_x2`: register values cannot change without we=1
- `p_sec_write_x1_no_corrupt_x2` / inverse: write isolation between x1 and x2
- `p_sec_write_gate_x1`: regs[1] changes if and only if we=1 and rd=1
- `p_sec_reset_zeros_x0` / `_x1`: reset clears internal registers

### Program Counter (pc_props.sv, pc_bind.sv)

The PC is a simple register.

Key assertions:
- `p_reset_value`: PC resets to 0
- `p_pc_register_update`: PC captures next_pc every cycle
- `p_pc_aligned`: PC[1:0] always equals 00
- `p_next_pc_aligned`: next_pc is also aligned

### Immediate Generator (immgen_props.sv, immgen_bind.sv)

The immediate generator is purely combinational.

Key assertions:
- `p_imm_i_sign_extended`: I-type immediate is correctly sign-extended from bit 31
- `p_imm_b_lsb_zero`: B-type immediate LSB is always 0 (branch targets are 2-byte aligned)
- `p_imm_j_lsb_zero`: J-type immediate LSB is always 0
- `p_imm_u_lower_zero`: U-type immediate lower 12 bits are always 0
- Sign-extension checks for B and J types

### Data Memory (dmem_props.sv, dmem_bind.sv)

Key assertions:
- `p_write_then_read`: write-then-read coherence for address-matching accesses
- `p_rdata_zero_when_disabled`: when rd_en is low, rdata must be 0

### Top Level (top_props.sv, top_bind.sv)

Integration-level properties that cross module boundaries.

Key assertions:
- `p_pc_aligned`: top-level PC always aligned
- `p_pc_plus4`: PC advances by exactly 4 (simple single-cycle without branches)
- `p_alu_src_mux`: alu_b is correct based on alu_src control
- `p_wb_mux_mem` / `_alu`: wb_data is correct based on memtoreg control
- `p_rtype_control`: R-type instructions generate exactly the right control word
- `p_store_control`: Store instructions set memwrite and clear reg_write

---

## Part 13: JasperGold Flow

JasperGold (Cadence Jasper) is a formal property verification tool. The flow for this project is:

1. Analyze (compile): load all RTL files, checker files, and bind files
2. Elaborate: build the design database for the target top module
3. Declare clock and reset: tell the tool how to interpret time
4. Prove: run the bounded or unbounded model checker on all `assert` properties
5. Check coverage: verify all `cover` properties are reachable
6. Debug: inspect counterexample traces for failed properties

### Proof result states

Each property can result in one of four states:

| State | Meaning |
|-------|---------|
| Proven | Property holds for all reachable states and all inputs |
| Bounded Proof | Property holds up to depth N (not exhaustive without k-induction) |
| Falsified | The tool found a counterexample -- a trace where the property is violated |
| Inconclusive | Tool ran out of time or memory before reaching a definitive answer |

### Key TCL commands

```tcl
clear -all                              -- reset the tool state
analyze -sv12 {file1.sv file2.sv}       -- compile RTL
elaborate -top module_name              -- build design database
clock clk                               -- declare primary clock
reset -expression {!rst_n}             -- declare reset condition
prove -bg -all                          -- prove all properties in background
report_results                          -- print summary table
```

---

## Part 14: Genus Synthesis Flow

Genus (Cadence Genus Synthesis Solution) converts RTL into a gate-level netlist using a standard cell library.

The flow:
1. Read HDL: load all RTL files
2. Elaborate: resolve hierarchy and parameters
3. Read SDC: apply timing constraints (clock period, input/output delays)
4. syn_generic: technology-independent optimization
5. syn_map: map to standard cells from the technology library
6. syn_opt: post-mapping optimization
7. Write outputs: netlist (.v), SDF delay file (.sdf), reports

The output netlist and SDF are inputs to:
- Gate Level Simulation (GLS): simulate the netlist with real delays
- Conformal equivalence checking: prove RTL == netlist
- JasperGold on the netlist: prove properties hold on the synthesized logic
- Innovus place and route

---

## Part 15: Innovus Place and Route Flow

Innovus (Cadence Innovus Implementation System) takes a synthesized netlist and produces a physical layout.

The flow:
1. Initialize design: load netlist, LEF files (cell geometry), liberty files (timing)
2. Floorplan: define die area, core area, power ring
3. Power planning: add power stripes and connect VDD/VSS to all cells
4. Placement: legally place all standard cells
5. Clock tree synthesis (CTS): build balanced clock distribution network
6. Routing: connect all signal wires within design rules
7. Post-route optimization: fix remaining timing violations
8. Write outputs: final netlist, DEF, GDS

---

## Progress Tracker

| Task | Status |
|------|--------|
| SVA reference document | Done |
| alu_props.sv + alu_bind.sv | Done |
| alu_ctrl_props.sv + alu_ctrl_bind.sv | Done |
| regfile_props.sv + regfile_bind.sv | Done |
| pc_props.sv + pc_bind.sv | Done |
| immgen_props.sv + immgen_bind.sv | Done |
| dmem_props.sv + dmem_bind.sv | Done |
| top_props.sv + top_bind.sv | Done |
| formal/prove_single_cycle.tcl | Done |
| syn/single_cycle_syn.tcl | Done |
| syn/constraints/single_cycle.sdc | Done |
| pnr/innovus_single_cycle.tcl | Done |
| JasperGold formal run on HPC | Pending |
| Genus synthesis run on HPC | Pending |
| Innovus P&R run on HPC | Pending |

---

## Interview Questions and Answers

**Q1: What is the difference between assert, cover, and assume in SVA?**

assert checks that a property must always be true. A violation is a bug. cover checks that a property is reachable -- it fires when the property is satisfied and is used for coverage measurement. assume constrains the environment in a formal proof. The solver treats an assume as a given fact about inputs, reducing the proof space to scenarios where the assumption holds.

**Q2: What does |-> mean vs |=>?**

Both are implication operators. `|->` is overlapping: if the antecedent holds at time T, the consequent must hold starting at T (same cycle). `|=>` is non-overlapping: if the antecedent holds at T, the consequent must hold at T+1 (next cycle). `a |=> b` is equivalent to `a |-> ##1 b`.

**Q3: What does disable iff do and why is it needed?**

disable iff suspends a concurrent assertion when its condition is true. It is needed because during reset, the design is not in a defined state and assertions would fire false violations. The condition is evaluated asynchronously, meaning it does not wait for the clock edge. Putting `!rst_n` in the antecedent instead would not work correctly for all reset scenarios because it would be evaluated only at clock edges.

**Q4: What is the bind construct and why is it preferred over inline assertions?**

bind instantiates a checker module inside a target module without modifying the target's source code. This separation is important because RTL source files should not be modified for verification. The checker can be added or removed without touching the design. bind also allows the checker to access internal signals not exposed as ports, enabling deeper verification. The same checker module can be bound to multiple instances.

**Q5: What is a phantom write and why is it a security concern?**

A phantom write is when a register value changes without the write-enable signal being asserted. In a normal processor, the only way to update a register is through the write-back path with we=1. If a hardware Trojan injects a value directly into the register array bypassing the write-enable gate, the formal checker's phantom-write property would catch it. This matters for logic-locked designs and trusted execution environments where register file integrity is a security guarantee.

**Q6: What does $past do and why is it useful for sequential properties?**

`$past(expr, N)` returns the value of expr N clock cycles ago. The default N is 1. It is essential for writing properties that relate the current state to a previous state. For example, to prove that the write-back value matches what was written, you need `rd1 == $past(wd)` because wd belongs to the previous cycle (the write cycle) while rd1 belongs to the current cycle (the read cycle). Without $past you can only reason about current-cycle values.

**Q7: What is the difference between a safety property and a liveness property?**

A safety property says that something bad never happens. All assert properties with |-> or |=> implication checking specific output values are safety properties. A liveness property says that something good eventually happens. Liveness requires temporal operators like `s_eventually` and is harder to prove because it requires showing that no matter what path the design takes, the good outcome is always reachable. Safety proofs terminate; liveness proofs can require infinite exploration unless bounded.

**Q8: What does JasperGold do with a cover property?**

JasperGold tries to find a finite trace that makes the cover property true. If it finds one, the property is "covered" and the tool reports a witness trace. If it proves no such trace exists, the scenario is unreachable -- either the design makes it structurally impossible, or the assume constraints are too tight. Unreachable covers are valuable: they confirm that truly impossible scenarios (like writing to x0) can never occur.

**Q9: Why do security assertions need access to internal signals and not just ports?**

Port-level assertions can only observe what the module exposes. A phantom write attack modifies internal register storage without affecting any observable port (the attacker's goal is stealth). To prove the register array is only modified through the write-enable path, you need to observe `regs[i]` directly. This is what the security assertions `p_sec_x0_internal_zero` and `p_sec_no_phantom_write_x1` do -- they observe the internal array via the bind mechanism, not the read ports.

---

## Next Week Plan

All assertion files are written. The following items remain for Week 04 completion and Week 05:

- Run JasperGold formal proof on TalTech HPC: `jg -batch formal/prove_single_cycle.tcl`
- Inspect any counterexamples and fix RTL or assertion bugs
- Run Genus synthesis: `genus -f syn/single_cycle_syn.tcl`
- Check area and timing reports
- Run Innovus place and route
- Begin Week 05: Phase 2 pipeline RTL -- instruction fetch stage
