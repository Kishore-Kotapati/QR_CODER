# Standalone copy of the DC script for design_1. Run from a folder next to rtl_r0_plain/ :  dc_shell -f design_1_dc.tcl
set env(DESIGN) mkQRDecoder
set env(TAG) r0_plain
set env(PERIOD) 5.0
set env(GATE) 0
set env(DONT_USE) ""
# -------------------------------------------------------
# Design and Path Variables
# -------------------------------------------------------
# Person B copy of Person A's team dc.tcl (A_R1_2026-10-31/syn_scripts/dc.tcl).
# Only these things differ, all marked "B:":
#   B: design / file list / period / tag come from the environment
#   B: optional clock gating (GATE=1) for redesign round R2
#   B: report_clock_gating added
#   B: v6: optional DONT_USE list of library cells (14 nm pin-access problem cells)
set DESIGN $env(DESIGN)
set TAG    $env(TAG)
set _OUTPUTS_PATH ../outputs_$TAG
set _REPORTS_PATH ../reports_$TAG

##
# -------------------------------------------------------
# Library Setup - SAED14nm EDK 03_2025
# -------------------------------------------------------
set PDK_PATH "/home/tools/pdk/SAED14nm_EDK_03_2025"

set target_library    [list]
set link_library      "*"

# Define the root path for Synopsys 2022 installation
set SYNOPSYS_ROOT "/home/tools/pd_tools/syn/U-2022.12"

set synthetic_library [list \
  $SYNOPSYS_ROOT/libraries/syn/dw_foundation.sldb \
  $SYNOPSYS_ROOT/libraries/syn/standard.sldb \
]

# Target library: SAED14 RVT, NLDM, base, SS corner (0.72V, 125C) - worst case for setup
set target_library [concat $target_library \
$PDK_PATH/SAED14nm_EDK_STD_RVT/liberty/nldm/base/saed14rvt_base_ss0p72v125c.db \
]

# Link library: same RVT base library
set link_library [concat $link_library \
$PDK_PATH/SAED14nm_EDK_STD_RVT/liberty/nldm/base/saed14rvt_base_ss0p72v125c.db \
]

# Combine all libraries
set link_library [concat $link_library $target_library $synthetic_library]

##
# -------------------------------------------------------
# Output Directory Setup and SVF
# -------------------------------------------------------
file mkdir ${_OUTPUTS_PATH}
file mkdir ${_REPORTS_PATH}
set_svf ${_OUTPUTS_PATH}/${DESIGN}.svf

# -------------------------------------------------------
# RTL Read and Elaboration
# -------------------------------------------------------
# B: file list made by run_dc_full.sh (all bsc Verilog + the Bluespec library modules used)
analyze -format verilog [split [string trim [read [open ../rtl_$TAG/files.txt]]] "\n"]
elaborate $DESIGN
current_design $DESIGN
link

# B: v6: cells that ICC cannot connect cleanly (LVS shorts between their own
# input pins), e.g. "SAEDRVT14_OAI22_* SAEDRVT14_OAI21_* SAEDRVT14_ND2_CDC_*"
if {[info exists env(DONT_USE)] && $env(DONT_USE) ne ""} {
  foreach pat $env(DONT_USE) {
    set lc [get_lib_cells -quiet */$pat]
    puts "B: dont_use $pat -> [sizeof_collection $lc] library cells"
    if {[sizeof_collection $lc] > 0} { set_dont_use $lc }
  }
}

# -------------------------------------------------------
# Apply Timing Constraints (Spec Section 6.2)
# -------------------------------------------------------
# B: same SDC as Person A (40 % IO delay), period from PERIOD
set T $env(PERIOD)
create_clock -name CLK -period $T [get_ports CLK]
set data_in [remove_from_collection [all_inputs] [get_ports CLK]]
set_input_delay  -clock CLK [expr 0.4*$T] $data_in
set_output_delay -clock CLK [expr 0.4*$T] [all_outputs]

# -------------------------------------------------------
# Optimization Constraints
# -------------------------------------------------------
set_max_area 0
set_dont_retime $DESIGN true

