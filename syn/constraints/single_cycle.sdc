# =============================================================================
# syn/constraints/single_cycle.sdc
# Synopsys Design Constraints for single_cycle_top RV32I
#
# Target: 100 MHz (10 ns clock period)
# These constraints are applied by Genus during logic synthesis to meet timing.
# =============================================================================

# Primary clock: 100 MHz, 50% duty cycle
create_clock -name clk \
             -period 10.0 \
             -waveform {0.0 5.0} \
             [get_ports clk]

# Input arrival times: assume inputs arrive 2 ns after the clock edge
# (leaves 8 ns of combinational slack for internal logic)
set_input_delay  2.0 -clock clk [all_inputs]

# Output required times: outputs must be stable 2 ns before the next clock edge
set_output_delay 2.0 -clock clk [all_outputs]

# Reset is asynchronous -- no timing constraint needed on reset path
set_false_path -from [get_ports rst_n]

# Disable timing checks on clock port itself
set_dont_touch_network [get_clocks clk]
