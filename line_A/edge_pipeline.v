// ============================================
// 模块：edge_pipeline（线A：找边缘）
// 功能：完整边缘检测流水线，红色边缘输出
//   流程：565拆解 → 灰度化 → 3x3窗口 → 中值滤波 → 3x3窗口 → Sobel → 自适应阈值
// 输入：clk、rst_n、rgb565_in（16位RGB565）、din_valid/hsync/vsync（伴生信号）
// 输出：rgb565_out（16位）、dout_valid/hsync/vsync（同步延迟的伴生信号）
// 说明：原图和灰度一起穿过两个 window3x3 的行缓存，延迟自动对齐，无需 DELAY 参数
// ============================================
module edge_pipeline #(
    parameter IMG_W = 4,        // 图像一行有效像素数（800x480 时=800）
    parameter IMG_H = 96,       // 图像行数（800x480 时=480）
    parameter LINE_W = 4        // 一行总周期含消隐 = H_Total_Time（800x480 时=1056）
                                // 必须传这个！行缓存要延迟「一整行」，不是有效宽
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [15:0] rgb565_in,   // 摄像头来的 16 位 RGB565
    input  wire din_valid,           // 数据有效
    input  wire din_hsync,           // 行同步
    input  wire din_vsync,           // 帧同步
    input  wire key0,                // 加档键（按下=0）
    input  wire key1,                // 减档键（按下=0）
    output wire [15:0] rgb565_out,   // 输出像素
    output wire dout_valid,          // 输出有效（与 rgb565_out 同步）
    output wire dout_hsync,          // 输出行同步
    output wire dout_vsync           // 输出帧同步
);

    wire [7:0] gray;
    // 拆 565
    wire [4:0] r5 = rgb565_in[15:11];
    wire [5:0] g6 = rgb565_in[10:5];
    wire [4:0] b5 = rgb565_in[4:0];

    // 补成 8 位（左移补零）
    wire [7:0] R8 = {r5, 3'b000};
    wire [7:0] G8 = {g6, 2'b00};
    wire [7:0] B8 = {b5, 3'b000};
    rgb2gray u_gray (.R(R8), .G(G8), .B(B8), .Y(gray));

    // 第一个窗口：给中值滤波凑 3x3（原图、伴生信号一起穿过）
    wire [7:0] m00,m01,m02,m10,m11,m12,m20,m21,m22;
    wire [15:0] rgb_mid;   // 第一个窗口输出的对齐原图
    wire valid_mid, hsync_mid, vsync_mid;
    window3x3 #(.LINE_W(LINE_W)) u_win1 (
        .clk(clk), .rst_n(rst_n), .din(gray), .din_rgb(rgb565_in),
        .din_valid(din_valid), .din_hsync(din_hsync), .din_vsync(din_vsync),
        .dout_rgb(rgb_mid),
        .dout_valid(valid_mid), .dout_hsync(hsync_mid), .dout_vsync(vsync_mid),
        .w00(m00), .w01(m01), .w02(m02),
        .w10(m10), .w11(m11), .w12(m12),
        .w20(m20), .w21(m21), .w22(m22)
    );

    wire [7:0] med;
    median9 u_median (
        .p00(m00), .p01(m01), .p02(m02),
        .p10(m10), .p11(m11), .p12(m12),
        .p20(m20), .p21(m21), .p22(m22),
        .med(med)
    );

    // 第二个窗口：给 Sobel 凑 3x3（原图、伴生信号继续穿过）
    wire [7:0] s00,s01,s02,s10,s11,s12,s20,s21,s22;
    wire [15:0] rgb_aligned;   // 最终对齐的原图
    window3x3 #(.LINE_W(LINE_W)) u_win2 (
        .clk(clk), .rst_n(rst_n), .din(med), .din_rgb(rgb_mid),
        .din_valid(valid_mid), .din_hsync(hsync_mid), .din_vsync(vsync_mid),
        .dout_rgb(rgb_aligned),
        .dout_valid(dout_valid), .dout_hsync(dout_hsync), .dout_vsync(dout_vsync),
        .w00(s00), .w01(s01), .w02(s02),
        .w10(s10), .w11(s11), .w12(s12),
        .w20(s20), .w21(s21), .w22(s22)
    );

    wire [10:0] grad;
    sobel_core u_sobel (
        .P0(s00), .P1(s01), .P2(s02),
        .P3(s10), .P4(s11), .P5(s12),
        .P6(s20), .P7(s21), .P8(s22),
        .G(grad)
    );

    // ===== 自适应阈值（方案B：均值×2）=====
    wire [31:0] grad_sum;
    wire [19:0] grad_cnt;
    wire frame_done;

    grad_stat u_stat (
        .clk(clk), .rst_n(rst_n),
        .grad(grad),
        .din_valid(dout_valid),
        .din_vsync(dout_vsync),
        .sum_out(grad_sum),
        .cnt_out(grad_cnt),
        .frame_done(frame_done)
    );

    // 按键调档：S0加档、S1减档，档位1~5
    wire [2:0] level;
    key_ctrl u_key (
        .clk(clk), .rst_n(rst_n),
        .key0(key0), .key1(key1),
        .level(level)
    );

    wire edge_flag;
    adaptive_threshold u_th (
        .grad(grad),
        .sum(grad_sum),
        .cnt(grad_cnt),
        .level(level),
        .edge_flag(edge_flag)
    );

    // 输出：边缘=红色，非边缘=对齐后的原图（无需 DELAY，自动对齐）
    assign rgb565_out = edge_flag ? 16'hF800 : rgb_aligned;

endmodule
