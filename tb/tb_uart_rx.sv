`timescale 1ns / 1ps

module tb_uart_rx();

    //Signal declarations

    logic clk, reset, rx;
    logic [7:0] rx_byte;
    logic done;

    int i;

    localparam CLK_PERIOD = 10;      //10ns period
    localparam BIT_TIME   = 868;     //cycles per UART bit 

    //DUT instantiation

    uart_rx DUT (

        .clk(clk),
        .rx(rx),
        .reset(reset),
        .rx_byte(rx_byte),
        .done(done)

    );

    //Clock generation

    initial clk = 0;
    always #(CLK_PERIOD/2.0) clk = ~clk;

    //Task to send one complete UART frame
    //stop_bit is a parameter so TC3 can deliberately send a broken frame

    task send_byte;
        input [7:0] data;
        input stop_bit;
        begin

            //Start bit
            rx = 0;
            repeat(BIT_TIME) @(posedge clk);
            #1;

            //8 data bits
            for (i = 0; i < 8; i = i + 1) begin
                rx = data[i];
                repeat(BIT_TIME) @(posedge clk);
                #1;
            end

            //Stop bit (or deliberately broken stop bit for TC3)
            rx = stop_bit;
            repeat(BIT_TIME) @(posedge clk);
            #1;

        end
    endtask

    //SystemVerilog Assertions (SVA)

        //SVA 1. When state is IDLE, done must always be LOW

        property p_idle_done_low;
            @(posedge clk) disable iff (reset)
            (DUT.state == DUT.IDLE) |-> (done == 1'b0);
        endproperty

        check_p_idle_done_low: assert property (p_idle_done_low)
            else $display("DONE LOW IN IDLE STATE ASSERTION FAILED at time %0t", $time);

        //SVA 2. When state is ERROR, done must always be LOW

        property p_error_done_low;
            @(posedge clk) disable iff (reset)
            (DUT.state == DUT.ERROR) |-> (done == 1'b0);
        endproperty

        check_p_error_done_low: assert property (p_error_done_low)
            else $display("DONE LOW IN ERROR STATE ASSERTION FAILED at time %0t", $time);

    //End of SVA

    //Main stimulus

    initial begin

        /*
        Corner cases to cover:

            1. Reset behavior: done should be LOW after reset (IDLE state)
            2. Normal byte: send a valid byte, done should pulse once
            3. Missing stop bit: done should NOT pulse, FSM goes to ERROR state
            4. Reset during reception: FSM should return to IDLE mid-frame
            5. Back to back bytes: start bit of second byte follows immediately after stop bit of first byte

        */

        //TC1. Normal reset time. initialize inputs

        reset = 1; rx = 1;

        repeat(BIT_TIME) @(posedge clk);
        #1;

        reset = 0;

        repeat(BIT_TIME) @(posedge clk);
        #1;

        $display("");
        $display("TC1 begins. (normal reset in beginning)");

        if (done !== 1'b0)
            $display("FAIL TC1. done after reset should be LOW, since reset goes to IDLE state. got %b", done);
        else
            $display("PASS TC1. done after reset is LOW (IDLE)");

        $display("TC1 finished");

        //TC2. Normal byte: send a valid byte, done should pulse once

        $display("");
        $display("TC2 begins. (normal byte reception). byte sent: 10011101");

        send_byte(8'b10011101, 1);

        if (done !== 1'b1)
            $display("FAIL TC2. expected done=1 after valid byte, got %b", done);
        else
            $display("PASS TC2. byte 10011101 received correctly (stop_bit=1)");

        //done should go back to 0 next cycle

        repeat(BIT_TIME) @(posedge clk);
        #1;

        if (done !== 1'b0)
            $display("FAIL TC2b. done should pulse only 1 cycle, still %b", done);
        else
            $display("PASS TC2b. done returns to 0");

        $display("TC2 finished");

        //TC3. Missing stop bit: FSM should go to ERROR, done should NOT pulse

        $display("");
        $display("TC3 begins. (missing stop bit - framing error). byte sent: 00101010");

        repeat(3*BIT_TIME) @(posedge clk);
        #1;

        send_byte(8'b00101010, 0);   //stop_bit = 0, deliberately broken frame

        if (done !== 1'b0)
            $display("FAIL TC3. done should be 0 on framing error, got %b", done);
        else
            $display("PASS TC3. done=0 on missing stop bit (ERROR state)");

        //recover: bring line HIGH to exit ERROR state

        rx = 1;
        repeat(3*BIT_TIME) @(posedge clk);
        #1;

        $display("TC3 finished");

        //TC4. Reset during reception: FSM should return to IDLE mid-frame

        $display("");
        $display("TC4 begins. (reset during reception)");

        rx = 0; repeat(BIT_TIME) @(posedge clk); #1;   //start bit
        rx = 1; repeat(BIT_TIME) @(posedge clk); #1;   //bit 0
        rx = 1; repeat(BIT_TIME) @(posedge clk); #1;   //bit 1
        rx = 1;                                    //bit 2

        //WE PRESS RESET

        reset = 1;

        repeat(BIT_TIME) @(posedge clk);
        #1;

        reset = 0;

        if (DUT.state !== DUT.IDLE)
            $display("FAIL TC4. state after mid-frame reset should be IDLE, got %b", DUT.state);
        else
            $display("PASS TC4. reset correctly returns FSM to IDLE mid-frame");

        rx = 1;
        repeat(3*BIT_TIME) @(posedge clk);
        #1;

        $display("TC4 finished");

        //TC5. Back to back bytes: second byte sent immediately after first byte stop bit

        $display("");
        $display("TC5 begins. (back to back bytes). first byte sent: 11100101");

        send_byte(8'b11100101, 1);   //first byte

        if (done !== 1'b1)
            $display("FAIL TC5a. first byte of back-to-back pair not received correctly, got %b", done);
        else
            $display("PASS TC5a. first byte 11100101 received correctly (back-to-back part 1)");

        $display("First byte sent. now immediately sending second byte: 01000001");

        send_byte(8'b01000001, 1);   //second byte, sent immediately after

        if (done !== 1'b1)
            $display("FAIL TC5b. second byte not received back-to-back, got %b", done);
        else if (rx_byte !== 8'b01000001)
            $display("FAIL TC5b. second byte value wrong, expected 41, got %h", rx_byte);
        else
            $display("PASS TC5b. second byte 01000001 received correctly back-to-back (0x%h)", rx_byte);

        repeat(BIT_TIME) @(posedge clk);
        #1;

        $display("TC5 finished");
        $display("");
        $display("End of UART RX Testbench.");
        $display("");

        $finish;

    end

endmodule