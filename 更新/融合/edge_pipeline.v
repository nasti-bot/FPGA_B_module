// ============================================
// 模块：edge_pipeline（线A：找边缘）—— 无 NMS 版本
// 功能：完整边缘检测流水线，红色边缘输出
//   流程：565拆解 → 灰度化 → 3x3窗口 → 中值滤波 → 3x3窗口 → Sobel(4向) → 自适应阈值 → 连通域过滤
// 说明：本版没有 NMS（非极大值抑制），边缘是 Sobel 原始的 2~3 像素粗带；
//       去噪靠 4 方向 Sobel + 自适应阈值（系数2~6）+ 连通域过滤（去孤立点）
// 输入：clk、rst_n、rgb565_in、din_valid/hsync/vsync、key0/key1（调阈值档位）
// 输出：rgb565_out、dout_valid/hsync/vsync
// ============================================
module edge_pipeline #(
    parameter IMG_W = 4,        // 图像一行有效像素数（800x480 时=800）
    parameter IMG_H = 96,       // 图像行数（800x480 时=480）
    parameter LINE_W = IMG_W    // 一行总周期含消隐 = H_Total_Time（800x480 时=1056）
                                // 默认=IMG_W 对应无消隐仿真；上板必须传 1056
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [15:0] rgb565_in,   // 摄像头来的 16 位 RGB565
    input  wire din_valid,
    input  wire din_hsync,
    input  wire din_vsync,
    input  wire key0,                // 加档键（按下=0）
    input  wire key1,                // 减档键（按下=0）
    output wire [15:0] rgb565_out,
    output wire edge_flag_out,    // 边缘标志（未染色，供融合模块用）
    output wire [15:0] rgb_out,   // 对齐后的原图（未染色，供融合模块用）
    output wire dout_valid,
    output wire dout_hsync,
    output wire dout_vsync
);

    wire [7:0] gray;
    wire [4:0] r5 = rgb565_in[15:11];
    wire [5:0] g6 = rgb565_in[10:5];
    wire [4:0] b5 = rgb565_in[4:0];
    wire [7:0] R8 = {r5, 3'b000};
    wire [7:0] G8 = {g6, 2'b00};
    wire [7:0] B8 = {b5, 3'b000};
    rgb2gray u_gray (.R(R8), .G(G8), .B(B8), .Y(gray));

    // 第一个窗口：中值滤波凑 3x3
    wire [7:0] m00,m01,m02,m10,m11,m12,m20,m21,m22;
    wire [15:0] rgb_mid;
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

    // 第二个窗口：Sobel 凑 3x3
    wire [7:0] s00,s01,s02,s10,s11,s12,s20,s21,s22;
    wire [15:0] rgb_aligned;
    wire valid_win2, hsync_win2, vsync_win2;
    window3x3 #(.LINE_W(LINE_W)) u_win2 (
        .clk(clk), .rst_n(rst_n), .din(med), .din_rgb(rgb_mid),
        .din_valid(valid_mid), .din_hsync(hsync_mid), .din_vsync(vsync_mid),
        .dout_rgb(rgb_aligned),
        .dout_valid(valid_win2), .dout_hsync(hsync_win2), .dout_vsync(vsync_win2),
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

    // ===== 自适应阈值统计（统计 grad 的均值和像素数）=====
    wire [31:0] grad_sum;
    wire [19:0] grad_cnt;
    wire frame_done;
    grad_stat u_stat (
        .clk(clk), .rst_n(rst_n),
        .grad(grad),
        .din_valid(valid_win2),
        .din_vsync(vsync_win2),
        .sum_out(grad_sum),
        .cnt_out(grad_cnt),
        .frame_done(frame_done)
    );

    // 按键调档
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

    // ===== 连通域过滤：去掉孤立噪点（粗边缘不受影响）=====
    wire edge_filtered;
    wire [15:0] rgb_filtered;
    wire valid_filtered, hsync_filtered, vsync_filtered;
    edge_filter #(.LINE_W(LINE_W)) u_flt (
        .clk(clk), .rst_n(rst_n),
        .edge_flag(edge_flag),
        .din_rgb(rgb_aligned),
        .din_valid(valid_win2), .din_hsync(hsync_win2), .din_vsync(vsync_win2),
        .edge_filtered(edge_filtered),
        .dout_rgb(rgb_filtered),
        .dout_valid(valid_filtered), .dout_hsync(hsync_filtered), .dout_vsync(vsync_filtered)
    );

    // 输出：边缘=红色，非边缘=对齐原图
    assign rgb565_out = edge_filtered ? 16'hF800 : rgb_filtered;
    assign edge_flag_out = edge_filtered;
    assign rgb_out = rgb_filtered;
    assign dout_valid = valid_filtered;
    assign dout_hsync = hsync_filtered;
    assign dout_vsync = vsync_filtered;

endmodule
