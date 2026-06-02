# =============================================================================
# pnr/innovus_single_cycle.tcl
# Cadence Innovus place and route script for single_cycle_top RV32I
#
# Usage (on TalTech HPC after loading Cadence environment):
#   cad && 1.3
#   cd <repo_root>
#   innovus -batch -files pnr/innovus_single_cycle.tcl
#
# Prerequisites:
#   1. Genus synthesis must have completed: syn/results/single_cycle_mapped.v
#      and syn/results/single_cycle.sdf must exist.
#   2. PDK environment variable must be set:
#      export PDK_DIR=/path/to/pdk
#   3. PDK must provide:
#      - LEF files: cells.lef (cell geometry), tech.lef (metal stack)
#      - Liberty file: typical.lib (timing model at nominal PVT)
#
# What this script produces:
#   pnr/results/single_cycle_final.v     -- post-route netlist
#   pnr/results/single_cycle_final.def   -- layout in DEF format
#   pnr/results/timing_violations.rpt    -- setup/hold violations
#   pnr/results/area.rpt                 -- final area report
# =============================================================================

# =============================================================================
# STEP 1: INITIALIZE DESIGN
# Load netlist, LEF files, liberty timing model, and SDC constraints.
# =============================================================================

read_netlist  syn/results/single_cycle_mapped.v -top single_cycle_top

read_lef [list \
    $env(PDK_DIR)/lef/tech.lef \
    $env(PDK_DIR)/lef/cells.lef \
]

read_lib $env(PDK_DIR)/lib/typical.lib

read_sdc syn/constraints/single_cycle.sdc

init_design

# =============================================================================
# STEP 2: FLOORPLAN
# Define die area and core area with margins on all sides (in microns).
# Aspect ratio 1.0 (square), target utilization 70%.
# =============================================================================

floorPlan -site core \
          -r 1.0 \
          -coreMarginsBy die \
          -d 200.0 200.0 \
          -e 10.0 10.0 10.0 10.0

# =============================================================================
# STEP 3: POWER PLANNING
# Add power ring around the core and power stripes across the interior.
# =============================================================================

addRing \
    -nets {VDD VSS} \
    -type core_rings \
    -layer {top M5 bottom M5 left M4 right M4} \
    -width 2.0 \
    -spacing 1.0 \
    -offset 1.0

addStripe \
    -nets {VDD VSS} \
    -layer M5 \
    -direction vertical \
    -width 1.0 \
    -spacing 0.5 \
    -set_to_set_distance 20.0

# Connect standard cell power pins to the power grid
globalNetConnect VDD -type pgpin -pin VDD -inst * -override
globalNetConnect VSS -type pgpin -pin VSS -inst * -override

# =============================================================================
# STEP 4: PLACEMENT
# Place all standard cells with timing-driven mode.
# =============================================================================

setPlaceMode -timingDriven true
place_design
checkPlace

# =============================================================================
# STEP 5: PRE-CTS OPTIMIZATION
# Fix setup violations before building the clock tree.
# =============================================================================

optDesign -preCTS

# =============================================================================
# STEP 6: CLOCK TREE SYNTHESIS (CTS)
# Build a balanced clock distribution network to minimize clock skew.
# =============================================================================

create_clock_tree_spec -output pnr/results/clock_spec.ctstch
clockDesign -specFile pnr/results/clock_spec.ctstch

# =============================================================================
# STEP 7: POST-CTS OPTIMIZATION
# Fix hold violations introduced by the clock tree.
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
# Fix remaining setup and hold violations after routing with real wire delays.
# =============================================================================

optDesign -postRoute
optDesign -postRoute -hold

# =============================================================================
# STEP 10: REPORTS
# =============================================================================

report_timing \
    -path_type full \
    -slack_lesser_than 0 \
    > pnr/results/timing_violations.rpt

report_area > pnr/results/area.rpt

# Print worst setup slack to terminal
report_timing -nworst 1 -path_type summary

# =============================================================================
# STEP 11: WRITE FINAL OUTPUTS
# =============================================================================

# Post-route Verilog netlist (for final GLS)
write_netlist -top_module_only pnr/results/single_cycle_final.v

# DEF file (physical layout for GDS generation)
write_def pnr/results/single_cycle_final.def

# Final SDF with actual routed wire delays
write_sdf pnr/results/single_cycle_postroute.sdf

puts "\n=== Place and route complete. Outputs in pnr/results/ ==="
puts "    Netlist : pnr/results/single_cycle_final.v"
puts "    DEF     : pnr/results/single_cycle_final.def"
puts "    SDF     : pnr/results/single_cycle_postroute.sdf"
puts "    Timing  : pnr/results/timing_violations.rpt"
