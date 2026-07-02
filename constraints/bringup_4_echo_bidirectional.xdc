##Clock signal

    set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS33 } [get_ports clk]    
    create_clock -add -name sys_clk_pin -period  10.00 -waveform {0 5} [get_ports clk]
    
##Reset button (Central button)

    set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports reset]
    
    
##tx and rx pin's

    set_property -dict { PACKAGE_PIN A18 IOSTANDARD LVCMOS33} [get_ports tx]
    set_property -dict { PACKAGE_PIN B18   IOSTANDARD LVCMOS33 } [get_ports rx]

