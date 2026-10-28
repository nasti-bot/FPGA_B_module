// ============================================
// 模块：adaptive_threshold
// 功能：自适应阈值比较 —— 判断当前像素是否为边缘
// 输入：grad（当前像素梯度）、sum（上一帧梯度总和）、cnt（上一帧像素数）
// 输出：edge（1=边缘）
// 说明：edge = (grad*cnt > 2*sum)，无除法。
//       数学：阈值=平均梯度*2=(sum/cnt)*2，grad>阈值 两边乘cnt得此式。
// ============================================
module adaptive_threshold(
    input  wire [10:0] grad,   // 当前梯度
    input  wire [31:0] sum,    // 上一帧梯度总和
    input  wire [19:0] cnt,    // 上一帧像素数
    output wire edge_flag      // 1=边缘
);

    // grad*cnt：11位 × 20位 → 最大约 2040×384000≈7.8亿，需31位，用32位存
    wire [31:0] grad_x_cnt = grad * cnt;

    // 2*sum：左移1位
    wire [31:0] sum_x2 = sum << 1;

    assign edge_flag = (grad_x_cnt > sum_x2) ? 1'b1 : 1'b0;

endmodule
