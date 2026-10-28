// ============================================
// 模块：window3x3
// 功能：3x3 窗口生成器 —— 把串行像素流变成 9 个并行像素（3行x3列）
// 输入：din（像素）、din_valid/hsync/vsync（伴生信号，与din同步延迟）
// 输出：w00~w22（3x3窗口）、dout_valid/hsync/vsync（与中心w11同步）
// 说明：伴生信号和数据一起穿过行缓存和移位寄存器，保证绝对同步
// ============================================
module window3x3 #(
    parameter WIDTH = 4    // 一行像素个数
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [7:0] din,
    input  wire din_valid,
    input  wire din_hsync,
    input  wire din_vsync,
    output wire [7:0] w00, w01, w02,
    output wire [7:0] w10, w11, w12,
    output wire [7:0] w20, w21, w22,
    output wire dout_valid,
    output wire dout_hsync,
    output wire dout_vsync
);

    // 三行同列（数据）
    wire [7:0] r0, r1, r2;
    assign r0 = din;   // 当前行

    // 三行同列（伴生信号 valid/hsync/vsync）
    wire r0_v, r1_v, r2_v;
    wire r0_h, r1_h, r2_h;
    wire r0_vs, r1_vs, r2_vs;
    assign r0_v  = din_valid;
    assign r0_h  = din_hsync;
    assign r0_vs = din_vsync;

    line_buffer #(.WIDTH(WIDTH)) lb1 (
        .clk(clk), .rst_n(rst_n),
        .din(din), .din_valid(din_valid), .din_hsync(din_hsync), .din_vsync(din_vsync),
        .dout(r1), .dout_valid(r1_v), .dout_hsync(r1_h), .dout_vsync(r1_vs)
    );
    line_buffer #(.WIDTH(WIDTH)) lb2 (
        .clk(clk), .rst_n(rst_n),
        .din(r1), .din_valid(r1_v), .din_hsync(r1_h), .din_vsync(r1_vs),
        .dout(r2), .dout_valid(r2_v), .dout_hsync(r2_h), .dout_vsync(r2_vs)
    );

    // 移位寄存器（数据）
    reg [7:0] r0_d1, r0_d2, r1_d1, r1_d2, r2_d1, r2_d2;
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

    // 3x3 窗口输出
    assign w00 = r2_d2; assign w01 = r2_d1; assign w02 = r2;
    assign w10 = r1_d2; assign w11 = r1_d1; assign w12 = r1;
    assign w20 = r0_d2; assign w21 = r0_d1; assign w22 = r0;

    // 伴生信号输出 = 中心像素 w11 对应的伴生信号
    assign dout_valid = r1_d1_v;
    assign dout_hsync = r1_d1_h;
    assign dout_vsync = r1_d1_vs;

endmodule
