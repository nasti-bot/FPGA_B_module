`timescale 1ns / 1ps

module shape_pipeline_tb;

    reg clk, rst_n;
    reg [15:0] rgb565_in;
    reg din_valid, din_hsync, din_vsync;
    wire [1:0] shape_out;
    wire dout_valid, dout_hsync, dout_vsync;

    shape_pipeline #(.IMG_W(16), .IMG_H(16)) uut (
        .clk(clk), .rst_n(rst_n),
        .rgb565_in(rgb565_in),
        .din_valid(din_valid), .din_hsync(din_hsync), .din_vsync(din_vsync),
        .shape_out(shape_out),
        .dout_valid(dout_valid), .dout_hsync(dout_hsync), .dout_vsync(dout_vsync)
    );

    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    integer k;
    initial begin
        rst_n = 0;
        din_valid = 0;
        din_hsync = 0;
        din_vsync = 0;
        @(negedge clk);
        rst_n = 1;
        din_valid = 1;
        din_hsync = 1;
        // 喂一帧 16x16 图：中间 8x8 黑方块（黑=0000），其余白（ffff）
        rgb565_in = ((0/16>=4)&&(0/16<=11)&&(0%16>=4)&&(0%16<=11)) ? 16'h0000 : 16'hFFFF;
        for (k = 1; k < 256; k = k + 1) begin
            @(negedge clk);
            rgb565_in = ((k/16>=4)&&(k/16<=11)&&(k%16>=4)&&(k%16<=11)) ? 16'h0000 : 16'hFFFF;
        end
        // 一帧喂完，拉高 vsync（帧结束脉冲）
        @(negedge clk);
        din_vsync = 1;
        @(negedge clk);
        din_vsync = 0;
        #60;
        $finish;
    end

    initial begin
        $monitor("time=%0t | shape=%b dv=%b dvs=%b", $time, shape_out, dout_valid, dout_vsync);
    end

endmodule
