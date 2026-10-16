`timescale 1ns / 1ps

module edge_pipeline_tb;

    reg clk;
    reg rst_n;
    reg [7:0] R;
    reg [7:0] G_in;     
    reg [7:0] B;
    wire edge_flag;

    edge_pipeline #(.IMG_W(16), .THRESHOLD(100)) uut (
        .clk(clk), .rst_n(rst_n),
        .R(R), .G_in(G_in), .B(B),
        .edge_flag(edge_flag)
    );

    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    integer k;
    reg [7:0] img [0:255];
    initial begin
        #25 rst_n = 1;
        @(negedge clk);
        for (k = 0; k < 256; k = k + 1) begin
    // 每行16个，列号 = k % 16
    // 列号 < 8 的是黑，>= 8 的是白
    if ((k % 16) < 8)
        img[k] = 0;    // 左边黑
    else
        img[k] = 255;  // 右边白
            R = img[k]; G_in = img[k]; B = img[k];
            #20;
        end
        #60 $finish;
    end

    initial begin
        $monitor("time=%0t | R=%0d G_in=%0d B=%0d edge_flag=%b", $time, R, G_in, B, edge_flag);
    end

endmodule