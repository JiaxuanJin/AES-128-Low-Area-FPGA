`timescale 1ns / 1ps

module tb_aes;

    reg clk;
    reg rst_n;
    reg start;
    reg [127:0] plaintext;
    reg [127:0] key;
    wire [127:0] ciphertext;
    wire done;

    // Instantiate Top Module
    aes uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .plaintext(plaintext),
        .key(key),
        .ciphertext(ciphertext),
        .done(done)
    );

    // Clock
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        // Initialize signals
        rst_n = 0; 
        start = 0; 
        plaintext = 0; 
        key = 0;
        
        // Hold reset for several cycles
        #100;
        rst_n = 1;
        #50; // Wait after reset before starting test

        // Test Case: FIPS-197 Appendix B (Example Vector)
        // Cipher Key: 2b7e151628aed2a6abf7158809cf4f3c
        // Plaintext:  3243f6a8885a308d313198a2e0370734
        // Expected:   3925841d02dc09fbdc118597196a0b32
        
        @(posedge clk);
        plaintext = 128'h3243f6a8885a308d313198a2e0370734;
        key       = 128'h2b7e151628aed2a6abf7158809cf4f3c;
        start     = 1'b1;
        @(posedge clk);
        start     = 1'b0;

        $display("--- AES-128 Encryption Start ---");
        $display("Plaintext:  %h", plaintext);
        $display("Key:        %h", key);

        wait(done);
        $display("Ciphertext: %h", ciphertext);
        $display("Expected:   3925841d02dc09fbdc118597196a0b32");

        if (ciphertext === 128'h3925841d02dc09fbdc118597196a0b32)
            $display("--- FULL SYSTEM PASS! ---");
        else
            $display("--- FULL SYSTEM FAIL! ---");

        #100;
        $finish;
    end

endmodule
