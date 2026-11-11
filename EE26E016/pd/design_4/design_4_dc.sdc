create_clock -name CLK -period 2.0 [get_ports CLK]
set_input_delay -clock CLK 0.8 [remove_from_collection [all_inputs] [get_ports CLK]]
set_output_delay -clock CLK 0.8 [all_outputs]
