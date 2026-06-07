# =============================================================================
# pnr/mmmc.tcl  -- Multi-Mode Multi-Corner timing setup for Innovus
#
# init_design reads this file (via init_mmmc_file). It must define the timing
# library, RC corner, the SDC constraint mode, and the analysis view, then call
# set_analysis_view. set_analysis_view is ONLY allowed from inside init_design's
# processing of this file -- calling it loose in the console errors (TCLCMD-1230).
#
# Confidential PDK paths come from pdk_local.tcl (git-ignored). Sourcing it here
# makes this file self-contained regardless of the scope init_design uses.
# =============================================================================

source pdk_local.tcl

create_library_set -name ls_typ -timing [list $PDK_TIMING_LIB]

# No QRC/extraction tech file in this academic PDK -> default unit RC is used.
create_rc_corner -name rc_typ -T 25

create_delay_corner -name dc_typ -library_set ls_typ -rc_corner rc_typ

create_constraint_mode -name cm_func -sdc_files [list syn/constraints/single_cycle.sdc]

create_analysis_view -name av_typ -constraint_mode cm_func -delay_corner dc_typ

set_analysis_view -setup {av_typ} -hold {av_typ}
