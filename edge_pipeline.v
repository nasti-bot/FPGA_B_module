// edge_pipeline：线A 边缘检测流水线。
//   RGB565 → 灰度 → 3x3窗口 → 中值滤波 → 3x3窗口 → Sobel → 自适应阈值
//   → 孤立点过滤 → 帧间去闪动 → 输出（边缘红、其余原图）。
//   中值和 Sobel 都要 3x3 邻域，所以过两个窗口。原图 rgb 和 valid/hsync/vsync
//   一路穿行对齐；clean_valid/clean_vsync 延迟 TD 拍，给线B 重建 col/row 用。
module edge_pipeline #(
    parameter IMG_W  = 800,
    parameter IMG_H  = 480,
    parameter LINE_W = 1056   // 完整行周期(含消隐)，不是有效宽
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [15:0] rgb565_in,
    input  wire din_valid,
    input  wire din_hsync,
    input  wire din_vsync,
    input  wire [2:0] level,
    output wire [15:0] rgb565_out,
    output wire edge_flag_out,
    output wire [15:0] rgb_out,
    output wire dout_valid,
    output wire dout_hsync,
    output wire dout_vsync,
    output wire clean_valid,
    output wire clean_vsync
);

    localparam TD = 3 * (LINE_W + 1);

    // RGB565 拆 R/G/B，转灰度
    wire [7:0] gray;
    wire [4:0] r5 = rgb565_in[15:11];
    wire [5:0] g6 = rgb565_in[10:5];
    wire [4:0] b5 = rgb565_in[4:0];
    wire [7:0] R8 = {r5, 3'b000};
    wire [7:0] G8 = {g6, 2'b00};
    wire [7:0] B8 = {b5, 3'b000};
    rgb2gray u_gray (.R(R8), .G(G8), .B(B8), .Y(gray));

    // 窗口① + 中值滤波
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

    // 窗口② + Sobel
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

    // 梯度统计 + 自适应阈值
    wire [31:0] grad_sum;
    wire [19:0] grad_cnt;
    grad_stat u_stat (
        .clk(clk), .rst_n(rst_n),
        .grad(grad),
        .din_valid(valid_win2),
        .din_vsync(vsync_win2),
        .sum_out(grad_sum),
        .cnt_out(grad_cnt),
        .frame_done()
    );

    wire edge_flag;
    adaptive_threshold u_th (
        .grad(grad),
        .sum(grad_sum),
        .cnt(grad_cnt),
        .level(level),
        .edge_flag(edge_flag)
    );

    // 孤立点过滤 + 帧间去闪动
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

    wire edge_prev;
    frame_delay_1bit #(.IMG_W(IMG_W), .IMG_H(IMG_H)) u_fd (
        .clk(clk), .rst_n(rst_n),
        .din(edge_filtered),
        .din_valid(valid_filtered),
        .din_vsync(vsync_filtered),
        .dout(edge_prev)
    );
    wire edge_stable = edge_filtered & edge_prev;   // 两帧都在才是稳定边缘

    // clean_valid/clean_vsync：din_valid/din_vsync 延迟 TD 拍，给线B 重建坐标
    reg [TD-1:0] valid_sr, vsync_sr;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_sr <= 0; vsync_sr <= 0;
        end else begin
            valid_sr <= {valid_sr[TD-2:0], din_valid};
            vsync_sr <= {vsync_sr[TD-2:0], din_vsync};
        end
    end

    assign rgb565_out  = edge_stable ? 16'hF800 : rgb_filtered;
    assign edge_flag_out = edge_stable;
    assign rgb_out      = rgb_filtered;
    assign dout_valid   = valid_filtered;
    assign dout_hsync   = hsync_filtered;
    assign dout_vsync   = vsync_filtered;
    assign clean_valid  = valid_sr[TD-1];
    assign clean_vsync  = vsync_sr[TD-1];

endmodule
