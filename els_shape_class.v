// shape_class：形状分类。先用外接框长宽比，再用四角贴合度区分圆/矩形。
// 判据：长宽比 > 1.25 → 矩形；正方形框 + 四角都远离（极值点在中线）→ 圆；
// 其余（四角贴合的矩形）→ 矩形。宁可误判矩形，不把带角的误判成圆。
// 极值点：lx_row/rx_row/ty_col/by_col 是最左/最右像素的行、最上/最下像素的列。
// 正方形四角贴合（极值点离角≈0），圆的极值点在中线（离角≈W/2）。
module shape_class #(
    parameter MIN_AREA = 500    // 最小填充面积，过滤噪点
)(
    input  wire [19:0] area,
    input  wire [10:0] W,
    input  wire [10:0] H,
    input  wire [10:0] x0,
    input  wire [10:0] y0,
    input  wire [10:0] lx_row,
    input  wire [10:0] rx_row,
    input  wire [10:0] ty_col,
    input  wire [10:0] by_col,
    output reg  [1:0]  shape    // 00都不是 01圆 10矩形
);

    // 长宽比：W > 1.25H 或 H > 1.25W
    wire oblong = (W > H + (H >> 2)) || (H > W + (W >> 2));

    // 四角远离：4 个极值点离角都 >= 宽的 1/4（靠中线）才算圆
    wire [10:0] qw = W >> 2;
    wire [10:0] qh = H >> 2;
    wire round = (lx_row - y0 >= qh) && (rx_row - y0 >= qh) &&
                 (ty_col - x0 >= qw) && (by_col - x0 >= qw);

    always @(*) begin
        if (area < MIN_AREA)
            shape = 2'b00;
        else if (oblong)
            shape = 2'b10;
        else if (round)
            shape = 2'b01;
        else
            shape = 2'b10;
    end

endmodule
