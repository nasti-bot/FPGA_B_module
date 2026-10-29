// ============================================
// 模块：nms_core
// 功能：非极大值抑制（NMS）—— 把 Sobel 的粗边缘细化到 1 像素
// 输入：grad（梯度幅值）、gx_s/gy_s（有符号梯度，判断方向）、din_valid、
//       din_rgb（原图，穿行对齐输出）
// 输出：nms_grad（局部最大保留，否则 0）、dout_rgb（对齐原图）、dout_valid
// 说明：
//   1. 用 gx_s/gy_s 判断梯度方向，量化成 4 个方向（水平/垂直/两个对角）
//   2. 梯度穿行成 3x3 窗口，沿梯度方向比较中心与两个邻居
//   3. 中心 >= 两个邻居才保留，否则抑制为 0
//   4. 原图 rgb 一起穿行（延迟 LINE_W+1），和 nms_grad 严格对齐
//   LINE_W 必须是一行总周期（含消隐），800x480 时 = 1056
// ============================================
module nms_core #(
    parameter LINE_W = 1056    // 一行总周期含消隐
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [10:0] grad,           // 梯度幅值（sobel_core 的 G）
    input  wire signed [10:0] gx_s,    // 有符号 Gx（右减左）
    input  wire signed [10:0] gy_s,    // 有符号 Gy（下减上）
    input  wire [15:0] din_rgb,        // 原图（穿行对齐）
    input  wire din_valid,
    input  wire din_hsync,
    input  wire din_vsync,
    output wire [10:0] nms_grad,       // 细化后的梯度
    output wire [15:0] dout_rgb,       // 与原图对齐（延迟 LINE_W+1）
    output wire dout_valid,
    output wire dout_hsync,
    output wire dout_vsync
);

    // ===== 1. 梯度方向判断（组合逻辑，量化 4 方向）=====
    // ax = |Gx|, ay = |Gy|
    wire [10:0] ax = (gx_s < 0) ? (-gx_s) : gx_s;
    wire [10:0] ay = (gy_s < 0) ? (-gy_s) : gy_s;
    // 用 2.4 ≈ 12/5 近似 tan67.5°=2.414，移位+加法避免乘法器
    wire [14:0] ax5  = (ax << 2) + ax;       // 5*ax
    wire [14:0] ay5  = (ay << 2) + ay;       // 5*ay
    wire [14:0] ax12 = (ax << 3) + (ax << 2);// 12*ax
    wire [14:0] ay12 = (ay << 3) + (ay << 2);// 12*ay

    wire [1:0] dir;
    assign dir = (ay5 > ax12) ? 2'b01 :                 // 垂直：比较上下
                 (ax5 > ay12) ? 2'b00 :                 // 水平：比较左右
                 (gx_s[10] == gy_s[10]) ? 2'b10         // 同号：45°（左上-右下）
                                       : 2'b11;         // 异号：135°（右上-左下）

    // ===== 2. 行缓存：grad 穿 2 行，dir/valid 穿 1 行，rgb 穿 1 行 =====
    reg [10:0] g1 [0:LINE_W-1];   // grad 行缓存1（延迟 LINE_W）
    reg [10:0] g2 [0:LINE_W-1];   // grad 行缓存2（再延迟 LINE_W）
    reg [1:0]  d1 [0:LINE_W-1];   // dir 行缓存1
    reg [15:0] rgb1 [0:LINE_W-1]; // rgb 行缓存1
    reg        v1 [0:LINE_W-1];   // valid 行缓存1
    reg        v2 [0:LINE_W-1];   // valid 行缓存2
    reg        h1 [0:LINE_W-1];   // hsync 行缓存1
    reg        vs1 [0:LINE_W-1];  // vsync 行缓存1
    integer i;

    wire [10:0] r1g = g1[LINE_W-1];
    wire [10:0] r2g = g2[LINE_W-1];
    wire [1:0]  r1d = d1[LINE_W-1];
    wire [15:0] r1rgb = rgb1[LINE_W-1];
    wire        r1v = v1[LINE_W-1];
    wire        r2v = v2[LINE_W-1];
    wire        r1h = h1[LINE_W-1];
    wire        r1vs = vs1[LINE_W-1];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < LINE_W; i = i + 1) begin
                g1[i] <= 0; g2[i] <= 0; d1[i] <= 0; rgb1[i] <= 0;
                v1[i] <= 0; v2[i] <= 0; h1[i] <= 0; vs1[i] <= 0;
            end
        end else begin
            // 行缓存1：输入 grad/dir/rgb/valid/hsync/vsync
            for (i = LINE_W-1; i > 0; i = i - 1) begin
                g1[i] <= g1[i-1]; d1[i] <= d1[i-1]; rgb1[i] <= rgb1[i-1];
                v1[i] <= v1[i-1]; h1[i] <= h1[i-1]; vs1[i] <= vs1[i-1];
            end
            g1[0] <= grad; d1[0] <= dir; rgb1[0] <= din_rgb;
            v1[0] <= din_valid; h1[0] <= din_hsync; vs1[0] <= din_vsync;
            // 行缓存2：输入行缓存1的输出（grad 和 valid）
            for (i = LINE_W-1; i > 0; i = i - 1) begin
                g2[i] <= g2[i-1]; v2[i] <= v2[i-1];
            end
            g2[0] <= r1g; v2[0] <= r1v;
        end
    end

    // ===== 3. 列移位寄存器（d1/d2）=====
    reg [10:0] r0g_d1, r0g_d2, r1g_d1, r1g_d2, r2g_d1, r2g_d2;
    reg [1:0]  r1d_d1;
    reg [15:0] r1rgb_d1;
    reg r0v_d1, r0v_d2, r1v_d1, r1v_d2, r2v_d1, r2v_d2;
    reg r1h_d1, r1vs_d1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r0g_d1 <= 0; r0g_d2 <= 0; r1g_d1 <= 0; r1g_d2 <= 0; r2g_d1 <= 0; r2g_d2 <= 0;
            r1d_d1 <= 0; r1rgb_d1 <= 0; r1h_d1 <= 0; r1vs_d1 <= 0;
            r0v_d1 <= 0; r0v_d2 <= 0; r1v_d1 <= 0; r1v_d2 <= 0; r2v_d1 <= 0; r2v_d2 <= 0;
        end else begin
            r0g_d1 <= grad;  r0g_d2 <= r0g_d1;
            r1g_d1 <= r1g;   r1g_d2 <= r1g_d1;
            r2g_d1 <= r2g;   r2g_d2 <= r2g_d1;
            r1d_d1 <= r1d;   r1rgb_d1 <= r1rgb;
            r1h_d1 <= r1h;   r1vs_d1 <= r1vs;
            r0v_d1 <= din_valid; r0v_d2 <= r0v_d1;
            r1v_d1 <= r1v;       r1v_d2 <= r1v_d1;
            r2v_d1 <= r2v;       r2v_d2 <= r2v_d1;
        end
    end

    // 3x3 梯度窗口（中心 w11 = r1g_d1 = grad 延迟 LINE_W+1）
    wire [10:0] w00 = r2g_d2, w01 = r2g_d1, w02 = r2g;
    wire [10:0] w10 = r1g_d2, w11 = r1g_d1, w12 = r1g;
    wire [10:0] w20 = r0g_d2, w21 = r0g_d1, w22 = grad;   // r0 即当前输入 grad
    wire [1:0]  center_dir = r1d_d1;

    // ===== 4. 沿梯度方向选两个邻居 =====
    reg [10:0] n1, n2;
    always @(*) begin
        case (center_dir)
            2'b00: begin n1 = w10; n2 = w12; end   // 水平：左右
            2'b01: begin n1 = w01; n2 = w21; end   // 垂直：上下
            2'b10: begin n1 = w00; n2 = w22; end   // 45°：左上-右下
            2'b11: begin n1 = w02; n2 = w20; end   // 135°：右上-左下
            default: begin n1 = w10; n2 = w12; end
        endcase
    end

    // 中心是局部最大才保留
    wire is_max = (w11 >= n1) && (w11 >= n2);
    assign nms_grad   = is_max ? w11 : 11'd0;
    assign dout_rgb   = r1rgb_d1;           // 原图对齐
    assign dout_valid = r1v_d1 && r2v;
    assign dout_hsync = r1h_d1;
    assign dout_vsync = r1vs_d1;

endmodule
