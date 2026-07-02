##Clock signal

    set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS33 } [get_ports clk]    
    create_clock -add -name sys_clk_pin -period  10.00 -waveform {0 5} [get_ports clk]
    
##Reset button (Central button)

    set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports reset]
    
##Done LED

    set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33} [get_ports led]
        
##tx_start input (left button)

    set_property -dict { PACKAGE_PIN W19 IOSTANDARD LVCMOS33} [get_ports tx_start]