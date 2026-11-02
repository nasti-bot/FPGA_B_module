// frame_delay_1bit：一帧延迟，输出"上一帧同一位置"的值。
// BRAM 存一整帧，地址由 valid 计数、vsync 清零，read-first 读旧写新。
// 用途：边缘检测的时间域去闪动——闪动噪点帧间随机出现，真边缘稳定，
// 把当前帧边缘和这一帧延迟(上一帧)做 AND，只保留两帧都在的稳定边缘。
module frame_delay_1bit #(
    parameter IMG_W = 800,
    parameter IMG_H = 480
)(
    input  wire clk,
    input  wire rst_n,
    input  wire din,
    input  wire din_valid,
    input  wire din_vsync,
    output reg  dout
);

    localparam DEPTH = IMG_W * IMG_H;   // 800*480 = 384000

    (* syn_ramstyle = "block_ram" *) reg mem [0:DEPTH-1];
    reg [18:0] addr;
    reg        vsync_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            addr <= 0; vsync_d <= 0; dout <= 0;
        end else begin
            vsync_d <= din_vsync;
            if (din_vsync && !vsync_d) begin
                addr <= 0;                 // 新一帧，地址归零
            end else if (din_valid) begin
                addr <= addr + 1;
            end

            if (din_valid) begin
                dout      <= mem[addr];   // 读上一帧同位置
                mem[addr] <= din;         // 写这一帧
            end
        end
    end

endmodule
