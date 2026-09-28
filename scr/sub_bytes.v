// ----------------------------------------------------------------------
// Module: sub_bytes
// Function: AES SubBytes transformation using a SINGLE S-Box
// Optimization: Minimum area, LATENCY = 17 cycles
// ----------------------------------------------------------------------
module sub_bytes (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire [127:0] state_in,
    output reg  [127:0] state_out,
    output reg          done
);

    // --- State Machine ---
    localparam IDLE = 2'd0;
    localparam CALC = 2'd1;
    localparam DONE = 2'd2;

    reg [1:0] state;
    reg [3:0] count; // Counter from 0 to 15 (16 bytes)
    reg [127:0] temp_state;

    // S-Box instantiation
    wire [7:0] sbox_in;
    wire [7:0] sbox_out;

    // Pick the current byte from temp_state based on count
    // Note: addr is muxed based on count
    assign sbox_in = temp_state[{count, 3'b000} +: 8];

    // XPM_MEMORY_SPROM: Single Port ROM (BRAM) 
    // This inline instantiation replaces the separate sbox_sync module
    xpm_memory_sprom #(
        .ADDR_WIDTH_A(8),              // 256 entries
        .MEMORY_INIT_FILE("sbox_data.mem"), // Load S-Box data from external file
        .MEMORY_OPTIMIZATION("true"),
        .MEMORY_SIZE(2048),            // 256 * 8 bits
        .MEMORY_PRIMITIVE("block"),      // Force Block RAM usage
        .READ_DATA_WIDTH_A(8),
        .READ_LATENCY_A(1)             // Standard BRAM latency
    )
    U_SBOX (
        .clka(clk),
        .addra(sbox_in),
        .douta(sbox_out),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(1'b0),
        .injectdbiterra(1'b0),
        .injectsbiterra(1'b0),
        .dbiterra(),
        .sbiterra()
    );

    // FSM Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            state_out  <= 128'h0;
            done       <= 1'b0;
            count      <= 4'd0;
            temp_state <= 128'h0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        temp_state <= state_in;
                        count      <= 4'd0;
                        state      <= CALC;
                    end
                end

                CALC: begin
                    // Byte substitution (S-Box output is valid 1 cycle after addr)
                    // We need a subtle delay or pipelining here.
                    // Cycle 0: provide addr to sbox
                    // Cycle 1: read data from sbox, store it, provide next addr
                    
                    if (count < 15) begin
                        // This logic is slightly tricky due to BRAM latency.
                        // We store the PREVIOUS sbox_out while providing the CURRENT addr.
                        if (count > 0) begin
                            state_out[{(count-4'd1), 3'b000} +: 8] <= sbox_out;
                        end
                        count <= count + 1'b1;
                    end else begin
                        // Final byte
                        state_out[{4'd14, 3'b000} +: 8] <= sbox_out;
                        state <= DONE;
                    end
                end

                DONE: begin
                    // Capture the very last byte (count 15)
                    state_out[{4'd15, 3'b000} +: 8] <= sbox_out;
                    done  <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
