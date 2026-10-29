// ============================================
// 模块：els_shape_edge_disp（给队长工程的包装器）
// 功能：把队长顶层例化的 els_shape_edge_disp 映射到 shape_edge_disp
// 说明：
//   1. 和 els_edge_pipeline 一样的用法，队长顶层按同一套接口例化
//   2. 功能 = 线A红色边缘 + 线B形状识别融合：检测到圆/矩形时边缘变黄色
//   3. key0/key1 = 调边缘检测阈值档位（和线A一样）
//   4. THRESHOLD/POLARITY/MIN_AREA = 线B形状识别参数（和线B一样）
//   5. LINE_W = 一行总周期含消隐 = 1056（800x480）
// ============================================
module els_shape_edge_disp #(
    parameter IMG_W     = 800,
    parameter IMG_H     = 480,
    parameter LINE_W    = 1056,
    parameter THRESHOLD = 128,
    parameter POLARITY  = 1,
    parameter MIN_AREA  = 500
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [15:0] rgb565_in,
    input  wire din_valid,
    input  wire din_hsync,
    input  wire din_vsync,
    input  wire key0,
    input  wire key1,
    output wire [15:0] rgb565_out,
    output wire dout_valid,
    output wire dout_hsync,
    output wire dout_vsync
);

    shape_edge_disp #(
        .IMG_W(IMG_W), .IMG_H(IMG_H), .LINE_W(LINE_W),
        .THRESHOLD(THRESHOLD), .POLARITY(POLARITY), .MIN_AREA(MIN_AREA)
    ) u_shape_edge (
        .clk(clk), .rst_n(rst_n),
        .rgb565_in(rgb565_in),
        .din_valid(din_valid), .din_hsync(din_hsync), .din_vsync(din_vsync),
        .key0(key0), .key1(key1),
        .rgb565_out(rgb565_out),
        .dout_valid(dout_valid), .dout_hsync(dout_hsync), .dout_vsync(dout_vsync)
    );

endmodule
