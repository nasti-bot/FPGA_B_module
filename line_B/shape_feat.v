// ============================================
// 模块：shape_feat
// 功能：形状特征提取 —— 数面积 + 找外接框（逐帧处理）
// 输入：px（二值像素，1=物体）、px_valid（数据有效）、din_vsync（帧同步）
// 输出：area（物体像素总数）、min_x/max_x/min_y/max_y（外接框四边界）、frame_done（帧结果有效脉冲）
// 说明：din_vsync 上升沿 = 一帧结束，锁存当前结果并清零，开始统计新帧；
//       frame_done 在锁存那一刻拉高一拍，标记输出有效
// ============================================
module shape_feat #(
    parameter IMG_W = 5,
    parameter IMG_H = 5
)(
    input  wire clk,
    input  wire rst_n,
    input  wire px,
    input  wire px_valid,
    input  wire din_vsync,      // 帧同步（高有效，上升沿=新帧开始）
    output reg  [15:0] area,    // 物体像素总数（锁存后的一帧结果）
    output reg  [7:0] min_x, max_x, min_y, max_y,
    output reg  frame_done      // 一帧结果有效的脉冲（1拍）
);

    // 内部累计器
    reg [15:0] area_acc;
    reg [7:0]  min_x_acc, max_x_acc, min_y_acc, max_y_acc;
    reg [7:0]  col, row;
    reg vsync_d;   // vsync 打一拍，用于检测上升沿

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col <= 0;
            row <= 0;
            area_acc <= 0;
            min_x_acc <= 8'hFF;
            max_x_acc <= 0;
            min_y_acc <= 8'hFF;
            max_y_acc <= 0;
            area  <= 0;
            min_x <= 8'hFF;
            max_x <= 0;
            min_y <= 8'hFF;
            max_y <= 0;
            frame_done <= 0;
            vsync_d <= 0;
        end else begin
            // 检测 vsync 上升沿
            vsync_d <= din_vsync;

            // vsync 上升沿：锁存当前帧结果，清零累计器，输出 frame_done
            if (din_vsync && !vsync_d) begin
                area  <= area_acc;
                min_x <= min_x_acc;
                max_x <= max_x_acc;
                min_y <= min_y_acc;
                max_y <= max_y_acc;
                frame_done <= 1'b1;
                // 清零累计器，开始新帧
                area_acc <= 0;
                min_x_acc <= 8'hFF;
                max_x_acc <= 0;
                min_y_acc <= 8'hFF;
                max_y_acc <= 0;
                col <= 0;
                row <= 0;
            end else if (px_valid) begin
                frame_done <= 0;
                // 数面积 + 找边界（只处理物体像素）
                if (px) begin
                    area_acc <= area_acc + 1;
                    if (col < min_x_acc) min_x_acc <= col;
                    if (col > max_x_acc) max_x_acc <= col;
                    if (row < min_y_acc) min_y_acc <= row;
                    if (row > max_y_acc) max_y_acc <= row;
                end
                // 追踪坐标：列到头换行
                if (col == IMG_W - 1) begin
                    col <= 0;
                    row <= row + 1;
                end else begin
                    col <= col + 1;
                end
            end else begin
                frame_done <= 0;
            end
        end
    end

endmodule
