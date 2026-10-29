// ============================================
// 模块：shape_pipeline（线B：认形状）
// 功能：单目标形状识别流水线（逐帧处理）
//   流程：565拆解 → 灰度化 → 阈值二值化 → shape_feat(面积+外接框) → shape_class(判形状)
// 输入：clk、rst_n、rgb565_in（16位RGB565）、din_valid/hsync/vsync（伴生信号）
// 输出：shape_out（2位：00都不是 01圆 10矩形）、dout_valid/hsync/vsync（帧结果同步脉冲）
// 说明：逐帧模块，shape_out 每帧出一个结论；
//       din_vsync 上升沿=新帧开始，dout_valid/vsync/hsync 在帧结果锁存时拉高一拍
// ============================================
module shape_pipeline #(
    parameter IMG_W = 16,
    parameter IMG_H = 16,
    parameter THRESHOLD = 128,
    parameter POLARITY = 1,    // 0=暗的算物体(gray<THRESHOLD)，1=亮的算物体(gray>THRESHOLD)
    parameter MIN_AREA = 500   // 最小面积：小于它的判「都不是」（过滤噪点团）
)(
    input  wire clk,
    input  wire rst_n,
    input  wire [15:0] rgb565_in,   // 摄像头来的 16 位 RGB565
    input  wire din_valid,           // 数据有效
    input  wire din_hsync,           // 行同步
    input  wire din_vsync,           // 帧同步
    output wire [1:0] shape_out,     // 00=都不是 01=圆 10=矩形
    output wire dout_valid,          // 帧结果有效脉冲
    output wire dout_hsync,          // 与 dout_valid 同步
    output wire dout_vsync           // 与 dout_valid 同步
);

    wire [7:0] gray;
    // 拆 565
    wire [4:0] r5 = rgb565_in[15:11];
    wire [5:0] g6 = rgb565_in[10:5];
    wire [4:0] b5 = rgb565_in[4:0];

    // 补成 8 位（左移补零）
    wire [7:0] R8 = {r5, 3'b000};
    wire [7:0] G8 = {g6, 2'b00};
    wire [7:0] B8 = {b5, 3'b000};

    rgb2gray u_gray (.R(R8), .G(G8), .B(B8), .Y(gray));

    // 阈值二值化：极性可配（暗物体/亮物体）
    wire px;
    assign px = POLARITY ? (gray > THRESHOLD) : (gray < THRESHOLD);

    wire [15:0] area;
    wire [7:0] min_x, max_x, min_y, max_y;
    wire frame_done;

    shape_feat #(.IMG_W(IMG_W), .IMG_H(IMG_H)) u_feat (
        .clk(clk), .rst_n(rst_n),
        .px(px), .px_valid(din_valid), .din_vsync(din_vsync),
        .area(area), .min_x(min_x), .max_x(max_x),
        .min_y(min_y), .max_y(max_y),
        .frame_done(frame_done)
    );

    // 外接框宽高（+1：第4列到第11列是8列，不是7）
    wire [7:0] W = max_x - min_x + 1;
    wire [7:0] H = max_y - min_y + 1;

    shape_class #(.MIN_AREA(MIN_AREA)) u_cls (.area(area), .W(W), .H(H), .shape(shape_out));

    // 伴生信号输出：帧结果有效时拉高一拍
    assign dout_valid = frame_done;
    assign dout_hsync = frame_done;
    assign dout_vsync = frame_done;

endmodule
