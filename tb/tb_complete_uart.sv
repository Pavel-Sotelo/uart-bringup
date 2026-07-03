`timescale 1ns / 1ps

module tb_complete_uart();

    //shared clock and reset in both RX and TX, UART is asychronous, but for testbench purposes we will share clock

    logic clk, reset;

    //tx_signal: output for tx, input for rx

    logic tx_signal;

    //Signal declarations of TX

    logic tx_start;
    logic [7:0] tx_byte;
    logic tx_busy;

    //Signal declarations of RX

    logic [7:0] rx_byte;
    logic done;

    //expected_byte to compare it to the final rx_byte. we dont compare it to DUT_TX.tx_byte)ff because that byte might changed during the comparation

    logic [7:0] expected_byte;

    //DUT Instantiations (TX to RX)

    uart_tx DUT_TX (

        .clk(clk),
        .reset(reset),
        .tx_start(tx_start),
        .tx_byte(tx_byte),
        .tx_busy(tx_busy),
        .tx(tx_signal)

    );

    uart_rx DUT_RX (

        .clk(clk),
        .reset(reset),
        .rx(tx_signal),
        .rx_byte(rx_byte),
        .done(done)

    );

    localparam CLK_PERIOD = 10;      //10ns period
    localparam BIT_TIME   = 868;     //cycles per UART bit

    //Clock generation

    initial clk = 0;
    always #(CLK_PERIOD/2.0) clk = ~clk;

    //TASKS:

    integer i;

    //task to verify each single tx_signal data bit

    task verify_tx;

        //If we want to start another data immediately after (back to back), we trigger tx_start HIGH in stop state (as a parameter if we want)
        //We might want as well to load the next back to back byte during STOP state, as a parameter

        input back_to_back;
        input [7:0] back_to_back_byte;

        begin
            //start bit tx verification

            if (tx_signal == 1'd0 && DUT_TX.state == DUT_TX.START)
                $display("PASS START TX_SIGNAL. tx_signal after tx_start is LOW (START BIT)");
            else if (tx_signal !== 1'd0)
                $display("FAIL START TX_SIGNAL. tx_signal should be LOW after tx_start. got %b", tx_signal);
            else if (DUT_TX.state !== DUT_TX.START)
                $display("FAIL START STATE. state should be START after tx_start. got %b", DUT_TX.state);

            repeat(568) @(posedge clk);
            #1;

            //each data bit tx verification

            for(i = 0; i < 8; i = i + 1) begin

                if(tx_signal !== DUT_TX.tx_byte_ff[i])
                   $display("FAILED tx_signal = tx_byte_ff[%0d]. got %b", i, tx_signal);
                else
                   $display("PASSED tx_signal = tx_byte_ff[%0d] = %b", i, tx_signal);

                repeat(BIT_TIME) @(posedge clk);
                #1;

            end

            //stop bit tx verification

            if (tx_signal == 1'd1 && DUT_TX.state == DUT_TX.STOP)
                $display("PASS STOP TX_SIGNAL. tx_signal after DATA is HIGH (STOP BIT). time %0t", $time);
            else if (tx_signal !== 1'd1)
                $display("FAIL STOP TX_SIGNAL. tx_signal should be HIGH after DATA state. got %b", tx_signal);
            else if (DUT_TX.state !== DUT_TX.STOP)
                $display("FAIL STOP STATE. state should be STOP after DATA. got %b", DUT_TX.state);

            //If we want to start another data immediately after (back to back), we trigger tx_start HIGH in stop state.
            //We might want to load the next back to back byte during STOP state

            tx_start = back_to_back;  tx_byte = back_to_back_byte;

            repeat(BIT_TIME) @(posedge clk);
            #1;

            tx_start = 0;

            if (done !== 1'b1)
                $display("FAIL DONE OUTPUT. expected done=1 after valid byte and valid stop bit, got %b, time %0t", done, $time);
            else
                $display("PASS DONE OUTPUT. done output. Success");

            if(rx_byte !== expected_byte)
                $display("FAIL DATA TRANSFER. rx_byte is not the same as expected_byte(%b). got %b", expected_byte, rx_byte);
            else
                $display("PASS DATA TRANSFER. rx_byte is the same as expected_byte. Success");
            end

    endtask

    //System Verilog Assertions

        //SVA 1. When tx state is IDLE, tx_signal must be always HIGH

        property p_idle_tx_high;
            @(posedge clk) disable iff (reset)
            (DUT_TX.state == DUT_TX.IDLE) |-> (tx_signal == 1'd1);
        endproperty

        check_p_idle_tx_high: assert property (p_idle_tx_high)
            else $display("TX_SIGNAL HIGH IN TX IDLE STATE ASSERTION FAILED. at time  %0t", $time);

        //SVA 2. When state is START, tx must be always LOW

        property p_start_tx_low;
            @(posedge clk) disable iff (reset)
            (DUT_TX.state == DUT_TX.START) |-> (tx_signal == 1'd0);
        endproperty

        check_p_start_tx_low: assert property (p_start_tx_low)
            else $display("TX_SIGNAL LOW IN TX START STATE ASSERTION FAILED. at time  %0t", $time);

       //SVA 3. tx_start HIGH in IDLE state, tx_busy must be HIGH in next cycle

        property p_tx_start_next_cycle_busy;
            @(posedge clk) disable iff (reset)
            (tx_start && (DUT_TX.state == DUT_TX.IDLE)) |=> (tx_busy == 1'd1);
        endproperty

        check_p_tx_start_next_cycle_busy: assert property (p_tx_start_next_cycle_busy)
            else $display("TX_START IN TX IDLE STATE AFTER NEXT CYCLE TX_BUSY IS HIGH FAILED. at time  %0t", $time);

        //SVA 4. When state is IDLE, done must always be LOW
        //(we will check rx states since done is part of rx)

        property p_idle_done_low;
            @(posedge clk) disable iff (reset)
            (DUT_RX.state == DUT_RX.IDLE) |-> (done == 1'b0);
        endproperty

        check_p_idle_done_low: assert property (p_idle_done_low)
            else $display("DONE LOW IN RX IDLE STATE ASSERTION FAILED at time %0t", $time);

    //End of SVA

    initial begin

        /*
        Corner cases to cover:

            1. Reset behavior: tx should be HIGH after reset (IDLE state)
            2. Normal tx_start: We activate tx_start, loading as well a tx_byte. in RX DONE state, we check if DONE is HIGH and if rx_byte is the same as the sent byte.
            3. Back to back byte: After stop bit of a byte, immediately send another byte (tx_start in STOP state). checking as well DONE output and a correct rx_byte.
            4. Reset while transfering DATA: while transfering DATA. reset goes HIGH. should be turned back to IDLE state.
        */

        //TC1 begins

        $display("");
        $display("TC1 begins. (normal reset in beginning)");

        reset = 1;

        tx_start = 0; tx_byte = 8'd0;

        repeat(BIT_TIME) @(posedge clk);
        #1;

        reset = 0;

        repeat(BIT_TIME) @(posedge clk);
        #1;

        if(tx_signal !== 1'd1)
            $display("FAIL TC1. tx_signal after reset should be HIGH, since reset goes to IDLE state. got %b", tx_signal);
        else
            $display("PASS TC1. tx_signal after reset is HIGH (IDLE)");

        $display("TC1 finished");

        //TC2 begins

        $display("");
        $display("TC2 begins. (normal byte tranfer)");

        $display("The byte sent will be 150 decimal (%b)", 8'd150);

        tx_start = 1; tx_byte = 8'd150; expected_byte = tx_byte;

        //UART TX will react to tx_start at the very next clock cycle (1, not 868) so, next to that cycle, we are now in START state and the 868 counter starts
        repeat(1) @(posedge clk);

        //We increment the duration of tx_start, just for seeing it more longer in the waveform.
        repeat(300) @(posedge clk); #1;

        tx_start = 0;

        verify_tx(0, 8'd0);

        repeat(BIT_TIME) @(posedge clk);
        #1;

        $display("TC2 finished");

        repeat(1736) @(posedge clk);
        #1;

        //TC3 begins

        $display("");
        $display("TC3 begins. (2 back to back bytes)");

        $display("The first byte sent will be 35 decimal (%b)", 8'd35);

        tx_start = 1; tx_byte = 8'd35; expected_byte = tx_byte;

        //UART TX will react to tx_start at the very next clock cycle (1, not 868) so, next to that cycle, we are now in START state and the 868 counter starts
        repeat(1) @(posedge clk);

        //We increment the duration of tx_start, just for seeing it more longer in the waveform.
        repeat(300) @(posedge clk); #1;

        tx_start = 0;

        //We load the next back to back byte in the first sent byte

        verify_tx(1, 8'd243);

        $display("First byte 35 decimal sent. now immediately in STOP state, tx_start goes to HIGH and another byte is loaded into tx_byte");
        $display("");

        expected_byte = tx_byte;

        //wait for 300 cycles (only to match it with the next 568 cycle in the beginning of the task block)
        repeat(300) @(posedge clk);

        verify_tx(0, 8'd0);

        $display("Second byte 243 decimal sent.");

        repeat(BIT_TIME) @(posedge clk);
        #1;

        $display("TC3 finished");
        $display("");

        repeat(1768) @(posedge clk);
        #1;

        //TC4 begins

        $display("TC4 begins. (reset during DATA tranfer). byte send: 11000100 (196 decimal)");

        $display("The byte sent will be 196 decimal (%b)", 8'd196);

        tx_start = 1; tx_byte = 8'd196; expected_byte = tx_byte;

        //UART TX will react to tx_start at the very next clock cycle (1, not 868) so, next to that cycle, we are now in START state and the 868 counter starts
        repeat(1) @(posedge clk);

        //We increment the duration of tx_start, just for seeing it more longer in the waveform.
        repeat(300) @(posedge clk); #1;

        tx_start = 0;

        //we want to be able to do RESET while transmiting DATA bits of the byte, so verify_task is not functional here since it does its normal data transfer, we will do a little block of code to do this reset.

        //start bit tx verification

        if (tx_signal == 1'd0 && DUT_TX.state == DUT_TX.START)
            $display("PASS START TX_SIGNAL. tx_signal after tx_start is LOW (START BIT)");
        else if (tx_signal !== 1'd0)
            $display("FAIL START TX_SIGNAL. tx_signal should be LOW after tx_start. got %b", tx_signal);
        else if (DUT_TX.state !== DUT_TX.START)
            $display("FAIL START STATE. state should be START after tx_start. got %b", DUT_TX.state);

        repeat(568) @(posedge clk);
        #1;

        //data bit tx verification. we will press RESET during data bit tx = tx_byte[5]

        for(i = 0; i < 5; i = i + 1) begin

            if(tx_signal !== DUT_TX.tx_byte_ff[i])
                $display("FAILED tx_signal = tx_byte_ff[%0d]. got %b", i, tx_signal);
            else
                $display("PASSED tx_signal = tx_byte_ff[%0d] = %b", i, tx_signal);

            repeat(BIT_TIME) @(posedge clk);
            #1;

        end

        //done 4 data bit tranfers. now we in the current cycle of tx_byte[5]

        if(tx_signal !== DUT_TX.tx_byte_ff[5])
            $display("FAILED tx_signal = tx_byte_ff[5]. got %b", tx_signal);
        else
            $display("PASSED tx_signal = tx_byte_ff[5] = %b", tx_signal);

        //WE PRESS RESET

        reset = 1;

        $display("We press reset here");

        repeat(BIT_TIME) @(posedge clk);
        #1;

        reset = 0;

        if (tx_signal == 1'd1 && DUT_TX.state == DUT_TX.IDLE)
            $display("PASS TC4. tx_signal after reset is HIGH - state is IDLE");
        else if (tx_signal !== 1'd1)
            $display("FAIL TC4. tx_signal should be HIGH after reset. got %b", tx_signal);
        else if (DUT_TX.state !== DUT_TX.IDLE)
            $display("FAIL TC4. state should be IDLE after reset. got %b", DUT_TX.state);

        repeat(1736) @(posedge clk);
        #1;

        $display("TC4 finished");
        $display("");
        $display("End of COMPLETE UART LOOPBACK Testbench.");
        $display("");

        $finish;
    end

endmodule
