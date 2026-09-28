// ----------------------------------------------------------------------
// Module: gmul_gf256
// Function: Implement GF(2^8) multiplication (a * b)
// Optimization: Minimal resource usage (Pure combinational, no registers)
// ----------------------------------------------------------------------
module gmul_gf256 (
    input  wire [7:0] a,
    input  wire [7:0] b,
    output wire [7:0] product
);

    // --- Internal Signals ---
    // a_x1 to a_x8 represent a * x^0 to x^7
    // i.e., a, a*2, a*4, a*8 ...
    wire [7:0] a_x1;
    wire [7:0] a_x2;
    wire [7:0] a_x3;
    wire [7:0] a_x4;
    wire [7:0] a_x5;
    wire [7:0] a_x6;
    wire [7:0] a_x7;
    wire [7:0] a_x8; 

    // --- Instantiate gmul2_xtime chain ---
    // a_x1 = a * 1 = a
    assign a_x1 = a;

    // a_x2 = a * 2 = xtime(a)
    gmul2_xtime U_X2 (.a(a_x1), .result(a_x2));

    // a_x3 = a * 4 = xtime(a * 2)
    gmul2_xtime U_X3 (.a(a_x2), .result(a_x3));

    // a_x4 = a * 8
    gmul2_xtime U_X4 (.a(a_x3), .result(a_x4));

    // a_x5 = a * 16
    gmul2_xtime U_X5 (.a(a_x4), .result(a_x5));

    // a_x6 = a * 32
    gmul2_xtime U_X6 (.a(a_x5), .result(a_x6));

    // a_x7 = a * 64
    gmul2_xtime U_X7 (.a(a_x6), .result(a_x7));

    // a_x8 = a * 128
    gmul2_xtime U_X8 (.a(a_x7), .result(a_x8));


    // --- Product Calculation (XOR Sum) ---
    // product = sum( b[i] * (a * x^i) )
    
    assign product = (b[0] ? a_x1 : 8'h00) ^
                     (b[1] ? a_x2 : 8'h00) ^
                     (b[2] ? a_x3 : 8'h00) ^
                     (b[3] ? a_x4 : 8'h00) ^
                     (b[4] ? a_x5 : 8'h00) ^
                     (b[5] ? a_x6 : 8'h00) ^
                     (b[6] ? a_x7 : 8'h00) ^
                     (b[7] ? a_x8 : 8'h00);

endmodule