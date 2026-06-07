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

## Part 1a: Standard Cell Libraries -- The Beginner's Guide (Vivado vs Genus)

If you have only used Vivado or Quartus before, the single biggest surprise with Genus is this: **you must supply a technology library, or the tool literally cannot run.** This section explains why, in plain terms.

### The Vivado experience you already know

In Vivado, you write RTL, click "Synthesize," and it just works. You never hand it a library file. Why? Because Vivado targets a **specific Xilinx FPGA chip you already selected** (for example, an Artix-7 xc7a35t). That chip is fixed silicon. It already physically contains:

- A fixed number of Look-Up Tables (LUTs)
- A fixed number of flip-flops
- Dedicated block RAM, DSP slices, clock managers

The "library" for an FPGA is **built into the chip and bundled inside Vivado**. When you pick the part number, Vivado already knows every primitive available, their exact timing, and their exact resources. The library is invisible because it is baked in. You are not building the silicon -- you are configuring silicon that already exists.

### Why Genus is completely different

Genus does **ASIC** synthesis, not FPGA synthesis. You are not configuring an existing chip -- you are **building a brand-new chip from scratch**. There is no pre-existing silicon. There are no LUTs. The transistors do not exist yet.

So Genus has to ask a question Vivado never asks:

> "What logic gates am I even allowed to use, and how big and how fast is each one?"

That answer comes from the **standard cell library** -- the `.lib` (Liberty) file you supply. Without it, Genus has no vocabulary. It is like asking someone to write a sentence but giving them no alphabet.

### What a standard cell library actually contains

A standard cell library is a catalog, provided by the chip foundry, describing every pre-designed logic gate available in that manufacturing process. For each cell (e.g. a 2-input AND gate, typically named something like `AND2`), the `.lib` file lists (the numbers below are illustrative -- the real values are specific to your licensed library):

| Information | Example | Why Genus needs it |
|-------------|---------|-------------------|
| Logic function | `Z = A & B` | To know what the cell does |
| Area | ~10 um^2 (illustrative) | To minimize total chip size |
| Input-to-output delay | ~80 ps (illustrative) | To meet your clock period |
| Input capacitance | ~5 fF (illustrative) | To compute loading on driving cells |
| Power per switch | tiny (illustrative) | To estimate power consumption |
| Drive strength variants | base cell + larger `...X2`, `...X4` versions | Bigger versions drive more load faster |

When Genus loads the library it reports how many cells are available, e.g.:
```
domain _default_: <N> combo usable cells and <M> sequential usable cells
```
That means the library gives Genus a few hundred combinational gates and several dozen flip-flop/latch types to build the processor from. That is its entire alphabet. (The exact cell names, counts, and per-cell numbers belong to your licensed PDK and are not reproduced here.)

### The mental model: synthesis is translation

Think of synthesis as translating your design into a new language:

- **Your RTL** = the meaning you want to express (the source language)
- **The standard cell library** = the dictionary of available words (the target language)
- **Genus** = the translator
- **The gate-level netlist** = the translated sentence

A translator with no dictionary produces nothing. That is exactly why our first attempt with a missing/wrong setup failed, and why the library path is the very first thing the script sets.

### Why the foundry, not Cadence, provides the library

This is a subtle but important point. Cadence makes the **tool** (Genus). But the **library** describes physical transistors that only exist in a specific factory's manufacturing process. Only the foundry (e.g. TSMC, GlobalFoundries, Intel, Samsung) knows:

- How fast their transistors switch
- How much area each gate occupies on their wafer
- How much current each gate leaks

So the foundry characterizes their cells and ships the `.lib` file. Cadence's tool reads it. This separation is why the same RTL can be synthesized to a 28nm chip or a 180nm chip just by swapping the library -- the RTL never changes, only the target "dictionary" does.

### FPGA vs ASIC library summary

| Aspect | FPGA (Vivado) | ASIC (Genus) |
|--------|---------------|--------------|
| Target | Existing chip you bought | New chip you are creating |
| Primitives | LUTs, BRAM, DSP (fixed) | Standard cells from a `.lib` |
| Library source | Built into Vivado | Supplied by the foundry |
| Do you pick a library? | No (pick a part number) | Yes (mandatory `.lib` path) |
| Can the tool run without it? | Yes | No -- it has no gates to map to |
| Output | Bitstream to configure the FPGA | Netlist to manufacture a chip |
| Can you change the clock target? | Within the chip's limits | Anything the process supports |

### What this means for our project

