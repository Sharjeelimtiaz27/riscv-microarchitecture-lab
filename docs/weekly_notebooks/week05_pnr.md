# Week 05 — Place & Route: From a Synthesized Netlist to a Routed Chip (Cadence Innovus)

**Focus:** Taking the gate-level netlist from synthesis all the way to a physically placed, clock-tree-built, and routed layout using Cadence Innovus — done **live, step by step, in the GUI**, with every error explained.

**What you will have at the end:** a complete physical implementation of the `single_cycle_core` RV32I processor — cells placed on silicon, a balanced clock tree, all 5500+ nets routed, timing closed, and the design saved to disk.

> This is a beginner's field guide. It is written so that someone who has never opened Innovus can, with this document and an AI assistant, reproduce the full flow and reach a routed chip. It deliberately includes the **mistakes and errors we hit**, because debugging them is where the real learning is.

> **Confidentiality note (read this first):** The standard-cell library, LEF, Liberty, and process kit (PDK) are under a commercial/NDA license. **None of their file names, paths, cell names, layer names, or characterized numbers appear in this repository.** All such values live in a single git-ignored file, `pdk_local.tcl`. Throughout this guide we refer to them only through generic variables like `$PDK_TIMING_LIB`, `$PDK_SITE`, `$PDK_HMETAL`. When you share screenshots publicly (LinkedIn, papers), **share the layout canvas only, never the terminal** — the terminal prints the licensed paths/names.

---

## Part 0 — The Big Picture: Where P&R Sits

```
RTL (SystemVerilog)
   │  Genus synthesis  (Week 04)
   ▼
Gate-level netlist (.v) + SDC constraints
   │  Innovus place & route  (Week 05 — this guide)
   ▼
Placed + clock-treed + routed layout
   │  outputs:
   ├─ final netlist (.v)         → for gate-level simulation
   ├─ DEF (.def)                 → physical geometry
   ├─ post-route SDF (.sdf)      → real wire delays, for GLS
   └─ saved design (.enc.dat)    → restorable database
```

Synthesis answered *"which gates?"*. Place & route answers *"where does each gate sit on the silicon, and how are they wired together?"*

P&R converts the netlist into a physical layout by:
1. **Placing** each standard cell at a legal location in rows on the die.
2. Building a **clock tree** so every flip-flop receives the clock at nearly the same time.
3. **Routing** metal wires between all cells, obeying the manufacturing design rules.
4. **Closing timing** using the real, extracted wire delays.

---

## Part 1 — The Inputs P&R Needs (and Why)

P&R cannot start from RTL. It needs a synthesized netlist plus a description of the target technology. Here is every input, what it is, and why it is required.

| Input | What it is | Why P&R needs it |
|-------|-----------|------------------|
| **Gate-level netlist** (`.v`) | The list of standard cells and how they connect, produced by synthesis | This is *what* to place and wire |
| **Technology LEF** | Defines the metal routing layers, their preferred direction, and via rules | So the router knows what layers/wires are legal |
| **Standard-cell LEF** | The physical shape, size, and pin locations of every cell | So the placer knows how big each cell is and where its pins are |
| **Liberty timing library** (`.lib`) | Per-cell delay/slew/power model | So Innovus can analyze timing and optimize |
| **SDC constraints** | Clock period, input/output delays, false paths | Defines the timing target the design must meet |
| **Placement SITE** | The unit grid cells snap onto (named in the cell LEF) | Floorplanning aligns rows to this grid |

**The crucial split for this design:** we place the **core** (`single_cycle_core`), *not* the full `single_cycle_top`. The top embeds instruction/data memories, and **memories are not standard cells** — they are large pre-made macros (or, in this academic kit, external SRAM). Innovus cannot place a memory as a logic cell. So Week 04 synthesized a logic-only core with the memories pulled out to ports, and that core (`single_cycle_core_mapped.v`) is what we place here.

> **War story #1 — wrong netlist.** The original script pointed at `single_cycle_mapped.v` / `single_cycle_top`. That netlist still has memories baked in and would choke `init_design`. Fix: target `single_cycle_core_mapped.v` / `single_cycle_core`.

### The confidential-PDK pattern (`pdk_local.tcl`)

Because the PDK paths/names are licensed, **they are never committed**. Instead:

