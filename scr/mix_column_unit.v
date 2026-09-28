module mix_column_unit (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire [31:0]  col_in,  // [s0, s1, s2, s3] big-endian
    output reg  [31:0]  col_out,
    output reg          done
);

    // --- FSM States ---
    localparam IDLE = 2'd0;
    localparam CALC = 2'd1;
    localparam DONE_ST = 2'd2;

    reg [1:0] state;
    reg [3:0] count; // 0 to 15

    // Intermediate Accumulators
    reg [7:0] acc0, acc1, acc2, acc3;

    // --- Coefficient Table (BRAM) ---
    wire [7:0] g_b;
    
    // CRITICAL: Use combinational address to avoid the extra register delay!
    // The BRAM address must be valid BEFORE the clock edge so that
    // douta is available on the NEXT clock edge.
    wire [4:0] coeff_addr = (state == IDLE && start) ? 5'd0 :
                            (state == CALC && count < 4'd15) ? {1'b0, count} + 5'd1 :
                            {1'b0, count};
    
    xpm_memory_sprom #(
        .ADDR_WIDTH_A(5),
        .MEMORY_INIT_FILE("mc_coeff_data.mem"),
        .MEMORY_OPTIMIZATION("true"),
        .MEMORY_SIZE(256),
        .MEMORY_PRIMITIVE("block"),
        .READ_DATA_WIDTH_A(8),
        .READ_LATENCY_A(1)
    ) U_COEFF (
        .clka(clk),
        .addra(coeff_addr),
        .douta(g_b),
        .ena(1'b1),
        .regcea(1'b1),
        .rsta(1'b0),
        .injectdbiterra(1'b0), .injectsbiterra(1'b0), .dbiterra(), .sbiterra()
    );

    // Multiplier Interface
    // Source byte selection: combinational from count
    wire [1:0] cur_col = count[1:0];
    wire [7:0] cur_s   = col_in[{(2'd3 - cur_col), 3'b000} +: 8];
    wire [7:0] g_p;
    
    gmul_gf256 U_GMUL (.a(cur_s), .b(g_b), .product(g_p));

    // Row index for accumulation
    wire [1:0] cur_row = count[3:2];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= IDLE;
            col_out <= 32'h0;
            done    <= 1'b0;
            count   <= 4'd0;
            acc0 <= 8'h0; acc1 <= 8'h0; acc2 <= 8'h0; acc3 <= 8'h0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        count <= 4'd0;
                        acc0 <= 8'h0; acc1 <= 8'h0; acc2 <= 8'h0; acc3 <= 8'h0;
                        state <= CALC;
                        // coeff_addr is combinational: already presenting addr 0 to BRAM
                        // On next clock, g_b = coeff[0], count will be 0, cur_s = s[0]
                        // So g_p = gmul(s[0], coeff[0]) will be valid
                    end
                end

                CALC: begin
                    // At this point:
                    // g_b = coeff[count] (from BRAM, address was set combinationally last cycle)
                    // cur_s = s[count % 4] (combinational from count)
                    // g_p = gmul(s[count%4], coeff[count]) - VALID and ALIGNED!
                    
                    case (cur_row)
                        2'd0: acc0 <= acc0 ^ g_p;
                        2'd1: acc1 <= acc1 ^ g_p;
                        2'd2: acc2 <= acc2 ^ g_p;
                        2'd3: acc3 <= acc3 ^ g_p;
                    endcase

                    if (count == 4'd15) begin
                        state <= DONE_ST;
                    end else begin
                        count <= count + 1'b1;
                        // coeff_addr is combinational: already presenting (count+1) to BRAM
                    end
                end

                DONE_ST: begin
                    col_out <= {acc0, acc1, acc2, acc3};
                    done    <= 1'b1;
                    state   <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
