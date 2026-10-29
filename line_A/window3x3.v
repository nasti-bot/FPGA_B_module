// ============================================
// 模块：window3x3
// 功能：3x3 窗口生成器 —— 把串行像素流变成 9 个并行像素（3行x3列）
// 输入：din（灰度）、din_rgb（原图）、din_valid/hsync/vsync（伴生信号）
// 输出：w00~w22（3x3窗口）、dout_rgb（与中心w11对齐的原图）、dout_valid/hsync/vsync
// 说明：原图和灰度、伴生信号一起穿过行缓存和移位寄存器，保证绝对同步
// ============================================
module window3x3 #(
    parameter LINE_W = 4    // 一行总周期(含消隐)=H_Total_Time，不是图像有效宽！
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [7:0] din,          // 灰度
    input  wire [15:0] din_rgb,     // 原图 RGB565
    input  wire din_valid,
    input  wire din_hsync,
    input  wire din_vsync,
    output wire [7:0] w00, w01, w02,
    output wire [7:0] w10, w11, w12,
    output wire [7:0] w20, w21, w22,
    output wire [15:0] dout_rgb,    // 与中心w11对齐的原图
    output wire dout_valid,
    output wire dout_hsync,
    output wire dout_vsync
);

    // 三行同列（灰度）
    wire [7:0] r0, r1, r2;
    assign r0 = din;

    // 三行同列（原图）
    wire [15:0] r0_rgb, r1_rgb, r2_rgb;
    assign r0_rgb = din_rgb;

    // 三行同列（伴生信号）
    wire r0_v, r1_v, r2_v;
    wire r0_h, r1_h, r2_h;
    wire r0_vs, r1_vs, r2_vs;
    assign r0_v  = din_valid;
    assign r0_h  = din_hsync;
    assign r0_vs = din_vsync;

    line_buffer #(.WIDTH(LINE_W)) lb1 (
        .clk(clk), .rst_n(rst_n),
        .din(din), .din_rgb(din_rgb),
        .din_valid(din_valid), .din_hsync(din_hsync), .din_vsync(din_vsync),
        .dout(r1), .dout_rgb(r1_rgb),
        .dout_valid(r1_v), .dout_hsync(r1_h), .dout_vsync(r1_vs)
    );
    line_buffer #(.WIDTH(LINE_W)) lb2 (
        .clk(clk), .rst_n(rst_n),
        .din(r1), .din_rgb(r1_rgb),
        .din_valid(r1_v), .din_hsync(r1_h), .din_vsync(r1_vs),
        .dout(r2), .dout_rgb(r2_rgb),
        .dout_valid(r2_v), .dout_hsync(r2_h), .dout_vsync(r2_vs)
    );

    // 移位寄存器（灰度）
    reg [7:0] r0_d1, r0_d2, r1_d1, r1_d2, r2_d1, r2_d2;
    // 移位寄存器（原图）
    reg [15:0] r0_rgb_d1, r1_rgb_d1, r2_rgb_d1;
    // 移位寄存器（valid）
    reg r0_d1_v, r0_d2_v, r1_d1_v, r1_d2_v, r2_d1_v, r2_d2_v;
    // 移位寄存器（hsync）
    reg r0_d1_h, r0_d2_h, r1_d1_h, r1_d2_h, r2_d1_h, r2_d2_h;
    // 移位寄存器（vsync）
    reg r0_d1_vs, r0_d2_vs, r1_d1_vs, r1_d2_vs, r2_d1_vs, r2_d2_vs;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r0_d1 <= 0; r0_d2 <= 0;
            r1_d1 <= 0; r1_d2 <= 0;
            r2_d1 <= 0; r2_d2 <= 0;
            r0_rgb_d1 <= 0; r1_rgb_d1 <= 0; r2_rgb_d1 <= 0;
            r0_d1_v <= 0; r0_d2_v <= 0;
            r1_d1_v <= 0; r1_d2_v <= 0;
            r2_d1_v <= 0; r2_d2_v <= 0;
            r0_d1_h <= 0; r0_d2_h <= 0;
            r1_d1_h <= 0; r1_d2_h <= 0;
            r2_d1_h <= 0; r2_d2_h <= 0;
            r0_d1_vs <= 0; r0_d2_vs <= 0;
            r1_d1_vs <= 0; r1_d2_vs <= 0;
            r2_d1_vs <= 0; r2_d2_vs <= 0;
        end else begin
            r0_d1 <= r0;  r0_d2 <= r0_d1;
            r1_d1 <= r1;  r1_d2 <= r1_d1;
            r2_d1 <= r2;  r2_d2 <= r2_d1;
            r0_rgb_d1 <= r0_rgb;
            r1_rgb_d1 <= r1_rgb;
            r2_rgb_d1 <= r2_rgb;
            r0_d1_v <= r0_v;  r0_d2_v <= r0_d1_v;
            r1_d1_v <= r1_v;  r1_d2_v <= r1_d1_v;
            r2_d1_v <= r2_v;  r2_d2_v <= r2_d1_v;
            r0_d1_h <= r0_h;  r0_d2_h <= r0_d1_h;
            r1_d1_h <= r1_h;  r1_d2_h <= r1_d1_h;
            r2_d1_h <= r2_h;  r2_d2_h <= r2_d1_h;
            r0_d1_vs <= r0_vs;  r0_d2_vs <= r0_d1_vs;
            r1_d1_vs <= r1_vs;  r1_d2_vs <= r1_d1_vs;
            r2_d1_vs <= r2_vs;  r2_d2_vs <= r2_d1_vs;
        end
    end

    // 3x3 窗口输出（灰度）
    assign w00 = r2_d2; assign w01 = r2_d1; assign w02 = r2;
    assign w10 = r1_d2; assign w11 = r1_d1; assign w12 = r1;
    assign w20 = r0_d2; assign w21 = r0_d1; assign w22 = r0;

    // 输出：与中心 w11 对齐的原图 = r1_rgb 延迟1拍
    assign dout_rgb = r1_rgb_d1;

    // 伴生信号输出
    // dout_valid = 窗口满的标志：三行都到齐（r2_v有效说明上上行有数据）
    assign dout_valid = r1_d1_v && r2_v;
    assign dout_hsync = r1_d1_h;
    assign dout_vsync = r1_d1_vs;

endmodule