- `pdk_local.tcl` (git-ignored) holds the real values, only on the HPC:
  ```tcl
  set PDK_LIB_SEARCH   <dir of your .lib>
  set PDK_LIBERTY      <your_cell_library.lib>
  set PDK_TIMING_LIB   <full path to your .lib>
  set PDK_TECH_LEF     <full path to your technology LEF>
  set PDK_CELL_LEF     <full path to your standard-cell LEF>
  set PDK_SITE         <placement site name>
  set PDK_PWR_PIN      <cell power pin name>
  set PDK_GND_PIN      <cell ground pin name>
  set PDK_HMETAL       <a horizontal-preferred top metal>
  set PDK_VMETAL       <a vertical-preferred top metal>
  ```
- `pdk_local.tcl.template` (committed) shows the *shape* of this file with generic placeholders, so a new student knows what to fill in.
- The synthesis and P&R scripts `source pdk_local.tcl` and use only the `$PDK_*` variables.

**How to discover these values for your own kit** (these are the exact moves we used):
```bash
# Find LEF files in your PDK tree
find <pdk_root> -name "*.lef"
# In the technology LEF, list routing layers and their preferred direction:
grep -iE "LAYER |TYPE |DIRECTION " <tech.lef>
# In the cell LEF, find the placement SITE name:
grep -i site <tech.lef> <cell.lef>
# In the cell LEF, find the power/ground pin names:
grep -iB2 "USE POWER"  <cell.lef> | grep -i pin | sort -u
grep -iB2 "USE GROUND" <cell.lef> | grep -i pin | sort -u
```

---

## Part 2 — The Outputs P&R Produces (and How to Read Them)

| Output | File | What it is / how to read it |
|--------|------|------------------------------|
| Final netlist | `single_cycle_final.v` | The post-route netlist (now includes clock-tree buffers). Used for the final gate-level simulation (GLS). |
| DEF | `single_cycle_final.def` | Physical geometry: cell positions, wire routes. Can be viewed or handed to later tools. |
| Post-route SDF | `single_cycle_postroute.sdf` | Real per-net wire delays extracted after routing. Back-annotated in GLS for accurate timing simulation. |
| Area report | `area.rpt` | Total cell area and instance count. Sanity-check it against your expectation. |
| Timing report | `timing_postroute.rpt` | Worst paths and their **slack**. Positive slack = timing met. |
| Saved design | `single_cycle_routed.enc` + `.enc.dat/` | A self-contained, restorable database. Reload with `restoreDesign` instead of redoing the whole flow. |

**Reading a timing line:** `slack = required_time − arrival_time`. Required time comes from the clock period minus setup. Arrival time is the actual delay through the logic. **Positive slack = the design runs at the target clock. Negative slack = it is too slow and must be fixed.** We finished with a comfortably positive worst slack (TNS = 0, i.e. zero total violation).

---

## Part 3 — GUI vs Batch, and Getting the GUI to Actually Appear

Innovus can run two ways:

- **Batch:** `innovus -batch -files pnr/innovus_single_cycle.tcl` — runs the whole script, no window. Fast, reproducible, good once the flow is proven.
- **GUI (interactive):** `innovus` opens a window with a layout canvas; you type commands in the **console** and *watch* each step. Best for learning and debugging.

**Where do you type?** When you launch `innovus` from a terminal, **that terminal is the Tcl console** (the `innovus N>` prompt). The big GUI window is just the picture — it redraws as you run commands in the terminal. You do **not** type into the black canvas.

> **War story #2 — "no window mode".** Launching `innovus` over a plain SSH session printed:
> `**WARN: (IMPSYT-1507): The display is invalid and will start in no window mode`
> The GUI needs a real graphical display. SSH alone has none. The fix: connect with a remote desktop (VNC), open a terminal **inside** that desktop (so `echo $DISPLAY` shows e.g. `:5`), and launch `innovus` from there. If VNC sessions pile up, list them with `vncserver -list`, kill stale ones with `vncserver -kill :N`, and start a fresh one.

> **Shell gotcha (tcsh):** the HPC shell is tcsh, not bash. Things that bit us: here-docs (`<< EOF`) are finicky; a `!` inside a value (some cell power/ground pin names end in `!`) triggers history expansion; and lines beginning with `#` are *not* comments interactively. Easiest fix for multi-line files: use `nano` and paste, rather than shell here-docs.

---

## Part 4 — The MMMC Concept (Timing Setup) — and the Rule That Tripped Us

