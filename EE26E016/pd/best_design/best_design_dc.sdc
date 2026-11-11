create_clock -name CLK -period 1.2 [get_ports CLK]
set_input_delay -clock CLK 0.48 [remove_from_collection [all_inputs] [get_ports CLK]]
set_output_delay -clock CLK 0.48 [all_outputs]
