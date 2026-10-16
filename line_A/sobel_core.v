// Sobel 卷积核心（纯组合逻辑）
// 输入：3x3 窗口的 9 个像素 P0~P8（8位灰度）
// 输出：gx_mag=水平梯度幅值, gy_mag=垂直梯度幅值, G=边缘强度
//
// 窗口布局：
//   P0 P1 P2
//   P3 P4 P5    （P4 中心像素，Sobel 不用它）
//   P6 P7 P8
module sobel_core(
    input  wire [7:0] P0, P1, P2, P3, P4, P5, P6, P7, P8,
    output wire [10:0] gx_mag,   // |Gx|，最大1020
    output wire [10:0] gy_mag,   // |Gy|，最大1020
    output wire [10:0] G         // 边缘强度 = |Gx|+|Gy|，最大2040
);

    wire [10:0] gx_pos, gx_neg, gy_pos, gy_neg;

    // Gx：右边三列 减 左边三列（找竖直边缘）
    assign gx_pos = P2 + 2*P5 + P8;
    assign gx_neg = P0 + 2*P3 + P6;

    // Gy：下边三行 减 上边三行（找水平边缘）
    assign gy_pos = P6 + 2*P7 + P8;
    assign gy_neg = P0 + 2*P1 + P2;

    // 绝对值：谁大减谁
    assign gx_mag = (gx_pos >= gx_neg) ? (gx_pos - gx_neg) : (gx_neg - gx_pos);
    assign gy_mag = (gy_pos >= gy_neg) ? (gy_pos - gy_neg) : (gy_neg - gy_pos);

    // 边缘强度
    assign G = gx_mag + gy_mag;

endmodule
