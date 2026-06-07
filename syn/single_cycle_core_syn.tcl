# =============================================================================
# syn/single_cycle_core_syn.tcl
# Cadence Genus 23.33 synthesis script for single_cycle_core (RV32I core)
#
# This synthesizes the CORE LOGIC ONLY -- memories are external (port interface).
# Use this instead of single_cycle_syn.tcl, which embeds the memories and
# therefore produces only the PC (the memories black-box and collapse the
# datapath to constant 0).
#
# Technology : 0.18um CMOS standard-cell process, typical corner
# Library    : supplied via pdk_local.tcl (git-ignored; commercial/NDA PDK)
#
# Usage (on the HPC, from the repo root):
#   cad && 1.3
#   genus -f syn/single_cycle_core_syn.tcl
#   (pdk_local.tcl must exist -- see pdk_local.tcl.template)
#
# Outputs (in syn/results/):
#   single_cycle_core_mapped.v  -- gate-level netlist
#   single_cycle_core.sdf       -- SDF delay file for GLS
#   core_area.rpt / core_timing.rpt / core_power.rpt
# =============================================================================

set_db / .hdl_max_loop_limit 8192

# Technology library paths come from the git-ignored local PDK config.
if {![file exists pdk_local.tcl]} {
    puts "ERROR: pdk_local.tcl not found. Copy pdk_local.tcl.template and fill it in."
    exit 1
}
source pdk_local.tcl
set_db lib_search_path $PDK_LIB_SEARCH
set_db library         [list $PDK_LIBERTY]

# Read core RTL + its sub-modules. NO inst_memory, NO data_memory --
# they are external to the core and connected through ports.
read_hdl -sv {
    rtl/common/alu.sv
    rtl/common/alu_ctrl.sv
    rtl/common/regfile.sv
    rtl/common/pc.sv
    rtl/common/immgen.sv
    rtl/single_cycle/single_cycle_core.sv
}

elaborate single_cycle_core

# Timing constraints (reuse the same SDC; clock port is 'clk' in both)
read_sdc syn/constraints/single_cycle.sdc

# Three-stage synthesis
syn_generic
syn_map
syn_opt

# Outputs
write_hdl > syn/results/single_cycle_core_mapped.v
write_sdf > syn/results/single_cycle_core.sdf

# Reports
redirect syn/results/core_area.rpt    { report area   }
redirect syn/results/core_timing.rpt  { report timing }
redirect syn/results/core_power.rpt   { report power  }

report area
report timing -nworst 5

puts "\n=== Core synthesis complete ==="
puts "    Netlist : syn/results/single_cycle_core_mapped.v"
puts "    SDF     : syn/results/single_cycle_core.sdf"
puts "    Area    : syn/results/core_area.rpt"
puts "    Timing  : syn/results/core_timing.rpt"

exit
