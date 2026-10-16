// 行缓存：本质是一个移位寄存器（FIFO）
// 输出 = 输入延迟「一行宽度」拍之后的值
// 所以输出正好是「上一行、同一列」的像素
module line_buffer #(
    parameter WIDTH = 4,   // 一行像素个数（先用4做小例子）
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
