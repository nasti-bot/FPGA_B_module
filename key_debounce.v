// key_debounce：按键消抖，输出单拍单击脉冲。key 低有效（按下=0）。
// 两步：计数器滤毛刺，再对稳定状态取下降沿得单拍脉冲。
module key_debounce #(
    parameter DEBOUNCE_CNT = 100000  // 消抖计数阈值
)(
    input  wire clk,
    input  wire rst_n,
    input  wire key,
    output reg  key_pressed
);

    reg [19:0] cnt;
    reg key_last;
    reg stable;          // 消抖后稳定的按键状态（0=按下）
    reg stable_last;     // stable 上一拍，取下降沿用

    // 计数器滤毛刺
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= 0;
            key_last <= 1;
            stable <= 1;
        end else begin
            key_last <= key;
            if (key != key_last) begin
                cnt <= 0;                  // 抖动，重新数
            end else if (cnt < DEBOUNCE_CNT) begin
                cnt <= cnt + 1;
            end else begin
                stable <= key;             // 数满，确认稳定状态
            end
        end
    end

    // 稳定状态 1→0（刚按下）时输出单拍脉冲
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stable_last <= 1;
            key_pressed <= 0;
        end else begin
            stable_last <= stable;
            if (stable_last == 1'b1 && stable == 1'b0)
                key_pressed <= 1'b1;
            else
                key_pressed <= 1'b0;
        end
    end

endmodule
