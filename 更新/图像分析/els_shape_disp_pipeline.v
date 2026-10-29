// ============================================
// 模块：els_shape_disp_pipeline（给队长工程的包装器）
// 功能：把队长顶层例化的 els_shape_disp_pipeline 映射到核心 shape_disp_pipeline
// 说明：
//   1. 和 els_edge_pipeline 一样的用法，队长顶层按同一套接口例化
//   2. 线B 是「形状识别 + 原图文字标注」：识别出圆/矩形后，在画面左上角
//      叠加中文「圆形」/「矩形」文字
//   3. THRESHOLD = 二值化阈值（灰度 < 阈值 算物体），默认 100。
//      要识别「暗物体在亮背景」，保持默认；识别「亮物体在暗背景」要调大。
//   4. X0/Y0 = 文字左上角坐标，默认 (16,16)
//   5. 线B 不依赖行周期（不做行缓存），所以没有 LINE_W 参数
// ============================================
module els_shape_disp_pipeline #(
    parameter IMG_W     = 800,   // 图像宽
    parameter IMG_H     = 480,   // 图像高
    parameter THRESHOLD = 128,   // 二值化阈值
    parameter POLARITY  = 1,     // 0=暗的算物体(gray<阈值)，1=亮的算物体(gray>阈值)
    parameter MIN_AREA  = 500,   // 最小面积（过滤噪点团，800x480下真实物体几千像素）
    parameter X0        = 16,    // 文字左上角 x
    parameter Y0        = 16     // 文字左上角 y
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [15:0] rgb565_in,
    input  wire din_valid,
    input  wire din_hsync,
    input  wire din_vsync,
    output wire [15:0] rgb565_out,
    output wire dout_valid,
    output wire dout_hsync,
    output wire dout_vsync
);

    shape_disp_pipeline #(
        .IMG_W(IMG_W), .IMG_H(IMG_H), .THRESHOLD(THRESHOLD),
        .POLARITY(POLARITY), .MIN_AREA(MIN_AREA), .X0(X0), .Y0(Y0)
    ) u_shape_disp (
        .clk(clk), .rst_n(rst_n),
        .rgb565_in(rgb565_in),
        .din_valid(din_valid), .din_hsync(din_hsync), .din_vsync(din_vsync),
        .rgb565_out(rgb565_out),
        .dout_valid(dout_valid), .dout_hsync(dout_hsync), .dout_vsync(dout_vsync)
    );

endmodule
