`timescale 1ns / 1ps


module uart_tx(

    input clk,
    input reset,
    input tx_start,
    input [7:0] tx_byte,
    output reg tx,
    output tx_busy
    
    );

    localparam IDLE = 0, START = 1, DATA = 2, STOP = 3;
    reg [1:0] state, next_state;
    
    reg [9:0] cycle_counter;
    reg [3:0] d_counter;
    reg [7:0] tx_byte_ff;
    
    //state register logic
    
    always @(posedge clk) begin
    
        if(reset) 
            state <= IDLE;
        else if(tx_start && state == IDLE)    
            state <= START;
        else if (cycle_counter == 10'd867)
            state <= next_state;

    end
    
    //cycle counter (868 cycles)
    
    always @(posedge clk) begin
    
        if(reset) 
            cycle_counter <= 10'd0;
        else if (cycle_counter == 10'd867)
            cycle_counter <= 10'd0;
        else if (state != IDLE)
            cycle_counter <= cycle_counter + 1'd1;
        else
           cycle_counter <= 10'd0; 

    end        

    //data bit counter
    
    always @(posedge clk) begin
    
        if(state != DATA) 
            d_counter <= 4'd0;
        else if (cycle_counter == 10'd867)
            d_counter <= d_counter + 1'd1;

    end
    
    //tx_byte_ff: it avoids to send another tx_byte input during DATA. it captures only when a byte is not getting send
    
    always @(posedge clk) begin
    
        if (tx_start && (state == IDLE  || state == STOP)) begin
            tx_byte_ff <= tx_byte;
        end              
    end
           
    //state transition logic
    
    always @(*) begin
    
        case(state)
        
           //IDLE does not count with the 868 counter, the counter begins when state is IDLE and tx_start is HIGH, so state <= next_state should be with that conditions since it does not count.
           //after state == IDLE and tx_start = 1 , the counter begins.
           START: next_state = DATA;
            DATA: next_state = (d_counter == 4'd7)? STOP : DATA;
            STOP: next_state = tx_start? START : IDLE;
        
        default: next_state = IDLE;
        
        endcase
    end
    
    //output logic
    
    always @(*) begin
    
        case(state)
    
            IDLE: tx = 1'd1;
           START: tx = 1'd0;
            
            DATA: begin
            
                    case(d_counter)
            
                        4'd0: tx = tx_byte_ff[0];    
                        4'd1: tx = tx_byte_ff[1]; 
                        4'd2: tx = tx_byte_ff[2]; 
                        4'd3: tx = tx_byte_ff[3]; 
                        4'd4: tx = tx_byte_ff[4]; 
                        4'd5: tx = tx_byte_ff[5]; 
                        4'd6: tx = tx_byte_ff[6]; 
                        4'd7: tx = tx_byte_ff[7]; 
            
                        default: tx = 1'd1;
                    endcase
            
                  end
                    
            STOP: tx = 1'd1;
             
            default: tx = 1'd1;      
        endcase
        
    end
    
    assign tx_busy = (state != IDLE);
    
    
endmodule
