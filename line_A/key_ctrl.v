// ============================================
// 模块：key_ctrl
// 功能：按键控制阈值档位 —— S0加档、S1减档，档位1~5循环
// 输入：clk、rst_n、key0（加档，低有效）、key1（减档，低有效）
// 输出：level（档位1~5，对应阈值系数）
// 说明：两个按键各自消抖后，驱动档位加减循环
// ============================================
module key_ctrl #(
    parameter DEBOUNCE_CNT = 100000  // 消抖计数阈值
)(
    input  wire clk,
    input  wire rst_n,
    input  wire key0,         // 加档键（按下=0）
    input  wire key1,         // 减档键（按下=0）
    output reg  [2:0] level   // 档位 1~5
);

    wire key0_pressed, key1_pressed;

    // 两个按键各自消抖
    key_debounce #(.DEBOUNCE_CNT(DEBOUNCE_CNT)) u_db0 (
        .clk(clk), .rst_n(rst_n), .key(key0), .key_pressed(key0_pressed)
    );
    key_debounce #(.DEBOUNCE_CNT(DEBOUNCE_CNT)) u_db1 (
        .clk(clk), .rst_n(rst_n), .key(key1), .key_pressed(key1_pressed)
    );

    // 档位寄存器：加档/减档，1~5 循环
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            level <= 3'd2;    // 默认档位2（=系数2，即"均值×2"）
        end else if (key0_pressed) begin
            // 加档：灵敏度降低，阈值升高
            level <= (level >= 3'd5) ? 3'd1 : level + 1'b1;
        end else if (key1_pressed) begin
            // 减档：灵敏度升高，阈值降低
            level <= (level <= 3'd1) ? 3'd5 : level - 1'b1;
        end
    end

endmodule
