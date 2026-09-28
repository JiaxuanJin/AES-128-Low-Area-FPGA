`timescale 1ns / 1ps

module tb_gmul_gf256;

    // Inputs
    reg [7:0] a;
    reg [7:0] b;

    // Outputs
    wire [7:0] product;

    // Instantiate the Unit Under Test (UUT)
    gmul_gf256 uut (
        .a(a), 
        .b(b), 
        .product(product)
    );

    // Test Variables
    integer i;
    wire [7:0] expected;
    assign expected = gmul_golden(a, b);

    // Direct implementation of gmul Logic for Verification (Golden Model in TB)
    function [7:0] gmul_golden;
        input [7:0] a_val;
        input [7:0] b_val;
        reg [7:0] p;
        reg [7:0] temp_a; // Use temp variable instead of modifying input
        integer j;
        begin
            p = 8'h00;
            temp_a = a_val; // Initialize temp_a with input a_val
            for (j = 0; j < 8; j = j + 1) begin
                if (b_val[0] == 1'b1) begin // Check LSB
                    p = p ^ temp_a;
                end
                
                // xtime logic
                if (temp_a[7] == 1'b1) begin
                   temp_a = (temp_a << 1) ^ 8'h1B;
                end else begin
                   temp_a = temp_a << 1;
                end
                
                b_val = b_val >> 1; // Shift b right
            end
            gmul_golden = p;
        end
    endfunction

    initial begin
        // Initialize Inputs
        a = 0;
        b = 0;
        
        // Wait for potential reset (none in comb logic, but good practice)
        #10;
        
        $display("--------------------------------------------------");
        $display("Starting Testbench for gmul_gf256 (Combinational)");
        $display("--------------------------------------------------");

        // Test Case 1: Zero Multiplication
        a = 8'h57; b = 8'h00; #10;
        check_result(a, b);

        a = 8'h00; b = 8'h13; #10;
        check_result(a, b);

        // Test Case 2: Identity Multiplication (multiply by 1)
        a = 8'h57; b = 8'h01; #10;
        check_result(a, b);

        a = 8'h01; b = 8'h57; #10;
        check_result(a, b);

        // Test Case 3: AES Example Vectors (from FIPS-197 or standard examples)
        // Example: {57} * {13} = {FE}  (hex)
        a = 8'h57; b = 8'h13; #10;
        check_result(a, b);  // Existing logic should match this

        // Example: {57} * {83} = {C1}
        a = 8'h57; b = 8'h83; #10;
        check_result(a, b);
        
        // Random Testing
        $display("Running 100 Random Test Vectors...");
        for (i = 0; i < 100; i = i + 1) begin
            a = $random;
            b = $random;
            #10;
            check_result(a, b);
        end

        $display("--------------------------------------------------");
        $display("Testbench Completed.");
        $display("--------------------------------------------------");
        $finish;
    end

    // Verification Task
    task check_result;
        input [7:0] in_a;
        input [7:0] in_b;
        begin
            if (product !== expected) begin
                $display("ERROR: a=%h, b=%h | Expected=%h, Got=%h", in_a, in_b, expected, product);
            end else begin
                // Uncomment for verbose output
                // $display("PASS: a=%h, b=%h -> %h", in_a, in_b, product);
            end
        end
    endtask
      
endmodule
