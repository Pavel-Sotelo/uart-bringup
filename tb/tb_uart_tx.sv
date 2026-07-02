`timescale 1ns / 1ps


module tb_uart_tx();

    //Signal declarations
    
    logic clk, reset, tx_start;
    logic [7:0] tx_byte;
    logic tx_busy, tx;
    
    int i;

    localparam CLK_PERIOD = 10;   //10ns period

    //DUT instantiation

    uart_tx DUT (
    
        .clk(clk),
        .reset(reset),
        .tx_start(tx_start),
        .tx_byte(tx_byte),
        .tx_busy(tx_busy),
        .tx(tx)
        
    );

    //Clock generation
    
    initial clk = 0;
    always #(CLK_PERIOD/2.0) clk = ~clk;

    //task to verify each single tx data bit

    task verify_tx;  
    
       begin
       
            //start bit tx verification
       
            if (tx == 1'd0 && DUT.state == DUT.START)
                $display("PASS START TX. tx after tx_start is LOW (START BIT)");
            else if (tx !== 1'd0)
                $display("FAIL START TX. tx should be LOW after tx_start. got %b", tx);
            else if (DUT.state !== DUT.START)
                $display("FAIL START STATE. state should be START after tx_start. got %b", DUT.state);
    
            repeat(868) @(posedge clk); 
            #1;    

            //each data bit tx verification

            for(i = 0; i < 8; i = i + 1) begin

                if(tx !== DUT.tx_byte_ff[i])
                   $display("FAILED tx = tx_byte_ff[%0d]. got %b", i, tx); 
                else
                   $display("PASSED tx = tx_byte_ff[%0d] = %b", i, tx);
                   
                repeat(868) @(posedge clk); 
                #1;
                    
            end
            
            //stop bit tx verification
            
            if (tx == 1'd1 && DUT.state == DUT.STOP)
                $display("PASS STOP TX. tx after DATA is HIGH (STOP BIT)");
            else if (tx !== 1'd1)
                $display("FAIL STOP TX. tx should be HIGH after DATA state. got %b", tx);
            else if (DUT.state !== DUT.STOP)
                $display("FAIL STOP STATE. state should be STOP after DATA. got %b", DUT.state);
                
            //not capturing yet the clock cycle, in case that we want to start another byte in STOP state, externally. 
              
        end

    endtask
    
    //System Verilog Assertions (SVA)
    
        //SVA 1. When state is IDLE, tx must be always HIGH
        
        property p_idle_tx_high;
            @(posedge clk) disable iff (reset)
            (DUT.state == DUT.IDLE) |-> (tx == 1'd1);
        endproperty
    
        check_p_idle_tx_high: assert property (p_idle_tx_high)
            else $display("TX HIGH IN IDLE STATE ASSERTION FAILED. at time  %0t", $time);  
    
        //SVA 2. When state is START, tx must be always LOW
        
        property p_start_tx_low;
            @(posedge clk) disable iff (reset)
            (DUT.state == DUT.START) |-> (tx == 1'd0);
        endproperty
    
        check_p_start_tx_low: assert property (p_start_tx_low)
            else $display("TX LOW IN START STATE ASSERTION FAILED. at time  %0t", $time); 
            
       //SVA 3. tx_start HIGH in IDLE state, tx_busy must be HIGH in next cycle     
            
        property p_tx_start_next_cycle_busy;
            @(posedge clk) disable iff (reset)
            tx_start && (DUT.state == DUT.IDLE) |=> (tx_busy == 1'd1);
        endproperty
    
        check_p_tx_start_next_cycle_busy: assert property (p_tx_start_next_cycle_busy)
            else $display("TX_START IN IDLE STATE AFTER NEXT CYCLE TX_BUSY IS HIGH FAILED. at time  %0t", $time);        

    //End of SVA


    //Main stimulus
    
    initial begin

        /*
        Corner cases to cover:
        
            1. Reset behavior: tx should be HIGH after reset (IDLE state) 
            2. Normal tx_start: We activate tx_start, loading as well a tx_byte
            3. Back to back byte: After stop bit of a byte, immediately send another byte
            4. Reset while transfering DATA: while transfering DATA. reset goes HIGH. should be turned back to IDLE state
            
        */

        // TC1. Normal reset time. initialize inputs

        reset = 1; tx_start = 0; tx_byte = 8'd0;
               
        repeat(868) @(posedge clk); 
        #1;
        
        reset = 0; 

        repeat(868) @(posedge clk); 
        #1;
        
        $display("");
        $display("TC1 begins. (normal reset in beginning)");
        
        if(tx !== 1'd1)
            $display("FAIL TC1. tx after reset should be HIGH, since reset goes to IDLE state. got %b", tx);
        else
            $display("PASS TC1. tx after reset is HIGH (IDLE)");
            
        $display("TC1 finished");  

        
        //TC2. tx_start HIGH: The transfer begins
        
        $display("");
        $display("TC2 begins (normal tx_start). byte send: 01101101 (109 decimal)");

        tx_byte = 8'd109;  // We load a byte
        tx_start = 1; 

        repeat(868) @(posedge clk); 
        #1;

        tx_start = 0;

        verify_tx();

        repeat(868) @(posedge clk); 
        #1;
        
        $display("TC2 finished");
        $display("");
        
        //TC3. Back to back bytes
        
        $display("TC3 begins. (back to back bytes). first byte send: 11110011 (243 decimal)");
        
        tx_start = 1; tx_byte = 8'd243;
        
        repeat(868) @(posedge clk); 
        #1;
        
        tx_start = 0;
        
        verify_tx();
        
        $display("First byte 243 decimal sent. now immediately in STOP state, tx_start goes to HIGH and another byte is loaded into tx_byte input (01100011)");
        $display("");
        
        tx_start = 1; tx_byte = 8'd99;  
        
        repeat(868) @(posedge clk); 
        #1;
        
        tx_start = 0;
         
        $display("Second byte send immediately after: 01100011 (99 decimal)");
        
        verify_tx();
         
        $display("TC3 finished");
        $display("");
         
        repeat(868) @(posedge clk); 
        #1;                      
        
        //TC4. reset during DATA. to check if it goes to IDLE state correctly
        
        $display("TC4 begins. (reset during DATA tranfer). byte send: 11000100 (196 decimal)");
        
        tx_start = 1; tx_byte = 8'd196;
        
        repeat(868) @(posedge clk); 
        #1;
        
        tx_start = 0;
                 
        //we want to be able to do RESET while transmiting DATA bits of the byte, so verify_task is not functional here since it does its normal data transfer, we will do a little block of code to do this reset.
        
        //start bit tx verification
       
        if (tx == 1'd0 && DUT.state == DUT.START)
            $display("PASS START TX. tx after tx_start is LOW (START BIT)");
        else if (tx !== 1'd0)
            $display("FAIL START TX. tx should be LOW after tx_start. got %b", tx);
        else if (DUT.state !== DUT.START)
            $display("FAIL START STATE. state should be START after tx_start. got %b", DUT.state);
    
        repeat(868) @(posedge clk); 
        #1;    

        //data bit tx verification. we will press RESET during data bit tx = tx_byte[5]      

        for(i = 0; i < 5; i = i + 1) begin

            if(tx !== DUT.tx_byte_ff[i])
                $display("FAILED tx = tx_byte_ff[%0d]. got %b", i, tx); 
            else
                $display("PASSED tx = tx_byte_ff[%0d] = %b", i, tx);
                   
            repeat(868) @(posedge clk); 
            #1;
                    
        end       
        
        //done 4 data bit tranfers. now we in the current cycle of tx_byte[5]

        if(tx !== DUT.tx_byte_ff[5])
            $display("FAILED tx = tx_byte_ff[5]. got %b", tx); 
        else
            $display("PASSED tx = tx_byte_ff[5] = %b", tx);

        //WE PRESS RESET
       
        reset = 1;
        
        repeat(868) @(posedge clk); 
        #1;       
        
        reset = 0;
        
        if (tx == 1'd1 && DUT.state == DUT.IDLE)
            $display("PASS TC4. tx after reset is HIGH - state is IDLE");
        else if (tx !== 1'd1)
            $display("FAIL TC4. tx should be HIGH after reset. got %b", tx);
        else if (DUT.state !== DUT.START)
            $display("FAIL TC4. state should be IDLE after reset. got %b", DUT.state);
        
        repeat(2604) @(posedge clk); 
        #1;
               
        $display("TC4 finished");
        $display("");
        $display("End of UART TX Testbench.");            
        $display("");       
        
        $finish;       
    end

endmodule
