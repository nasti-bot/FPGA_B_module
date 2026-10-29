// ============================================
// 模块：adaptive_threshold
// 功能：自适应阈值比较 —— 判断当前像素是否为边缘
// 输入：grad（当前梯度）、sum（上一帧梯度总和）、cnt（上一帧像素数）、level（档位1~5）
// 输出：edge_flag（1=边缘）
// 说明：edge = (grad*cnt > level*sum)，无除法。
//       阈值 = 平均梯度×level = (sum/cnt)*level，两边乘cnt得此式。
//       level 由按键调节，默认2（=均值×2）。
// ============================================
module adaptive_threshold(
    input  wire [10:0] grad,   // 当前梯度
    input  wire [31:0] sum,    // 上一帧梯度总和
    input  wire [19:0] cnt,    // 上一帧像素数
    input  wire [2:0]  level,  // 档位1~5
    output wire edge_flag      // 1=边缘
);

    // grad*cnt
    wire [31:0] grad_x_cnt = grad * cnt;

    // level*sum（用移位+加法，避免乘法器）
    // 档位系数整体上移：level1~5 对应 2~6 倍均值（原来 1~5 倍太低）
    reg [31:0] threshold;
    always @(*) begin
        case (level)
            3'd1: threshold = sum << 1;                    // 系数2
            3'd2: threshold = (sum << 1) + sum;            // 系数3
            3'd3: threshold = sum << 2;                    // 系数4
            3'd4: threshold = (sum << 2) + sum;            // 系数5
            3'd5: threshold = (sum << 2) + (sum << 1);     // 系数6
            default: threshold = (sum << 1) + sum;         // 系数3
        endcase
    end

    assign edge_flag = (grad_x_cnt > threshold) ? 1'b1 : 1'b0;

endmodule
