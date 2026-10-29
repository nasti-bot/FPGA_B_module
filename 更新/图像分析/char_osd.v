// ============================================
// 模块：char_osd
// 功能：OSD 文字叠加 —— 在画面上指定位置叠加中文文字
// 输入：rgb565_in（原图）、din_valid/hsync/vsync、shape（锁存后的形状结论）
// 输出：rgb565_out（叠加文字后的图）、dout_valid
// 说明：
//   shape=01(圆)  → 显示「圆形」
//   shape=10(矩形) → 显示「矩形」
//   shape=00      → 不显示文字，原图直通
//   文字位置 X0,Y0（左上角），每字 16x16，2 个字共 32x16
//   行列计数器 col/row 在 din_valid 时递增，vsync 上升沿清零
// ============================================
module char_osd #(
    parameter IMG_W = 800,
    parameter IMG_H = 480,
    parameter X0 = 16,      // 文字区左上角 x
    parameter Y0 = 16       // 文字区左上角 y
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [15:0] rgb565_in,   // 原图 RGB565
    input  wire din_valid,
    input  wire din_hsync,
    input  wire din_vsync,
    input  wire [1:0] shape,        // 00都不是 01圆 10矩形（帧级锁存结论）
    output wire [15:0] rgb565_out,
    output wire dout_valid
);

    // 文字颜色：黄色（醒目，且和线A的红色边缘区分）
    localparam [15:0] TEXT_COLOR = 16'hFFE0;

    // ---- 行列计数器 ----
    reg [11:0] col, row;
    reg vsync_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col <= 0; row <= 0; vsync_d <= 0;
        end else begin
            vsync_d <= din_vsync;
            if (din_vsync && !vsync_d) begin   // vsync 上升沿 = 新帧
                col <= 0;
                row <= 0;
            end else if (din_valid) begin
                if (col == IMG_W - 1) begin    // 行末换行
                    col <= 0;
                    row <= row + 1;
                end else begin
                    col <= col + 1;
                end
            end
        end
    end

    // ---- 是否显示文字 ----
    wire show_text = (shape != 2'b00);

    // ---- 是否在文字区（2字 × 16x16 = 32x16）----
    wire in_text = show_text &&
                   (col >= X0) && (col < X0 + 32) &&
                   (row >= Y0) && (row < Y0 + 16);

    // ---- 文字区内偏移 ----
    wire [5:0] ox = col[5:0] - X0[5:0];   // 0~31
    wire [3:0] cy = row[3:0] - Y0[3:0];   // 0~15
    wire char_idx = ox[4];                 // 第0或第1个字
    wire [3:0] cx = ox[3:0];               // 字内列 0~15

    // ---- 字索引：第0个字=圆(0)或矩(2)，第1个字=形(1) ----
    wire [1:0] char_sel = char_idx ? 2'd1 : (shape == 2'b01 ? 2'd0 : 2'd2);

    // ---- 查字模：addr = {char_idx, row, byte_sel} ----
    wire byte_sel = cx[3];                 // 0=左半(列0~7) 1=右半(列8~15)
    wire [6:0] rom_addr = {char_sel[1:0], cy[3:0], byte_sel};
    wire [7:0] rom_data;
    char_rom u_rom (.addr(rom_addr), .data(rom_data));

    // ---- 取位：MSB first，bit = rom_data[7 - cx[2:0]] ----
    wire [2:0] bitpos = cx[2:0];
    wire bit_val = (rom_data >> (3'd7 - bitpos)) & 1'b1;

    // ---- 叠加：文字笔画处输出文字色，否则原图 ----
    assign rgb565_out = (in_text && bit_val) ? TEXT_COLOR : rgb565_in;
    assign dout_valid = din_valid;

endmodule
