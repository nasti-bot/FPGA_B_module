`timescale 1ns / 1ps

module shape_pipeline_tb;

    reg clk, rst_n, px_valid;
    reg [7:0] R, G, B;
    wire [1:0] shape_out;

    shape_pipeline #(.IMG_W(16), .IMG_H(16)) uut (
        .clk(clk), .rst_n(rst_n), .px_valid(px_valid),
        .R(R), .G(G), .B(B), .shape_out(shape_out)
    );

    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // 16x16 image: dark 8x8 square in the middle, white background
    // square: rows 4..11, cols 4..11
    integer k;
    initial begin
        rst_n = 0;
        px_valid = 0;
        @(negedge clk);
        rst_n = 1;
        px_valid = 1;
        // feed pixel 0 right away (same beat as reset release)
        if ((0/16 >= 4) && (0/16 <= 11) && (0%16 >= 4) && (0%16 <= 11)) begin
            R=0; G=0; B=0;
        end else begin
            R=255; G=255; B=255;
        end
        for (k = 1; k < 256; k = k + 1) begin
            @(negedge clk);
            if ((k/16 >= 4) && (k/16 <= 11) && (k%16 >= 4) && (k%16 <= 11)) begin
                R=0; G=0; B=0;      // dark square
            end else begin
                R=255; G=255; B=255; // white background
            end
        end
        @(negedge clk);
        px_valid = 0;
        #60;   // wait a few cycles for area/bbox to settle
        $display("FINAL shape = %b (00=none 01=circle 10=rect)", shape_out);
        $finish;
    end

endmodule
