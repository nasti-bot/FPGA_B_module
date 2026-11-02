// boundary：二值图的边界提取（边缘带），顺带把原图/边缘穿行对齐。
// boundary_flag = 3x3 窗口内"既有图形也有背景"= 图形边缘带（约 3 像素粗）。
// bin_out 是延迟后的二值图中心（给形状识别），edge_out/rgb_out 是穿行对齐。
// 行缓存 BRAM（读 rd=wr+1、写 wr、非阻塞），理由同 edge_filter。
module boundary #(
    parameter LINE_W = 1056
)(
    input  wire clk,
    input  wire rst_n,
    input  wire bin,
    input  wire edge_flag,
    input  wire [15:0] rgb_in,
    input  wire din_valid,
    input  wire din_hsync,
    input  wire din_vsync,
    output wire boundary_flag,
    output wire bin_out,
    output wire edge_out,
    output wire [15:0] rgb_out,
    output wire dout_valid,
    output wire dout_hsync,
    output wire dout_vsync
);

    (* syn_ramstyle = "block_ram" *) reg        b1 [0:LINE_W-1];   // bin 上一行
    (* syn_ramstyle = "block_ram" *) reg        b2 [0:LINE_W-1];   // bin 上上行
    (* syn_ramstyle = "block_ram" *) reg        e1 [0:LINE_W-1];   // edge 上一行
    (* syn_ramstyle = "block_ram" *) reg [15:0] rgb1 [0:LINE_W-1]; // rgb 上一行
    (* syn_ramstyle = "block_ram" *) reg        v1 [0:LINE_W-1];   // valid 上一行
    (* syn_ramstyle = "block_ram" *) reg        v2 [0:LINE_W-1];   // valid 上上行
    (* syn_ramstyle = "block_ram" *) reg        h1 [0:LINE_W-1];   // hsync 上一行
    (* syn_ramstyle = "block_ram" *) reg        s1 [0:LINE_W-1];   // vsync 上一行
    reg [10:0] wr;

    wire [10:0] rd = (wr == LINE_W-1) ? 11'd0 : wr + 11'd1;

    reg        r1b, r2b, r1e, r1v, r2v, r1h, r1vs;
    reg [15:0] r1rgb;

    reg r0b_d1, r0b_d2, r1b_d1, r1b_d2, r2b_d1, r2b_d2;
    reg r1e_d1;
    reg [15:0] r1rgb_d1;
    reg r0v_d1, r0v_d2, r1v_d1, r1v_d2, r2v_d1, r2v_d2;
    reg r1h_d1, r1vs_d1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr <= 0;
            r1b <= 0; r2b <= 0; r1e <= 0; r1v <= 0; r2v <= 0; r1h <= 0; r1vs <= 0;
            r1rgb <= 0;
            r0b_d1 <= 0; r0b_d2 <= 0; r1b_d1 <= 0; r1b_d2 <= 0; r2b_d1 <= 0; r2b_d2 <= 0;
            r1e_d1 <= 0; r1rgb_d1 <= 0;
            r0v_d1 <= 0; r0v_d2 <= 0; r1v_d1 <= 0; r1v_d2 <= 0; r2v_d1 <= 0; r2v_d2 <= 0;
            r1h_d1 <= 0; r1vs_d1 <= 0;
        end else begin
            r1b   <= b1[rd];      // 上一行 col+1
            r2b   <= b2[rd];      // 上上行 col+1
            r1e   <= e1[rd];
            r1rgb <= rgb1[rd];
            r1v   <= v1[rd];
            r2v   <= v2[rd];
            r1h   <= h1[rd];
            r1vs  <= s1[rd];

            b1[wr]   <= bin;
            b2[wr]   <= r1b;
            e1[wr]   <= edge_flag;
            rgb1[wr] <= rgb_in;
            v1[wr]   <= din_valid;
            v2[wr]   <= r1v;
            h1[wr]   <= din_hsync;
            s1[wr]   <= din_vsync;

            wr <= (wr == LINE_W-1) ? 0 : wr + 1'b1;

            r0b_d1 <= bin; r0b_d2 <= r0b_d1;
            r1b_d1 <= r1b; r1b_d2 <= r1b_d1;
            r2b_d1 <= r2b; r2b_d2 <= r2b_d1;
            r1e_d1 <= r1e; r1rgb_d1 <= r1rgb;
            r0v_d1 <= din_valid; r0v_d2 <= r0v_d1;
            r1v_d1 <= r1v; r1v_d2 <= r1v_d1;
            r2v_d1 <= r2v; r2v_d2 <= r2v_d1;
            r1h_d1 <= r1h; r1vs_d1 <= r1vs;
        end
    end

    // 3x3 窗口
    wire b00 = r2b_d2, b01 = r2b_d1, b02 = r2b;
    wire b10 = r1b_d2, b11 = r1b_d1, b12 = r1b;
    wire b20 = r0b_d2, b21 = r0b_d1, b22 = bin;

    // 边缘带：窗口内既有图形也有背景
    wire any_one = b00 | b01 | b02 | b10 | b11 | b12 | b20 | b21 | b22;
    wire all_one = b00 & b01 & b02 & b10 & b11 & b12 & b20 & b21 & b22;
    assign boundary_flag = any_one & ~all_one;

    assign bin_out    = b11;
    assign edge_out   = r1e_d1;
    assign rgb_out    = r1rgb_d1;
    // valid 用纯延迟，和 bin_out 严格对齐（AND 会每行多 1 拍空档导致文字斜体）
    assign dout_valid = r1v_d1;
    assign dout_hsync = r1h_d1;
    assign dout_vsync = r1vs_d1;

endmodule