Innovus needs timing context. It is supplied through **MMMC** (Multi-Mode Multi-Corner), which bundles:

- **library_set** — which timing `.lib` (the per-cell stopwatch),
- **rc_corner** — the wire-parasitic conditions,
- **delay_corner** — library_set + rc_corner = one PVT corner,
- **constraint_mode** — the SDC (clock, I/O delays),
- **analysis_view** — one constraint_mode tied to one delay_corner,
- and finally `set_analysis_view`, which activates it.

We put all of this in a small file, **`pnr/mmmc.tcl`**:
```tcl
source pdk_local.tcl
create_library_set   -name ls_typ -timing [list $PDK_TIMING_LIB]
create_rc_corner     -name rc_typ -T 25
create_delay_corner  -name dc_typ -library_set ls_typ -rc_corner rc_typ
create_constraint_mode -name cm_func -sdc_files [list syn/constraints/single_cycle.sdc]
create_analysis_view -name av_typ -constraint_mode cm_func -delay_corner dc_typ
set_analysis_view    -setup {av_typ} -hold {av_typ}
```

> **War story #3 — `set_analysis_view` is not allowed loose.** Typing the MMMC commands directly in the console failed:
> `**ERROR (TCLCMD-1230): set_analysis_view is called before the design is initialized and not from init_design.`
> Innovus only allows `set_analysis_view` to run **from inside `init_design`** (via the MMMC file). So the timing setup must live in `pnr/mmmc.tcl`, which `init_design` reads.

> **War story #4 — physical-only mode.** Before we understood the above, we tried `read_physical` + `read_netlist` + a loose `set_analysis_view`. Because no timing view was active when the netlist loaded, Innovus initialized in *physical-only* mode and then refused timing commands. The clean fix is the **atomic `init_design`** flow below, where LEF + netlist + MMMC are loaded together.

---

## Part 5 — The Step-by-Step Flow (What We Actually Ran)

Everything below is run from the repo root, in the Innovus console. Each block: the command, what it does, and what to look for. `$PDK_*` values come from `pdk_local.tcl`.

### Step 1 — Initialize the design (atomic load)

```tcl
source pdk_local.tcl
set init_mmmc_file pnr/mmmc.tcl
set init_lef_file  [list $PDK_TECH_LEF $PDK_CELL_LEF]
set init_verilog   syn/results/single_cycle_core_mapped.v
set init_top_cell  single_cycle_core
set_db init_power_nets  {VDD}
set_db init_ground_nets {VSS}
init_design
```
**Does:** loads LEF (physical), the netlist (logical), and `pnr/mmmc.tcl` (timing) in one shot, then builds the in-memory database. Because `set_analysis_view` runs from inside this, timing mode is active.
**Watch for:** `0 error(s)`; it lists usable buffers/inverters/delay cells (proof timing libs loaded); the cell count appears (`stdCell insts`). Many `**WARN` lines about antenna/cap-table/sheet-resistance are normal for an academic kit with no parasitic-extraction data — timing becomes approximate, which is fine for learning.

### Step 2 — Floorplan

```tcl
floorPlan -site $PDK_SITE -r 1.0 0.60 10 10 10 10
```
**Does:** creates the die/core. `-r 1.0` = square; `0.60` = target 60% cell density (40% left for wiring); `10 10 10 10` = core-to-die margins (µm). Innovus auto-sizes the die and lays down placement **rows**.
**See:** a rectangle with thin horizontal lines (rows). Press `f` to fit the view. Cells are not placed yet.

### Step 3 — Power planning (PDN)

