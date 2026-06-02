# Week 04 -- Logic Synthesis: Genus Flow, SDC Constraints, and Reports

**Focus:** Converting RTL to a gate-level netlist using Cadence Genus. Understanding synthesis steps, timing constraints, and reading area/timing reports.

**Prerequisite:** JasperGold formal run complete, all assertions proven.

---

## Part 1: What Logic Synthesis Is and Why It Matters

Logic synthesis is the step that converts RTL (SystemVerilog behavioral descriptions) into a technology-specific gate-level netlist. The netlist contains actual standard cells from a cell library: AND gates, flip-flops, MUX cells, buffer cells -- real silicon primitives with known area, power, and timing characteristics.

Before synthesis, your design exists as abstract RTL. After synthesis, you have:
- A gate-level netlist (Verilog .v) that can be simulated, formally verified, and placed
- An SDF (Standard Delay Format) file with propagation delays for each gate
- Area, timing, and power reports

Synthesis outputs feed directly into:
- **Gate Level Simulation (GLS):** simulate the netlist with real timing
- **Conformal equivalence checking:** prove RTL == netlist, no logic was changed
- **JasperGold on netlist:** prove formal properties hold on actual gates
- **Innovus place and route:** take the netlist to physical layout

---

## Part 2: The Three-Stage Synthesis Flow

Genus synthesis has three mandatory stages, each with a specific purpose.

### Stage 1: syn_generic -- Technology-Independent Optimization

The RTL is compiled into a generic Boolean network (using AND/OR/NOT primitives) without mapping to any real cell library. The optimizer reduces logic at the Boolean level: removes redundant gates, applies constant propagation, and simplifies multiplexers.

This stage produces the best possible logic WITHOUT knowing which cells are available. It sets the ceiling for what syn_map can achieve.

### Stage 2: syn_map -- Technology Mapping

Maps the generic Boolean network to actual standard cells from the technology library (.lib file). Each cell has area, drive strength, and timing data. The mapper selects cells that meet the timing constraints from the SDC file while minimizing area.

This is where the clock period constraint matters: if you specify 10 ns, the mapper will use faster (larger area) cells on the critical path and smaller (slower) cells on non-critical paths.

### Stage 3: syn_opt -- Post-Map Optimization

Fine-tunes the mapped netlist: inserts buffers to fix fanout violations, sizes cells up or down, reworks critical paths. This is where the last few nanoseconds of timing margin are recovered.

---

## Part 3: SDC Timing Constraints Explained

SDC (Synopsys Design Constraints) is the standard format for telling the synthesis tool what timing the design must meet.

### Clock definition

```tcl
create_clock -name clk -period 10.0 -waveform {0.0 5.0} [get_ports clk]
```

- `-period 10.0`: clock period in nanoseconds (100 MHz)
- `-waveform {0.0 5.0}`: rising edge at 0 ns, falling edge at 5 ns (50% duty cycle)
- `[get_ports clk]`: this clock is defined on the top-level port named `clk`

### Input and output delay

```tcl
set_input_delay  2.0 -clock clk [all_inputs]
set_output_delay 2.0 -clock clk [all_outputs]
```

- `input_delay 2.0`: inputs arrive 2 ns after the clock edge. The synthesis tool must ensure internal logic from this input completes within `period - input_delay - setup_time = 10 - 2 - setup = ~7.5 ns`.
- `output_delay 2.0`: outputs must be stable 2 ns before the NEXT clock edge.

### False path on reset

```tcl
set_false_path -from [get_ports rst_n]
```

Reset is asynchronous. There is no point enforcing setup/hold timing on an asynchronous signal. The false path directive tells Genus not to analyze timing from `rst_n` to any flip-flop reset pin.

### What happens if you have no SDC?

Genus will synthesize with NO timing pressure. It picks the smallest cells, producing maximum area efficiency but no guarantee of timing. Always run with SDC.

---

## Part 4: The Genus TCL Script Walkthrough

File: `syn/single_cycle_syn.tcl`

```tcl
# Allow large loop unrolling (needed for register file reset loop)
set_db / .hdl_max_loop_limit 8192

# Load all RTL -- assertion files are NOT included (not synthesizable)
read_hdl -sv12 { rtl/common/*.sv rtl/single_cycle/*.sv }

# Elaborate: resolve hierarchy, parameters, generate internal representation
elaborate single_cycle_top

# Apply timing constraints
read_sdc syn/constraints/single_cycle.sdc

# Three-stage synthesis
syn_generic    # technology-independent Boolean optimization
syn_map        # map to standard cells
syn_opt        # post-map timing cleanup

# Write outputs
write_hdl -mapped > syn/results/single_cycle_mapped.v  # gate-level netlist
write_sdf syn/results/single_cycle.sdf                  # delay file for GLS

# Reports
report_area   > syn/results/area.rpt
report_timing > syn/results/timing.rpt
report_power  > syn/results/power.rpt
```

