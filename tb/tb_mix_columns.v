`timescale 1ns / 1ps

module tb_mix_columns;

    reg clk;
    reg rst_n;
    reg start;
    reg [127:0] state_in;
    wire [127:0] state_out;
    wire done;

    // Instantiate UUT
    mix_columns uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .state_in(state_in),
        .state_out(state_out),
        .done(done)
    );

    // Clock
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst_n = 0; start = 0; state_in = 0;
        #20;
        rst_n = 1;

        // Test Case: AES First Round Example (Aligned with my_aes.py)
        // Input after ShiftRows: d4 bf 5d 30 | e0 b4 52 ae | b8 41 11 f1 | 1e 27 98 e5
        @(posedge clk);
        state_in <= 128'hd4bf5d30e0b452aeb84111f11e2798e5;
        start    <= 1'b1;
        @(posedge clk);
        start    <= 1'b0;

        wait(done);
        $display("Input:    %h", state_in);
        $display("Output:   %h", state_out);
        $display("Expected: 046681e5e0cb199a48f8d37a2806264c");

        if (state_out === 128'h046681e5e0cb199a48f8d37a2806264c)
            $display("PASS!");
        else
            $display("FAIL!");

        #50;
        $finish;
    end

endmodule
