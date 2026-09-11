
#NOTICE, CLOCK IS ALWAYS AT 100 MHZ
set_property -dict { PACKAGE_PIN H4  IOSTANDARD LVCMOS33 } [get_ports { CLK }]; 
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { CLK }];

#RESET BUTTON, PWM BUTTON AND FREQ BUTTON
set_property -dict { PACKAGE_PIN D14 IOSTANDARD LVCMOS33 } [get_ports RESET];
set_property -dict { PACKAGE_PIN M4 IOSTANDARD LVCMOS33 } [get_ports SELECT1];
set_property -dict { PACKAGE_PIN C3 IOSTANDARD LVCMOS33 } [get_ports SELECT2];

#GPIO PIN FOR PWM in output
set_property -dict { PACKAGE_PIN L1 IOSTANDARD LVCMOS33 } [get_ports DAC_DIN];
set_property -dict { PACKAGE_PIN M1 IOSTANDARD LVCMOS33 } [get_ports DAC_CLK];
set_property -dict { PACKAGE_PIN N1 IOSTANDARD LVCMOS33 } [get_ports DAC_SYNC];
set_property -dict { PACKAGE_PIN N14 IOSTANDARD LVCMOS33 } [get_ports INT_PIN];
