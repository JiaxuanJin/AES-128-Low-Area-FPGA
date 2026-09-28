`include "aes_defines.vh"

// ----------------------------------------------------------------------
// Module: key_expand
// Function: AES-128 Key Expansion (Generates NEXT round key from PREVIOUS)
// Optimization: Word-serial (32-bit) to save area, shares S-Box
// ----------------------------------------------------------------------
module key_expand (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire [3:0]   round,      // Current round index (1 to 10)
    input  wire [127:0] key_in,     // Previous round key
    output reg  [127:0] key_out,    // Next round key
    output reg          done
);

    // --- FSM States ---
    localparam IDLE     = 2'd0;
    localparam SUB_ROT  = 2'd1; // Special operations for Word 0
    localparam GEN_WORD = 2'd2; // Generating words 0, 1, 2, 3
    localparam DONE_ST  = 2'd3;

    reg [1:0] state;
    reg [1:0] word_idx; // 0 to 3

    // --- S-Box Logic for SubWord ---
    // In a full system, we might share the BRAM S-Box. 
    // For now, we'll use a small combinational S-Box or its own BRAM to keep the module independent.
    // Let's use the BRAM-based XPM approach for consistency.
    wire [7:0] sbox_in;
    wire [7:0] sbox_out;
    reg  [7:0] sbox_in_reg;

    assign sbox_in = sbox_in_reg;

    xpm_memory_sprom #(
        .ADDR_WIDTH_A(8),
        .MEMORY_INIT_FILE("sbox_data.mem"),
        .MEMORY_OPTIMIZATION("true"),
        .MEMORY_SIZE(2048),
        .MEMORY_PRIMITIVE("block"),
        .READ_DATA_WIDTH_A(8),
        .READ_LATENCY_A(1)
    ) U_SBOX_KEY (
        .clka(clk),
        .addra(sbox_in),
        .douta(sbox_out),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(1'b0),
        .injectdbiterra(1'b0), .injectsbiterra(1'b0), .dbiterra(), .sbiterra()
    );

    // --- RCON Table ---
    // --- Rcon Table (BRAM) ---
    wire [7:0] rcon_out;
    xpm_memory_sprom #(
        .ADDR_WIDTH_A(4),              // 16 entries for 4-bit round index
        .MEMORY_INIT_FILE("rcon_data.mem"),
        .MEMORY_OPTIMIZATION("true"),
        .MEMORY_SIZE(128),             // 16 * 8 bits
        .MEMORY_PRIMITIVE("block"),
        .READ_DATA_WIDTH_A(8),
        .READ_LATENCY_A(1)
    ) U_RCON (
        .clka(clk),
        .addra(round),
        .douta(rcon_out),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(1'b0),
        .injectdbiterra(1'b0), .injectsbiterra(1'b0), .dbiterra(), .sbiterra()
    );

    // Registers for Word processing
    reg [31:0] temp_word;
    reg [31:0] prev_w3;
    reg [2:0] sub_count; // Need one more bit for extra wait state

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            key_out <= 128'h0;
            done <= 1'b0;
            word_idx <= 2'd0;
            sub_count <= 3'd0;
            sbox_in_reg <= 8'h0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        prev_w3 <= key_in[31:0];
                        word_idx <= 2'd0;
                        sub_count <= 3'd0;
                        // Pre-load first S-Box address
                        sbox_in_reg <= key_in[23:16]; // b1 after rotation
                        state <= SUB_ROT;
                    end
                end

                SUB_ROT: begin
                    // RotWord: [b0 b1 b2 b3] -> [b1 b2 b3 b0]
                    // With BRAM latency: addr provided, data valid next cycle
                    case (sub_count)
                        3'd0: begin 
                            // Address for b1 was set in IDLE
                            // Next address: b2
                            sbox_in_reg <= prev_w3[15:8];
                            sub_count <= 3'd1;
                        end
                        3'd1: begin
                            // sbox_out now has S(b1)
                            temp_word[31:24] <= sbox_out;
                            // Next address: b3
                            sbox_in_reg <= prev_w3[7:0];
                            sub_count <= 3'd2;
                        end
                        3'd2: begin
                            // sbox_out now has S(b2)
                            temp_word[23:16] <= sbox_out;
                            // Next address: b0
                            sbox_in_reg <= prev_w3[31:24];
                            sub_count <= 3'd3;
                        end
                        3'd3: begin
                            // sbox_out now has S(b3)
                            temp_word[15:8] <= sbox_out;
                            sub_count <= 3'd4;
                        end
                        3'd4: begin
                            // sbox_out now has S(b0)
                            // temp_word[7:0] will be set in GEN_WORD
                            state <= GEN_WORD;
                            sub_count <= 3'd0;
                        end
                    endcase
                end

                GEN_WORD: begin
                    // Note: rcon_out is being read continuously based on 'round' input
                    // It has 1 cycle latency from when round was set (in top-level at START_EXPAND)
                    case (word_idx)
                        2'd0: begin
                            // w0 = key_in[127:96] ^ (SubWord(RotWord(key_in[31:0])) ^ Rcon)
                            // temp_word holds [S(B1), S(B2), S(B3), X]
                            // sbox_out holds S(B0)
                            // Rcon must be XORed with the FIRST byte of the word
                            key_out[127:96] <= key_in[127:96] ^ {temp_word[31:24] ^ rcon_out, temp_word[23:16], temp_word[15:8], sbox_out};
                            word_idx <= 2'd1;
                        end
                        2'd1: begin
                            key_out[95:64] <= key_in[95:64] ^ key_out[127:96];
                            word_idx <= 2'd2;
                        end
                        2'd2: begin
                            key_out[63:32] <= key_in[63:32] ^ key_out[95:64];
                            word_idx <= 2'd3;
                        end
                        2'd3: begin
                            key_out[31:0] <= key_in[31:0] ^ key_out[63:32];
                            state <= DONE_ST;
                        end
                    endcase
                end

                DONE_ST: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
