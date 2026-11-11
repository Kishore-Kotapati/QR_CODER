# icc_qr.tcl -- place and route of the whole QR decoder (mkQRDecoder) in ICC.
# Person B.  This is the course udcounter/icc1/scripts/icc.tcl step by step.
# Changes, all marked "B:":
#   B: design, netlist, period and core size come from run_icc.sh (environment)
#   B: clock port is CLK (bsc name), not Clk
#   B: no PlacePins.tcl (the decoder has ~100 pins; ICC spreads them evenly)
#   B: power straps spaced for a ~300 um core instead of a 10 um core
#   B: one extra detail-route pass only if DRCs are left
#   B: v2 (2 Nov): clock tree built first, clock wires routed as a separate,
#      limited step; no crosstalk-driven routing; PGRT-030 messages hidden
#   B: v3 (2 Nov): routing only on M2..M7 (M3..M7 are strict one-way layers in
#      this 14 nm tech file), clock wires on M3..M6, clock wires routed fresh
#      (not from the CTS rough routes).  Test on run 2's placement: clock
#      DRCs 36,354 (stuck 13 h) -> 41 in 9 minutes.  Router output now in icc.log.
#   B: v4 (3 Nov): first full run (v3b) finished: setup met, 54,599 um2, 2.26 mW,
#      but 1,390 DRCs, 20 LVS shorts (M1/M2), 119 hold paths at -0.01 ns.
#      v4: removed the clock_opt -only_psyn line that failed (COPT-001);
#      post-route hold fix; DRC repair loop (up to 3 passes, 40 rounds each);
#      fillers placed with metal checking (-cell_with_metal); DRC repair after fillers.
#   B: v5 (3 Nov): v4 runs (UTIL 0.6 and 0.5) both ended with ~1,180 DRCs and
#      20 LVS shorts: every short is signal-signal on M1 at a cell pin (0.034 um
#      squares, mostly in the Chien/Forney logic).  v5: router must land vias
#      INSIDE the M1 cell pins (no M1 patches next to pins); optional limit on
#      local cell density (DENSITY=...) so dense logic is spread out.
#   B: v6 (3 Nov): v5 pin rule made it far worse (146,000+ DRCs): removed.
#      Diagnosis of v4's 20 LVS shorts: 18 are between two INPUT pins of the same
#      cell (OAI22 B1/B2, OAI21 A1/A2, ND2_CDC A1/A2): the via on one pin touches
#      the next pin.  Fix at the source: DC and ICC must not use those cells
#      (DONT_USE).  Also a 0.02 ns hold margin while fixing hold.
#   B: extra reports for Table 6: hold timing, area, power, utilization,
#      clock tree, LVS (verify_lvs); a "B: STAGE" time stamp per step; exit at the end
set sh_continue_on_error true
set DESIGN mkQRDecoder
set NET $env(QR_NET)
set T   $env(QR_PERIOD)
set L   $env(QR_L)
proc stage {s} { puts "B: STAGE $s [clock format [clock seconds] -format {%d %b %H:%M}]" }
stage "start: $DESIGN, netlist $NET, period $T ns, core ${L} x ${L} um"
catch { set_host_options -max_cores $env(QR_CORES) }
# B: v2: 595,875 "via dropped" power warnings filled a 117 MB log in run 1
suppress_message PGRT-030

source ../scripts/icc_lib_setup.tcl
source ../scripts/icc_initial_setup.tcl
read_verilog -top $DESIGN -cell $DESIGN [list $NET]
read_sdc ../scripts/qr_icc.sdc
link -force
current_design
# B: v6: same dont_use cells as DC, so ICC does not size cells into them
if {[info exists env(QR_DONT_USE)] && $env(QR_DONT_USE) ne ""} {
  foreach pat $env(QR_DONT_USE) {
    set lc [get_lib_cells -quiet */$pat]
    if {[sizeof_collection $lc] > 0} { set_dont_use $lc }
    stage "dont_use $pat: [sizeof_collection $lc] lib cells, [sizeof_collection [get_cells -quiet -hier -filter "ref_name=~$pat"]] used in netlist"
  }
}
#
create_port {VDD VSS} -direction inout
set_user_grid -user_grid {{0 0} {0.0005 0.0005}}
set_fp_pin_constraints -allowed_layers {M2 M3} -pin_spacing 4
create_floorplan -control_type width_and_height -core_width $L -core_height $L
derive_pg_connection -power_net {VDD} -ground_net {VSS} -power_pin {VDD} -ground_pin {VSS}
derive_pg_connection -power_net {VDD} -ground_net {VSS} -tie
connect_net {VDD} {VDD}
connect_net {VSS} {VSS}
stage "floorplan done"
# B: same layers / widths as the course, wider steps (course: 10 um core)
create_power_straps -direction vertical -start_at 3.000 -nets {VDD VSS} -layer M6 \
  -width 0.5 -configure step_and_stop -step 20 -stop $L -pitch_within_group 1.0
