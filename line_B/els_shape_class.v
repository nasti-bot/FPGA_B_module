// ============================================
// 模块：shape_class
// 功能：形状分类 —— 用填充率判断圆/矩形/都不是
// 输入：area（面积）、W（宽）、H（高）
// 输出：shape（2位：00=都不是，01=圆，10=矩形）
// 说明：填充率 = area/(W*H)，圆≈0.79、矩形≈1.0；
//       避免除法：改成乘法比较（area*10 与 9*W*H / 6*W*H 比）
// ============================================
module shape_class(
    input  wire [15:0] area,
    input  wire [7:0]  W,
    input  wire [7:0]  H,
    output reg  [1:0]  shape   // 00=都不是 01=圆 10=矩形
);

    // 外接框面积
    wire [15:0] box_area = W * H;

    // 乘法用移位+加法实现（避免乘法器）：
    //   x*10 = x*8 + x*2
    //   x*9  = x*8 + x*1
    //   x*6  = x*4 + x*2
    wire [15:0] area10 = (area << 3) + (area << 1);
    wire [15:0] box9  = (box_area << 3) + box_area;
    wire [15:0] box6  = (box_area << 2) + (box_area << 1);

    always @(*) begin
        if (area10 > box9)
            shape = 2'b10;   // 填充率>0.9 → 矩形
        else if (area10 > box6)
            shape = 2'b01;   // 填充率0.6~0.9 → 圆
        else
            shape = 2'b00;   // 其他 → 都不是
    end

endmodule
