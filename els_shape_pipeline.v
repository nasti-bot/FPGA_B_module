// shape_pipeline：线B 形状识别。ccl_main 连通域分析找最大非贴边连通域，
// shape_class 用外接框长宽比 + 四角贴合度分类，再加优先级锁定防止抖动。
// 锁定：先出现的形状不切换，消失满 HYSTERESIS 帧才释放。
module shape_pipeline #(
    parameter IMG_W = 800,
    parameter IMG_H = 480,
    parameter MIN_AREA = 50,
    parameter HYSTERESIS = 4
)(
    input  wire clk,
    input  wire rst_n,
    input  wire edge_in,
    input  wire edge_valid,
    input  wire edge_vsync,
    output wire [1:0] shape_out,
    output wire [19:0] area_out,
    output wire [10:0] bbox_x0, bbox_x1, bbox_y0, bbox_y1,
    output wire dout_valid,
    output wire dout_hsync,
    output wire dout_vsync
);

    // 连通域分析：最大非贴边连通域
    wire [10:0] ccl_x0, ccl_x1, ccl_y0, ccl_y1;
    wire [10:0] ccl_lx, ccl_rx, ccl_ty, ccl_by;
    wire [19:0] ccl_fill;
    wire ccl_found, ccl_done;
    ccl_main #(.IMG_W(IMG_W), .IMG_H(IMG_H)) u_ccl (
        .clk(clk), .rst_n(rst_n),
        .px(edge_in), .px_valid(edge_valid), .px_vsync(edge_vsync),
        .bbox_x0(ccl_x0), .bbox_x1(ccl_x1), .bbox_y0(ccl_y0), .bbox_y1(ccl_y1),
        .lx_row(ccl_lx), .rx_row(ccl_rx), .ty_col(ccl_ty), .by_col(ccl_by),
        .area_out(), .fill_out(ccl_fill), .found(ccl_found), .frame_done(ccl_done)
    );

    // 当前帧分类
    wire [10:0] W    = ccl_found ? (ccl_x1 - ccl_x0 + 1) : 11'd0;
    wire [10:0] H    = ccl_found ? (ccl_y1 - ccl_y0 + 1) : 11'd0;
    wire [19:0] fill = ccl_found ? ccl_fill : 20'd0;
    wire [1:0] shape_raw;
    shape_class #(.MIN_AREA(MIN_AREA)) u_cls (
        .area(fill), .W(W), .H(H),
        .x0(ccl_x0), .y0(ccl_y0),
        .lx_row(ccl_lx), .rx_row(ccl_rx), .ty_col(ccl_ty), .by_col(ccl_by),
        .shape(shape_raw)
    );

    // 优先级锁定：先出现的不切换（分类 + 外接框一起锁）
    reg [1:0]  shape_reg;
    reg [3:0]  lost_cnt;
    reg [10:0] bbox_reg_x0, bbox_reg_x1, bbox_reg_y0, bbox_reg_y1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shape_reg <= 2'b00;
            lost_cnt <= 0;
            bbox_reg_x0 <= 11'h7FF; bbox_reg_x1 <= 11'd0;
            bbox_reg_y0 <= 11'h7FF; bbox_reg_y1 <= 11'd0;
        end else if (ccl_done) begin
            if (shape_reg == 2'b00) begin
                // 未锁定：出现形状立即锁定
                if (shape_raw != 2'b00) begin
                    shape_reg <= shape_raw;
                    bbox_reg_x0 <= ccl_x0; bbox_reg_x1 <= ccl_x1;
                    bbox_reg_y0 <= ccl_y0; bbox_reg_y1 <= ccl_y1;
                end
                lost_cnt <= 0;
            end else if (shape_raw == shape_reg) begin
                // 锁定形状还在：更新外接框
                bbox_reg_x0 <= ccl_x0; bbox_reg_x1 <= ccl_x1;
                bbox_reg_y0 <= ccl_y0; bbox_reg_y1 <= ccl_y1;
                lost_cnt <= 0;
            end else begin
                // 形状丢失，保持 HYSTERESIS 帧再切换
                if (lost_cnt >= HYSTERESIS) begin
                    shape_reg <= shape_raw;
                    if (shape_raw != 2'b00) begin
                        bbox_reg_x0 <= ccl_x0; bbox_reg_x1 <= ccl_x1;
                        bbox_reg_y0 <= ccl_y0; bbox_reg_y1 <= ccl_y1;
                    end else begin
                        bbox_reg_x0 <= 11'h7FF; bbox_reg_x1 <= 11'd0;
                        bbox_reg_y0 <= 11'h7FF; bbox_reg_y1 <= 11'd0;
                    end
                    lost_cnt <= 0;
                end else begin
                    lost_cnt <= lost_cnt + 1;
                end
            end
        end
    end

    // 未锁定时 bbox 退化，in_bbox 恒假不标黄
    assign bbox_x0 = (shape_reg != 2'b00) ? bbox_reg_x0 : 11'h7FF;
    assign bbox_x1 = (shape_reg != 2'b00) ? bbox_reg_x1 : 11'd0;
    assign bbox_y0 = (shape_reg != 2'b00) ? bbox_reg_y0 : 11'h7FF;
    assign bbox_y1 = (shape_reg != 2'b00) ? bbox_reg_y1 : 11'd0;

    assign area_out = fill;
    assign shape_out = shape_reg;

    assign dout_valid = ccl_done;
    assign dout_hsync = ccl_done;
    assign dout_vsync = ccl_done;

endmodule