create_power_straps -direction horizontal -start_at 2.500 -nets {VDD VSS} -layer M5 \
  -width 0.5 -configure step_and_stop -step 20 -stop $L -pitch_within_group 1.0
create_power_straps -direction vertical -start_at 2.000 -nets {VDD VSS} -layer M4 \
  -width 0.2 -configure step_and_stop -step 10 -stop $L -pitch_within_group 0.3
preroute_standard_cells -extend_for_multiple_connections  -extension_gap 50 -connect horizontal \
  -fill_empty_rows  -port_filter_mode off -cell_master_filter_mode off -cell_instance_filter_mode \
  off -voltage_area_filter_mode off -route_type {P/G Std. Cell Pin Conn}
derive_pg_connection -power_net {VDD} -ground_net {VSS} -power_pin {VDD} -ground_pin {VSS}
derive_pg_connection -power_net {VDD} -ground_net {VSS} -power_pin {VDD} -ground_pin {VSS} -tie
set_operating_conditions -analysis_type on_chip_variation -max ss0p72v125c -min ff0p88v125c \
  -min_library {saed14rvt_base_ff0p88v125c} -max_library {saed14rvt_base_ss0p72v125c}
stage "power grid done"
#
set_auto_disable_drc_nets -constant false
set_fix_hold CLK
set_app_var enable_recovery_removal_arcs true
set_place_opt_strategy -layer_optimization_effort high
set_place_opt_strategy -consider_routing  true
# B: v5: optional local density limit (env QR_DENSITY, e.g. 0.65)
if {[info exists env(QR_DENSITY)] && $env(QR_DENSITY) ne ""} {
  set_app_var placer_max_cell_density_threshold $env(QR_DENSITY)
  stage "local cell density limit $env(QR_DENSITY)"
}
create_fp_placement -effort high
derive_pg_connection -power_net {VDD} -ground_net {VSS} -power_pin {VDD} -ground_pin {VSS}
derive_pg_connection -power_net {VDD} -ground_net {VSS} -power_pin {VDD} -ground_pin {VSS} -tie
if {[info exists env(QR_MAXFO)]} { set_max_fanout $env(QR_MAXFO) [current_design] }
place_opt -effort high -congestion -continue_on_missing_scandef
if {[info exists env(QR_MAXFO)]} { catch { psynopt -only_design_rule } }
set unq_input_list [all_inputs]
foreach_in_collection unq_clock_element [all_clocks] {
  set unq_clock_name [get_port $unq_clock_element]
  set unq_input_list [remove_from_collection $unq_input_list $unq_clock_name]
}
group_path -name f2f -from [all_registers]  -to [all_registers] -critical_range 0.7
group_path -name i2f -from $unq_input_list -to [all_registers] -critical_range 0.7
group_path -name f2o -from [all_registers]  -to [all_outputs]   -critical_range 0.7
group_path -name i2o -from $unq_input_list -to [all_outputs]   -critical_range 0.7
report_timing -delay_type max -transition > ../reports/PlaceOpt_Timing
report_qor > ../reports/PlaceOpt_QOR
report_placement_utilization > ../reports/PlaceOpt_Util
save_mw_cel -as ${DESIGN}_PlaceOpt
stage "placement done"
# B: v7: TA notice 3 Nov 23:33: grading uses PlaceOpt QoR; CTS and routing not required.
# QR_STOP=place stops here (PlaceOpt_* reports and the PlaceOpt cell are already saved).
if {[info exists env(QR_STOP)] && $env(QR_STOP) eq "place"} {
  report_power > ../reports/PlaceOpt_Power
  report_area  > ../reports/PlaceOpt_Area
  report_timing -delay_type min > ../reports/PlaceOpt_Hold
  close_mw_lib
  stage "STOPPED after PlaceOpt"
  exit
}
# B: v3b: from here on EXACTLY the commands of the clock test (try_clock.tcl,
# 41 clock DRCs in 9 min): re-open the saved placement, routing on M2..M7,
# no refine/legalize, no read_user_metal_blockage_layer.  (v3/v3a with those
# differences: 88,000 clock DRCs.)
close_mw_cel
open_mw_cel ${DESIGN}_PlaceOpt
stage "placement re-opened"
check_legality -verbose
set_operating_conditions -analysis_type on_chip_variation -max ss0p72v125c -min ff0p88v125c \
  -min_library {saed14rvt_base_ff0p88v125c} -max_library {saed14rvt_base_ss0p72v125c}
