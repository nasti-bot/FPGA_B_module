// shape_class: classify shape as rectangle / circle / neither
// using fill ratio = area / (W*H), but avoiding division:
//   rectangle: area*10 > 9*(W*H)   (fill > 0.9)
//   circle:    area*10 > 6*(W*H)   (fill in 0.6..0.9)
//   neither:   otherwise
module shape_class(
    input  wire [15:0] area,
    input  wire [7:0]  W,
    input  wire [7:0]  H,
    output reg  [1:0]  shape   // 00=neither, 01=circle, 10=rectangle
);

    // W*H (box area)
    wire [15:0] box_area = W * H;

    // area*10  and  box_area*9, box_area*6
    // x*10 = x*8 + x*2  (shifts)
    wire [15:0] area10 = (area << 3) + (area << 1);
    wire [15:0] box9  = (box_area << 3) + box_area;      // 8x + 1x
    wire [15:0] box6  = (box_area << 2) + (box_area << 1); // 4x + 2x

    always @(*) begin
        if (area10 > box9)
            shape = 2'b10;   // rectangle (fill > 0.9)
        else if (area10 > box6)
            shape = 2'b01;   // circle (fill 0.6..0.9)
        else
            shape = 2'b00;   // neither
    end

endmodule
