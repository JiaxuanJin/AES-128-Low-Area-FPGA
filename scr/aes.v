`include "aes_defines.vh"

// ----------------------------------------------------------------------
// Module: aes
// Function: AES-128 Encryption Top-Level (Iterative Architecture)
// Optimization: Minimal Area, Sequential processing
// ----------------------------------------------------------------------
module aes (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire [127:0] plaintext,
    input  wire [127:0] key,
    output reg  [127:0] ciphertext,
    output reg          done
);

    // --- FSM States ---
    localparam IDLE         = 3'd0;
    localparam INIT_KEY     = 3'd1; // AddRoundKey(0)
    localparam START_EXPAND = 3'd2; // Trigger Key Expansion
    localparam SUB_BYTES    = 3'd3; // Round transformations
    localparam MIX_COLS     = 3'd4;
    localparam ROUND_END    = 3'd5;
    localparam DONE_ST      = 3'd6;

    reg [2:0] state;
    reg [3:0] round_count;

    // --- Internal Registers ---
    reg [127:0] current_state;
    reg [127:0] current_key;

    // --- Transformation Modules Interface ---
    
    // 1. SubBytes
    reg         sb_start;
    wire [127:0] sb_out;
    wire        sb_done;
    sub_bytes U_SUB_BYTES (
        .clk(clk), .rst_n(rst_n), .start(sb_start),
        .state_in(current_state), .state_out(sb_out), .done(sb_done)
    );

    // 2. ShiftRows (Combinational)
    wire [127:0] sr_out;
    shift_rows U_SHIFT_ROWS (
        .state_in(sb_out), .state_out(sr_out)
    );

    // 3. MixColumns
    reg         mc_start;
    wire [127:0] mc_out;
    wire        mc_done;
    mix_columns U_MIX_COLS (
        .clk(clk), .rst_n(rst_n), .start(mc_start),
        .state_in(sr_out), .state_out(mc_out), .done(mc_done)
    );

    // 4. AddRoundKey (Combinational)
    wire [127:0] ark_in_state;
    wire [127:0] ark_out;
    assign ark_in_state = (round_count == 4'd10) ? sr_out : mc_out;
    add_round_key U_ADD_ROUND_KEY (
        .state_in(ark_in_state), .round_key(ke_out), .state_out(ark_out)
    );

    // 5. Key Expansion
    reg         ke_start;
    wire [127:0] ke_out;
    wire        ke_done;
    key_expand U_KEY_EXPAND (
        .clk(clk), .rst_n(rst_n), .start(ke_start),
        .round(round_count), .key_in(current_key), .key_out(ke_out), .done(ke_done)
    );

    reg         ke_ready;

    // --- Control Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            round_count <= 4'd0;
            ciphertext <= 128'h0;
            done <= 1'b0;
            sb_start <= 1'b0;
            mc_start <= 1'b0;
            ke_start <= 1'b0;
            ke_ready <= 1'b0;
            current_state <= 128'h0;
            current_key <= 128'h0;
        end else begin
            // Capture key expansion done signal (only when waiting for it)
            if (state != IDLE && state != START_EXPAND && ke_done) 
                ke_ready <= 1'b1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current_state <= plaintext ^ key;
                        current_key   <= key;
                        round_count   <= 4'd1;
                        ke_ready      <= 1'b0;
                        state         <= START_EXPAND;
                    end
                end

                START_EXPAND: begin
                    ke_start <= 1'b1;
                    sb_start <= 1'b1;
                    ke_ready <= 1'b0; // Clear flag for new round
                    state    <= SUB_BYTES;
                end

                SUB_BYTES: begin
                    ke_start <= 1'b0;
                    sb_start <= 1'b0;
                    if (sb_done) begin
                        if (round_count == 4'd10) begin
                            state <= ROUND_END;
                        end else begin
                            mc_start <= 1'b1;
                            state <= MIX_COLS;
                        end
                    end
                end

                MIX_COLS: begin
                    mc_start <= 1'b0;
                    if (mc_done) begin
                        state <= ROUND_END;
                    end
                end

                ROUND_END: begin
                    if (ke_ready) begin
                        current_state <= ark_out;
                        current_key   <= ke_out;
                        ke_ready      <= 1'b0;
                        if (round_count == 4'd10) begin
                            ciphertext <= ark_out;
                            state <= DONE_ST;
                        end else begin
                            round_count <= round_count + 1'b1;
                            state <= START_EXPAND;
                        end
                    end
                end

                DONE_ST: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
