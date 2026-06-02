# =============================================================================
# syn/single_cycle_syn.tcl
# Cadence Genus 23.33 synthesis script for single_cycle_top RV32I
#
# Technology : 0.18um CMOS (c18), typical corner, 1.8V
# Library    : <TIMING_LIB>
#
# Usage (on TalTech HPC):
#   cad && 1.3
#   cd <repo_root>
#   genus -f syn/single_cycle_syn.tcl
#
# Outputs:
#   syn/results/single_cycle_mapped.v  -- gate-level netlist
#   syn/results/single_cycle.sdf       -- SDF delay file for GLS
#   syn/results/area.rpt               -- area report
#   syn/results/timing.rpt             -- timing report
#   syn/results/power.rpt              -- power report
# =============================================================================

# Allow loop unrolling for the register-file reset loop (32 iterations)
set_db / .hdl_max_loop_limit 8192

# =============================================================================
# STEP 1: TECHNOLOGY LIBRARY
# 0.18um CMOS, typical PVT corner (1.8V, 25C, nominal)
# TYP corner is used for initial synthesis and area estimation.
# Use WC (worst case) for timing sign-off.
# =============================================================================

set_db lib_search_path <LIB_DIR>
set_db library         {<cell_library.lib>}

# =============================================================================
# STEP 2: READ RTL
# Assertion files are NOT loaded -- they are simulation/formal only.
# =============================================================================

read_hdl -sv {
    rtl/common/alu.sv
    rtl/common/alu_ctrl.sv
    rtl/common/regfile.sv
    rtl/common/pc.sv
    rtl/common/immgen.sv
    rtl/common/data_memory.sv
    rtl/common/inst_memory.sv
    rtl/single_cycle/single_cycle_top.sv
}

# =============================================================================
# STEP 3: ELABORATE
# =============================================================================

elaborate single_cycle_top

# single_cycle_top has no output ports (simulation-only RTL design).
# Without this, Genus removes ALL logic as "not driving any primary output"
# (GLO-34 message). With these set, flip-flops are kept, and all combinational
# logic feeding their D inputs is preserved by cascade.
set_db / .delete_unloaded_insts false
set_db / .delete_unloaded_seqs  false

# =============================================================================
# STEP 4: TIMING CONSTRAINTS
# Target: 100 MHz (10 ns). 0.18um typical corner can meet this.
# If timing is not met, relax to 20 ns (50 MHz) in the SDC.
# =============================================================================

read_sdc syn/constraints/single_cycle.sdc

# =============================================================================
# STEP 5: SYNTHESIS
# =============================================================================

syn_generic
syn_map
syn_opt

# =============================================================================
# STEP 6: WRITE OUTPUTS
# =============================================================================

write_hdl > syn/results/single_cycle_mapped.v
write_sdf > syn/results/single_cycle.sdf

# =============================================================================
# STEP 7: REPORTS
# =============================================================================

redirect syn/results/area.rpt    { report area   }
redirect syn/results/timing.rpt  { report timing }
redirect syn/results/power.rpt   { report power  }

report area
report timing -nworst 5

puts "\n=== Synthesis complete ==="
puts "    Netlist : syn/results/single_cycle_mapped.v"
puts "    SDF     : syn/results/single_cycle.sdf"
puts "    Area    : syn/results/area.rpt"
puts "    Timing  : syn/results/timing.rpt"
