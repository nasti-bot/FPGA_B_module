`timescale 1ns / 1ps

module sobel_core_tb;

    reg  [7:0] P0, P1, P2, P3, P4, P5, P6, P7, P8;
    wire [10:0] gx_mag, gy_mag, G;

    sobel_core dut(
        .P0(P0), .P1(P1), .P2(P2),
        .P3(P3), .P4(P4), .P5(P5),
        .P6(P6), .P7(P7), .P8(P8),
        .gx_mag(gx_mag), .gy_mag(gy_mag), .G(G)
    );

    initial begin
        // 测试1：竖直边缘（左边黑右边白）
        P0=0;   P1=0;   P2=255;
        P3=0;   P4=0;   P5=255;
        P6=0;   P7=0;   P8=255;
        #10;

        // 测试2：水平边缘（上边黑下边白）
        P0=0;   P1=0;   P2=0;
        P3=0;   P4=0;   P5=0;
        P6=255; P7=255; P8=255;
        #10;

        // 测试3：平坦区域（全一样）
        P0=128; P1=128; P2=128;
        P3=128; P4=128; P5=128;
        P6=128; P7=128; P8=128;
        #10;

        $finish;
    end

    initial begin
        $monitor("gx_mag=%d gy_mag=%d G=%d", gx_mag, gy_mag, G);
    end

endmodule
