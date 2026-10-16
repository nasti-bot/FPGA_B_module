// ============================================
// 模块：line_buffer
// 功能：行缓存 —— 把一行像素存起来，延迟「一行宽度」拍输出
// 输入：din（像素流，每拍一个，位宽 DW）
// 输出：dout = 输入延迟 WIDTH 拍后的值，即「上一行同一列」的像素
// 说明：本质是移位寄存器(FIFO)；两个行缓存串联就能凑出三行，
//       是 3x3 窗口（Sobel/中值滤波）的基础
// ============================================
module line_buffer #(
    parameter WIDTH = 4,   // 一行像素个数
    parameter DW    = 8    // 数据位宽
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [DW-1:0] din,
    output reg  [DW-1:0] dout
);

    reg [DW-1:0] mem [0:WIDTH-1];   // WIDTH 个寄存器
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < WIDTH; i = i + 1)
                mem[i] <= 0;
            dout <= 0;
        end else begin
            dout <= mem[WIDTH-1];          // 最老的那个被挤出去
            for (i = WIDTH-1; i > 0; i = i - 1)
                mem[i] <= mem[i-1];        // 全体往右挪一格
            mem[0] <= din;                 // 新的从最左边进来
        end
    end

endmodule
