# =============================================================================
# pnr/innovus_single_cycle.tcl
# Cadence Innovus place and route script for the single_cycle RV32I CORE
#
# Technology-specific values (library/LEF paths, site, layer, pin names) are
# NOT hard-coded here -- they are read from pdk_local.tcl, which is git-ignored
# because it contains commercial/NDA PDK details. Copy pdk_local.tcl.template
# to pdk_local.tcl and fill in your own PDK values before running.
#
# Usage (on the HPC, after loading the Cadence environment, from the repo root):
#   innovus                         # then in the GUI console: source <this file>
#   -- or batch --
#   innovus -batch -files pnr/innovus_single_cycle.tcl
#
# Prerequisites:
#   1. Genus core synthesis complete:
#        syn/results/single_cycle_core_mapped.v   (module single_cycle_core)
#   2. SDC constraints present:  syn/constraints/single_cycle.sdc
#   3. pdk_local.tcl present (see pdk_local.tcl.template)
#
# P&R TARGET: single_cycle_core (logic only). The instruction and data
# memories are EXTERNAL SRAM macros and are not placed here.
#
# Outputs (pnr/results/):
#   single_cycle_final.v        -- post-route netlist (for GLS)
#   single_cycle_final.def      -- layout in DEF format
#   single_cycle_postroute.sdf  -- post-route delays for GLS
#   timing_violations.rpt       -- setup/hold violations
#   area.rpt                    -- final area report
# =============================================================================

if {![file exists pdk_local.tcl]} {
    puts "ERROR: pdk_local.tcl not found."
    puts "       Copy pdk_local.tcl.template to pdk_local.tcl and fill in your PDK paths."
    exit 1
}
source pdk_local.tcl

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

create_library_set -name ls_typ -timing [list $PDK_TIMING_LIB]

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
#   tech LEF  -> metal routing layers and vias
#   cell LEF  -> the physical shape of every standard cell
read_physical -lef [list $PDK_TECH_LEF $PDK_CELL_LEF]

# Load the logical design (gate-level netlist).
read_netlist syn/results/single_cycle_core_mapped.v -top single_cycle_core

# Select the analysis view, then build the in-memory design database.
set_analysis_view -setup {av_typ} -hold {av_typ}
init_design

# =============================================================================
# STEP 2: FLOORPLAN
# Utilization-based: Innovus auto-sizes the die to hit the target density.
#   -r  aspect ratio 1.0 (square)
#   0.60 target core utilization (60% cells, 40% free for routing)
#   10 10 10 10  core-to-die margins (microns) on left/bottom/right/top
# =============================================================================

floorPlan -site $PDK_SITE -r 1.0 0.60 10 10 10 10

# =============================================================================
# STEP 3: POWER PLANNING  (PDN: power distribution network)
# Ring + stripes on the thick top metals (one horizontal, one vertical), so
# M1..lower metals stay free for signal routing. Standard cells take power on
# the pins named in pdk_local.tcl.
# =============================================================================

# Logically connect every cell power/ground pin to the global VDD/VSS nets.
globalNetConnect VDD -type pgpin -pin $PDK_PWR_PIN -inst * -override
globalNetConnect VSS -type pgpin -pin $PDK_GND_PIN -inst * -override

# Power ring around the core: top/bottom on the horizontal top metal, sides on
# the vertical top metal (matching each layer's preferred routing direction).
addRing \
    -nets {VDD VSS} \
    -type core_rings \
    -layer [list top $PDK_HMETAL bottom $PDK_HMETAL left $PDK_VMETAL right $PDK_VMETAL] \
    -width 2.0 \
    -spacing 1.0 \
    -offset 1.0

# Vertical power stripes across the interior, feeding the core.
addStripe \
    -nets {VDD VSS} \
    -layer $PDK_VMETAL \
    -direction vertical \
    -width 1.0 \
    -spacing 0.5 \
    -set_to_set_distance 20.0

# Connect the standard-cell power rails (follow-pins) up to the ring/stripes.
sroute -connect {corePin} -nets {VDD VSS}

# =============================================================================
# STEP 4: PLACEMENT
# =============================================================================

setPlaceMode -timingDriven true
place_design
checkPlace

# =============================================================================
# STEP 5: PRE-CTS OPTIMIZATION
# =============================================================================

optDesign -preCTS

# =============================================================================
# STEP 6: CLOCK TREE SYNTHESIS (CTS)
# ccopt_design is the modern concurrent CTS + optimization engine.
# =============================================================================

create_clock_tree_spec
ccopt_design

# =============================================================================
# STEP 7: POST-CTS HOLD FIX
# =============================================================================

optDesign -postCTS -hold

# =============================================================================
# STEP 8: ROUTING
# =============================================================================

routeDesign
checkRoute

# =============================================================================
# STEP 9: POST-ROUTE OPTIMIZATION
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
