// ============================================
// 模块：sobel_core
// 功能：Sobel 边缘检测卷积核心（4 方向，纯组合逻辑）
// 输入：3x3 窗口的 9 个像素 P0~P8（8 位灰度）
// 输出：gx_mag(|G90|)、gy_mag(|G0|)、G(边缘强度=4方向最大值)
// 说明：参考官方 Sobeledge_proc，4 方向算子取 max 比 |Gx|+|Gy| 更抗噪
//       （sum 会把各方向噪声叠加放大，max 不会）
// 窗口布局：
//   P0 P1 P2
//   P3 P4 P5    （P4 中心像素，Sobel 不用它）
//   P6 P7 P8
// ============================================
module sobel_core(
    input  wire [7:0] P0, P1, P2, P3, P4, P5, P6, P7, P8,
    output wire [10:0] gx_mag,   // |G90|，垂直边缘（左右差分）
    output wire [10:0] gy_mag,   // |G0|，水平边缘（上下差分）
    output wire [10:0] G,        // 边缘强度 = max(G0,G45,G90,G135)，最大1020
    output wire signed [10:0] gx_s,  // 有符号 Gx（右减左），NMS 判断梯度方向
    output wire signed [10:0] gy_s   // 有符号 Gy（下减上），NMS 判断梯度方向
);

    wire [10:0] G0_p,  G0_n,  G45_p, G45_n, G90_p, G90_n, G135_p, G135_n;
    wire [10:0] G0, G45, G90, G135;

    // 4 方向算子（{1'b0,P,1'b0} = 2*P，位宽明确、无乘法器）
    // 0°：上下差分，找水平边缘
    assign G0_p  = P0 + {1'b0, P1, 1'b0} + P2;
    assign G0_n  = P6 + {1'b0, P7, 1'b0} + P8;
    // 45°：找 ↘ 对角边缘
    assign G45_p = P5 + {1'b0, P8, 1'b0} + P7;
    assign G45_n = P1 + {1'b0, P0, 1'b0} + P3;
    // 90°：左右差分，找垂直边缘
    assign G90_p = P2 + {1'b0, P5, 1'b0} + P8;
    assign G90_n = P0 + {1'b0, P3, 1'b0} + P6;
    // 135°：找 ↙ 对角边缘
    assign G135_p = P1 + {1'b0, P2, 1'b0} + P5;
    assign G135_n = P3 + {1'b0, P6, 1'b0} + P7;

    // 绝对值：谁大减谁（避免有符号数）
    assign G0   = (G0_p   >= G0_n)   ? (G0_p   - G0_n)   : (G0_n   - G0_p);
    assign G45  = (G45_p  >= G45_n)  ? (G45_p  - G45_n)  : (G45_n  - G45_p);
    assign G90  = (G90_p  >= G90_n)  ? (G90_p  - G90_n)  : (G90_n  - G90_p);
    assign G135 = (G135_p >= G135_n) ? (G135_p - G135_n) : (G135_n - G135_p);

    // 取最大
    wire [10:0] Gmax_a, Gmax_b;
    assign Gmax_a = (G0  >= G45)  ? G0  : G45;
    assign Gmax_b = (G90 >= G135) ? G90 : G135;
    assign G      = (Gmax_a >= Gmax_b) ? Gmax_a : Gmax_b;

    // 保留两个正交方向供参考
    assign gx_mag = G90;
    assign gy_mag = G0;

    // 有符号梯度（NMS 判断方向用）：右减左、下减上
    assign gx_s = $signed({1'b0, G90_p}) - $signed({1'b0, G90_n});
    assign gy_s = $signed({1'b0, G0_p})  - $signed({1'b0, G0_n});

endmodule
