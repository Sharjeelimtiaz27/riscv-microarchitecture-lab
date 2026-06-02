# Week 04 -- Place and Route: Innovus Flow, Physical Design Concepts, and Reports

**Focus:** Taking the synthesized gate-level netlist through physical implementation using Cadence Innovus. Understanding floorplanning, power planning, placement, clock tree synthesis, routing, and output verification.

**Prerequisite:** Genus synthesis complete. `syn/results/single_cycle_mapped.v` and `syn/results/single_cycle.sdf` exist and Conformal equivalence check passed.

---

## Part 1: What Place and Route Is

After synthesis, the design exists as a gate-level netlist: a list of standard cells connected by logical wires. There is no physical location assigned to any cell. Place and Route (P&R) converts the netlist into a physical layout by:

1. Assigning each standard cell a physical location on the silicon die
2. Connecting all cells with metal wires that obey the design rules of the process technology
3. Building the clock distribution network to deliver the clock signal to every flip-flop with minimal skew

The output of P&R is:
- A final placed-and-routed netlist (Verilog .v)
- A DEF (Design Exchange Format) file describing physical geometry
- A post-route SDF file with actual wire delays (more accurate than pre-route SDF)
- A GDS file (for tape-out -- not generated in this university flow)

---

## Part 2: Required Inputs

| Input | Source | Purpose |
|-------|--------|---------|
| Gate-level netlist (.v) | Genus synthesis | What cells to place |
| LEF files (tech.lef, cells.lef) | PDK | Physical geometry of each cell |
| Liberty file (.lib) | PDK | Timing model for each cell |
| SDC file | syn/constraints/ | Same timing constraints as synthesis |

**PDK (Process Design Kit):** The collection of files describing a specific semiconductor process (e.g., TSMC 28nm, GlobalFoundries 22nm). On TalTech HPC, set the PDK path:
```bash
export PDK_DIR=/path/to/pdk
```

---

## Part 3: The Complete P&R Flow

### Step 1: Initialize Design

Load the netlist and technology files into Innovus.

```tcl
read_netlist  syn/results/single_cycle_mapped.v -top single_cycle_top
read_lef [list $env(PDK_DIR)/lef/tech.lef $env(PDK_DIR)/lef/cells.lef]
read_lib $env(PDK_DIR)/lib/typical.lib
read_sdc syn/constraints/single_cycle.sdc
init_design
```

`init_design` cross-references the netlist cells against the LEF/LIB files. Every cell instance in the netlist must have a matching entry in the LEF/LIB.

### Step 2: Floorplanning

Defines the die area, the core area (where cells can be placed), and the margins.

```tcl
floorPlan -site core \
          -r 1.0 \      # aspect ratio 1.0 = square
          -d 200.0 200.0 \   # die width and height in microns
          -e 10.0 10.0 10.0 10.0  # core margins (left right top bottom)
```

**Utilization:** The ratio of cell area to available core area. A 70% utilization target means 30% of the core area is free for routing. Higher utilization = smaller die = harder to route. Start with 60-70% for educational flows.

### Step 3: Power Planning

Creates the power distribution network (PDN) that delivers VDD and VSS to every standard cell.

```tcl
# Power ring around the core
addRing -nets {VDD VSS} -type core_rings \
        -layer {top M5 bottom M5 left M4 right M4} \
        -width 2.0 -spacing 1.0

# Power stripes across the interior
addStripe -nets {VDD VSS} -layer M5 -direction vertical \
          -width 1.0 -spacing 0.5 -set_to_set_distance 20.0

# Connect standard cell power pins to the grid
globalNetConnect VDD -type pgpin -pin VDD -inst *
globalNetConnect VSS -type pgpin -pin VSS -inst *
```

Why power planning matters: Standard cells have VDD and VSS pins at fixed locations. The PDN must deliver current to all cells without excessive IR drop (voltage drop due to wire resistance). Insufficient PDN causes cells near the center of the die to see lower VDD, which slows them down and causes timing violations.

### Step 4: Placement

Places all standard cells in legal locations within the core area.

```tcl
setPlaceMode -timingDriven true
place_design
checkPlace       # verify no overlapping cells
```

