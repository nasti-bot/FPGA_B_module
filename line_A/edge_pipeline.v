// ============================================
// 模块：edge_pipeline（线A：找边缘）
// 功能：完整边缘检测流水线，红色边缘输出
//   流程：565拆解 → 灰度化 → 3x3窗口 → 中值滤波 → 3x3窗口 → Sobel → 阈值
// 输入：clk、rst_n、rgb565_in（16位RGB565）
// 输出：rgb565_out（16位，边缘=红色F800，非边缘=原图）
// 说明：两个 window3x3 分别给中值滤波和 Sobel 凑 3x3 窗口
// ============================================
module edge_pipeline #(
    parameter IMG_W = 4,        // 一行宽
    parameter THRESHOLD = 100   // 边缘阈值
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [15:0] rgb565_in,   // 摄像头来的 16 位 RGB565
    output wire [15:0] rgb565_out
);

    wire [7:0] gray;
    // 拆 565
    wire [4:0] r5 = rgb565_in[15:11];
    wire [5:0] g6 = rgb565_in[10:5];
    wire [4:0] b5 = rgb565_in[4:0];

    // 补成 8 位（左移补零）
    wire [7:0] R8 = {r5, 3'b000};   // 5位 → 8位，左移3位
    wire [7:0] G8 = {g6, 2'b00};    // 6位 → 8位，左移2位
    wire [7:0] B8 = {b5, 3'b000};
    rgb2gray u_gray (.R(R8), .G(G8), .B(B8), .Y(gray));

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

    // 阈值判断：产生 edge_flag（内部信号）
    wire edge_flag;
    assign edge_flag = (grad > THRESHOLD) ? 1'b1 : 1'b0;

    // 原图延迟链：让原图和 edge_flag 对齐
    // DELAY 是拍数
parameter DELAY = 34; 

reg [15:0] delay_line [0:63];
integer di;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (di = 0; di < 64; di = di + 1)
            delay_line[di] <= 0;
    end else begin
        delay_line[0] <= rgb565_in;
        for (di = 1; di < 64; di = di + 1)
            delay_line[di] <= delay_line[di-1];
    end
end

assign rgb565_out = edge_flag ? 16'hF800 : delay_line[DELAY];

endmodule
