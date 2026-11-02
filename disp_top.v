// disp_top：顶层，按键切换线A/线B，叠加输出。
//   key_mode 切 A/B；key_level 线A调 Sobel 档位、线B调二值化阈值。
//   结构：edge_pipeline(边缘) + boundary(边界/原图穿行) + shape_pipeline(形状识别)
//   + col/row 坐标重建 + 文字/黄边/红边叠加。线A/线B 共用 edge_pipeline。
//   输出优先级：黄边缘 > 文字 > 红边缘 > 原图。
module disp_top #(
    parameter IMG_W     = 800,
    parameter IMG_H     = 480,
    parameter LINE_W    = 1056,
    parameter MIN_AREA  = 300,
    parameter X0        = 16,
    parameter Y0        = 16
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [15:0] rgb565_in,
    input  wire din_valid,
    input  wire din_hsync,
    input  wire din_vsync,
    input  wire key_mode,
    input  wire key_level,
    input  wire key_debug,
    output wire [15:0] rgb565_out,
    output wire dout_valid,
    output wire dout_hsync,
    output wire dout_vsync
);

    localparam RED    = 16'hF800;
    localparam YELLOW = 16'hFFE0;

    // 按键消抖 + 模式切换
    wire key_pressed;
    key_debounce u_db (.clk(clk), .rst_n(rst_n), .key(key_mode), .key_pressed(key_pressed));
    reg mode;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) mode <= 1'b0;
        else if (key_pressed) mode <= ~mode;
    end

    // 阈值按键：线A调 Sobel 档位、线B调二值化阈值
    wire level_pressed;
    key_debounce u_db_level (.clk(clk), .rst_n(rst_n), .key(key_level), .key_pressed(level_pressed));
    reg [2:0] level;
    reg [2:0] bin_level;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            level <= 3'd3;      // 自适应阈值默认档3（系数4）
            bin_level <= 3'd5;  // 二值化默认档5 = 阈值192
        end else if (level_pressed) begin
            if (mode == 1'b0)
                level <= (level >= 3'd5) ? 3'd1 : level + 1'b1;
            else
                bin_level <= (bin_level >= 3'd5) ? 3'd1 : bin_level + 1'b1;
        end
    end

    wire [2:0] level_eff = level;

    // 二值化阈值：bin_flag = gray < thresh，阈值越高越灵敏（越多判成图形）
    wire [7:0] bin_thresh =
        (bin_level == 3'd1) ? 8'd64  :
        (bin_level == 3'd2) ? 8'd96  :
        (bin_level == 3'd3) ? 8'd128 :
        (bin_level == 3'd4) ? 8'd160 :
                              8'd192;

    // 调试模式：dbg=0正常 1二值图 2边界 3Sobel 4bbox
    wire dbg_pressed;
    key_debounce u_db_dbg (.clk(clk), .rst_n(rst_n), .key(key_debug), .key_pressed(dbg_pressed));
    reg [2:0] dbg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) dbg <= 3'd0;
        else if (dbg_pressed) dbg <= (dbg >= 3'd4) ? 3'd0 : dbg + 1'b1;
    end

    // 线A 边缘流水线
    wire edge_flag;
    wire [15:0] rgb_aligned;
    wire de_valid, de_hsync, de_vsync;
    wire clean_valid, clean_vsync;
    edge_pipeline #(
        .IMG_W(IMG_W), .IMG_H(IMG_H), .LINE_W(LINE_W)
    ) u_edge (
        .clk(clk), .rst_n(rst_n),
        .rgb565_in(rgb565_in),
        .din_valid(din_valid), .din_hsync(din_hsync), .din_vsync(din_vsync),
        .rgb565_out(),
        .level(level_eff),
        .edge_flag_out(edge_flag),
        .rgb_out(rgb_aligned),
        .dout_valid(de_valid), .dout_hsync(de_hsync), .dout_vsync(de_vsync),
        .clean_valid(clean_valid), .clean_vsync(clean_vsync)
    );

    // 线B 二值图：原图转灰度 + 阈值化
    wire [4:0] r5_b = rgb_aligned[15:11];
    wire [5:0] g6_b = rgb_aligned[10:5];
    wire [4:0] b5_b = rgb_aligned[4:0];
    wire [7:0] R8_b = {r5_b, 3'b000};
    wire [7:0] G8_b = {g6_b, 2'b00};
    wire [7:0] B8_b = {b5_b, 3'b000};
    wire [7:0] gray_b;
    rgb2gray u_gray_b (.R(R8_b), .G(G8_b), .B(B8_b), .Y(gray_b));

    wire bin_flag = (gray_b < bin_thresh);

    // 边界提取 + 原图/边缘穿行
    wire boundary_flag, bin_out, edge_out;
    wire [15:0] rgb_out;
    wire b_valid, b_hsync, b_vsync;
    boundary #(.LINE_W(LINE_W)) u_boundary (
        .clk(clk), .rst_n(rst_n),
        .bin(bin_flag),
        .edge_flag(edge_flag),
        .rgb_in(rgb_aligned),
        .din_valid(clean_valid), .din_hsync(de_hsync), .din_vsync(clean_vsync),
        .boundary_flag(boundary_flag), .bin_out(bin_out),
        .edge_out(edge_out), .rgb_out(rgb_out),
        .dout_valid(b_valid), .dout_hsync(b_hsync), .dout_vsync(b_vsync)
    );

    // 形状识别
    wire [1:0] shape;
    wire [10:0] bbox_x0, bbox_x1, bbox_y0, bbox_y1;
    shape_pipeline #(
        .IMG_W(IMG_W), .IMG_H(IMG_H), .MIN_AREA(MIN_AREA)
    ) u_shape (
        .clk(clk), .rst_n(rst_n),
        .edge_in(bin_out),
        .edge_valid(b_valid),
        .edge_vsync(b_vsync),
        .shape_out(shape),
        .area_out(),
        .bbox_x0(bbox_x0), .bbox_x1(bbox_x1), .bbox_y0(bbox_y0), .bbox_y1(bbox_y1),
        .dout_valid(), .dout_hsync(), .dout_vsync()
    );

    // 用 clean_valid/clean_vsync 重建 col/row，和边缘数据对齐
    reg [10:0] col, row;
    reg vsync_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col <= 0; row <= 0; vsync_d <= 0;
        end else begin
            vsync_d <= b_vsync;
            if (b_vsync && !vsync_d) begin
                col <= 0; row <= 0;
            end else if (b_valid) begin
                if (col == IMG_W - 1) begin
                    col <= 0; row <= row + 1;
                end else begin
                    col <= col + 1;
                end
            end
        end
    end

    // 形状外接框内判定
    wire shape_active = (shape != 2'b00);
    wire in_bbox = shape_active &&
                   (col >= bbox_x0) && (col <= bbox_x1) &&
                   (row >= bbox_y0) && (row <= bbox_y1);

    // 文字（左上角 32x16，查字模 ROM）
    wire in_text = shape_active &&
                   (col >= X0) && (col < X0 + 32) &&
                   (row >= Y0) && (row < Y0 + 16);
    wire [5:0] ox = col[5:0] - X0[5:0];
    wire [3:0] cy = row[3:0] - Y0[3:0];
    wire char_idx = ox[4];
    wire [3:0] cx = ox[3:0];
    wire [1:0] char_sel = char_idx ? 2'd1 : (shape == 2'b01 ? 2'd0 : 2'd2);
    wire byte_sel = cx[3];
    wire [6:0] rom_addr = {char_sel[1:0], cy[3:0], byte_sel};
    wire [7:0] rom_data;
    char_rom u_rom (.addr(rom_addr), .data(rom_data));
    wire [2:0] bitpos = cx[2:0];
    wire bit_val = (rom_data >> (3'd7 - bitpos)) & 1'b1;

    // 叠加：黄边缘 > 文字 > 红边缘 > 原图
    wire show_text   = (mode == 1'b1) && in_text && bit_val;
    wire show_yellow = (mode == 1'b1) && boundary_flag && in_bbox;
    wire show_red    = (mode == 1'b0) && edge_out;

    wire [15:0] normal_out = show_yellow ? YELLOW :
                             show_text   ? YELLOW :
                             show_red    ? RED :
                                           rgb_out;

    assign rgb565_out = (dbg == 3'd1) ? (bin_out       ? 16'hFFFF : 16'h0000) :
                        (dbg == 3'd2) ? (boundary_flag ? 16'hFFFF : 16'h0000) :
                        (dbg == 3'd3) ? (edge_out      ? 16'hFFFF : 16'h0000) :
                        (dbg == 3'd4) ? (in_bbox       ? 16'hFFE0 : rgb_out) :
                                        normal_out;

    assign dout_valid = b_valid;
    assign dout_hsync = b_hsync;
    assign dout_vsync = b_vsync;

endmodule
