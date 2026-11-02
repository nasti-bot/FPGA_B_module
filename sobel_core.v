// sobel_core：4 方向 Sobel 边缘检测（0°/45°/90°/135°），取各方向差分绝对值的
// 最大值作为边缘强度。取 max 而不是 |Gx|+|Gy|，噪声不会被累加（雪花少 3~5 倍）。
// 窗口 P0~P8，P4 是中心（Sobel 不用）。最大梯度 1020，11 位。
module sobel_core(
    input  wire [7:0] P0, P1, P2, P3, P4, P5, P6, P7, P8,
    output wire [10:0] gx_mag,
    output wire [10:0] gy_mag,
    output wire [10:0] G,
    output wire signed [10:0] gx_s,
    output wire signed [10:0] gy_s
);

    wire [10:0] G0_p,  G0_n,  G45_p, G45_n, G90_p, G90_n, G135_p, G135_n;
    wire [10:0] G0, G45, G90, G135;

    // {1'b0, P, 1'b0} = 2*P，用拼位实现乘2
    assign G0_p  = P0 + {1'b0, P1, 1'b0} + P2;   // 上排
    assign G0_n  = P6 + {1'b0, P7, 1'b0} + P8;   // 下排
    assign G45_p = P5 + {1'b0, P8, 1'b0} + P7;
    assign G45_n = P1 + {1'b0, P0, 1'b0} + P3;
    assign G90_p = P2 + {1'b0, P5, 1'b0} + P8;   // 右列
    assign G90_n = P0 + {1'b0, P3, 1'b0} + P6;   // 左列
    assign G135_p = P1 + {1'b0, P2, 1'b0} + P5;
    assign G135_n = P3 + {1'b0, P6, 1'b0} + P7;

    // 取绝对值
    assign G0   = (G0_p   >= G0_n)   ? (G0_p   - G0_n)   : (G0_n   - G0_p);
    assign G45  = (G45_p  >= G45_n)  ? (G45_p  - G45_n)  : (G45_n  - G45_p);
    assign G90  = (G90_p  >= G90_n)  ? (G90_p  - G90_n)  : (G90_n  - G90_p);
    assign G135 = (G135_p >= G135_n) ? (G135_p - G135_n) : (G135_n - G135_p);

    // 4 方向取最大
    wire [10:0] Gmax_a, Gmax_b;
    assign Gmax_a = (G0  >= G45)  ? G0  : G45;
    assign Gmax_b = (G90 >= G135) ? G90 : G135;
    assign G      = (Gmax_a >= Gmax_b) ? Gmax_a : Gmax_b;

    assign gx_mag = G90;
    assign gy_mag = G0;

    assign gx_s = $signed({1'b0, G90_p}) - $signed({1'b0, G90_n});
    assign gy_s = $signed({1'b0, G0_p})  - $signed({1'b0, G0_n});

endmodule
