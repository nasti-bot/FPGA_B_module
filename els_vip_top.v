// ============================================
// 模块：els_disp_top（给队长工程的包装器）
// 功能：把队长顶层例化的 els_disp_top 映射到 disp_top
// 说明：
//   1. 一个按键 key_mode 切换两种模式：线A(红边缘) / 线B(形状黄边缘+文字)
//   2. 线A 阈值已固定（均值×4），不再需要调档按键
//   3. 其他接口和 els_edge_pipeline 一样
// ============================================
module els_vip_top #(
    parameter IMG_W     = 800,
    parameter IMG_H     = 480,
    parameter LINE_W    = 1056,
    parameter MIN_AREA  = 500
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [15:0] rgb565_in,
    input  wire din_valid,
    input  wire din_hsync,
    input  wire din_vsync,
    input  wire key_mode,          // 低有效，切换 A/B
    input  wire key_level,         // 低有效，循环调阈值档位（线A）
    input  wire key_debug,         // 低有效，循环切换调试显示（0~4）
    output wire [15:0] rgb565_out,
    output wire dout_valid,
    output wire dout_hsync,
    output wire dout_vsync
);

    disp_top #(
        .IMG_W(IMG_W), .IMG_H(IMG_H), .LINE_W(LINE_W), .MIN_AREA(MIN_AREA)
    ) u_disp (
        .clk(clk), .rst_n(rst_n),
        .rgb565_in(rgb565_in),
        .din_valid(din_valid), .din_hsync(din_hsync), .din_vsync(din_vsync),
        .key_mode(key_mode),
        .key_level(key_level),
        .key_debug(key_debug),
        .rgb565_out(rgb565_out),
        .dout_valid(dout_valid), .dout_hsync(dout_hsync), .dout_vsync(dout_vsync)
    );

endmodule
