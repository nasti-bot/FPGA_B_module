// shape_pipeline: shape recognition (line B)
// flow: gray -> binary -> shape_feat(area+bbox) -> shape_class(circle/rect)
module shape_pipeline #(
    parameter IMG_W = 16,
    parameter IMG_H = 16,
    parameter THRESHOLD = 100
)(
    input  wire clk,
    input  wire rst_n,
    input  wire px_valid,      // 1 = pixel data is valid (from camera)
    input  wire [7:0] R, G, B,
    output wire [1:0] shape_out // 00=none 01=circle 10=rect
);

    wire [7:0] gray;
    wire px;
    wire [15:0] area;
    wire [7:0] min_x, max_x, min_y, max_y;
    wire [7:0] W, H;

    rgb2gray u_gray (.R(R), .G(G), .B(B), .Y(gray));

    assign px = (gray < THRESHOLD) ? 1'b1 : 1'b0;   // dark = object

    shape_feat #(.IMG_W(IMG_W), .IMG_H(IMG_H)) u_feat (
        .clk(clk), .rst_n(rst_n),
        .px(px), .px_valid(px_valid),
        .area(area), .min_x(min_x), .max_x(max_x),
        .min_y(min_y), .max_y(max_y)
    );

    assign W = max_x - min_x + 1;
    assign H = max_y - min_y + 1;

    shape_class u_cls (.area(area), .W(W), .H(H), .shape(shape_out));

endmodule
