# =============================================================================
# formal/prove_single_cycle.tcl
# JasperGold formal verification script for single_cycle_top RV32I
#
# Usage (on TalTech HPC after loading Cadence environment):
#   cad && 1.3
#   cd <repo_root>
#   jg -proj formal/sessions/single_cycle -batch formal/prove_single_cycle.tcl
#
# The -proj flag stores all JasperGold session data (proof databases, waveforms,
# counterexample traces) in formal/sessions/single_cycle/.
# For the pipeline design (Phase 2), use:
#   jg -proj formal/sessions/pipeline -batch formal/prove_pipeline.tcl
#
# What this script does:
#   1. Analyzes all RTL files and all assertion files (which include bind)
#   2. Elaborates single_cycle_top as the top module
#   3. Declares clock and reset
#   4. Proves all assert properties exhaustively
#   5. Checks all cover properties are reachable
# =============================================================================

clear -all

# =============================================================================
# STEP 1: ANALYZE
# Load all SystemVerilog files. Assertion files include bind statements so
# they are analyzed alongside the RTL -- no separate bind file pass needed.
# =============================================================================

analyze -sv12 \
    rtl/common/alu.sv \
    rtl/common/alu_ctrl.sv \
    rtl/common/regfile.sv \
    rtl/common/pc.sv \
    rtl/common/immgen.sv \
    rtl/common/data_memory.sv \
    rtl/common/inst_memory.sv \
    rtl/single_cycle/single_cycle_top.sv

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
# -bbox_a 8192: prevents auto-black-boxing of memory arrays (VERI-9033).
# Without this, inst_memory and data_memory are black-boxed and
# write-then-read properties become unprovable.
# =============================================================================

elaborate -top single_cycle_top -bbox_a 8192

# =============================================================================
# STEP 3: CLOCK AND RESET
# =============================================================================

clock clk
reset -expression {!rst_n}

# =============================================================================
# STEP 4: PROVE
# prove -all runs synchronously and blocks until all proofs complete.
# JasperGold prints the full SUMMARY table automatically on exit.
# Session data (CEX waveforms, proof databases) is written to the
# -proj directory: formal/sessions/single_cycle/
# =============================================================================

set_prove_time_limit 3600s
prove -all

puts "\n=== Formal verification complete. Session data in formal/sessions/single_cycle/ ==="
