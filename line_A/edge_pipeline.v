// ============================================
// 模块：edge_pipeline（线A：找边缘）
// 功能：完整边缘检测流水线
//   流程：灰度化 → 3x3窗口 → 中值滤波 → 3x3窗口 → Sobel → 阈值
// 输入：clk、rst_n、R/G_in/B（各8位彩色像素）
// 输出：edge_flag（1=边缘，0=非边缘）
// 说明：两个 window3x3 分别给中值滤波和 Sobel 凑 3x3 窗口
// ============================================
module edge_pipeline #(
    parameter IMG_W = 4,        // 一行宽
    parameter THRESHOLD = 100   // 边缘阈值
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [7:0] R,
    input  wire [7:0] G_in,     // 注意：G 已被 Sobel 的 G 占用，绿色通道改叫 G_in
    input  wire [7:0] B,
    output wire edge_flag
);

    wire [7:0] gray;
    rgb2gray u_gray (.R(R), .G(G_in), .B(B), .Y(gray));

    // 第一个窗口：给中值滤波凑 3x3
    wire [7:0] m00,m01,m02,m10,m11,m12,m20,m21,m22;
    window3x3 #(.WIDTH(IMG_W)) u_win1 (
        .clk(clk), .rst_n(rst_n), .din(gray),
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

    // 第二个窗口：给 Sobel 凑 3x3
    wire [7:0] s00,s01,s02,s10,s11,s12,s20,s21,s22;
    window3x3 #(.WIDTH(IMG_W)) u_win2 (
        .clk(clk), .rst_n(rst_n), .din(med),
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

    assign edge_flag = (grad > THRESHOLD) ? 1'b1 : 1'b0;

endmodule
