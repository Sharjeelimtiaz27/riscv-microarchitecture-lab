# =============================================================================
# pnr/innovus_single_cycle.tcl
# Cadence Innovus place and route script for the single_cycle RV32I CORE
#
# Technology-specific values (library/LEF paths, site, layer, pin names) are
# read from pdk_local.tcl, which is git-ignored because it contains
# commercial/NDA PDK details. Copy pdk_local.tcl.template -> pdk_local.tcl and
# fill in your own PDK values before running. The timing setup (MMMC) lives in
# pnr/mmmc.tcl, which init_design reads.
#
# Verified working flow on Innovus v23.33.
#
# Usage (on the HPC, from the repo root, inside a graphical session for the GUI):
#   innovus                         # then in the console: source <this file>
#   -- or batch --
#   innovus -batch -files pnr/innovus_single_cycle.tcl
#
# Prerequisites:
#   1. Genus CORE synthesis complete (with scan flops disabled -- see
#      syn/single_cycle_core_syn.tcl): syn/results/single_cycle_core_mapped.v
#   2. syn/constraints/single_cycle.sdc present.
#   3. pdk_local.tcl present (see pdk_local.tcl.template).
#
# P&R TARGET: single_cycle_core (logic only). Memories are external SRAM macros.
#
# Outputs (pnr/results/): single_cycle_final.v, .def, _postroute.sdf,
#   timing_violations.rpt, area.rpt
# =============================================================================

if {![file exists pdk_local.tcl]} {
    puts "ERROR: pdk_local.tcl not found."
    puts "       Copy pdk_local.tcl.template to pdk_local.tcl and fill in your PDK paths."
    exit 1
}
source pdk_local.tcl

# =============================================================================
# STEP 1: INITIALIZE DESIGN  (one atomic load: LEF + netlist + MMMC timing)
#
# init_design reads everything together: the physical LEF, the gate-level
# netlist, and pnr/mmmc.tcl (timing). set_analysis_view runs from inside
# init_design (via the MMMC file), which is the only place Innovus allows it.
# =============================================================================

set init_mmmc_file pnr/mmmc.tcl
set init_lef_file  [list $PDK_TECH_LEF $PDK_CELL_LEF]
set init_verilog   syn/results/single_cycle_core_mapped.v
set init_top_cell  single_cycle_core

set_db init_power_nets  {VDD}
set_db init_ground_nets {VSS}

init_design

# =============================================================================
# STEP 2: FLOORPLAN
#   -r 1.0          square aspect ratio
#   0.60            target core utilization (60% cells, 40% free for routing)
#   10 10 10 10     core-to-die margins (microns): left bottom right top
# =============================================================================

floorPlan -site $PDK_SITE -r 1.0 0.60 10 10 10 10

# =============================================================================
# STEP 3: POWER PLANNING  (PDN)
# Ring + stripes on the thick top metals (one horizontal, one vertical);
# cell rails connected with sroute. Cell power pins come from pdk_local.tcl.
# =============================================================================

globalNetConnect VDD -type pgpin -pin $PDK_PWR_PIN -inst * -override
globalNetConnect VSS -type pgpin -pin $PDK_GND_PIN -inst * -override

addRing \
    -nets {VDD VSS} \
    -type core_rings \
    -layer [list top $PDK_HMETAL bottom $PDK_HMETAL left $PDK_VMETAL right $PDK_VMETAL] \
    -width 2.0 \
    -spacing 1.0 \
    -offset 1.0

addStripe \
    -nets {VDD VSS} \
    -layer $PDK_VMETAL \
    -direction vertical \
    -width 1.0 \
    -spacing 0.5 \
    -set_to_set_distance 20.0

sroute -connect {corePin} -nets {VDD VSS}

# =============================================================================
# STEP 4: PLACEMENT
# (Netlist must be synthesized WITHOUT scan flops -- see core synthesis script --
#  otherwise place_design aborts with IMPSP-9099.)
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
