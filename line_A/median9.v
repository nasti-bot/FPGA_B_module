// ============================================
// 模块：median9
// 功能：中值滤波 —— 3x3 窗口的 9 个像素，取中位数输出（去噪）
// 输入：p00~p22（9 个像素，3行x3列）
// 输出：med（9 个数的中位数）
// 说明：算法是「先排每行，再排每列，取中间」；
//       噪点(极端值)排序后被挤到边上，不影响中位数
// ============================================
module median9(
    input  wire [7:0] p00, p01, p02,
    input  wire [7:0] p10, p11, p12,
    input  wire [7:0] p20, p21, p22,
    output wire [7:0] med
);

    // 第一步：排每一行（3 行）
    wire [7:0] r0_min, r0_mid, r0_max;
    wire [7:0] r1_min, r1_mid, r1_max;
    wire [7:0] r2_min, r2_mid, r2_max;

    sort3 s_row0 (.a(p00), .b(p01), .c(p02), .min(r0_min), .mid(r0_mid), .max(r0_max));
    sort3 s_row1 (.a(p10), .b(p11), .c(p12), .min(r1_min), .mid(r1_mid), .max(r1_max));
    sort3 s_row2 (.a(p20), .b(p21), .c(p22), .min(r2_min), .mid(r2_mid), .max(r2_max));

    // 第二步：排每一列（3 列）
    wire [7:0] c0_min, c0_mid, c0_max;
    wire [7:0] c1_min, c1_mid, c1_max;
    wire [7:0] c2_min, c2_mid, c2_max;

    sort3 s_col0 (.a(r0_min), .b(r1_min), .c(r2_min), .min(c0_min), .mid(c0_mid), .max(c0_max));
    sort3 s_col1 (.a(r0_mid), .b(r1_mid), .c(r2_mid), .min(c1_min), .mid(c1_mid), .max(c1_max));
    sort3 s_col2 (.a(r0_max), .b(r1_max), .c(r2_max), .min(c2_min), .mid(c2_mid), .max(c2_max));

    // 第三步：中位数 = 中间列的中间值
    assign med = c1_mid;

endmodule
