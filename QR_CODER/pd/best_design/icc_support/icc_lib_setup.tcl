# Same as the course udcounter/icc1/scripts/icc_lib_setup.tcl (unchanged).
set search_path [ list "/home/tools/pdk/SAED14nm_EDK_03_2025/SAED14nm_EDK_STD_RVT/liberty/nldm/base" ]
set_app_var target_library "saed14rvt_base_ss0p72v125c.db"
set_app_var link_library   "saed14rvt_base_ss0p72v125c.db"
set_min_library saed14rvt_base_ss0p72v125c.db -min_version saed14rvt_base_ff0p88v125c.db
set symbol_library ""
set_tlu_plus_files \
  -max_tluplus /home/tools/pdk/SAED14nm_EDK_03_2025/SAED14nm_EDK_TECH_DATA/tlup/saed14nm_1p9m_Cmax.tlup \
  -min_tluplus /home/tools/pdk/SAED14nm_EDK_03_2025/SAED14nm_EDK_TECH_DATA/tlup/saed14nm_1p9m_Cmin.tlup \
  -tech2itf_map /home/tools/pdk/SAED14nm_EDK_03_2025/SAED14nm_EDK_TECH_DATA/map/saed14nm_tf_itf_tluplus.map