Timing-driven placement prioritizes cells on the critical path, placing them close together to minimize wire length and propagation delay.

After placement, a pre-CTS timing analysis shows whether the placed design can meet timing BEFORE the clock tree is built (pessimistic: assumes zero clock skew).

### Step 5: Pre-CTS Optimization

Fixes setup timing violations before building the clock tree.

```tcl
optDesign -preCTS
```

This is important because large setup violations at pre-CTS stage are cheaper to fix (by swapping cells or resizing) than at post-route stage.

### Step 6: Clock Tree Synthesis (CTS)

Builds the clock distribution network. The goal is to deliver the clock to every flip-flop with minimal skew (difference in clock arrival time between the earliest and latest flip-flop).

```tcl
create_clock_tree_spec -output pnr/results/clock_spec.ctstch
clockDesign -specFile pnr/results/clock_spec.ctstch
```

Without CTS, if one flip-flop receives the clock 200 ps later than another, their effective setup time window is reduced by 200 ps -- a potential timing violation.

After CTS, Innovus inserts a balanced tree of clock buffers. Check the CTS report:
- Max clock skew (target: < 50-100 ps for modern designs)
- Max clock latency
- Number of clock buffers inserted

### Step 7: Post-CTS Optimization (Hold Fix)

After CTS, the tool knows real clock skew values. This can CREATE hold violations that did not exist before CTS (a fast flip-flop can capture data intended for the next cycle).

```tcl
optDesign -postCTS -hold
```

Hold violations are fixed by inserting delay buffers on the data path.

### Step 8: Routing

Routes all signal wires on the metal layers, obeying design rules (minimum spacing, minimum width, via rules).

```tcl
routeDesign
checkRoute    # verify no DRC violations
```

Routing fills the remaining metal capacity after the PDN stripes and clock tree are placed. If utilization is too high, routing becomes congested and some wires cannot be placed -- this is called a routing overflow.

### Step 9: Post-Route Optimization

Final timing closure with actual wire delays.

```tcl
optDesign -postRoute        # setup fix
optDesign -postRoute -hold  # hold fix
```

### Step 10: Write Outputs

```tcl
write_netlist -top_module_only pnr/results/single_cycle_final.v
write_def pnr/results/single_cycle_final.def
write_sdf pnr/results/single_cycle_postroute.sdf
```

---

## Part 4: Timing Reports After P&R

Post-route timing is more accurate than post-synthesis timing because it includes actual wire delays. Run:

```tcl
report_timing -path_type full -slack_lesser_than 0 > pnr/results/timing_violations.rpt
```

If no violations: the file will be empty (all slacks are positive). If violations exist, each path shows:
- Which cell is the startpoint and endpoint
- Each stage of the path with cell delay and wire delay
- The slack value

Typical critical path for single_cycle_top:
```
regfile read → rs1_data → alu_a → ALU computation → alu_res → writeback → regfile write
```

The ALU (especially the adder and shift operations) usually dominates the critical path.

---

## Part 5: Post-Route Gate-Level Simulation

After P&R, run a final GLS with the post-route SDF to catch:
- Wire delay effects not visible in pre-route SDF
- Signal integrity issues from long wires
- Hold violations introduced by routing

```bash
xrun -sv pnr/results/single_cycle_final.v \
     tb/single_cycle_smoke_tb.sv \
     -sdf_file pnr/results/single_cycle_postroute.sdf \
     -R -access +rwc \
     -l artifacts/xrun_postroute_gls.log

grep -i "SMOKE PASS\|fail\|timing\|violation" artifacts/xrun_postroute_gls.log
```

---

## Part 6: Common P&R Issues and Fixes

### Issue: Routing congestion / routing overflow

Cause: Utilization too high or cells in one region are too dense.
Fix: Reduce target utilization (increase die area), spread cells manually, or add blockages to guide placement.

### Issue: Clock skew too large

Cause: Unbalanced clock tree, or clock tree spec not properly constraining skew.
Fix: Check `create_clock_tree_spec` parameters, add clock tree exceptions for high-fanout cells.

### Issue: Hold violations after CTS