##
# -------------------------------------------------------
# Path Group Setup (matching noc_d1)
# -------------------------------------------------------
set unq_input_list [all_inputs]
foreach_in_collection unq_clock_element [all_clocks] {
  set unq_clock_name [get_port $unq_clock_element]
  set unq_input_list [remove_from_collection $unq_input_list $unq_clock_name]
}

# Critical range scaled down for 14nm (0.15 ns)
group_path -name f2f -from [all_registers]  -to [all_registers] -critical_range 0.15
group_path -name i2f -from $unq_input_list  -to [all_registers] -critical_range 0.15
group_path -name f2o -from [all_registers]  -to [all_outputs]   -critical_range 0.15
group_path -name i2o -from $unq_input_list  -to [all_outputs]   -critical_range 0.15

##
# -------------------------------------------------------
# Pre-Compile Design Check
# -------------------------------------------------------
check_design > ${_REPORTS_PATH}/check_design.pre_compile.rpt

# -------------------------------------------------------
# Synthesis: compile_ultra
# -------------------------------------------------------
# B: R2 = clock gating.  DC replaces "flop + enable mux" by one clock gate
# per group of flops that share an enable (each 8-bit store byte = 1 group).
if {$env(GATE) == 1} {
  # integrated clock-gating cell if the library has one, else latch + AND
  set nicg 0
  catch {set nicg [sizeof_collection [get_lib_cells -quiet */* -filter "clock_gating_integrated_cell =~ latch_posedge*"]]}
  if {$nicg > 0} {
    puts "B: $nicg integrated clock-gating cells in the library -> using them"
    set_clock_gating_style -sequential_cell latch -positive_edge_logic {integrated} -minimum_bitwidth 3
  } else {
    puts "B: no integrated clock-gating cell found, using latch + AND"
    set_clock_gating_style -sequential_cell latch -positive_edge_logic {and} -minimum_bitwidth 3
  }
  compile_ultra -no_autoungroup -no_seq_output_inversion -timing_high_effort_script -gate_clock
} else {
  compile_ultra -no_autoungroup -no_seq_output_inversion -timing_high_effort_script
}

# -------------------------------------------------------
# Naming Convention Enforcement
# -------------------------------------------------------
define_name_rules verilog -allowed "a-z A-Z 0-9 _ /"
change_names -hier -rules verilog

# -------------------------------------------------------
# Write Post-Synthesis Outputs
# -------------------------------------------------------
write -format verilog -hierarchy -output ${_OUTPUTS_PATH}/$DESIGN.verilog.v
write -format ddc     -hierarchy -output ${_OUTPUTS_PATH}/$DESIGN.compile.ddc

# -------------------------------------------------------
# Timing, Area, Power and QoR Reports
# -------------------------------------------------------
report_qor > ${_REPORTS_PATH}/dc_compile_ultra_1.qor

report_timing -nosplit -max_paths 20 -input -nets -cap -tran -nosplit -sig 2 -group f2f > ${_REPORTS_PATH}/setup.f2f.tim.rpt
report_timing -nosplit -max_paths 20 -input -nets -cap -tran -nosplit -sig 2 -group i2f > ${_REPORTS_PATH}/setup.i2f.tim.rpt
report_timing -nosplit -max_paths 20 -input -nets -cap -tran -nosplit -sig 2 -group f2o > ${_REPORTS_PATH}/setup.f2o.tim.rpt
report_timing -nosplit -max_paths 20 -input -nets -cap -tran -nosplit -sig 3 -group i2o > ${_REPORTS_PATH}/setup.i2o.tim.rpt

report_area -hierarchy > ${_REPORTS_PATH}/area_hierarchy.rpt
report_power -analysis_effort medium > ${_REPORTS_PATH}/power.rpt
report_clock_gating -nosplit > ${_REPORTS_PATH}/clock_gating.rpt
report_constraint -all_violators > ${_REPORTS_PATH}/constraints.rpt

check_design > ${_REPORTS_PATH}/check_design.dc_compile_1.rpt

# -------------------------------------------------------
# Multi-Port Net Fix
# -------------------------------------------------------
set verilogout_no_tri  "true"
set_app_var compile_advanced_fix_multiple_port_nets "true"
set_fix_multiple_port_nets -all -buffer_constants
change_names -hier -rules verilog

write -format verilog -hierarchy -output ${_OUTPUTS_PATH}/$DESIGN.verilog_noassign.v

exit
