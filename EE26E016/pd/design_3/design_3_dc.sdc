create_clock -name CLK -period 2.5 [get_ports CLK]
set_input_delay -clock CLK 1 [remove_from_collection [all_inputs] [get_ports CLK]]
set_output_delay -clock CLK 1 [all_outputs]
