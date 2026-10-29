// ============================================
// 模块：shape_edge_disp（线A+线B 融合：边缘 + 形状反控颜色）
// 功能：红色边缘检测，检测到圆/矩形时边缘变黄色
// 流程：
//   线A edge_pipeline（无NMS）→ edge_flag（边缘）+ rgb_aligned（原图）
//   线B shape_pipeline → shape（帧级结论：00都不是 01圆 10矩形）
//   融合：边缘颜色 = 检测到形状 ? 黄 : 红
// 输入：clk、rst_n、rgb565_in、din_valid/hsync/vsync、key0/key1（调边缘阈值档位）
// 输出：rgb565_out（红/黄边缘 + 原图）、dout_valid/hsync/vsync
// 说明：shape 是上一帧的锁存结果，所以检测到形状后延迟一帧才变黄（视觉无感）
// ============================================
module shape_edge_disp #(
    parameter IMG_W     = 800,   // 图像宽
    parameter IMG_H     = 480,   // 图像高
    parameter LINE_W    = 1056,  // 一行总周期含消隐（800x480=1056）
    parameter THRESHOLD = 128,   // 线B二值化阈值
    parameter POLARITY  = 1,     // 0=暗的算物体，1=亮的算物体
    parameter MIN_AREA  = 500    // 线B最小面积（过滤噪点）
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [15:0] rgb565_in,
    input  wire din_valid,
    input  wire din_hsync,
    input  wire din_vsync,
    input  wire key0,                // 线A 加档键（调边缘阈值）
    input  wire key1,                // 线A 减档键
    output wire [15:0] rgb565_out,
    output wire dout_valid,
    output wire dout_hsync,
    output wire dout_vsync
);

    // ===== 线A：边缘检测（无 NMS）=====
    wire edge_flag;
    wire [15:0] rgb_aligned;
    edge_pipeline #(
        .IMG_W(IMG_W), .IMG_H(IMG_H), .LINE_W(LINE_W)
    ) u_edge (
        .clk(clk), .rst_n(rst_n),
        .rgb565_in(rgb565_in),
        .din_valid(din_valid), .din_hsync(din_hsync), .din_vsync(din_vsync),
        .key0(key0), .key1(key1),
        .rgb565_out(),                // 不用默认红色版，融合层自己染色
        .edge_flag_out(edge_flag),
        .rgb_out(rgb_aligned),
        .dout_valid(dout_valid), .dout_hsync(dout_hsync), .dout_vsync(dout_vsync)
    );

    // ===== 线B：形状识别 =====
    wire [1:0] shape;
    shape_pipeline #(
        .IMG_W(IMG_W), .IMG_H(IMG_H), .THRESHOLD(THRESHOLD),
        .POLARITY(POLARITY), .MIN_AREA(MIN_AREA)
    ) u_shape (
        .clk(clk), .rst_n(rst_n),
        .rgb565_in(rgb565_in),
        .din_valid(din_valid), .din_hsync(din_hsync), .din_vsync(din_vsync),
        .shape_out(shape),
        .dout_valid(), .dout_hsync(), .dout_vsync()   // 帧级脉冲，不用
    );

    // ===== 融合：边缘颜色由形状决定 =====
    localparam RED    = 16'hF800;   // 纯红
    localparam YELLOW = 16'hFFE0;   // 纯黄
    wire shape_active = (shape != 2'b00);

    assign rgb565_out = edge_flag ? (shape_active ? YELLOW : RED) : rgb_aligned;

endmodule
