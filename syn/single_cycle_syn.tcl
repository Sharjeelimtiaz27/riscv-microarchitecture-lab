# =============================================================================
# syn/single_cycle_syn.tcl
# Cadence Genus synthesis script for single_cycle_top RV32I
#
# Usage (on TalTech HPC after loading Cadence environment):
#   cad && 1.3
#   cd <repo_root>
#   genus -f syn/single_cycle_syn.tcl
#
# Prerequisite: a technology library must be configured.
# On TalTech HPC, set the PDK environment variable before running:
#   export PDK_LIB=/path/to/technology/library.lib
#
# What this script produces:
#   syn/results/single_cycle_mapped.v  -- gate-level netlist
#   syn/results/single_cycle.sdf       -- standard delay format (for GLS)
#   syn/results/area.rpt               -- area report
#   syn/results/timing.rpt             -- timing report
#   syn/results/power.rpt              -- power report
# =============================================================================

# Allow larger loop unrolling for the register-file reset loop
set_db / .hdl_max_loop_limit 8192

# =============================================================================
# STEP 1: READ HDL
# Load all RTL files in dependency order (modules before their wrappers).
# Assertion modules are NOT included in synthesis -- they are for verification only.
# =============================================================================

read_hdl -sv12 {
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
# STEP 2: ELABORATE
# Resolve hierarchy, parameters, and generate internal netlist representation.
# =============================================================================

elaborate single_cycle_top

# =============================================================================
# STEP 3: APPLY TIMING CONSTRAINTS
# =============================================================================

read_sdc syn/constraints/single_cycle.sdc

# =============================================================================
# STEP 4: SYNTHESIS FLOW
# syn_generic: technology-independent Boolean optimization
# syn_map:     map to standard cells from the technology library
# syn_opt:     post-map optimization (buffer insertion, gate sizing)
# =============================================================================

syn_generic
syn_map
syn_opt

# =============================================================================
# STEP 5: WRITE OUTPUTS
# =============================================================================

# Gate-level netlist (Verilog) for GLS and equivalence checking
write_hdl -mapped > syn/results/single_cycle_mapped.v

# SDF delay file for back-annotated gate-level simulation
write_sdf syn/results/single_cycle.sdf

# =============================================================================
# STEP 6: REPORTS
# =============================================================================

report_area   > syn/results/area.rpt
report_timing > syn/results/timing.rpt
report_power  > syn/results/power.rpt

# Print summary to terminal
report_area
report_timing -nworst 5

puts "\n=== Synthesis complete. Outputs in syn/results/ ==="
puts "    Netlist : syn/results/single_cycle_mapped.v"
puts "    SDF     : syn/results/single_cycle.sdf"
puts "    Area    : syn/results/area.rpt"
puts "    Timing  : syn/results/timing.rpt"
