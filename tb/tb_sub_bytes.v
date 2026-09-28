`timescale 1ns / 1ps

module tb_sub_bytes;

    reg clk;
    reg rst_n;
    reg start;
    reg [127:0] state_in;
    wire [127:0] state_out;
    wire done;

    // Instantiate UUT
    sub_bytes uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .state_in(state_in),
        .state_out(state_out),
        .done(done)
    );

    // Clock gen
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        // Initialize
        rst_n = 0;
        start = 0;
        state_in = 0;
        #20;
        rst_n = 1;

        // Test Case 1: Standard AES Vector
        @(posedge clk);
        state_in <= 128'h193de3bea0f4e22b9ac68d2ae9f84808;
        start    <= 1'b1;
        @(posedge clk);
        start    <= 1'b0;

        wait(done);
        $display("Input:   %h", state_in);
        $display("Output:  %h", state_out);
        $display("Expected: d42711aee0bf98f1b8b45de51e415230");
        
        if (state_out === 128'hd42711aee0bf98f1b8b45de51e415230)
            $display("PASS!");
        else
            $display("FAIL!");

        #100;
        $finish;
    end

endmodule