### What NOT to include in synthesis

- Assertion files (alu_assertions.sv, regfile_assertions.sv, etc.) -- not synthesizable
- Testbench files
- Files with `initial` blocks only (those are simulation constructs)

---

## Part 5: Reading Synthesis Reports

### Area Report (area.rpt)

The area report shows how much silicon area the design uses, measured in standard cell equivalents or square microns depending on the PDK.

Key fields:
```
Total Cell Area:     1234.56 um^2    -- total area of all standard cells
Combinational Area:   890.12 um^2    -- area of logic (AND, OR, MUX gates)
Sequential Area:      344.44 um^2    -- area of flip-flops and latches
Net Area:             (wire area -- available in some flows)
```

What to look for:
- Is the sequential area dominated by the register file? (32 x 32-bit = 1024 flip-flops -- expect it to be large)
- Is the combinational area dominated by the ALU? (32-bit adder and shifter are large)
- Are there unexpectedly large sections? (could indicate unintended logic replication)

### Timing Report (timing.rpt)

Shows the critical path: the longest combinational path through the design that determines the maximum clock frequency.

```
Startpoint: single_cycle_top/rf/regs_reg[5][0]   (flip-flop clocked by clk)
Endpoint:   single_cycle_top/rf/regs_reg[7][31]   (flip-flop clocked by clk)

Path Group: clk
Path Type:  max

Point                           Incr     Path
-----------------------------------------------
clock clk (rise edge)           0.00     0.00
...
rf/regs_reg[5][0]/CK            0.00     0.50    # clock to Q delay
alu_i/result[31]                1.23     1.73    # ALU propagation
rf/rd_data1[31]                 0.45     2.18    # register file read
...
Data Arrival Time                         7.82
-----------------------------------------------
clock clk (rise edge)          10.00    10.00
clock uncertainty              -0.10     9.90
library setup time             -0.15     9.75
Data Required Time                        9.75
-----------------------------------------------
Slack (MET)                               1.93   # POSITIVE = timing met
```

- **Slack > 0:** Timing MET. The design meets the 10 ns constraint.
- **Slack < 0:** Timing VIOLATED. The critical path is longer than the clock period.
- The critical path for single_cycle_top will run through: register file read → ALU computation → writeback → register file write. The ALU is typically the bottleneck.

### Power Report (power.rpt)

```
Dynamic Power:   0.45 mW   -- switching activity power
Static Power:    0.12 mW   -- leakage power when not switching
Total Power:     0.57 mW
```

Dynamic power scales with clock frequency and switching activity. Static power scales with temperature and process node.

---

## Part 6: Common Synthesis Issues and Fixes

### Issue: `initial` block warning -- ignored

```
[WARN (VERI-1060)] regfile.sv(56): 'initial' construct is ignored
```

Expected. Synthesis ignores simulation-only constructs. The register file's `initial` block zeros the simulation state but has no effect on the synthesized netlist (real flip-flops start in an unknown state after power-on, which is why proper reset logic is essential).

### Issue: Large array black-boxed

```
[WARN (VERI-9033)] array mem (size 8192) automatically BLACK-BOXED
```

Same warning as in JasperGold. In synthesis, black-boxing means the memory is treated as an external block (black box). For simulation this is fine, but it means the memory cells are NOT counted in the area report. Use `-bbox_a 8192` or let Genus infer a RAM macro from the RTL.

### Issue: Timing not met (negative slack)

Causes and fixes:
- Long combinational path through ALU → break with pipeline register (Phase 2 work)
- High fanout net (one signal driving many gates) → Genus auto-inserts buffers with syn_opt
- Tight constraint for the process node → relax clock period in SDC

### Issue: Genus cannot find the technology library

Error: `Cannot find lib file` or `No cells available for mapping`.

Fix: Set the PDK environment variable before running Genus:
```bash
export PDK_LIB=/path/to/technology_library.lib
genus -f syn/single_cycle_syn.tcl
```

On TalTech HPC, the PDK path depends on which library is available. Check with your lab administrator.

---

