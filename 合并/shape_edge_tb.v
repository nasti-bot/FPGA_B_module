`timescale 1ns / 1ps
// 融合测试台：喂亮圆（白圆在黑背景），验证检测到圆后边缘变黄色
module shape_edge_tb;

    reg clk, rst_n;
    reg [15:0] rgb565_in;
    reg din_valid, din_hsync, din_vsync;
    reg key0, key1;
    wire [15:0] rgb565_out;
    wire dout_valid, dout_hsync, dout_vsync;

    shape_edge_disp #(
        .IMG_W(160), .IMG_H(96), .LINE_W(160),
        .THRESHOLD(128), .POLARITY(1), .MIN_AREA(500)
    ) uut (
        .clk(clk), .rst_n(rst_n),
        .rgb565_in(rgb565_in),
        .din_valid(din_valid), .din_hsync(din_hsync), .din_vsync(din_vsync),
        .key0(key0), .key1(key1),
        .rgb565_out(rgb565_out),
        .dout_valid(dout_valid), .dout_hsync(dout_hsync), .dout_vsync(dout_vsync)
    );

    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    integer kk;
    integer yellow_count;
    integer red_count;
    integer row, col;

    task feed_frame;
        begin
            for (kk = 0; kk < 160*96; kk = kk + 1) begin
                @(negedge clk);
                row = kk / 160;
                col = kk % 160;
                // 白圆（中心80,48 半径30）在黑背景
                if ((row-48)*(row-48) + (col-80)*(col-80) <= 30*30)
                    rgb565_in = 16'hFFFF;
                else
                    rgb565_in = 16'h0000;
            end
        end
    endtask

    initial begin
        rst_n = 0; din_valid = 0; din_hsync = 0; din_vsync = 0;
        key0 = 1; key1 = 1; rgb565_in = 0;
        @(negedge clk);
        rst_n = 1;
        din_valid = 1; din_hsync = 1;

        // 第一帧：识别形状（锁存 shape）
        feed_frame;
        @(negedge clk); din_vsync = 1;
        @(negedge clk); din_vsync = 0;

        // 第二帧：shape 已锁存，统计黄/红边缘像素
        yellow_count = 0;
        red_count = 0;
        for (kk = 0; kk < 160*96; kk = kk + 1) begin
            @(negedge clk);
            row = kk / 160;
            col = kk % 160;
            if ((row-48)*(row-48) + (col-80)*(col-80) <= 30*30)
                rgb565_in = 16'hFFFF;
            else
                rgb565_in = 16'h0000;
            @(posedge clk);
            if (dout_valid && rgb565_out == 16'hFFE0) yellow_count = yellow_count + 1;
            if (dout_valid && rgb565_out == 16'hF800) red_count = red_count + 1;
        end

        $display("黄色边缘像素 = %0d，红色边缘像素 = %0d", yellow_count, red_count);
        $display("期望：检测到圆 → 黄色>0 且 红色=0");

        #100 $finish;
    end

endmodule
