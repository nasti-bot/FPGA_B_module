`timescale 1ns / 1ps

module edge_pipeline_tb;

    reg clk;
    reg rst_n;
    reg [15:0] rgb565_in;
    wire [15:0] rgb565_out;

    edge_pipeline #(.IMG_W(16), .THRESHOLD(100)) uut (
        .clk(clk), .rst_n(rst_n),
        .rgb565_in(rgb565_in),
        .rgb565_out(rgb565_out)
    );

    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    integer k;
    initial begin
        rst_n = 0;
        @(negedge clk);
        rst_n = 1;
        // 喂第一个像素（黑 = 16'h0000，白 = 16'hFFFF）
        rgb565_in = ((0 % 16) < 8) ? 16'h0000 : 16'hFFFF;
        for (k = 1; k < 256; k = k + 1) begin
            @(negedge clk);
            rgb565_in = ((k % 16) < 8) ? 16'h0000 : 16'hFFFF;   // 左黑右白
        end
        #60;
        $finish;
    end

    initial begin
        $monitor("time=%0t | in=%h out=%h", $time, rgb565_in, rgb565_out);
    end

endmodule
