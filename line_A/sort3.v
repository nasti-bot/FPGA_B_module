// ============================================
// 模块：sort3
// 功能：三个 8 位数排序，从小到大输出 min / mid / max
// 输入：a、b、c（各 8 位）
// 输出：min(最小)、mid(中间)、max(最大)
// 说明：用「比较+选择」实现，不用时钟（纯组合逻辑）；
//       是中值滤波(median9)的基本单元
// ============================================
module sort3(
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire [7:0] c,
    output wire [7:0] min,
    output wire [7:0] mid,
    output wire [7:0] max
);

    wire [7:0] ab_min, ab_max;

    // 第一步：比较 a、b，挑出小的和大的
    assign ab_min = (a < b) ? a : b;
    assign ab_max = (a < b) ? b : a;

    // 第二步：max = ab_max 和 c 里更大的那个
    assign max = (ab_max > c) ? ab_max : c;

    // 第三步：min = ab_min 和 c 里更小的那个
    assign min = (ab_min < c) ? ab_min : c;

    // 第四步：mid = 三个数去掉最大最小剩下的那个
    assign mid = a + b + c - min - max;

endmodule
