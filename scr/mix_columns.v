// ----------------------------------------------------------------------
// Module: mix_columns
// Function: AES MixColumns iterative implementation (One column at a time)
// Optimization: Minimum area (shared unit), Latency = 4 cycles
// ----------------------------------------------------------------------
module mix_columns (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire [127:0] state_in,
    output reg  [127:0] state_out,
    output reg          done
);

    // --- State Machine ---
    localparam IDLE       = 3'd0;
    localparam UNIT_START = 3'd1;
    localparam UNIT_WAIT  = 3'd2;
    localparam NEXT_COL   = 3'd3;
    localparam DONE_ST    = 3'd4;

    reg [2:0] state;
    reg [2:0] count;
    reg [127:0] temp_state;

    // Unit connection
    wire [31:0] cur_col_in;
    wire [31:0] cur_col_out;
    reg         unit_start;
    wire        unit_done;

    assign cur_col_in = temp_state[{(3'd3-count), 5'b00000} +: 32];

    mix_column_unit U_MIX_UNIT (
        .clk(clk),
        .rst_n(rst_n),
        .start(unit_start),
        .col_in(cur_col_in),
        .col_out(cur_col_out),
        .done(unit_done)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            state_out  <= 128'h0;
            done       <= 1'b0;
            count      <= 3'd0;
            temp_state <= 128'h0;
            unit_start <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        temp_state <= state_in;
                        count      <= 3'd0;
                        state      <= UNIT_START;
                    end
                end

                UNIT_START: begin
                    unit_start <= 1'b1;
                    state      <= UNIT_WAIT;
                end

                UNIT_WAIT: begin
                    unit_start <= 1'b0;
                    if (unit_done) begin
                        state_out[{(3'd3-count), 5'b00000} +: 32] <= cur_col_out;
                        state <= NEXT_COL;
                    end
                end

                NEXT_COL: begin
                    if (count == 3'd3) begin
                        state <= DONE_ST;
                    end else begin
                        count <= count + 1'b1;
                        state <= UNIT_START;
                    end
                end

                DONE_ST: begin
                    done  <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