Cause: Expected. CTS reveals real skew which can create hold violations.
Fix: `optDesign -postCTS -hold` inserts delay buffers. If violations remain, increase hold fix effort.

### Issue: PDK not found / init_design fails

Cause: PDK environment variable not set, or LEF/LIB files missing.
Fix: Verify `$env(PDK_DIR)` points to the correct PDK directory before running Innovus.

### Issue: Power pin connection error

Cause: Cell power pin name in the netlist (e.g., `VDD`) does not match the PDK's power pin name.
Fix: Update `globalNetConnect` to use the exact pin names from the PDK's LEF file.

---

## Progress Tracker (P&R)

| Task | Status |
|------|--------|
| pnr/innovus_single_cycle.tcl written | Done |
| Synthesis prerequisite complete | Pending |
| Innovus P&R run on TalTech HPC | Pending |
| Floorplan set, power ring placed | Pending |
| Placement complete, no overlaps | Pending |
| CTS complete, skew report reviewed | Pending |
| Routing complete, no DRC violations | Pending |
| Post-route timing clean (positive slack) | Pending |
| Post-route GLS passing | Pending |
| Final netlist and DEF written | Pending |

---

## Interview Questions and Answers

**Q1: What are the stages of place and route and what does each produce?**

Floorplanning defines the die area and places macros and I/O pins. Power planning creates the VDD/VSS distribution network. Placement assigns physical locations to all standard cells. Clock tree synthesis builds a balanced clock buffer tree so all flip-flops receive the clock at nearly the same time. Routing connects all signal wires between cells using the metal layers defined in the technology LEF. Post-route optimization fixes remaining timing violations. Together these stages convert a gate-level netlist into a physical layout.

**Q2: What is clock skew and why does it matter?**

Clock skew is the difference in arrival time of the clock signal between the earliest and latest flip-flop in the design. In an ideal design, all flip-flops receive the clock at exactly the same time. In reality, wire resistance and capacitance create delays. If flip-flop A receives the clock 200 ps after flip-flop B, then data launched by B may arrive at A before A's clock edge, creating a hold violation. CTS minimizes skew by building a balanced tree of clock buffers with matched wire lengths from the clock source to every flip-flop.

**Q3: What is the difference between pre-route and post-route timing?**

Pre-route timing (after placement, before routing) estimates wire delays using statistical wire-length models. Post-route timing uses actual routed wire geometries and the RC parasitics extracted from those wires, making it much more accurate. A design that meets timing pre-route may fail post-route because actual wire delays are longer than estimated. Post-route timing with the actual SDF file is the final ground truth for whether the design meets its clock frequency requirement.

**Q4: What is a hold violation and how does it differ from a setup violation?**

A setup violation means data arrives at a flip-flop TOO LATE -- the path is too slow, violating the setup time requirement before the clock edge. It is fixed by making the path faster: using larger cells, reducing wire length, or relaxing the clock period. A hold violation means data arrives TOO EARLY -- the path is so fast that it could corrupt the previous cycle's result still being captured by the destination flip-flop. It is fixed by making the path SLOWER, typically by inserting delay buffers.

**Q5: What is the power distribution network and why does it need careful planning?**

The PDN is the network of wide metal wires on upper metal layers that delivers VDD and VSS from the chip I/O pads to every standard cell's power pins. Standard cells consume current during switching. Wire resistance causes a voltage drop (IR drop) along the PDN -- cells far from the I/O pads see lower VDD. Lower VDD slows down switching, causing timing violations in cells that were otherwise meeting timing at nominal VDD. Power planning adds rings, stripes, and horizontal/vertical mesh to reduce the effective resistance and keep IR drop below 5-10% of VDD across the entire die.

**Q6: Why is post-route GLS important even after pre-route GLS passed?**

Pre-route GLS uses an SDF generated from synthesis with estimated wire delays. Post-route GLS uses an SDF extracted from the actual routed wires, which are longer and more capacitively loaded. Routing can introduce wire delays that were not present in the synthesis estimate, particularly on high-fanout nets that must be routed over long distances. Post-route GLS is the final confirmation that the physical implementation matches the behavioral RTL under real timing conditions. For security-critical designs, post-route GLS with the real SDF is mandatory before sign-off.