# B: v6: dont_use again after re-opening the cell
if {[info exists env(QR_DONT_USE)] && $env(QR_DONT_USE) ne ""} {
  foreach pat $env(QR_DONT_USE) { set lc [get_lib_cells -quiet */$pat]; if {[sizeof_collection $lc] > 0} { set_dont_use $lc } }
}
set_ignored_layers -min_routing_layer M2 -max_routing_layer M7
set_separate_process_options -routing false
set_auto_disable_drc_nets -constant false
remove_ideal_network -all
set_propagated_clock [all_clocks]
set_fix_hold [get_clocks *]
set_app_var cto_enable_drc_fixing true
# path groups again (in case re-opening the cell dropped them)
set unq_input_list [remove_from_collection [all_inputs] [get_ports CLK]]
group_path -name f2f -from [all_registers]  -to [all_registers] -critical_range 0.7
group_path -name i2f -from $unq_input_list -to [all_registers] -critical_range 0.7
group_path -name f2o -from [all_registers]  -to [all_outputs]   -critical_range 0.7
group_path -name i2o -from $unq_input_list -to [all_outputs]   -critical_range 0.7
set cts_instance_name_prefix cts
# B: v2: no crosstalk-driven routing (run 1 spent 13+ h routing clock wires with it)
set_si_options -delta_delay true -route_xtalk_prevention false -static_noise true
set_clock_tree_options -target_skew 0.300 -max_transition 0.350 -max_fanout 32 -layer_list {M3 M4 M5 M6}
# B: v2: step 1 = build the clock tree only (no clock wires yet)
clock_opt -only_cts -no_clock_route -operating_condition min_max
stage "clock tree built (not routed yet)"
# B: v2: step 2 = route only the clock wires, with a limit on repair rounds
route_zrt_group -all_clock_nets -max_detail_route_iterations 10
stage "clock wires routed"
redirect ../reports/Clock_DRC { verify_zrt_route }
derive_pg_connection -power_net {VDD} -ground_net {VSS} -power_pin {VDD} -ground_pin {VSS}
derive_pg_connection -power_net {VDD} -ground_net {VSS} -tie
# B: v4: (v2's "clock_opt -only_psyn -fix_hold_all_clocks" failed with COPT-001;
#        hold is fixed by psynopt below and after routing)
report_clock_timing -type summary > ../reports/ClockSummary
report_timing > ../reports/CTS_Timing
report_qor    > ../reports/CTS_QOR
save_mw_cel -as ${DESIGN}_CTS
stage "CTS done"
#
derive_pg_connection -power_net {VDD} -ground_net {VSS} -power_pin {VDD} -ground_pin {VSS}
derive_pg_connection -power_net {VDD} -ground_net {VSS} -tie
remove_ideal_network CLK
set_propagated_clock [all_clocks]
set_fix_hold [get_clocks *]
# B: v6: fix hold with 0.02 ns extra margin (v4 ended at -0.01 ns)
set_clock_uncertainty -hold 0.02 [all_clocks]
psynopt -only_hold_time
save_mw_cel -as ${DESIGN}_CTSopt
report_timing > ../reports/CTSopt_Timing
report_qor    > ../reports/CTSopt_QOR
derive_pg_connection -power_net {VDD} -ground_net {VSS} -power_pin {VDD} -ground_pin {VSS}
derive_pg_connection -power_net {VDD} -ground_net {VSS} -tie
verify_pg_nets > ../reports/PG_check
stage "hold fix done"
#
set_app_var enable_recovery_removal_arcs true
set_fix_hold [get_clocks *]
set_si_options -delta_delay true -static_noise true
set_route_mode_options -zroute true
set_route_zrt_global_options -default true
set_route_zrt_global_options -effort high
set_route_zrt_track_options -default true
set_app_var routeopt_drc_over_timing true
set_route_zrt_detail_options -timing_driven false -antenna false
set_route_zrt_detail_options -drc_convergence_effort_level high
# B: v7: v6 plateaued at ~1000 DRCs, mostly wrong-way and off-grid jogs from detail-route repair.
# Experiment x_cost (20:43-23:32) showed these costs cut the repair result from ~990 to 879 DRCs.
catch {
  set_route_zrt_common_options \
    -extra_nonpreferred_direction_wire_cost_multiplier_by_layer_name {{M2 10} {M3 20} {M4 20} {M5 20} {M6 20} {M7 20}} \
    -extra_via_off_grid_cost_multiplier_by_layer_name {{M2 20} {M3 20} {M4 20} {M5 20} {M6 20} {M7 20}}
}
set_route_opt_strategy -fix_hold_mode all
route_opt -effort high
derive_pg_connection -power_net {VDD} -ground_net {VSS} -power_pin {VDD} -ground_pin {VSS}
derive_pg_connection -power_net {VDD} -ground_net {VSS} -power_pin {VDD} -ground_pin {VSS} -tie
save_mw_cel -as ${DESIGN}_Route
stage "route done"
# B: v4: post-route hold fix (v3b ended with 119 hold paths at -0.01 ns)
route_opt -incremental -only_hold_time
set_clock_uncertainty -hold 0 [all_clocks]
stage "post-route hold fix done"
# B: v4: DRC repair loop: check, and if DRCs are left, a detail-route repair
# pass with up to 40 rounds; at most 3 passes
proc drc_count {file} {
  redirect $file { verify_zrt_route }
  set t ""; catch { set fh [open $file]; set t [read $fh]; close $fh }
  if {[regexp {Total number of DRCs\s*=\s*([0-9]+)} $t -> n]} { return $n }
  return -1
}
proc drc_repair {tag} {
  for {set i 1} {$i <= 5} {incr i} {
    set n [drc_count ../reports/DRC_${tag}_$i]
    stage "$tag check $i: $n DRCs"
    if {$n == 0} { return }
    route_zrt_detail -incremental true -max_number_iterations 40
  }
  stage "$tag after 5 passes: [drc_count ../reports/DRC_${tag}_end] DRCs"
}
drc_repair route
#
insert_stdcell_filler \
  -cell_with_metal "SAEDRVT14_FILL64 SAEDRVT14_FILL32 SAEDRVT14_FILL16 SAEDRVT14_FILL3 SAEDRVT14_FILL2 SAEDRVT14_FILL1" \
  -connect_to_power {VDD} -connect_to_ground {VSS}
