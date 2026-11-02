// adaptive_threshold：自适应阈值比较，梯度超过"整帧平均梯度×系数"判为边缘。
// edge ⇔ grad > (sum/cnt) × 系数，两边乘 cnt 消掉除法：grad×cnt > 系数×sum。
// sum/cnt 是 grad_stat 给的上一帧平均梯度。档位 1~5 → 系数 2~6。
module adaptive_threshold(
    input  wire [10:0] grad,
    input  wire [31:0] sum,
    input  wire [19:0] cnt,
    input  wire [2:0]  level,
    output wire edge_flag
);

    wire [31:0] grad_x_cnt = grad * cnt;

    // 系数 × sum，系数用移位+加法凑（不花乘法器）
    reg [31:0] threshold;
    always @(*) begin
        case (level)
            3'd1: threshold = sum << 1;                    // 系数2
            3'd2: threshold = (sum << 1) + sum;            // 系数3
            3'd3: threshold = sum << 2;                    // 系数4
            3'd4: threshold = (sum << 2) + sum;            // 系数5
            3'd5: threshold = (sum << 2) + (sum << 1);     // 系数6
            default: threshold = (sum << 1) + sum;
        endcase
    end

    assign edge_flag = (grad_x_cnt > threshold) ? 1'b1 : 1'b0;

endmodule
