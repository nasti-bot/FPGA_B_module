// ============================================
// 模块：shape_feat
// 功能：形状特征提取 —— 数面积 + 找外接框（逐帧处理）
// 输入：px（二值像素，1=物体）、px_valid（数据有效）
// 输出：area（物体像素总数）、min_x/max_x/min_y/max_y（外接框四边界）
// 说明：必须扫完整帧图，结果才有效（逐帧，不是逐像素）；
//       内部用两个计数器追踪行列坐标
// ============================================
module shape_feat #(
    parameter IMG_W = 5,
    parameter IMG_H = 5
)(
    input  wire clk,
    input  wire rst_n,
    input  wire px,
    input  wire px_valid,
    output reg  [15:0] area,   // 物体像素总数
    output reg  [7:0] min_x, max_x, min_y, max_y
);

    reg [7:0] col, row;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col <= 0;
            row <= 0;
            area <= 0;
            min_x <= 8'hFF;   // 找最小，初值设最大
            max_x <= 0;       // 找最大，初值设最小
            min_y <= 8'hFF;
            max_y <= 0;
        end else if (px_valid) begin
            // 数面积 + 找边界（只处理物体像素）
            if (px) begin
                area <= area + 1;      // 物体像素，面积 +1
                if (col < min_x) min_x <= col;
                if (col > max_x) max_x <= col;
                if (row < min_y) min_y <= row;
                if (row > max_y) max_y <= row;
            end
            // 追踪坐标：列到头换行
            if (col == IMG_W - 1) begin
                col <= 0;
                row <= row + 1;
            end else begin
                col <= col + 1;
            end
        end
    end

endmodule
