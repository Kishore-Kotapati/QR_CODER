create_clock -name CLK -period 5.0 [get_ports CLK]
set_input_delay -clock CLK 2 [remove_from_collection [all_inputs] [get_ports CLK]]
set_output_delay -clock CLK 2 [all_outputs]
