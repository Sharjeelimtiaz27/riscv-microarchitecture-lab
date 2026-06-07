# =============================================================================
# pnr/innovus_single_cycle.tcl
# Cadence Innovus place and route script for the single_cycle RV32I CORE
# Technology: 0.18um CMOS (c18), 6-metal stack (<tech_variant>), 1.8V typical corner
#
# Usage (on TalTech HPC after loading the Cadence environment):
#   cad && 1.3
#   cd <repo_root>
#   innovus                         # then in the GUI console: source this file
#   -- or batch --
#   innovus -batch -files pnr/innovus_single_cycle.tcl
#
# Prerequisites:
#   1. Genus core synthesis complete:
#        syn/results/single_cycle_core_mapped.v   (gate-level netlist, module
#                                                   single_cycle_core)
#   2. SDC constraints present:
#        syn/constraints/single_cycle.sdc
#
# P&R TARGET: single_cycle_core  (logic only). The instruction and data
# memories are EXTERNAL SRAM macros and are not placed here -- they connect
# to the core through ports.
#
# What this script produces:
#   pnr/results/single_cycle_final.v        -- post-route netlist (for GLS)
#   pnr/results/single_cycle_final.def      -- layout in DEF format
#   pnr/results/single_cycle_postroute.sdf  -- post-route delays for GLS
#   pnr/results/timing_violations.rpt       -- setup/hold violations
#   pnr/results/area.rpt                    -- final area report
# =============================================================================

# Real PDK file locations on TalTech HPC (the foundry c18, 6-metal):
set TECH_LEF  <TECH_LEF>
set CELL_LEF  <CELL_LEF>
set TIMING_LIB <TIMING_LIB>

# =============================================================================
# STEP 1: INITIALIZE DESIGN  (MMMC + physical + netlist)
#
# MMMC = Multi-Mode Multi-Corner. It bundles three things for Innovus:
#   library_set    -> which timing library  (the per-cell stopwatch)
#   delay_corner   -> the PVT corner (process/voltage/temperature conditions)
#   constraint_mode-> the SDC (clock period, I/O delays)
# An analysis_view ties one constraint_mode to one delay_corner; Innovus uses
# it for all timing analysis during placement, CTS, and routing.
# =============================================================================

create_library_set -name ls_typ -timing [list $TIMING_LIB]

# RC corner: with no extraction tech file, Innovus uses default unit RC. That
# is fine for a teaching flow -- timing is approximate but the flow runs.
create_rc_corner -name rc_typ -T 25

create_delay_corner -name dc_typ -library_set ls_typ -rc_corner rc_typ

create_constraint_mode -name cm_func -sdc_files [list syn/constraints/single_cycle.sdc]

create_analysis_view -name av_typ -constraint_mode cm_func -delay_corner dc_typ

# Tell init_design the names we will use for the global power and ground nets.
set_db init_power_nets  {VDD}
set_db init_ground_nets {VSS}

# Load the physical technology (LEF) before the netlist.
#   tech LEF  -> metal layers M1..M4,MT,AM and vias
#   cell LEF  -> the physical shape of every standard cell
read_physical -lef [list $TECH_LEF $CELL_LEF]

# Load the logical design (gate-level netlist).
read_netlist syn/results/single_cycle_core_mapped.v -top single_cycle_core

# Select the analysis view, then build the in-memory design database.
set_analysis_view -setup {av_typ} -hold {av_typ}
init_design

# =============================================================================
# STEP 2: FLOORPLAN
# Utilization-based: Innovus auto-sizes the die to hit the target density.
#   -r  aspect ratio 1.0 (square)
#   0.60 target core utilization (60% cells, 40% free for routing -- generous,
#        good for a first run to avoid routing congestion)
#   10 10 10 10  core-to-die margins (microns) on left/bottom/right/top
# =============================================================================

floorPlan -site <core_site> -r 1.0 0.60 10 10 10 10

# =============================================================================
# STEP 3: POWER PLANNING  (PDN: power distribution network)
# the foundry <tech_variant> has NO M5. The thick top metals are MT (horizontal) and AM
# (vertical) -- ideal for power. We leave M1..M4 free for signal routing.
# Standard cells take power on pins <VDD_PIN> / <GND_PIN>.
# =============================================================================

# Logically connect every cell power/ground pin to the global VDD/VSS nets.
globalNetConnect VDD -type pgpin -pin <VDD_PIN> -inst * -override
globalNetConnect VSS -type pgpin -pin <GND_PIN> -inst * -override

# Power ring around the core: top/bottom on MT (horizontal), sides on AM
# (vertical), matching each layer's preferred routing direction.
addRing \
    -nets {VDD VSS} \
    -type core_rings \
    -layer {top MT bottom MT left AM right AM} \
    -width 2.0 \
    -spacing 1.0 \
    -offset 1.0

# Vertical power stripes across the interior on AM, feeding the core.
addStripe \
    -nets {VDD VSS} \
    -layer AM \
    -direction vertical \
    -width 1.0 \
    -spacing 0.5 \
    -set_to_set_distance 20.0

# Connect the standard-cell power rails (M1 follow-pins) up to the ring/stripes.
sroute -connect {corePin} -nets {VDD VSS}

# =============================================================================
# STEP 4: PLACEMENT
# Place all standard cells in legal rows, timing-driven.
# =============================================================================

setPlaceMode -timingDriven true
place_design
checkPlace

# =============================================================================
# STEP 5: PRE-CTS OPTIMIZATION
# Fix setup violations before building the clock tree (cheaper to fix now).
# =============================================================================

optDesign -preCTS

# =============================================================================
# STEP 6: CLOCK TREE SYNTHESIS (CTS)
# Build a balanced clock distribution so every flop sees the clock at nearly
# the same time (minimal skew). ccopt_design is the modern concurrent CTS +
# optimization engine in Innovus.
# =============================================================================

create_clock_tree_spec
ccopt_design

# =============================================================================
# STEP 7: POST-CTS HOLD FIX
# Real clock skew (now known) can create hold violations. Insert delay buffers.
# =============================================================================

optDesign -postCTS -hold

# =============================================================================
# STEP 8: ROUTING
# Route all signal nets within design rules (spacing, width, via rules).
# =============================================================================

routeDesign
checkRoute

# =============================================================================
# STEP 9: POST-ROUTE OPTIMIZATION
# Final timing closure with real routed-wire delays: setup then hold.
# =============================================================================

optDesign -postRoute
optDesign -postRoute -hold

# =============================================================================
# STEP 10: REPORTS
# =============================================================================

report_timing -path_type full -slack_lesser_than 0 > pnr/results/timing_violations.rpt
report_area > pnr/results/area.rpt
report_timing -nworst 1 -path_type summary

# =============================================================================
# STEP 11: WRITE FINAL OUTPUTS
# =============================================================================

write_netlist -top_module_only pnr/results/single_cycle_final.v
write_def pnr/results/single_cycle_final.def
write_sdf pnr/results/single_cycle_postroute.sdf

puts "\n=== Place and route complete. Outputs in pnr/results/ ==="
puts "    Netlist : pnr/results/single_cycle_final.v"
puts "    DEF     : pnr/results/single_cycle_final.def"
puts "    SDF     : pnr/results/single_cycle_postroute.sdf"
puts "    Timing  : pnr/results/timing_violations.rpt"
