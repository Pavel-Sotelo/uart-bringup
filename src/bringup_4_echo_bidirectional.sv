`timescale 1ns / 1ps



module top_uart_basys3_pc_echo(

    input  logic clk,    
    input  logic reset,
    input  logic rx,
    output logic tx
        
    );
    
    logic [7:0] tx_byte;
    logic tx_busy;        
    
    logic [7:0] rx_byte;
    logic done;    
    

    assign tx_start = done;

    
    uart_tx DUT_TX (
    
        .clk(clk),
        .reset(reset),
        .tx_start(tx_start),
        .tx_byte(rx_byte),
        .tx_busy(tx_busy),
        .tx(tx)
        
    );        
    
    
    uart_rx RX (

        .clk(clk),
        .reset(reset),
        .rx(rx),
        .rx_byte(rx_byte),
        .done(done)

    );       
    
    
    
    
    
    
    
    
endmodule
