`timescale 1ns / 1ps

module tb_shift_rows;

    reg [127:0] state_in;
    wire [127:0] state_out;

    // Instantiate UUT
    shift_rows uut (
        .state_in(state_in),
        .state_out(state_out)
    );

    initial begin
        // Test Case: AES FIPS-197 Example (Appendix B)
        // State after SubBytes:
        // d4 e0 b8 1e
        // 27 bf b4 41
        // 11 b2 5d 52
        // ae f1 e5 30
        
        // Input as 128-bit hex string (Column-major sequence)
        state_in = 128'hd42711aee0bf98f1b8b45de51e415230;

        #10;
        $display("Input State:  %h", state_in);
        $display("Output State: %h", state_out);
        
        // Expected result from FIPS-197:
        // d4 e0 b8 1e  (Row 0 - Same)
        // bf b4 41 27  (Row 1 - Shift L 1)
        // 5d 52 11 b2  (Row 2 - Shift L 2)
        // 30 ae f1 e5  (Row 3 - Shift L 3)
        // Formatted 128-bit (Col 0, Col 1, Col 2, Col 3):
        // Col 0: d4 bf 5d 30
        // Col 1: e0 b4 52 ae
        // Col 2: b8 41 11 f1
        // Col 3: 1e 27 b2 e5
        // Full: d4bf5d30e0b452aeb84111f11e27b2e5
        
        $display("Expected:     d4bf5d30e0b452aeb84111f11e27b2e5");

        if (state_out === 128'hd4bf5d30e0b452aeb84111f11e27b2e5)
            $display("PASS!");
        else
            $display("FAIL!");

        $finish;
    end

endmodule
