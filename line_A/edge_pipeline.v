// ============================================
// 模块：edge_pipeline（线A：找边缘）
// 功能：完整边缘检测流水线，红色边缘输出
//   流程：565拆解 → 灰度化 → 3x3窗口 → 中值滤波 → 3x3窗口 → Sobel → 阈值
// 输入：clk、rst_n、rgb565_in（16位RGB565）、din_valid/hsync/vsync（伴生信号）
// 输出：rgb565_out（16位）、dout_valid/hsync/vsync（同步延迟的伴生信号）
// 说明：valid/hsync/vsync 穿过两个 window3x3，与数据绝对同步；
//       原图延迟 DELAY 拍与 edge_flag 对齐（DELAY 实测约 35 拍）
// ============================================
module edge_pipeline #(
    parameter IMG_W = 4,        // 一行宽
    parameter THRESHOLD = 100,  // 边缘阈值
    parameter DELAY = 2*IMG_W + 3  // 原图延迟拍数（=2×行宽+3，自动跟随分辨率；IMG_W=16时=35，IMG_W=800时=1603）
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [15:0] rgb565_in,   // 摄像头来的 16 位 RGB565
    input  wire din_valid,           // 数据有效
    input  wire din_hsync,           // 行同步
    input  wire din_vsync,           // 帧同步
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

    // 第一个窗口：给中值滤波凑 3x3（伴生信号一起穿过）
    wire [7:0] m00,m01,m02,m10,m11,m12,m20,m21,m22;
    wire valid_mid, hsync_mid, vsync_mid;
    window3x3 #(.WIDTH(IMG_W)) u_win1 (
        .clk(clk), .rst_n(rst_n), .din(gray),
        .din_valid(din_valid), .din_hsync(din_hsync), .din_vsync(din_vsync),
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

    // 第二个窗口：给 Sobel 凑 3x3（伴生信号继续穿过）
    wire [7:0] s00,s01,s02,s10,s11,s12,s20,s21,s22;
    window3x3 #(.WIDTH(IMG_W)) u_win2 (
        .clk(clk), .rst_n(rst_n), .din(med),
        .din_valid(valid_mid), .din_hsync(hsync_mid), .din_vsync(vsync_mid),
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
    // grad_stat 统计一帧的平均梯度，adaptive_threshold 用它判边缘
    wire [31:0] grad_sum;    // 上一帧梯度总和
    wire [19:0] grad_cnt;    // 上一帧像素数
    wire frame_done;         // 帧统计完成脉冲（暂未用，保留）

    grad_stat u_stat (
        .clk(clk), .rst_n(rst_n),
        .grad(grad),
        .din_valid(dout_valid),   // 流水线后的有效信号（和 grad 对齐）
        .din_vsync(dout_vsync),   // 流水线后的帧同步（和 grad 对齐）
        .sum_out(grad_sum),
        .cnt_out(grad_cnt),
        .frame_done(frame_done)
    );

    wire edge_flag;
    adaptive_threshold u_th (
        .grad(grad),
        .sum(grad_sum),
        .cnt(grad_cnt),
        .edge_flag(edge_flag)
    );

    // 原图延迟链：让原图和 edge_flag 对齐（延迟 DELAY 拍）
    reg [15:0] rgb_delay [0:DELAY];
    integer di;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (di = 0; di <= DELAY; di = di + 1)
                rgb_delay[di] <= 0;
        end else begin
            rgb_delay[0] <= rgb565_in;
            for (di = 1; di <= DELAY; di = di + 1)
                rgb_delay[di] <= rgb_delay[di-1];
        end
    end

    // 输出：边缘=红色，非边缘=延迟对齐后的原图
    assign rgb565_out = edge_flag ? 16'hF800 : rgb_delay[DELAY];

endmodule
