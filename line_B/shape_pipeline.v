// ============================================
// 模块：shape_pipeline（线B：认形状）
// 功能：单目标形状识别流水线
//   流程：灰度化 → 阈值二值化 → shape_feat(面积+外接框) → shape_class(判形状)
// 输入：clk、rst_n、px_valid、R/G/B（8位彩色像素）
// 输出：shape_out（2位：00=都不是，01=圆，10=矩形）
// 说明：二值化阈值约定「暗的算物体」(gray < THRESHOLD)；
//       形状结果是逐帧的（扫完一帧图才有效）
// ============================================
module shape_pipeline #(
    parameter IMG_W = 16,
    parameter IMG_H = 16,
    parameter THRESHOLD = 100
)(
    input  wire clk,
    input  wire rst_n,
    input  wire px_valid,      // 1 = 数据有效（来自摄像头）
    input  wire [7:0] R, G, B,
    output wire [1:0] shape_out // 00=都不是 01=圆 10=矩形
);

    wire [7:0] gray;
    wire px;
    wire [15:0] area;
    wire [7:0] min_x, max_x, min_y, max_y;
    wire [7:0] W, H;

    rgb2gray u_gray (.R(R), .G(G), .B(B), .Y(gray));

    // 阈值二值化：暗的算物体
    assign px = (gray < THRESHOLD) ? 1'b1 : 1'b0;

    shape_feat #(.IMG_W(IMG_W), .IMG_H(IMG_H)) u_feat (
        .clk(clk), .rst_n(rst_n),
        .px(px), .px_valid(px_valid),
        .area(area), .min_x(min_x), .max_x(max_x),
        .min_y(min_y), .max_y(max_y)
    );

    // 外接框宽高（+1：第4列到第11列是8列，不是7）
    assign W = max_x - min_x + 1;
    assign H = max_y - min_y + 1;

    shape_class u_cls (.area(area), .W(W), .H(H), .shape(shape_out));

endmodule
