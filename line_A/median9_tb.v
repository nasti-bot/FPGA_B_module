`timescale 1ns / 1ps

module median9_tb;

    reg  [7:0] p00,p01,p02,p10,p11,p12,p20,p21,p22;
    wire [7:0] med;

    median9 dut(
        .p00(p00), .p01(p01), .p02(p02),
        .p10(p10), .p11(p11), .p12(p12),
        .p20(p20), .p21(p21), .p22(p22),
        .med(med)
    );

    initial begin
        // test1: all clean 10s, no noise -> med should be 10
        p00=10; p01=10; p02=10;
        p10=10; p11=10; p12=10;
        p20=10; p21=10; p22=10;
        #10;
        // test2: one bright noise 255 in center -> med should still be ~10
        p00=10; p01=10; p02=10;
        p10=10; p11=255; p12=10;
        p20=10; p21=10; p22=10;
        #10;
        // test3: several noise -> median should be a middle-ish value
        p00=5;  p01=200; p02=8;
        p10=7;  p11=180; p12=9;
        p20=6;  p21=190; p22=10;
        #10;
        $finish;
    end

    initial begin
        $monitor("med=%0d", med);
    end

endmodule
