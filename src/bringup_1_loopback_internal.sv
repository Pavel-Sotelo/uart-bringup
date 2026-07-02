`timescale 1ns / 1ps

module top_uart_basys3(

    input clk,
    input reset,
    input tx_start,
    output led


    );


    logic tx_signal;
    logic [7:0] tx_byte;
    logic tx_busy;
    logic [7:0] rx_byte;
    logic done;      
   
    //We assign a random byte just for test purposes
    
    assign tx_byte = 8'd157;

    //UART instantiation for TX and RX

    uart_tx TX (
    
        .clk(clk),
        .reset(reset),
        .tx_start(tx_start),
        .tx_byte(tx_byte),
        .tx_busy(tx_busy),
        .tx(tx_signal)
        
    );

    uart_rx RX (

        .clk(clk),
        .reset(reset),
        .rx(tx_signal),
        .rx_byte(rx_byte),
        .done(done)

    );   
    
    //The led will indicate a successful transmition
 
    assign led = done && (rx_byte == tx_byte);   
    
endmodule