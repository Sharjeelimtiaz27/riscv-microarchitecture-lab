# =============================================================================
# syn/constraints/single_cycle.sdc
# Timing constraints for single_cycle_top RV32I
# Technology: 0.18um CMOS, typical corner, 1.8V
#
# Target: 50 MHz (20 ns) -- conservative for single-cycle RV32I.
# The single-cycle critical path runs: regfile read -> ALU -> writeback.
# 0.18um TYP can meet this comfortably.
# For the pipelined RV64IM (Phase 2), target 100-200 MHz.
# =============================================================================

create_clock -name clk \
             -period 20.0 \
             -waveform {0.0 10.0} \
             [get_ports clk]

# Input delay: 2 ns after clock edge
set_input_delay  2.0 -clock clk [all_inputs]

# Output delay: 2 ns before next clock edge
set_output_delay 2.0 -clock clk [all_outputs]

# Reset is asynchronous -- skip timing analysis on this path
set_false_path -from [get_ports rst_n]
