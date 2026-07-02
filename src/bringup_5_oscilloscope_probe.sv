`timescale 1ns / 1ps

module uart_tx_to_oscilloscope(

    input logic clk,    
    input logic reset,
    output logic tx

    );
    
    logic tx_start;
    logic [7:0] tx_byte;
    logic tx_busy;
    
    logic [9:0] idle_counter;        
    
    assign tx_byte = 8'b11001010;
 
    //sequetial block to wait 868 cycles on IDLE state to pulse tx_start HIGH (and immediately return it to LOW) to see IDLE state on oscilloscope
 
    always_ff @(posedge clk) begin
    
        if(reset) begin
            idle_counter <= 10'd0;
            tx_start <= 1'd0;
            
        end else if (~tx_busy) begin

            tx_start <= 1'd0;

            if(idle_counter == 10'd867) begin
                
                tx_start <= 1'd1;
                idle_counter <= 10'd0;

            end else begin
                idle_counter <= idle_counter + 1'd1;
            end
 
        end else begin
        
            idle_counter <= 10'd0;
        
        end
 
    end
    
    uart_tx TX (
    
        .clk(clk),
        .reset(reset),
        .tx_start(tx_start),
        .tx_byte(tx_byte),
        .tx_busy(tx_busy),
        .tx(tx)
        
    );    
    
endmodule
