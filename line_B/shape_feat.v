// shape_feat: extract shape features (area + bounding box)
// input: binary pixel stream (px=1 means object)
// output: area (pixel count), and bounding box W/H
module shape_feat #(
    parameter IMG_W = 5,
    parameter IMG_H = 5
)(
    input  wire clk,
    input  wire rst_n,
    input  wire px,
    input  wire px_valid,
    output reg  [15:0] area,   // total object pixels
    output reg  [7:0] min_x, max_x, min_y, max_y
);

    reg [7:0] col, row;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col <= 0;
            row <= 0;
            area <= 0;
            min_x <= 8'hFF;
            max_x <= 0;
            min_y <= 8'hFF;
            max_y <= 0;
        end else if (px_valid) begin
            // count area
            if (px) begin
                area <= area + 1;      // object pixel -> area +1
                if (col < min_x) min_x <= col;
                if (col > max_x) max_x <= col;
                if (row < min_y) min_y <= row;
                if (row > max_y) max_y <= row;
            end
            // advance position
            if (col == IMG_W - 1) begin
                col <= 0;
                row <= row + 1;
            end else begin
                col <= col + 1;
            end
        end
    end

endmodule
