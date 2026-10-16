`timescale 1ns / 1ps

module sort3_tb;

    reg  [7:0] a, b, c;
    wire [7:0] min, mid, max;

    sort3 dut(
        .a(a), .b(b), .c(c),
        .min(min), .mid(mid), .max(max)
    );

    initial begin
        // test1: already sorted 10 20 30
        a=10; b=20; c=30;  #10;
        // test2: reversed 30 20 10
        a=30; b=20; c=10;  #10;
        // test3: random 50 10 40
        a=50; b=10; c=40;  #10;
        // test4: with noise 10 255 12
        a=10; b=255; c=12; #10;
        $finish;
    end

    initial begin
        $monitor("a=%0d b=%0d c=%0d | min=%0d mid=%0d max=%0d",
                 a, b, c, min, mid, max);
    end

endmodule
