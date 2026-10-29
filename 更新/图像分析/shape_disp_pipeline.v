// ============================================
// 模块：shape_disp_pipeline（线B：认形状 + 显示文字）
// 功能：形状识别 + 原图文字标注
//   流程：原图 → [shape_pipeline 识别] → shape 结论（帧级）
//         原图 → [char_osd 叠加文字] → 带文字标注的图
// 输入：clk、rst_n、rgb565_in、din_valid/hsync/vsync
// 输出：rgb565_out（原图 + 文字标注）、dout_valid/hsync/vsync
// 说明：shape 结论每帧更新一次（上一帧结果），文字显示在左上角
// ============================================
module shape_disp_pipeline #(
    parameter IMG_W = 16,
    parameter IMG_H = 16,
    parameter THRESHOLD = 128,
    parameter POLARITY = 1,    // 0=暗的算物体，1=亮的算物体
    parameter MIN_AREA = 500,  // 最小面积（过滤噪点团）
    parameter X0 = 16,      // 文字左上角 x
    parameter Y0 = 16       // 文字左上角 y
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [15:0] rgb565_in,   // 摄像头来的 16 位 RGB565
    input  wire din_valid,
    input  wire din_hsync,
    input  wire din_vsync,
    output wire [15:0] rgb565_out,  // 原图 + 文字标注
    output wire dout_valid,
    output wire dout_hsync,
    output wire dout_vsync
);

    // ---- 形状识别（帧级结论）----
    wire [1:0] shape;
    shape_pipeline #(
        .IMG_W(IMG_W), .IMG_H(IMG_H), .THRESHOLD(THRESHOLD),
        .POLARITY(POLARITY), .MIN_AREA(MIN_AREA)
    ) u_shape (
        .clk(clk), .rst_n(rst_n),
        .rgb565_in(rgb565_in),
        .din_valid(din_valid), .din_hsync(din_hsync), .din_vsync(din_vsync),
        .shape_out(shape),
        .dout_valid(), .dout_hsync(), .dout_vsync()   // 帧结果脉冲，这里不用
    );

    // ---- OSD 文字叠加 ----
    char_osd #(
        .IMG_W(IMG_W), .IMG_H(IMG_H), .X0(X0), .Y0(Y0)
    ) u_osd (
        .clk(clk), .rst_n(rst_n),
        .rgb565_in(rgb565_in),
        .din_valid(din_valid), .din_hsync(din_hsync), .din_vsync(din_vsync),
        .shape(shape),
        .rgb565_out(rgb565_out),
        .dout_valid(dout_valid)
    );

    // 伴生信号直通（OSD 无延迟）
    assign dout_hsync = din_hsync;
    assign dout_vsync = din_vsync;

endmodule
