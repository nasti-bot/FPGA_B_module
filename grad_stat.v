// grad_stat：算整帧平均梯度，给自适应阈值当基准。
// 帧流水线：当前帧累加 sum/cnt，vsync 下降沿把结果锁存到 sum_out/cnt_out（上一帧），
// 供下一帧阈值比较。不在这里做除法，比较在 adaptive_threshold 里变成乘法。
// 队长的 vsync 低电平=同步期，用下降沿(1→0)检测帧结束。
module grad_stat(
    input  wire clk,
    input  wire rst_n,
    input  wire [10:0] grad,
    input  wire din_valid,
    input  wire din_vsync,
    output reg  [31:0] sum_out,
    output reg  [19:0] cnt_out,
    output reg  frame_done
);

    reg [31:0] sum;
    reg [19:0] cnt;
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
            if (!din_vsync && vsync_d) begin
                // vsync 下降沿：锁存上一帧结果，清零累加
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
