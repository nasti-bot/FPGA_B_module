// line_buffer：行缓存，输出"上一行同一列"的像素（延迟 WIDTH 拍）。
// 用 BRAM 不用 for 移位链：Efinity 不把 for 移位链推断成 SRL，会退化成 FF 爆资源。
// 非阻塞读 mem[wr] 先于写，read-first 读到旧值。
// 坑：WIDTH 要用完整行周期(含消隐)=1056，不是有效宽 800，否则上一行对不齐、整图错乱。
module line_buffer #(
    parameter WIDTH  = 1056,   // 完整行周期(含消隐)
    parameter DW     = 8,      // 灰度位宽
    parameter RGB_DW = 16      // 原图位宽 RGB565
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [DW-1:0] din,
    input  wire [RGB_DW-1:0] din_rgb,
    input  wire din_valid,
    input  wire din_hsync,
    input  wire din_vsync,
    output reg  [DW-1:0] dout,
    output reg  [RGB_DW-1:0] dout_rgb,
    output reg  dout_valid,
    output reg  dout_hsync,
    output reg  dout_vsync
);

    (* syn_ramstyle = "block_ram" *) reg [DW-1:0]     mem     [0:WIDTH-1];
    (* syn_ramstyle = "block_ram" *) reg [RGB_DW-1:0] rgb_mem [0:WIDTH-1];
    (* syn_ramstyle = "block_ram" *) reg              valid_mem [0:WIDTH-1];
    (* syn_ramstyle = "block_ram" *) reg              hsync_mem [0:WIDTH-1];
    (* syn_ramstyle = "block_ram" *) reg              vsync_mem [0:WIDTH-1];

    reg [10:0] wr;   // 写指针

    always @(posedge clk) begin
        if (!rst_n) begin
            wr <= 0;
            dout <= 0; dout_rgb <= 0; dout_valid <= 0; dout_hsync <= 0; dout_vsync <= 0;
        end else begin
            dout       <= mem[wr];
            dout_rgb   <= rgb_mem[wr];
            dout_valid <= valid_mem[wr];
            dout_hsync <= hsync_mem[wr];
            dout_vsync <= vsync_mem[wr];
            mem[wr]       <= din;
            rgb_mem[wr]   <= din_rgb;
            valid_mem[wr] <= din_valid;
            hsync_mem[wr] <= din_hsync;
            vsync_mem[wr] <= din_vsync;
            wr <= (wr == WIDTH-1) ? 0 : wr + 1'b1;
        end
    end

endmodule
