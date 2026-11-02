// sort3：三个 8 位数排序，输出 min/mid/max。中值滤波 median9 的基本单元。
// 纯组合逻辑，一拍内出结果。
module sort3(
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire [7:0] c,
    output wire [7:0] min,
    output wire [7:0] mid,
    output wire [7:0] max
);

    wire [7:0] ab_min, ab_max;

    assign ab_min = (a < b) ? a : b;
    assign ab_max = (a < b) ? b : a;
    assign max = (ab_max > c) ? ab_max : c;
    assign min = (ab_min < c) ? ab_min : c;
    // mid = 三数之和去掉最大最小，省比较器
    assign mid = a + b + c - min - max;

endmodule