This is why our synthesis script begins by pointing Genus at the library (the real
paths live in the git-ignored `pdk_local.tcl`, never committed):
```tcl
set_db lib_search_path $PDK_LIB_SEARCH   ;# directory holding the .lib
set_db library         [list $PDK_LIBERTY]  ;# the Liberty file name
```
Those two lines hand Genus its alphabet (the 0.18um cells at the typical corner). Everything after -- `read_hdl`, `elaborate`, `syn_generic`, `syn_map` -- depends on that alphabet existing. The `syn_map` stage in particular is the moment Genus replaces your abstract logic with real cells picked from this library.

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

## Part 5: Reading Synthesis Reports -- Beginner Walkthrough

You chose the library, you ran Genus, three report files appeared. Now what?
This section teaches you to read each one, using the ACTUAL output from our
first real synthesis run of single_cycle_top. Every number below is real.

The reports live in `syn/results/`:
```
area.rpt     -- how big is the design (silicon area)
timing.rpt   -- is it fast enough (does it meet the clock)
power.rpt    -- how much energy does it use
```

### 5.1 -- The Area Report

This was our real area.rpt:
```
    Instance     Module  Cell-Count  Cell-Area  Net-Area   Total-Area     Wireload
--------------------------------------------------------------------------------------
single_cycle_top NA              59   2839.334   633.043     3472.378 <wireload> (S)
```

Read it column by column:

| Column | Our value | What it means |
|--------|-----------|---------------|
| Cell-Count | 59 | Number of standard cells (gates + flip-flops) used |
| Cell-Area | 2839.334 | Area of the logic cells, in um^2 |
| Net-Area | 633.043 | Estimated area of the wires connecting them, in um^2 |
| Total-Area | 3472.378 | Cell + Net area = total silicon footprint |
| Wireload | `<wireload>` | The model Genus used to estimate wire delay before P&R |

The `(S)` means Genus auto-selected the wireload model.

**How to sanity-check area:** ask yourself "does this number make sense for what
I designed?" A full RV32I single-cycle core with a 32-entry register file should
be LARGE -- the register file alone is 32 registers x 32 bits = 1024 flip-flops,
and one flip-flop is roughly 10-15 um^2 in this 0.18um process. So the register
file alone should be ~10000-15000 um^2.

Our total was only 3472 um^2. **That is a red flag.** It is far too small for a
full core. This number alone tells us something is missing -- which leads to the
diagnostic in Part 5.4 below.

### 5.2 -- The Timing Report

This was our real critical path (trimmed):
```
Path 1: MET (15745 ps) Setup Check with Pin pc_i_pc_reg[31]/CP->D
          Group: clk
     Startpoint: (R) pc_i_pc_reg[2]/CP
       Endpoint: (R) pc_i_pc_reg[31]/D

        Clock Edge:+   20000            0
           Arrival:=   20000            0
             Setup:-     162
     Required Time:=   19838
         Data Path:-    4093
             Slack:=   15745

  pc_i_pc_reg[2]/Q             <DFF>     308    308    (clock-to-Q of source flop)
  inc_add_126_23_g553__2398/CO <HADD>    147    455    (carry through PC+4 adder)
  inc_add_126_23_g552__5477/CO <HADD>    128    583
  ... (more half-adder stages) ...
```

Read it top-down:

| Line | Our value | Meaning |
|------|-----------|---------|
| MET / VIOLATED | MET | Did this path pass timing? MET = yes |
| Startpoint | pc_i_pc_reg[2] | The flip-flop where the path BEGINS (launch) |
| Endpoint | pc_i_pc_reg[31] | The flip-flop where the path ENDS (capture) |
| Clock Edge | 20000 ps | Our clock period (20 ns = 50 MHz from the SDC) |
| Setup | 162 ps | Time the capture flop needs data stable before the edge |
| Required Time | 19838 ps | Deadline for data to arrive (20000 - 162) |
| Data Path | 4093 ps | How long the logic ACTUALLY takes |
| **Slack** | **15745 ps** | Required - Arrival. POSITIVE = passed, with margin |

**The golden rule of timing:**
```
Slack = Required Time - Data Path Delay
Slack > 0  ->  MET     (design runs at this clock speed)
Slack < 0  ->  VIOLATED (design is too slow, must fix)
```

**Reading the path stages:** each row is one gate the signal passes through.
- `pc_i_pc_reg[2]/Q` -- the signal leaves PC bit 2 (the cell is a D flip-flop)
- `inc_add_126_..._CO` -- it ripples through the PC+4 incrementer. CO = carry out.
  The cell is a half-adder. You can literally see the carry chain rippling bit by bit.
- The path ends at `pc_i_pc_reg[31]/D` -- the D input of PC bit 31.

So this path is: **PC -> (PC + 4 adder) -> PC**. The whole 30-bit increment takes
4093 ps. With a 20000 ps clock, this could actually run at 1/4093ps = ~244 MHz.
We have enormous headroom. If we wanted, we could tighten the clock to 5 ns.

