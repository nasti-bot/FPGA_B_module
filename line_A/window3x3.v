// ============================================
// 模块：window3x3
// 功能：3x3 窗口生成器 —— 把串行像素流变成 9 个并行的像素（3行x3列）
// 输入：din（像素流）、din_valid（数据有效，与din同步延迟）
// 输出：w00~w22（3x3窗口）、dout_valid（与窗口中心w11同步的有效标志）
// 说明：valid 和数据一起穿过行缓存和移位寄存器，保证绝对同步
// ============================================
module window3x3 #(
    parameter WIDTH = 4    // 一行像素个数
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [7:0] din,
    input  wire din_valid,
    output wire [7:0] w00, w01, w02,
    output wire [7:0] w10, w11, w12,
    output wire [7:0] w20, w21, w22,
    output wire dout_valid
);

    // 三行同列（数据）
    wire [7:0] r0, r1, r2;
    assign r0 = din;   // 当前行

    // 三行同列（valid）
    wire r0_v, r1_v, r2_v;
    assign r0_v = din_valid;   // 当前行的 valid

    line_buffer #(.WIDTH(WIDTH)) lb1 (
        .clk(clk), .rst_n(rst_n),
        .din(din),      .din_valid(din_valid),
        .dout(r1),      .dout_valid(r1_v)     // 上一行 + 上一行的valid
    );
    line_buffer #(.WIDTH(WIDTH)) lb2 (
        .clk(clk), .rst_n(rst_n),
        .din(r1),       .din_valid(r1_v),
        .dout(r2),      .dout_valid(r2_v)     // 上上行 + 上上行的valid
    );

    // 移位寄存器（数据 + valid）
    reg [7:0] r0_d1, r0_d2, r1_d1, r1_d2, r2_d1, r2_d2;
    reg r0_d1_v, r0_d2_v, r1_d1_v, r1_d2_v, r2_d1_v, r2_d2_v;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r0_d1 <= 0; r0_d2 <= 0;
            r1_d1 <= 0; r1_d2 <= 0;
            r2_d1 <= 0; r2_d2 <= 0;
            r0_d1_v <= 0; r0_d2_v <= 0;
            r1_d1_v <= 0; r1_d2_v <= 0;
            r2_d1_v <= 0; r2_d2_v <= 0;
        end else begin
            r0_d1 <= r0;  r0_d2 <= r0_d1;
            r1_d1 <= r1;  r1_d2 <= r1_d1;
            r2_d1 <= r2;  r2_d2 <= r2_d1;
            r0_d1_v <= r0_v;  r0_d2_v <= r0_d1_v;
            r1_d1_v <= r1_v;  r1_d2_v <= r1_d1_v;
            r2_d1_v <= r2_v;  r2_d2_v <= r2_d1_v;
        end
    end

    // 3x3 窗口输出
    //   w00 w01 w02   =   r2_d2 r2_d1 r2
    //   w10 w11 w12   =   r1_d2 r1_d1 r1
    //   w20 w21 w22   =   r0_d2 r0_d1 r0
    assign w00 = r2_d2; assign w01 = r2_d1; assign w02 = r2;
    assign w10 = r1_d2; assign w11 = r1_d1; assign w12 = r1;
    assign w20 = r0_d2; assign w21 = r0_d1; assign w22 = r0;

    // valid 输出 = 中心像素 w11 对应的 valid
    assign dout_valid = r1_d1_v;

endmodule
