// ----------------------------------------------------------------------
// Module: add_round_key
// Function: AES AddRoundKey transformation (Bitwise XOR)
// Optimization: Purely combinational (Zero latency, Minimal area)
// ----------------------------------------------------------------------
module add_round_key (
    input  wire [127:0] state_in,
    input  wire [127:0] round_key,
    output wire [127:0] state_out
);

    assign state_out = state_in ^ round_key;

endmodule
