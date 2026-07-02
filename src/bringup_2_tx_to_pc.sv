`timescale 1ns / 1ps

module top_uart_basys3_pc_tx(

    input logic clk,    
    input logic reset,
    input logic tx_start,
    output logic tx
    
    );
    

    logic [7:0] tx_byte = 8'h43;
    logic tx_busy;
    
    logic tx_start_prev;
    logic tx_start_pulse;
    
    
    always_ff @(posedge clk) begin
    
        if(reset)
            tx_start_prev <= 1'd0;
        else
            tx_start_prev <= tx_start;    

    end
    
   assign tx_start_pulse = tx_start && ~tx_start_prev;   
    
    
    uart_tx DUT_TX (
    
        .clk(clk),
        .reset(reset),
        .tx_start(tx_start_pulse),
        .tx_byte(tx_byte),
        .tx_busy(tx_busy),
        .tx(tx)
        
    );    


endmodule
