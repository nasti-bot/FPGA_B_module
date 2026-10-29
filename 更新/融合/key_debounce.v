// ============================================
// 模块：key_debounce
// 功能：按键消抖 —— 过滤机械抖动，输出干净的单拍单击脉冲
// 输入：clk、rst_n、key（按键，低电平有效：按下=0，松开=1）
// 输出：key_pressed（单击脉冲，稳定按下后仅拉高一拍）
// 说明：两步——①计数器滤毛刺 ②上升沿检测得单拍脉冲
// ============================================
module key_debounce #(
    parameter DEBOUNCE_CNT = 100000  // 消抖计数阈值
)(
    input  wire clk,
    input  wire rst_n,
    input  wire key,            // 按键（低有效）
    output reg  key_pressed     // 单拍单击脉冲
);

    reg [19:0] cnt;
    reg key_last;
    reg stable;          // 消抖后稳定的"按键状态"（0=按下稳定）
    reg stable_last;     // stable 的上一拍，用于取上升沿

    // ① 计数器滤毛刺
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

    // ② 上升沿检测：stable 从1变0（按下）时，输出单拍脉冲
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stable_last <= 1;
            key_pressed <= 0;
        end else begin
            stable_last <= stable;
            // stable 上一拍是1、这一拍是0 → 刚按下 → 单拍脉冲
            if (stable_last == 1'b1 && stable == 1'b0)
                key_pressed <= 1'b1;
            else
                key_pressed <= 1'b0;
        end
    end

endmodule
