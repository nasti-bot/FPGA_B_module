// ============================================
// 模块：line_buffer
// 功能：行缓存 —— 把一行像素存起来，延迟「一行宽度」拍输出
// 输入：din（像素）、din_valid/hsync/vsync（伴生信号）
// 输出：dout（延迟后的像素）、dout_valid/hsync/vsync（同步延迟的伴生信号）
// 说明：valid/hsync/vsync 与数据同步移位，保证绝对对齐
// ============================================
module line_buffer #(
    parameter WIDTH = 4,   // 一行像素个数
    parameter DW    = 8    // 数据位宽
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [DW-1:0] din,
    input  wire din_valid,
    input  wire din_hsync,
    input  wire din_vsync,
    output reg  [DW-1:0] dout,
    output reg  dout_valid,
    output reg  dout_hsync,
    output reg  dout_vsync
);

    reg [DW-1:0] mem [0:WIDTH-1];      // 数据移位链
    reg valid_mem [0:WIDTH-1];         // valid 移位链
    reg hsync_mem [0:WIDTH-1];         // hsync 移位链
    reg vsync_mem [0:WIDTH-1];         // vsync 移位链
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < WIDTH; i = i + 1) begin
                mem[i]       <= 0;
                valid_mem[i] <= 0;
                hsync_mem[i] <= 0;
                vsync_mem[i] <= 0;
            end
            dout       <= 0;
            dout_valid <= 0;
            dout_hsync <= 0;
            dout_vsync <= 0;
        end else begin
            // 最老的被挤出去
            dout       <= mem[WIDTH-1];
            dout_valid <= valid_mem[WIDTH-1];
            dout_hsync <= hsync_mem[WIDTH-1];
            dout_vsync <= vsync_mem[WIDTH-1];
            // 全体往右挪一格
            for (i = WIDTH-1; i > 0; i = i - 1) begin
                mem[i]       <= mem[i-1];
                valid_mem[i] <= valid_mem[i-1];
                hsync_mem[i] <= hsync_mem[i-1];
                vsync_mem[i] <= vsync_mem[i-1];
            end
            // 新的从最左边进来
            mem[0]       <= din;
            valid_mem[0] <= din_valid;
            hsync_mem[0] <= din_hsync;
            vsync_mem[0] <= din_vsync;
        end
    end

endmodule