**`report timing -nworst 5`** prints the 5 slowest paths. If path 1 passes, all
others pass too (they are faster). Always look at path 1 first.

### 5.3 -- The Power Report

```
Dynamic Power:   (switching) -- power burned every time a signal toggles 0<->1
Static Power:    (leakage)   -- power burned just by being powered on
Total Power:     Dynamic + Static
```

- **Dynamic power** scales with clock frequency and how much activity there is.
  Faster clock = more toggles per second = more dynamic power.
- **Static (leakage) power** is constant -- transistors leak a tiny current even
  when idle. It scales with temperature and gets worse at smaller process nodes.

For a tiny design at 50 MHz in 0.18um, total power will be well under 1 mW.
Power matters most for battery devices and large chips; for our learning core it
is informational.

### 5.4 -- Reading the WARNINGS (this is where bugs hide)

The reports tell you what WAS built. The **synthesis log** (the text that scrolls
during the run) tells you what went WRONG. Beginners ignore warnings. Experienced
engineers read them first. Here are the ones from our real run and what they meant:

**Warning 1 -- undriven signals (the smoking gun):**
```
ELABUTL-125  Warning  256  Undriven signal detected.
```
256 signals had nothing driving them. These were the bits of `inst_memory` and
`data_memory` -- the memory arrays. This warning is the first clue that the
memories did not synthesize as normal logic.

**Warning 2 -- deleted logic:**
```
GLO-34  Deleting instances not driving any primary outputs.
```
Genus removed logic that did not connect to any output port. (This is what gave
us a completely EMPTY netlist on the very first run, before we added the debug
output ports.)

**Warning 3 -- SDC command not understood:**
```
SDC-202  Error  Could not interpret SDC command.
```
One line in our SDC file (`set_dont_touch_network`) was a Synopsys DC command
that Genus does not support. The constraint was silently skipped. Always grep the
log for `SDC-202` to catch constraints that did not apply.

**Warning 4 -- ignored simulation constructs:**
```
VLOGPT-37  Warning  Ignoring unsynthesizable construct.
   - initial block, $readmemh, etc.
```
Expected and harmless. `initial` blocks and `$readmemh` are simulation-only.
Synthesis correctly ignores them. Real silicon has no "initial" -- that is why
proper reset logic exists.

### 5.5 -- The Diagnostic Skill: "30 flops is wrong"

This is the most important habit to learn. After synthesis, do not just accept
the result -- **predict what you SHOULD see, then check.**

Our design has:
- A 32-bit PC -> 32 flip-flops
- A 32 x 32-bit register file -> 1024 flip-flops
- Expected total: ~1056 flip-flops, area in the tens of thousands of um^2

We counted the flip-flops in the netlist:
```bash
grep -c <FF_PREFIX> syn/results/single_cycle_mapped.v
```
and found about **30**. The PC is 32 bits, but `pc[1:0]` are always 00 (4-byte
aligned), so Genus optimized those 2 constant bits away -> 30 flops. That means
**only the PC survived. The entire 1024-flop register file is missing.**

Why? The chain of reasoning:
1. The memories were black-boxed (Warning 1: 256 undriven signals).
2. A black-boxed memory has undefined outputs, so `instr` got tied to 0.
3. `instr = 0` -> every decoded field (opcode, rd, rs1, rs2) = 0.
4. opcode = 0 -> control logic sets reg_write = 0, all control = 0.
5. Register file never written, always reads x0 = 0 -> folds to constant 0.
6. ALU inputs all 0 -> output 0 -> wb_data = 0.

Inspecting the actual netlist confirmed every downstream signal collapsed:
```verilog
assign dbg_wb_data[0..31] = 1'b0;   // entire writeback = ZERO
assign dbg_rd[0..4]       = 1'b0;   // destination register = ZERO
assign dbg_reg_write      = 1'b0;   // write enable = ZERO
assign dbg_instr[...]     = 1'b0;   // instruction = ZERO
```
Only `dbg_pc` and its `inc_add` (PC+4) incrementer were real logic. The PC
survived because it is a self-contained loop (pc -> +4 -> pc) that does not
depend on the memory output. The instruction memory feeds the ENTIRE rest of
the processor, so tying it to 0 deletes everything downstream.

**This is the real lesson:** the area report said "3472 um^2" and the tool
reported SUCCESS. Nothing crashed. But the design was wrong -- most of it was
silently missing. Only by predicting "I should have ~1056 flops" and checking
"I only got 30" did we catch it. A report that says PASS does not mean your
design is correct. You must read the numbers against your own expectation.