## Part 7: What Happens After Synthesis

### Gate-Level Simulation (GLS)

Run the same pyuvm testbench (or xrun smoke test) against the synthesized netlist with SDF back-annotation:
```bash
xrun -sv syn/results/single_cycle_mapped.v \
     tb/single_cycle_smoke_tb.sv \
     -sdf_file syn/results/single_cycle.sdf \
     -R -access +rwc \
     -l artifacts/xrun_gls.log
```

What to check: do the simulation results match RTL simulation? Any X-propagation or SDF timing violations?

### Conformal Equivalence Checking

Proves RTL == synthesized netlist with mathematical certainty.
```bash
lec -xl -nogui -dofile formal/conformal_check.do
```

If Conformal PASSES: the netlist is provably equivalent to the RTL. All formal properties proven on RTL also hold on the netlist by transitivity.

If Conformal FAILS: synthesis introduced a functional mismatch. This is rare but critical to catch before P&R.

---

## Progress Tracker (Synthesis)

| Task | Status |
|------|--------|
| syn/single_cycle_syn.tcl written | Done |
| syn/constraints/single_cycle.sdc written | Done |
| Genus synthesis run on TalTech HPC | Pending |
| Area report reviewed | Pending |
| Timing report reviewed -- critical path identified | Pending |
| Gate-level netlist produced (single_cycle_mapped.v) | Pending |
| SDF file produced (single_cycle.sdf) | Pending |
| GLS run with SDF back-annotation | Pending |
| Conformal equivalence check (RTL == netlist) | Pending |

---

## Interview Questions and Answers

**Q1: What are the three stages of Genus synthesis and what does each do?**

syn_generic performs technology-independent Boolean optimization on the compiled RTL, reducing the logic to a minimal AND/OR/NOT representation without targeting any specific cell library. syn_map takes the generic network and maps it to real standard cells from the technology library, selecting cells that meet the timing constraints specified in the SDC file. syn_opt performs post-mapping optimization: inserting buffers for fanout violations, resizing cells on the critical path, and recovering remaining timing slack.

**Q2: What is an SDC file and what are the three most important constraints?**

SDC (Synopsys Design Constraints) is the industry standard format for timing constraints. The three essential constraints are: `create_clock` which defines the clock period and waveform; `set_input_delay` which tells the tool how late after the clock edge inputs can arrive; and `set_output_delay` which tells the tool how early before the next clock edge outputs must be stable. A fourth important constraint is `set_false_path` which removes timing analysis from asynchronous paths like reset.

**Q3: What does positive slack in a timing report mean?**

Positive slack means timing is met. Slack is the difference between the data required time and the data arrival time. Required time is derived from the clock period minus setup time. Arrival time is the actual propagation delay through the critical path from the source flip-flop to the destination flip-flop. Positive slack = required time > arrival time = the design can run at the target clock frequency. Negative slack = timing violation = must optimize the critical path or reduce the clock frequency.

**Q4: Why does synthesis ignore the initial block in regfile.sv?**

`initial` blocks are simulation constructs. They execute once at time 0 in a simulator to initialize state. Real silicon flip-flops have no mechanism to execute arbitrary initialization code at power-on. The synthesized register file flip-flops will start in an unknown state after power-on, which is why the RTL has a proper synchronous reset path (`always_ff @(posedge clk or negedge rst_n) if (!rst_n) ...`). The reset path IS synthesized and will properly initialize all registers when rst_n is driven low.

**Q5: What is gate-level simulation and why do you run it after synthesis?**

Gate-level simulation runs the existing testbench against the synthesized netlist instead of the RTL, with real gate propagation delays back-annotated from the SDF file. This catches two things that RTL simulation cannot: timing violations where a signal arrives at a flip-flop later than its setup time (which could cause metastability), and functional bugs introduced by synthesis optimizations that Conformal equivalence checking might miss in corner cases. For security-critical designs, GLS is essential because synthesis can restructure logic in ways that change observable power/timing behavior even when the functional behavior is equivalent.

**Q6: What is Conformal equivalence checking and why is it run after synthesis?**

Conformal (Cadence Conformal Logic Equivalence Checker) formally proves that two representations of a design are logically equivalent for all possible inputs. After synthesis, Conformal compares the RTL (golden) against the gate-level netlist (revised). If it passes, the netlist is proven to be a correct implementation of the RTL. This matters because synthesis optimizations could theoretically introduce functional differences. If Conformal passes, all formal properties proven on the RTL are also valid on the netlist by transitivity.
