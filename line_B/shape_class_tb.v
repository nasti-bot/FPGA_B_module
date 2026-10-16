`timescale 1ns / 1ps

module shape_class_tb;

    reg  [15:0] area;
    reg  [7:0]  W, H;
    wire [1:0]  shape;

    shape_class dut(
        .area(area), .W(W), .H(H), .shape(shape)
    );

    initial begin
        // test1: 3x3 rectangle, area=9 -> fill 1.0 -> rectangle
        area=9;  W=3; H=3;  #10;
        // test2: circle in 3x3 box -> roughly 0.79 fill -> circle
        area=7;  W=3; H=3;  #10;
        // test3: sparse (a cross) -> low fill -> neither
        area=5;  W=3; H=3;  #10;
        $finish;
    end

    initial begin
        $monitor("area=%0d W=%0d H=%0d -> shape=%b (00=none 01=circle 10=rect)",
                 area, W, H, shape);
    end

endmodule
