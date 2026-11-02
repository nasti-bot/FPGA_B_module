// edge_filter：边缘图的孤立点/微团过滤（去噪）。
// 8 邻域至少 2 个边缘邻居才保留，孤立点和成对噪点被删掉，闭合边缘不受影响。
//
// 行缓存用 BRAM，不是 for 循环移位：Efinity 不把 for 移位链推断成 SRL，
// 会全退化成 FF 爆资源。读写都非阻塞（读 rd=wr+1、写 wr，不同地址）。
// 坑：读地址是 wr+1 不是 wr，读 wr 会让窗口右列 e12/e02 错位成中心列，
// 真边缘被误删（当年红边从 960 掉到 682 就是这个）。
module edge_filter #(
    parameter LINE_W = 1056   // 完整行周期(含消隐)，800x480 时=1056，不是有效宽
)(
    input  wire clk,
    input  wire rst_n,
    input  wire edge_flag,
    input  wire [15:0] din_rgb,
    input  wire din_valid,
    input  wire din_hsync,
    input  wire din_vsync,
    output wire edge_filtered,
    output wire [15:0] dout_rgb,
    output wire dout_valid,
    output wire dout_hsync,
    output wire dout_vsync
);

    // 行缓存（BRAM）
    (* syn_ramstyle = "block_ram" *) reg        e1 [0:LINE_W-1];   // 边缘 上一行
    (* syn_ramstyle = "block_ram" *) reg        e2 [0:LINE_W-1];   // 边缘 上上行
    (* syn_ramstyle = "block_ram" *) reg [15:0] rgb1 [0:LINE_W-1]; // 原图 上一行
    (* syn_ramstyle = "block_ram" *) reg        v1 [0:LINE_W-1];   // valid 上一行
    (* syn_ramstyle = "block_ram" *) reg        v2 [0:LINE_W-1];   // valid 上上行
    (* syn_ramstyle = "block_ram" *) reg        h1 [0:LINE_W-1];   // hsync 上一行
    (* syn_ramstyle = "block_ram" *) reg        vs1 [0:LINE_W-1];  // vsync 上一行
    reg [10:0] wr;

    // 读地址 = 写地址 + 1，读到 LINE_W-1 拍前的值（上一行 col+1），
    // 再列移位 d1 变成上一行 col（中心）。
    wire [10:0] rd = (wr == LINE_W-1) ? 11'd0 : wr + 11'd1;

    reg        r1e, r2e, r1v, r2v, r1h, r1vs;
    reg [15:0] r1rgb;

    // 列移位寄存器
    reg r0e_d1, r0e_d2, r1e_d1, r1e_d2, r2e_d1, r2e_d2;
    reg [15:0] r1rgb_d1;
    reg r0v_d1, r0v_d2, r1v_d1, r1v_d2, r2v_d1, r2v_d2;
    reg r1h_d1, r1vs_d1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr <= 0;
            r1e <= 0; r2e <= 0; r1v <= 0; r2v <= 0; r1h <= 0; r1vs <= 0;
            r1rgb <= 0;
            r0e_d1 <= 0; r0e_d2 <= 0; r1e_d1 <= 0; r1e_d2 <= 0; r2e_d1 <= 0; r2e_d2 <= 0;
            r1rgb_d1 <= 0; r1h_d1 <= 0; r1vs_d1 <= 0;
            r0v_d1 <= 0; r0v_d2 <= 0; r1v_d1 <= 0; r1v_d2 <= 0; r2v_d1 <= 0; r2v_d2 <= 0;
        end else begin
            r1e   <= e1[rd];      // 上一行 col+1
            r2e   <= e2[rd];      // 上上行 col+1
            r1rgb <= rgb1[rd];
            r1v   <= v1[rd];
            r2v   <= v2[rd];
            r1h   <= h1[rd];
            r1vs  <= vs1[rd];

            e1[wr]   <= edge_flag;
            e2[wr]   <= r1e;      // r1e 上一拍是上一行 col，写进 e2 变上上行
            rgb1[wr] <= din_rgb;
            v1[wr]   <= din_valid;
            v2[wr]   <= r1v;
            h1[wr]   <= din_hsync;
            vs1[wr]  <= din_vsync;

            wr <= (wr == LINE_W-1) ? 0 : wr + 1'b1;

            // 列移位
            r0e_d1 <= edge_flag; r0e_d2 <= r0e_d1;
            r1e_d1 <= r1e;       r1e_d2 <= r1e_d1;
            r2e_d1 <= r2e;       r2e_d2 <= r2e_d1;
            r1rgb_d1 <= r1rgb;   r1h_d1 <= r1h; r1vs_d1 <= r1vs;
            r0v_d1 <= din_valid; r0v_d2 <= r0v_d1;
            r1v_d1 <= r1v;       r1v_d2 <= r1v_d1;
            r2v_d1 <= r2v;       r2v_d2 <= r2v_d1;
        end
    end

    // 3x3 窗口，中心 e11 = r1e_d1
    wire e00 = r2e_d2, e01 = r2e_d1, e02 = r2e;
    wire e10 = r1e_d2, e11 = r1e_d1, e12 = r1e;
    wire e20 = r0e_d2, e21 = r0e_d1, e22 = edge_flag;

    // 8 邻域边缘个数（8 个 1bit 相加）
    wire [3:0] nbr_cnt = e00 + e01 + e02 + e10 + e12 + e20 + e21 + e22;

    // 邻居数 >= 2 才保留：闭合边缘每个点都有前后 2 个邻居，完全保留；
    // 孤立点（0 邻居）和成对噪点（1 邻居）被删。
    assign edge_filtered = e11 & (nbr_cnt >= 2);
    assign dout_rgb      = r1rgb_d1;
    assign dout_valid    = r1v_d1 && r2v;
    assign dout_hsync    = r1h_d1;
    assign dout_vsync    = r1vs_d1;

endmodule
