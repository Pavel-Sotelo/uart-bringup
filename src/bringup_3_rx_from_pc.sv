`timescale 1ns / 1ps

module top_uart_basys3_pc_rx(

    input logic clk,    
    input logic reset,
    input logic rx, 
    output logic led
    
    );
    
    logic [7:0] rx_byte;
    logic done;
    
    logic led_reg;
    
    
    always_ff @(posedge clk) begin
    
        if(reset)
            led_reg <= 1'd0;
        else if (done && (rx_byte == 8'h41))
            led_reg <= 1'd1;            
        else if (done && (rx_byte == 8'h42))
            led_reg <= 1'd0;         
    
    end
    
    
    
    uart_rx RX (

        .clk(clk),
        .reset(reset),
        .rx(rx),
        .rx_byte(rx_byte),
        .done(done)

    );       
    
    assign led = led_reg;    
    

endmodule