**The fix** is core/memory separation (Part 7): synthesize the core logic and
treat the memories as external SRAM macros, exactly as real chips do.

### 5.6 -- Quick commands to inspect any netlist

```bash
# Count flip-flops. Replace <FF_PREFIX> with your library's flip-flop cell
# prefix (look at any instance line in the netlist to find it).
grep -c <FF_PREFIX> syn/results/single_cycle_mapped.v

# Count total cell instances (most cells end with a drive-strength suffix
# like X1, X2, X4 -- adjust the pattern to your library if needed)
grep -cE "X[0-9]" syn/results/single_cycle_mapped.v

# See which named sub-blocks survived
grep -iE "alu|regfile|imm|add" syn/results/single_cycle_mapped.v | head

# Look for the worst timing path only
grep -A 30 "Path 1:" syn/results/timing.rpt

# Find any SDC commands that failed to apply
grep -i "SDC-202\|SDC-204\|failed" <synthesis log>
```

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

## Part 6a: Core/Memory Separation -- The Real Fix

The "30 flops" diagnosis (Part 5.5) showed that embedding memories inside the
synthesized module collapses the datapath. The professional fix is **core/memory
separation**, which is how every real processor is built.

### The principle

In a real chip, the processor CORE (control + datapath logic) and the MEMORIES
(SRAM) are physically different things:
- The core is **random logic** -- synthesized to standard cells by Genus.
- The memories are **SRAM macros** -- dense pre-built arrays from a memory
  compiler, dropped in during floorplanning, NOT synthesized as logic.

So the core should never contain the memories. Instead it exposes a memory
**interface** (address out, data in) and the memories connect through those ports.

### Two module roles in this project

| Module | Contains memories? | Used for |
|--------|-------------------|----------|
| `single_cycle_top` | Yes (inst_memory + data_memory inside) | Simulation, pyuvm, formal |
| `single_cycle_core` | No (memory ports only) | Synthesis, place-and-route |

`single_cycle_top` stays exactly as it is -- it is the verified simulation and
formal target, and the testbench preloads its instruction memory from a hex file.
`single_cycle_core` is the synthesis target: identical datapath, but the two
memories are replaced by port connections.

### The core memory interface

```systemverilog
module single_cycle_core (
  input  logic        clk,
  input  logic        rst_n,
  // Instruction memory interface
  output logic [31:0] imem_addr,    // = PC          (drive address OUT)
  input  logic [31:0] imem_rdata,   // = instruction (take data IN)
  // Data memory interface
  output logic [31:0] dmem_addr,    // = ALU result
  output logic [31:0] dmem_wdata,   // = store data
  output logic        dmem_we,      // = write enable
  output logic        dmem_re,      // = read enable
  input  logic [31:0] dmem_rdata,   // = load data
  // debug outputs ...
);
```

### Why this synthesizes fully

`imem_rdata` and `dmem_rdata` are primary **input ports**. Synthesis treats input
ports as free, externally driven signals -- they are NOT tied to 0 like a
black-boxed memory output. So:
- `instr = imem_rdata` is a real driven signal
- the decoder, register file, ALU, and immediate generator all stay alive
- nothing collapses to constant 0

The full datapath is preserved, and you get a realistic cell count and a real
critical path through the regfile-read -> ALU -> writeback logic.

### Running the core synthesis

```bash
genus -f syn/single_cycle_core_syn.tcl
cat syn/results/core_area.rpt
grep -c <FF_PREFIX> syn/results/single_cycle_core_mapped.v   # expect ~1056, not 30
```

The core synthesis script reads only the core sub-modules (alu, alu_ctrl,
regfile, pc, immgen, single_cycle_core) -- NOT inst_memory or data_memory.

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
| 0.18um standard-cell library located and configured | Done |
| First synthesis attempt (single_cycle_top) | Done -- empty/30-flop, diagnosed |
| Root cause found: memories black-boxed, datapath collapsed | Done |
| single_cycle_core.sv created (memory port interface) | Done |
| syn/single_cycle_core_syn.tcl written | Done |
| Core synthesis run on TalTech HPC | Done |
| Area report reviewed (3421 cells, 180420 um^2) | Done |
| Timing report reviewed (critical path: imem_rdata -> ALU -> wb, MET +3979 ps) | Done |
| Flip-flop count verified (1022 = 30 PC + 992 regfile) | Done |
| Gate-level netlist produced (single_cycle_core_mapped.v) | Done |
| SDF file produced (single_cycle_core.sdf) | Done |
| Results committed and pushed to GitHub | Done |
| GLS run with SDF back-annotation | Pending (Week 05) |
| Conformal equivalence check (RTL == netlist) | Pending (Week 05) |

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
