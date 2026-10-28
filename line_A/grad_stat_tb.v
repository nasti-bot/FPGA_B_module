`timescale 1ns / 1ps

module grad_stat_tb;

    reg clk, rst_n;
    reg [10:0] grad;
    reg din_valid, din_vsync;
    wire [31:0] sum_out;
    wire [19:0] cnt_out;
    wire frame_done;
    wire edge_flag;

    grad_stat u_stat (
        .clk(clk), .rst_n(rst_n),
        .grad(grad), .din_valid(din_valid), .din_vsync(din_vsync),
        .sum_out(sum_out), .cnt_out(cnt_out), .frame_done(frame_done)
    );

    adaptive_threshold u_th (
        .grad(grad), .sum(sum_out), .cnt(cnt_out), .edge_flag(edge_flag)
    );

    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    integer k;
    initial begin
        rst_n = 0;
        din_valid = 0;
        din_vsync = 0;
        grad = 0;
        @(negedge clk);
        rst_n = 1;
        din_valid = 1;

        // 第一帧：90个梯度10（平坦）+ 10个梯度500（强边缘）
        for (k = 0; k < 100; k = k + 1) begin
            @(negedge clk);
            if (k < 90)
                grad = 10;      // 平坦区
            else
                grad = 500;     // 强边缘
        end

        // 帧结束，拉 vsync 一帧（让 grad_stat 锁存 sum/cnt）
        @(negedge clk);
        din_vsync = 1;
        @(negedge clk);
        din_vsync = 0;

        // 第二帧：用上一帧统计的 sum/cnt 来判。喂同样的梯度，看 edge 输出
        for (k = 0; k < 100; k = k + 1) begin
            @(negedge clk);
            if (k < 90)
                grad = 10;      // 平坦，应该 edge=0
            else
                grad = 500;     // 强边缘，应该 edge=1
        end

        #60 $finish;
    end

    initial begin
        $monitor("time=%0t | grad=%0d sum=%0d cnt=%0d edge=%b", $time, grad, sum_out, cnt_out, edge_flag);
    end

endmodule
