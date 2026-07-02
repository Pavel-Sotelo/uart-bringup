`timescale 1ns / 1ps
// UART RX (Serial receiver with datapath)
// Idle state is when receiving 1, else start the DATA transfer (Start bit is a 0).
module uart_rx(

    input clk,
    input reset,
    input rx, 
    output [7:0] rx_byte,
    output done

); 
    parameter IDLE=0, DATA = 1, DONE = 2, ERROR = 3;
    
    reg [3:0] d_counter;
    reg [1:0] state, next_state;
    reg [7:0] store_rx;
    
    //counter to count the 868 clock cycle
    reg [9:0] cycle_counter;
    
    //the value of rx captured at the midpoint of the bit
    reg sample_rx;
    
    
    //Counter: counts 0 to 867 within whatever state we're in,
    //resets to 0 every time we change state.
    always @(posedge clk) begin
        if (reset) begin
            cycle_counter <= 10'd0;
        end else if (cycle_counter == 10'd867) begin
            cycle_counter <= 10'd0;    //full bit period completed, reset for next bit
        end else begin
            cycle_counter <= cycle_counter + 10'd1;
        end
    end
    
    //Sample rx once, at the midpoint of every bit (433),
    //exactly the same way for every state. 
    always @(posedge clk) begin
        if (cycle_counter == 10'd433) begin
            sample_rx <= rx;
        end
    end

    //State register
    //it advances on cycle_counter==867
    //instead of advancing every single clock edge
    
    always @(posedge clk) begin        
        if (reset) begin
            state <= IDLE;
        end else if (cycle_counter == 10'd867) begin
            state <= next_state;
        end
    end
    
    //Data bit counter
    //stores each data bit every 434 cycles
    // the data bit counter only counts in DATA state
    always @(posedge clk) begin
        if (state != DATA) begin
            d_counter <= 4'd0;
        end else if (cycle_counter == 10'd433) begin
            store_rx[d_counter] <= rx;
                        
        end else if (cycle_counter == 10'd867) begin
            d_counter <= d_counter + 4'd1;
        end
    end    
    
    // State transition logic 
    
    always @(*) begin
        case(state)
            IDLE : next_state = sample_rx ? IDLE : DATA;
            DATA : next_state = (d_counter == 4'd8) ? (sample_rx ? DONE : ERROR) : DATA;
            DONE : next_state = sample_rx ? IDLE : DATA;
            ERROR: next_state = sample_rx ? IDLE : ERROR;
            default: next_state = IDLE;
        endcase
    end
    
    assign done = (state == DONE);
    assign rx_byte = (state == DONE) ? store_rx : 8'd0;
    
endmodule
