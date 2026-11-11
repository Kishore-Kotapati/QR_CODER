# same constraints as DC (team SDC, 40 % IO delay), period 1.2 ns
create_clock -name CLK -period 1.2 -waveform {0.0 0.6} [get_ports CLK]
set_input_delay  -clock CLK 0.48 [all_inputs]
set_output_delay -clock CLK 0.48 [all_outputs]
