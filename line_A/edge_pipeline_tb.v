`timescale 1ns / 1ps

module edge_pipeline_tb;

    reg clk, rst_n;
    reg [15:0] rgb565_in;
    reg din_valid, din_hsync, din_vsync;
    wire [15:0] rgb565_out;
    wire dout_valid, dout_hsync, dout_vsync;

    // 等比例缩小：800x480 的 1/5 = 160x96
    edge_pipeline #(.IMG_W(160)) uut (
        .clk(clk), .rst_n(rst_n),
        .rgb565_in(rgb565_in),
        .din_valid(din_valid), .din_hsync(din_hsync), .din_vsync(din_vsync),
        .rgb565_out(rgb565_out),
        .dout_valid(dout_valid), .dout_hsync(dout_hsync), .dout_vsync(dout_vsync)
    );

    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // 喂一帧 160x96 图：中间 40 列白竖条（强边缘），其余黑（平坦）
    // 白条：第 60~99 列
    integer kk;
    task feed_frame;
        begin
            for (kk = 0; kk < 160*96; kk = kk + 1) begin
                @(negedge clk);
                if ((kk % 160) >= 60 && (kk % 160) <= 99)
                    rgb565_in = 16'hFFFF;   // 白条
                else
                    rgb565_in = 16'h0000;   // 黑
            end
        end
    endtask

    initial begin
        rst_n = 0;
        din_valid = 0; din_hsync = 0; din_vsync = 0;
        @(negedge clk);
        rst_n = 1;
        din_valid = 1; din_hsync = 1;

        // 第一帧：喂图（统计 sum/cnt）
        rgb565_in = 16'h0000;
        feed_frame;

        // 帧结束：拉 vsync 一拍
        @(negedge clk);
        din_vsync = 1;
        @(negedge clk);
        din_vsync = 0;

        // 第二帧：用上一帧统计的自适应阈值判边缘
        feed_frame;

        // 再结束一帧
        @(negedge clk);
        din_vsync = 1;
        @(negedge clk);
        din_vsync = 0;

        #60 $finish;
    end

    initial begin
        $monitor("time=%0t | in=%h out=%h dv=%b", $time, rgb565_in, rgb565_out, dout_valid);
    end

endmodule
