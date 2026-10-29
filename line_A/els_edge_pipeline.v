// ============================================
// 模块：els_edge_pipeline（给队长工程的包装器）
// 功能：把队长顶层例化的 els_edge_pipeline 接口，映射到核心模块 edge_pipeline
// 说明：
//   1. 队长顶层 els_ov_ddr_hdmi.v 里例化的是「els_edge_pipeline」这个名字
//      （他们工程里所有模块都是 els_ 前缀）
//   2. 我们的核心模块叫 edge_pipeline，这里做一个薄包装，队长无需改顶层
//   3. LINE_W = 一行总周期(含消隐) = H_Total_Time
//      800x480 分辨率下 = 1056（800 有效 + 256 消隐）
//      这个参数极其重要：行缓存要延迟「一整行」，不是有效宽 800！
//      如果队长换成别的分辨率，这里要跟着改成对应的 H_Total_Time
// ============================================
module els_edge_pipeline #(
    parameter IMG_W   = 800,   // 图像一行有效像素数
    parameter IMG_H   = 480,   // 图像行数
    parameter LINE_W  = 1056   // 一行总周期含消隐 = H_Total_Time（800x480 = 1056）
)(
    input  wire clk,
    input  wire rst_n,
    input  wire key0,                // 加档键（按下=0）
    input  wire key1,                // 减档键（按下=0）
    input  wire [15:0] rgb565_in,    // 摄像头/显示端来的 16 位 RGB565
    input  wire din_valid,
    input  wire din_hsync,
    input  wire din_vsync,
    output wire [15:0] rgb565_out,
    output wire dout_valid,
    output wire dout_hsync,
    output wire dout_vsync
);

    edge_pipeline #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .LINE_W(LINE_W)
    ) u_edge_pipeline (
        .clk(clk), .rst_n(rst_n),
        .key0(key0), .key1(key1),
        .rgb565_in(rgb565_in),
        .din_valid(din_valid), .din_hsync(din_hsync), .din_vsync(din_vsync),
        .rgb565_out(rgb565_out),
        .dout_valid(dout_valid), .dout_hsync(dout_hsync), .dout_vsync(dout_vsync)
    );

endmodule
