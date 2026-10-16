`timescale 1ns / 1ps

module shape_feat_tb;

    reg  clk, rst_n, px, px_valid;
    wire [15:0] area;
    wire [7:0] min_x, max_x, min_y, max_y;

    shape_feat #(.IMG_W(5), .IMG_H(5)) dut(
        .clk(clk), .rst_n(rst_n), .px(px), .px_valid(px_valid),
        .area(area), .min_x(min_x), .max_x(max_x), .min_y(min_y), .max_y(max_y)
    );

    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // 3x3 rectangle: 9 object pixels
    reg [0:24] img;
    integer k;
    initial begin
        img = {5'b00000, 5'b01110, 5'b01110, 5'b01110, 5'b00000};
        rst_n = 0;
        px_valid = 0;
        px = 0;
        @(negedge clk);
        rst_n = 1;
        px_valid = 1;
        px = img[0];
        for (k = 1; k < 25; k = k + 1) begin
            @(negedge clk);
            px = img[k];
        end
        @(negedge clk);
        $finish;
    end

    initial begin
        $monitor("time=%0t | px=%b area=%0d min_x=%0d max_x=%0d min_y=%0d max_y=%0d",
                 $time, px, area, min_x, max_x, min_y, max_y);
    end

endmodule
