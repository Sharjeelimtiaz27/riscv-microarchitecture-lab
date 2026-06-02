# =============================================================================
# formal/prove_single_cycle.tcl
# JasperGold formal verification script for single_cycle_top RV32I
#
# Usage (on TalTech HPC after loading Cadence environment):
#   cad && 1.3
#   cd <repo_root>
#   jg -batch formal/prove_single_cycle.tcl
#
# What this script does:
#   1. Analyzes all RTL files and all assertion files (which include bind)
#   2. Elaborates single_cycle_top as the top module
#   3. Declares clock and reset
#   4. Proves all assert properties exhaustively
#   5. Checks all cover properties are reachable
#   6. Writes summary and counterexample reports
# =============================================================================

clear -all

# =============================================================================
# STEP 1: ANALYZE
# Load all SystemVerilog files. The assertion files include bind statements
# so they are analyzed alongside the RTL -- no separate bind file pass needed.
# =============================================================================

# RTL design files
analyze -sv12 \
    rtl/common/alu.sv \
    rtl/common/alu_ctrl.sv \
    rtl/common/regfile.sv \
    rtl/common/pc.sv \
    rtl/common/immgen.sv \
    rtl/common/data_memory.sv \
    rtl/common/inst_memory.sv \
    rtl/single_cycle/single_cycle_top.sv

# Assertion files -- each file contains the checker module AND its bind statement
analyze -sv12 \
    rtl/assertions/alu_assertions.sv \
    rtl/assertions/alu_ctrl_assertions.sv \
    rtl/assertions/regfile_assertions.sv \
    rtl/assertions/pc_assertions.sv \
    rtl/assertions/immgen_assertions.sv \
    rtl/assertions/dmem_assertions.sv \
    rtl/assertions/top_assertions.sv

# =============================================================================
# STEP 2: ELABORATE
# Build the design database. The IMEM_INIT parameter gives the path to the
# hex program loaded into instruction memory. JasperGold will treat the memory
# contents as free symbolic values unless constrained.
# =============================================================================

elaborate \
    -top single_cycle_top \
    -param {IMEM_INIT rtl/common/programs/prog1.hex}

# =============================================================================
# STEP 3: CLOCK AND RESET
# Declare the primary clock and the active-low reset expression.
# JasperGold uses these to define the sampling edge for all concurrent
# assertions and to identify the initial state for k-induction.
# =============================================================================

clock clk
reset -expression {!rst_n}

# =============================================================================
# STEP 4: PROOF CONFIGURATION
# Set proof depth and time limit.
# - For safety properties with no state depth > 5, bounded proof to depth 20
#   is usually sufficient to find counterexamples.
# - For full exhaustive proof (unbounded), JasperGold uses k-induction.
# =============================================================================

set_prove_time_limit 3600s

# =============================================================================
# STEP 5: PROVE ALL PROPERTIES
# -bg runs proofs in background (parallel where resources allow).
# JasperGold will produce: Proven / Bounded Proof / Falsified / Inconclusive.
# =============================================================================

prove -bg -all

# =============================================================================
# STEP 6: REPORTS
# Write summary and counterexample reports to the results directory.
# =============================================================================

report_results -type summary  -file formal/results/proof_summary.rpt
report_results -type property -file formal/results/property_details.rpt

# Print result table to log for quick review on HPC terminal
puts "\n=== PROOF SUMMARY ==="
report_results -type summary

puts "\n=== Formal verification complete. Check formal/results/ for reports. ==="
