// window3x3：3x3 窗口生成器。行方向用两片 line_buffer（上一行、上上行），
// 列方向用移位寄存器（左 1/2 列），拼出 9 个相邻像素 w00~w22，w11 是中心。
// dout_rgb/dout_valid 和中心 w11 对齐（延迟 LINE_W+1 拍）。
module window3x3 #(
    parameter LINE_W = 4   // 完整行周期(含消隐)，顶层传 1056
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [7:0] din,
    input  wire [15:0] din_rgb,
    input  wire din_valid,
    input  wire din_hsync,
    input  wire din_vsync,
    output wire [7:0] w00, w01, w02,
    output wire [7:0] w10, w11, w12,
    output wire [7:0] w20, w21, w22,
    output wire [15:0] dout_rgb,
    output wire dout_valid,
    output wire dout_hsync,
    output wire dout_vsync
);

    // 行方向三行
    wire [7:0] r0, r1, r2;
    assign r0 = din;

    wire [15:0] r0_rgb, r1_rgb, r2_rgb;
    assign r0_rgb = din_rgb;

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

    // 列方向移位
    reg [7:0] r0_d1, r0_d2, r1_d1, r1_d2, r2_d1, r2_d2;
    reg [15:0] r0_rgb_d1, r1_rgb_d1, r2_rgb_d1;
    reg r0_d1_v, r0_d2_v, r1_d1_v, r1_d2_v, r2_d1_v, r2_d2_v;
    reg r0_d1_h, r0_d2_h, r1_d1_h, r1_d2_h, r2_d1_h, r2_d2_h;
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

    // 拼 3x3 窗口
    assign w00 = r2_d2; assign w01 = r2_d1; assign w02 = r2;
    assign w10 = r1_d2; assign w11 = r1_d1; assign w12 = r1;
    assign w20 = r0_d2; assign w21 = r0_d1; assign w22 = r0;

    // 原图和伴生信号跟中心 w11 对齐
    assign dout_rgb = r1_rgb_d1;
    assign dout_valid = r1_d1_v && r2_v;
    assign dout_hsync = r1_d1_h;
    assign dout_vsync = r1_d1_vs;

endmodule
