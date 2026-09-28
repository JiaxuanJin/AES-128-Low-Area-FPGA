// ----------------------------------------------------------------------
// Module: gmul2_xtime
// Function: Implement multiply by 2 (xtime) in GF(2^8)
// Logic: (a << 1) ^ (a & 0x80 ? 0x1B : 0x00)
// Pure combinational logic
// ----------------------------------------------------------------------
module gmul2_xtime (
    input  wire [7:0] a,      // Input data
    output wire [7:0] result  // Output a * 2
);

    // Logic description:
    // 1. Left shift by 1: a << 1
    // 2. If MSB a[7] is 1, XOR with irreducible polynomial 0x1B
    
    wire [7:0] mask;
    assign mask = (a[7] == 1'b1) ? 8'h1B : 8'h00;

    // Result = (a << 1) XOR mask
    assign result = (a << 1) ^ mask;

endmodule
