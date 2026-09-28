`timescale 1ns / 1ps

module tb_add_round_key;

    reg [127:0] state_in;
    reg [127:0] round_key;
    wire [127:0] state_out;

    // Instantiate UUT
    add_round_key uut (
        .state_in(state_in),
        .round_key(round_key),
        .state_out(state_out)
    );

    initial begin
        // Test Case: AES FIPS-197 Example
        state_in  = 128'h046681e5e0cb199a48f8d10a2806127c;
        round_key = 128'ha0fafe1788542cb123a339392a6c7605;
        
        #10;
        $display("Input State: %h", state_in);
        $display("Round Key:   %h", round_key);
        $display("Output:      %h", state_out);
        $display("Expected:    a49c7ff2689f352b6b5be833026a6479");

        if (state_out === 128'ha49c7ff2689f352b6b5be833026a6479)
            $display("PASS!");
        else
            $display("FAIL!");

        $finish;
    end

endmodule
