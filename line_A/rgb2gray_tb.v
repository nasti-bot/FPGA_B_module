`timescale 1ns / 1ps

module rgb2gray_tb;

    reg  [7:0] R, G, B;
    wire [7:0] Y;

    rgb2gray dut(
        .R(R), .G(G), .B(B), .Y(Y)
    );

    initial begin
        // 白色：255,255,255 -> Y 应该接近 255
        R = 255; G = 255; B = 255;  #10;
        // 黑色：0,0,0 -> Y 应该 = 0
        R = 0;   G = 0;   B = 0;    #10;
        // 纯红：255,0,0 -> Y 应该约 = 77
        R = 255; G = 0;   B = 0;    #10;
        // 纯绿：0,255,0 -> Y 应该约 = 150
        R = 0;   G = 255; B = 0;    #10;
        // 纯蓝：0,0,255 -> Y 应该约 = 29
        R = 0;   G = 0;   B = 255;  #10;
        $finish;
    end

    initial begin
        $monitor("R=%d G=%d B=%d -> Y=%d", R, G, B, Y);
    end

endmodule