derive_pg_connection -power_net {VDD} -ground_net {VSS} -power_pin {VDD} -ground_pin {VSS}
derive_pg_connection -power_net {VDD} -ground_net {VSS} -tie
save_mw_cel -as ${DESIGN}_fillers
stage "fillers done"
drc_repair fillers
#
# B: final checks and Table 6 reports (on the finished layout)
redirect ../reports/DRCreport { verify_zrt_route }
redirect ../reports/LVSreport { verify_lvs -ignore_floating_port -ignore_floating_net -check_open_locator -check_short_locator }
report_timing -transition -capacitance -crosstalk_delta > ../reports/RouteOpt_Timing
report_timing -delay_type min > ../reports/RouteOpt_Hold
report_qor   > ../reports/RouteOpt_QOR
report_area  > ../reports/RouteOpt_Area
report_power > ../reports/RouteOpt_Power
report_placement_utilization > ../reports/RouteOpt_Util
report_clock_tree -summary > ../reports/ClockTree
stage "reports done"
#
change_names -rules verilog -hierarchy
write_verilog -pg -no_corner_pad_cells -no_pad_filler_cells -no_core_filler_cells -supply_statement \
  all -split_bus \
  -force_no_output_references {SAEDRVT14_FILL64 SAEDRVT14_FILL32 SAEDRVT14_FILL16 SAEDRVT14_FILL3 SAEDRVT14_FILL2 SAEDRVT14_FILL1} \
  ../results/${DESIGN}_out.v
write_verilog -no_physical_only_cells -no_pg_pin_only_cells -no_corner_pad_cells ../results/${DESIGN}_for_pt.v
set_write_stream_options -skip_ref_lib_cells
set_write_stream_options -output_pin text -keep_data_type
set_write_stream_options -output_pin geometry
set_write_stream_options -map_layer /home/tools/pdk/SAED14nm_EDK_03_2025/SAED14nm_EDK_TECH_DATA/map/saed14nm_1p9m_gdsin_gdsout.map
save_mw_cel -as ${DESIGN}_final
write_stream -format gds -cells ${DESIGN}_final ../results/${DESIGN}.gds
close_mw_lib
stage "ALL DONE"
exit
