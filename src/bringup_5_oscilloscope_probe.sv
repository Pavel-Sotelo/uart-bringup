`timescale 1ns / 1ps

//Stage 5: tx for direct oscilloscope measurement.
//Adds an idle_counter so IDLE gets the same 868-cycle width as every other bit, otherwise IDLE never shows up on the waveform (Bug 5 on readme)

module uart_tx_to_oscilloscope(
    input logic clk,
    input logic reset,
    output logic tx
);

    logic tx_start;
    logic [7:0] tx_byte;
    logic tx_busy;
    logic [9:0] idle_counter;

    localparam FULL_CYCLE = 10'd867;

    assign tx_byte = 8'b11001010;

    //waits FULL_CYCLE cycles in IDLE , then pulses tx_start for one cycle
    always_ff @(posedge clk) begin
        if (reset) begin
            idle_counter <= 10'd0;
            tx_start <= 1'd0;
        end else if (~tx_busy) begin
            tx_start <= 1'd0;
            if (idle_counter == FULL_CYCLE) begin
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
