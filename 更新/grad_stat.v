// ============================================
// 模块：grad_stat
// 功能：统计一帧图像的梯度总和 sum 和像素数 cnt（用于自适应阈值）
// 输入：grad（当前像素梯度，11位）、din_valid、din_vsync
// 输出：sum_out（上一帧梯度总和）、cnt_out（上一帧像素数）、frame_done
// 说明：帧流水线——当前帧累加，vsync 时锁存上一帧结果并清零。
//       不做除法，下游用 "grad*cnt > 2*sum" 判边缘。
// ============================================
module grad_stat #(
    parameter SHIFT = 0
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [10:0] grad,      // 当前像素梯度 0~2040
    input  wire din_valid,        // 数据有效
    input  wire din_vsync,        // 帧同步
    output reg  [31:0] sum_out,   // 上一帧梯度总和（锁存）
    output reg  [19:0] cnt_out,   // 上一帧像素数（锁存）
    output reg  frame_done        // 帧结果有效脉冲
);

    reg [31:0] sum;    // 当前帧累加和（一帧最多约7.8亿，32位够）
    reg [19:0] cnt;    // 当前帧像素数（384000<2^19，20位够）
    reg vsync_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum <= 0;
            cnt <= 0;
            sum_out <= 0;
            cnt_out <= 0;
            frame_done <= 0;
            vsync_d <= 0;
        end else begin
            vsync_d <= din_vsync;

            if (din_vsync && !vsync_d) begin
                // 帧结束：锁存上一帧结果，清零，开始新帧
                sum_out <= sum;
                cnt_out <= cnt;
                frame_done <= 1'b1;
                sum <= 0;
                cnt <= 0;
            end else if (din_valid) begin
                frame_done <= 0;
                sum <= sum + grad;
                cnt <= cnt + 1;
            end else begin
                frame_done <= 0;
            end
        end
    end

endmodule