```tcl
globalNetConnect VDD -type pgpin -pin $PDK_PWR_PIN -inst * -override
globalNetConnect VSS -type pgpin -pin $PDK_GND_PIN -inst * -override
addRing  -nets {VDD VSS} -type core_rings \
         -layer [list top $PDK_HMETAL bottom $PDK_HMETAL left $PDK_VMETAL right $PDK_VMETAL] \
         -width 2.0 -spacing 1.0 -offset 1.0
addStripe -nets {VDD VSS} -layer $PDK_VMETAL -direction vertical \
          -width 1.0 -spacing 0.5 -set_to_set_distance 20.0
sroute -connect {corePin} -nets {VDD VSS}
```
**Does:** declares which cell pins are VDD/VSS, draws a power **ring** on the thick top metals (horizontal layer top/bottom, vertical layer left/right — matching each layer's preferred direction), drops vertical power **stripes** across the interior, and `sroute` wires the standard-cell power **rails** (one pair per row) up to the grid.
**See:** the core fills with blue M1 power rails (one per row). The ring/stripes are on the top metals; they may be visually hidden under the dense rails until you toggle layers in the right-hand color panel.
**Why before placement:** the power grid is the skeleton; cells are placed around it and tap the nearest rail.

### Step 4 — Placement

```tcl
setPlaceMode -timingDriven true
place_design
checkPlace
```
**Does:** places every standard cell into legal row positions, prioritizing the critical path (timing-driven). `checkPlace` verifies legality.
**Watch for:** `place_design` taking real seconds; `checkPlace` reporting `Placed = <all cells>, Unplaced = 0`. The canvas fills with thousands of tiny cells (often overlaid with an early-global-route congestion map — green/yellow/red — which is just a routability check).

> **War story #5 — the scan-chain wall (the big one).** Placement aborted instantly with:
> `**ERROR (IMPSP-9099): Scan chains exist in this design but are not defined for 50.10% flops.`
> **Why:** Genus, by default, maps flip-flops to **scan flops** — flops with extra `SE/SI/SO` pins used for *manufacturing test* (DFT): after fabrication you chain all flops into one giant shift register to test the chip. Our netlist had these scan-capable flops, but we never *defined the scan chain*. Innovus sees "scan flops, no chain" and refuses to place, because guessing the order could ruin a real chip's testability.
> **What did NOT work:** `setPlaceMode -place_global_ignore_scan true` (that only controls scan *reordering*, not this check).
> **The fix (at synthesis):** re-synthesize telling Genus not to use scan flops —
> ```tcl
> set_db use_scan_seqs_for_non_dft false
> ```
> in `syn/single_cycle_core_syn.tcl`, then re-run `genus -f ...`. This yields plain functional flops (slightly larger, totally fine for us). After reloading, the error became a harmless `IMPSP-9025: No scan chain specified/traced` and **placement went through** (cell count rose from 3421 → 4414, exactly as expected from swapping scan flops for plain flops).

### Step 5 — Pre-CTS optimization

```tcl
optDesign -preCTS
```
**Does:** fixes setup-timing slow paths **now**, while the clock is still assumed ideal (cheaper here than after routing). (On a PODv2 database this runs as `place_opt_design`.)

### Step 6 — Clock Tree Synthesis (CTS)

```tcl
clock_opt_design
```
**Does:** builds a **balanced tree of clock buffers** so every flop receives `clk` at nearly the same time (minimal **skew**), and runs post-CTS optimization (setup + hold) concurrently.
**Watch for:** a skew/insertion-latency summary and the timing metric line (we got TNS = 0.000 ns, worst slack positive). Some `IMPCCOPT` errors at this stage are pre-route clock-net complaints (no routing exists yet) and are resolved by routing.

> **War story #6 — PODv2 command names.** The older `create_clock_tree_spec` was "invalid command name", and `ccopt_design` failed with:
> `**ERROR (IMPCCOPT-2440): The input db is PODv2. Please try clock_opt_design.`
> The tool literally told us the fix: on the newer **PODv2** database, the clock step is `clock_opt_design`.

### Step 7 — Routing

```tcl
routeDesign
checkRoute
```
**Does:** the **NanoRoute** engine draws every signal wire on the lower metals (the top metals stay reserved for power), obeying all design rules. `checkRoute` verifies connectivity.
**Watch for:** `routeDesign` ending with `0 error(s)`; `checkRoute` printing *"All <N> nets <M> terms ... are properly connected"*. We routed 5578 nets / 20193 terminals cleanly.

> **War story #7 — router name.** `route_design` (underscore) is **not** a command here; the router is the camelCase `routeDesign`. (Innovus is inconsistent: `clock_opt_design` has an underscore, `routeDesign` is camelCase.)

### Step 8 — Post-route optimization

```tcl
optDesign -postRoute
optDesign -postRoute -hold
```
**Does:** final timing closure using the **real routed-wire delays**. The `-hold` pass is important: routing can introduce **hold** violations (data arriving too early), fixed by inserting delay buffers.

### Step 9 — Reports

```tcl
report_area > pnr/results/area.rpt
report_timing -nworst 10 > pnr/results/timing_postroute.rpt
report_timing -nworst 1
```
**Does:** writes the final area and timing reports, and prints the worst post-route slack to the console (your sign-off number).

### Step 10 — Write outputs + save the design

```tcl
saveNetlist pnr/results/single_cycle_final.v
defOut -routing pnr/results/single_cycle_final.def
write_sdf  pnr/results/single_cycle_postroute.sdf
saveDesign pnr/results/single_cycle_routed.enc
```
**Does:** writes the final netlist, the DEF (with routing), the post-route SDF, and a full restorable database.
**Reload later without redoing the flow:**
```tcl
restoreDesign pnr/results/single_cycle_routed.enc.dat single_cycle_core
```

> **War story #8 — output command options.** `write_netlist -top_module_only` and `write_def` (with options) and `report_timing -slack_lesser_than 0` were rejected on this version, so no files appeared. The robust legacy writers `saveNetlist` / `defOut` work, and `saveDesign` always produces a self-contained `.enc.dat` — so even if a single writer misbehaves, your work is preserved in the saved design.

> **Never press Ctrl-C in the Innovus console** — one extra Ctrl-C exits Innovus, and the design lives only in memory until you `saveDesign`. Save early.

---

## Part 6 — The Whole Flow as One Script

Once proven interactively, the entire flow lives in `pnr/innovus_single_cycle.tcl` and can be run in one shot:
```bash
innovus -batch -files pnr/innovus_single_cycle.tcl   # batch
# or, in the GUI console:
source pnr/innovus_single_cycle.tcl
```
It sources `pdk_local.tcl`, reads `pnr/mmmc.tcl`, and runs Steps 1–10 above.

---

## Part 7 — Common P&R Issues and Fixes (Quick Table)

| Symptom | Cause | Fix |
|---------|-------|-----|
| `IMPSYT-1507 ... no window mode` | No graphical display on the launching terminal | Launch from a VNC desktop terminal where `echo $DISPLAY` is non-empty |
| `TCLCMD-1230 ... set_analysis_view ... not from init_design` | MMMC set up loosely in the console | Put MMMC in `pnr/mmmc.tcl`, load via `init_mmmc_file` + `init_design` |
| Initialized in physical-only mode | Netlist loaded before any timing view | Use the atomic `init_design` flow (LEF + netlist + MMMC together) |
| `IMPSP-9099 ... scan chains ... not defined` | Genus used scan flops, no scan chain | Re-synthesize with `set_db use_scan_seqs_for_non_dft false` |
| `IMPCCOPT-2440 ... try clock_opt_design` | PODv2 database, old CTS command | Use `clock_opt_design` |
| `route_design ... invalid command` | Wrong router name | Use `routeDesign` |
| Output file not written | Common-UI writer option rejected | Use `saveNetlist` / `defOut`; always `saveDesign` |
| Routing congestion / overflow | Utilization too high | Lower the floorplan utilization (e.g. 0.50–0.60) |
| Hold violations after CTS/route | Real skew/wire delay revealed | `optDesign -postRoute -hold` inserts delay buffers |

---

## Part 8 — Interview Questions and Answers

**Q1: What are the stages of place and route, and what does each produce?**
Floorplanning defines the die/core and rows. Power planning builds the VDD/VSS distribution network (rings, stripes, rails). Placement assigns every standard cell a legal location. Clock tree synthesis builds a balanced clock-buffer tree to minimize skew. Routing connects all signal nets on the metal layers. Post-route optimization closes timing with real wire delays. Together they turn a gate-level netlist into a physical layout.

**Q2: Why must memories be handled separately from the logic core in P&R?**
Standard-cell P&R places small logic cells from the cell library. A memory is not a standard cell — it is a large pre-made macro (or external SRAM) with its own layout. So you synthesize and place the logic *core* with memory ports, and treat memories as external/macro blocks. Placing a netlist with embedded memory arrays as if they were logic cells will fail.

**Q3: What is a scan flop, and why did it block placement?**
A scan flop is a flip-flop with extra pins (`SE/SI/SO`) that let all flops be chained into one shift register for manufacturing test (DFT). If the netlist contains scan flops but no scan chain is defined, the placer refuses, because placing them without a defined order can ruin testability. For a non-DFT learning flow, disable scan flop usage at synthesis (`use_scan_seqs_for_non_dft false`).

**Q4: What is clock skew and why does CTS exist?**
Skew is the difference in clock arrival time between the earliest and latest flop. Wire RC makes the clock arrive at different times. If one flop's clock is late, data launched from another can arrive too early and corrupt it (a hold violation). CTS builds a balanced buffer tree with matched path lengths so all flops see the clock nearly simultaneously.

**Q5: Setup vs hold violation?**
Setup = data arrives **too late** (path too slow); fix by making the path faster or relaxing the clock. Hold = data arrives **too early** (path too fast) and corrupts the previous value being captured; fix by making the path slower (insert delay buffers). Routing tends to reveal hold issues, which is why a post-route hold pass matters.

**Q6: Pre-route vs post-route timing — why both?**
Pre-route timing estimates wire delays from statistical models. Post-route timing uses the actual routed geometry and extracted parasitics, so it is the real ground truth for whether the design meets its clock. A design can pass pre-route and fail post-route if real wires are longer than estimated.

**Q7: Why is the power grid built before placement?**
The PDN (rings/stripes/rails) is the skeleton that delivers current to every cell. Building it first lets the placer position cells around the grid and tap the nearest rail, and reserves the top metals for power so routing congestion on signal layers is reduced.

---

## Part 9 — Progress Tracker (P&R)

| Task | Status |
|------|--------|
| Innovus GUI launched via VNC (display fixed) | Done |
| pdk_local.tcl created (confidential values, git-ignored) | Done |
| init_design: LEF + netlist + MMMC loaded, 0 errors | Done |
| Floorplan set (utilization-based), rows created | Done |
| Power ring + stripes + cell rails (sroute) | Done |
| Core re-synthesized without scan flops | Done |
| Placement complete, 0 unplaced | Done |
| Pre-CTS optimization | Done |
| CTS (clock_opt_design), skew/latency reviewed, TNS = 0 | Done |
| Routing complete, all nets connected, checkRoute clean | Done |
| Post-route optimization (setup + hold) | Done |
| Reports + final netlist/DEF/SDF + saved design written | Done |
| Post-route GLS (next: simulate final netlist with post-route SDF) | Next |

---

## Part 10 — Command Quick Reference (generic, copy-paste)

```tcl
# --- init (LEF + netlist + MMMC, atomic) ---
source pdk_local.tcl
set init_mmmc_file pnr/mmmc.tcl
set init_lef_file  [list $PDK_TECH_LEF $PDK_CELL_LEF]
set init_verilog   syn/results/single_cycle_core_mapped.v
set init_top_cell  single_cycle_core
set_db init_power_nets  {VDD}
set_db init_ground_nets {VSS}
init_design
# --- floorplan ---
floorPlan -site $PDK_SITE -r 1.0 0.60 10 10 10 10
# --- power ---
globalNetConnect VDD -type pgpin -pin $PDK_PWR_PIN -inst * -override
globalNetConnect VSS -type pgpin -pin $PDK_GND_PIN -inst * -override
addRing  -nets {VDD VSS} -type core_rings -layer [list top $PDK_HMETAL bottom $PDK_HMETAL left $PDK_VMETAL right $PDK_VMETAL] -width 2.0 -spacing 1.0 -offset 1.0
addStripe -nets {VDD VSS} -layer $PDK_VMETAL -direction vertical -width 1.0 -spacing 0.5 -set_to_set_distance 20.0
sroute -connect {corePin} -nets {VDD VSS}
# --- place ---
setPlaceMode -timingDriven true
place_design
checkPlace
# --- pre-CTS opt, CTS, route, post-route opt ---
optDesign -preCTS
clock_opt_design
routeDesign
checkRoute
optDesign -postRoute
optDesign -postRoute -hold
# --- reports + outputs ---
report_area > pnr/results/area.rpt
report_timing -nworst 10 > pnr/results/timing_postroute.rpt
report_timing -nworst 1
saveNetlist pnr/results/single_cycle_final.v
defOut -routing pnr/results/single_cycle_final.def
write_sdf  pnr/results/single_cycle_postroute.sdf
saveDesign pnr/results/single_cycle_routed.enc
```

---

*Generic by design: every technology-specific value is a `$PDK_*` variable from the git-ignored `pdk_local.tcl`. With this guide and that one local file filled in for your kit, a beginner can go from a synthesized netlist to a routed chip — exactly as we did.*
