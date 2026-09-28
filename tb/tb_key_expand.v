`timescale 1ns / 1ps

module tb_key_expand;

    reg clk;
    reg rst_n;
    reg start;
    reg [3:0] round;
    reg [127:0] key_in;
    wire [127:0] key_out;
    wire done;

    key_expand uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .round(round),
        .key_in(key_in),
        .key_out(key_out),
        .done(done)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst_n = 0; start = 0; round = 0; key_in = 0;
        #20;
        rst_n = 1;

        // Test Case: Round 0 to Round 1 Expansion
        // Key 0: 2b7e151628aed2a6abf7158809cf4f3c
        // Round 1 Constant: 01
        @(posedge clk);
        key_in <= 128'h2b7e151628aed2a6abf7158809cf4f3c;
        round  <= 4'd1;
        start  <= 1'b1;
        @(posedge clk);
        start  <= 1'b0;

        wait(done);
        $display("Master Key: %h", key_in);
        $display("Round 1 Key: %h", key_out);
        $display("Expected:    a0fafe1788542cb123a339392a6c7605");

        if (key_out === 128'ha0fafe1788542cb123a339392a6c7605)
            $display("PASS!");
        else
            $display("FAIL!");

        $finish;
    end

endmodule
