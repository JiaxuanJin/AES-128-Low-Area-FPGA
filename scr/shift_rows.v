// ----------------------------------------------------------------------
// Module: shift_rows
// Function: AES ShiftRows transformation (Cyclic Row Shift)
// Byte ordering: Big-endian (MSB = first byte)
//
// State matrix layout in 128-bit vector (big-endian):
//   Col0:       Col1:      Col2:      Col3:
//   [127:120]  [95:88]   [63:56]   [31:24]    Row 0
//   [119:112]  [87:80]   [55:48]   [23:16]    Row 1
//   [111:104]  [79:72]   [47:40]   [15:8]     Row 2
//   [103:96]   [71:64]   [39:32]   [7:0]      Row 3
// ----------------------------------------------------------------------
module shift_rows (
    input  wire [127:0] state_in,
    output wire [127:0] state_out
);

    // Row 0: No shift
    assign state_out[127:120] = state_in[127:120]; // Col0
    assign state_out[95:88]   = state_in[95:88];   // Col1
    assign state_out[63:56]   = state_in[63:56];   // Col2
    assign state_out[31:24]   = state_in[31:24];   // Col3

    // Row 1: Left circular shift by 1
    // [Col0,Col1,Col2,Col3] <- [Col1,Col2,Col3,Col0]
    assign state_out[119:112] = state_in[87:80];   // Col0 <- Col1
    assign state_out[87:80]   = state_in[55:48];   // Col1 <- Col2
    assign state_out[55:48]   = state_in[23:16];   // Col2 <- Col3
    assign state_out[23:16]   = state_in[119:112]; // Col3 <- Col0

    // Row 2: Left circular shift by 2
    // [Col0,Col1,Col2,Col3] <- [Col2,Col3,Col0,Col1]
    assign state_out[111:104] = state_in[47:40];   // Col0 <- Col2
    assign state_out[79:72]   = state_in[15:8];    // Col1 <- Col3
    assign state_out[47:40]   = state_in[111:104]; // Col2 <- Col0
    assign state_out[15:8]    = state_in[79:72];   // Col3 <- Col1

    // Row 3: Left circular shift by 3 (= Right circular shift by 1)
    // [Col0,Col1,Col2,Col3] <- [Col3,Col0,Col1,Col2]
    assign state_out[103:96]  = state_in[7:0];     // Col0 <- Col3
    assign state_out[71:64]   = state_in[103:96];  // Col1 <- Col0
    assign state_out[39:32]   = state_in[71:64];   // Col2 <- Col1
    assign state_out[7:0]     = state_in[39:32];   // Col3 <- Col2

endmodule
