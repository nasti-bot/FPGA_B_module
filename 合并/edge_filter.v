// ============================================
// 模块：edge_filter（连通域过滤，去孤立噪点）
// 功能：去掉孤立的单点边缘（雪花噪点），保留连续的边缘线
// 原理：噪点是孤立单点（8 邻域没有其他边缘），边缘是连续线（有邻居）
//   中心边缘=1 且 8 邻域至少有一个边缘 → 保留
//   中心边缘=1 且 8 邻域全 0          → 孤立噪点，去掉
// 输入：edge_flag（二值边缘）、din_rgb（原图，穿行对齐）、valid/hsync/vsync
// 输出：edge_filtered、dout_rgb（对齐）、dout_valid/hsync/vsync
//   LINE_W 必须是一行总周期（含消隐），800x480 时 = 1056
// ============================================
module edge_filter #(
    parameter LINE_W = 1056
)(
    input  wire clk,
    input  wire rst_n,
    input  wire edge_flag,          // 二值边缘（1=边缘）
    input  wire [15:0] din_rgb,     // 原图（穿行对齐）
    input  wire din_valid,
    input  wire din_hsync,
    input  wire din_vsync,
    output wire edge_filtered,      // 过滤后的边缘
    output wire [15:0] dout_rgb,    // 与原图对齐（延迟 LINE_W+1）
    output wire dout_valid,
    output wire dout_hsync,
    output wire dout_vsync
);

    // ===== 行缓存：edge 穿 2 行，rgb/valid 穿 2 行，hsync/vsync 穿 1 行 =====
    reg        e1 [0:LINE_W-1];   // edge 行缓存1
    reg        e2 [0:LINE_W-1];   // edge 行缓存2
    reg [15:0] rgb1 [0:LINE_W-1]; // rgb 行缓存1
    reg        v1 [0:LINE_W-1];   // valid 行缓存1
    reg        v2 [0:LINE_W-1];   // valid 行缓存2
    reg        h1 [0:LINE_W-1];   // hsync 行缓存1
    reg        vs1 [0:LINE_W-1];  // vsync 行缓存1
    integer i;

    wire        r1e = e1[LINE_W-1];
    wire        r2e = e2[LINE_W-1];
    wire [15:0] r1rgb = rgb1[LINE_W-1];
    wire        r1v = v1[LINE_W-1];
    wire        r2v = v2[LINE_W-1];
    wire        r1h = h1[LINE_W-1];
    wire        r1vs = vs1[LINE_W-1];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < LINE_W; i = i + 1) begin
                e1[i] <= 0; e2[i] <= 0; rgb1[i] <= 0;
                v1[i] <= 0; v2[i] <= 0; h1[i] <= 0; vs1[i] <= 0;
            end
        end else begin
            // 行缓存1：输入 edge/rgb/valid/hsync/vsync
            for (i = LINE_W-1; i > 0; i = i - 1) begin
                e1[i] <= e1[i-1]; rgb1[i] <= rgb1[i-1];
                v1[i] <= v1[i-1]; h1[i] <= h1[i-1]; vs1[i] <= vs1[i-1];
            end
            e1[0] <= edge_flag; rgb1[0] <= din_rgb;
            v1[0] <= din_valid; h1[0] <= din_hsync; vs1[0] <= din_vsync;
            // 行缓存2：输入行缓存1的输出（edge 和 valid）
            for (i = LINE_W-1; i > 0; i = i - 1) begin
                e2[i] <= e2[i-1]; v2[i] <= v2[i-1];
            end
            e2[0] <= r1e; v2[0] <= r1v;
        end
    end

    // ===== 列移位寄存器（d1/d2）=====
    reg r0e_d1, r0e_d2, r1e_d1, r1e_d2, r2e_d1, r2e_d2;
    reg [15:0] r1rgb_d1;
    reg r0v_d1, r0v_d2, r1v_d1, r1v_d2, r2v_d1, r2v_d2;
    reg r1h_d1, r1vs_d1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r0e_d1 <= 0; r0e_d2 <= 0; r1e_d1 <= 0; r1e_d2 <= 0; r2e_d1 <= 0; r2e_d2 <= 0;
            r1rgb_d1 <= 0; r1h_d1 <= 0; r1vs_d1 <= 0;
            r0v_d1 <= 0; r0v_d2 <= 0; r1v_d1 <= 0; r1v_d2 <= 0; r2v_d1 <= 0; r2v_d2 <= 0;
        end else begin
            r0e_d1 <= edge_flag; r0e_d2 <= r0e_d1;
            r1e_d1 <= r1e;       r1e_d2 <= r1e_d1;
            r2e_d1 <= r2e;       r2e_d2 <= r2e_d1;
            r1rgb_d1 <= r1rgb;   r1h_d1 <= r1h; r1vs_d1 <= r1vs;
            r0v_d1 <= din_valid; r0v_d2 <= r0v_d1;
            r1v_d1 <= r1v;       r1v_d2 <= r1v_d1;
            r2v_d1 <= r2v;       r2v_d2 <= r2v_d1;
        end
    end

    // 3x3 边缘窗口（中心 = r1e_d1）
    wire e00 = r2e_d2, e01 = r2e_d1, e02 = r2e;
    wire e10 = r1e_d2, e11 = r1e_d1, e12 = r1e;
    wire e20 = r0e_d2, e21 = r0e_d1, e22 = edge_flag;   // r0 即当前输入 edge_flag

    // 8 邻域是否有边缘（中心 e11 除外）
    wire has_neighbor = e00 | e01 | e02 | e10 | e12 | e20 | e21 | e22;

    // 中心是边缘 且 有邻居 → 保留；孤立点 → 去掉
    assign edge_filtered = e11 & has_neighbor;
    assign dout_rgb      = r1rgb_d1;
    assign dout_valid    = r1v_d1 && r2v;
    assign dout_hsync    = r1h_d1;
    assign dout_vsync    = r1vs_d1;

endmodule
