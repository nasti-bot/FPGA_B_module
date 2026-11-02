// ccl_main：连通域分析，run 级单遍扫描。逐行提取横向 run，和上一行 run 重叠匹配
// 定标签，找出最大非贴边连通域的外接框、填充面积、4 个极值点。
// 圆/矩形是凸形状，单遍扫描即可，不用并查集。填充面积 = 每行最左~最右跨度之和。
// 写法：A1/A2/A3 三段组合块（纯阻塞）+ B 一段时序块（纯非阻塞），严格分离，
// 别在时序块里用阻塞赋值塞临时变量。
module ccl_main #(
    parameter IMG_W     = 800,
    parameter IMG_H     = 480,
    parameter MAX_LABEL = 16,    // 标签 1..MAX_LABEL-1，0=无
    parameter LBLW      = 4,     // log2(MAX_LABEL)
    parameter MAX_RUNS  = 16     // 每行最多 run 数
)(
    input  wire clk,
    input  wire rst_n,
    input  wire px,
    input  wire px_valid,
    input  wire px_vsync,
    output reg  [10:0] bbox_x0, bbox_x1, bbox_y0, bbox_y1,
    output reg  [10:0] lx_row, rx_row, ty_col, by_col,
    output reg  [19:0] area_out,
    output reg  [19:0] fill_out,
    output reg  found,
    output reg  frame_done
);

    // 状态寄存器
    reg [10:0] col, row;
    reg        in_run;
    reg [10:0] run_start;
    reg [5:0]  next_label;
    reg        label_full;
    reg        vsync_d;

    // run 表
    reg [10:0]     prun_start [0:MAX_RUNS-1];
    reg [10:0]     prun_end   [0:MAX_RUNS-1];
    reg [LBLW-1:0] prun_label [0:MAX_RUNS-1];
    reg [5:0]      num_prev;

    reg [10:0]     crun_start [0:MAX_RUNS-1];
    reg [10:0]     crun_end   [0:MAX_RUNS-1];
    reg [LBLW-1:0] crun_label [0:MAX_RUNS-1];
    reg [5:0]      num_curr;

    // 连通域数据表：外接框 + 填充面积 + 行内 min/max + 极值点
    reg [10:0] comp_x0 [0:MAX_LABEL-1];
    reg [10:0] comp_x1 [0:MAX_LABEL-1];
    reg [10:0] comp_y0 [0:MAX_LABEL-1];
    reg [10:0] comp_y1 [0:MAX_LABEL-1];
    reg [19:0] comp_fill [0:MAX_LABEL-1];
    reg [10:0] comp_row_x0 [0:MAX_LABEL-1];
    reg [10:0] comp_row_x1 [0:MAX_LABEL-1];
    reg        comp_row_touched [0:MAX_LABEL-1];
    reg [10:0] comp_lx_row [0:MAX_LABEL-1];   // 最左像素的行号（四角贴合判据）
    reg [10:0] comp_rx_row [0:MAX_LABEL-1];   // 最右像素的行号
    reg [10:0] comp_ty_col [0:MAX_LABEL-1];   // 最上像素的列号
    reg [10:0] comp_by_col [0:MAX_LABEL-1];   // 最下像素的列号

    integer i;
    genvar  gi;

    // (A1) 组合：判定本拍是否收尾一个 run 及 [fin_s, fin_e]
    reg        do_fin;
    reg [10:0] fin_s, fin_e;
    reg        in_run_next;
    reg [10:0] run_start_next;

    always @(*) begin
        do_fin         = 1'b0;
        fin_s          = 11'd0;
        fin_e          = 11'd0;
        in_run_next    = in_run;
        run_start_next = run_start;

        if (px) begin
            if (!in_run) begin
                run_start_next = col;
                in_run_next    = 1'b1;
                if (col == IMG_W - 1) begin
                    do_fin      = 1'b1; fin_s = col; fin_e = col;
                    in_run_next = 1'b0;
                end
            end else if (col == IMG_W - 1) begin
                do_fin      = 1'b1; fin_s = run_start; fin_e = IMG_W - 1;
                in_run_next = 1'b0;
            end
        end else begin
            if (in_run) begin
                do_fin      = 1'b1; fin_s = run_start; fin_e = col - 1'b1;
                in_run_next = 1'b0;
            end
        end
    end

    // (A2) 组合：run 与上一行重叠匹配，定标签
    reg        any_overlap;
    reg [LBLW-1:0] first_lab;

    always @(*) begin
        any_overlap = 1'b0;
        first_lab   = {LBLW{1'b0}};
        for (i = 0; i < MAX_RUNS; i = i + 1) begin
            if (i < num_prev && prun_start[i] <= fin_e && prun_end[i] >= fin_s) begin
                if (!any_overlap) begin
                    first_lab   = prun_label[i];
                    any_overlap = 1'b1;
                end
            end
        end
    end

    wire [LBLW-1:0] run_lab_w   = any_overlap ? first_lab
                                              : (label_full ? {LBLW{1'b0}} : next_label[LBLW-1:0]);
    wire            new_label_w = (!any_overlap) && (!label_full);

    // (A3) 组合：帧末树形归约选最大连通域（log2(16)=4 级）。
    //   之前用串联 for 循环，组合逻辑 66 级 LUT、62ns，36MHz 下违例 35ns，
    //   改成两两归约后降到 4 级。候选编码 [24:0]={valid[24],lab[23:20],fill[19:0]}。

    // 每个标签是否"非贴边"（离图像边界都 >0）
    wire [MAX_LABEL-1:0] bfree;
    generate
        for (gi = 1; gi < MAX_LABEL; gi = gi + 1) begin : gen_bfree
            assign bfree[gi] = (comp_x0[gi] > 0) && (comp_x1[gi] < IMG_W-1) &&
                               (comp_y0[gi] > 0) && (comp_y1[gi] < IMG_H-1);
        end
    endgenerate
    assign bfree[0] = 1'b0;

    // 两两归约：valid 优先，然后 fill 大的
    function [24:0] max2;
        input [24:0] a, b;
        begin
            if (!a[24])                 max2 = b;
            else if (!b[24])            max2 = a;
            else if (a[19:0] >= b[19:0]) max2 = a;
            else                        max2 = b;
        end
    endfunction

    // 每个标签的候选：全局 g（不看贴边）、非贴边 best
    wire [24:0] g_cand    [0:MAX_LABEL-1];
    wire [24:0] best_cand [0:MAX_LABEL-1];
    generate
        for (gi = 0; gi < MAX_LABEL; gi = gi + 1) begin : gen_cand
            localparam [LBLW-1:0] lab = gi;   // genvar 不能位选择，先转成 4 位常量
            assign g_cand[gi]    = {comp_fill[gi] != 0, lab, comp_fill[gi]};
            assign best_cand[gi] = {bfree[gi] && (comp_fill[gi] != 0), lab, comp_fill[gi]};
        end
    endgenerate

    // ---- 树形归约 4 级（16→8→4→2→1）----
    wire [24:0] g1 [0:7], g2 [0:3], g3 [0:1];
    wire [24:0] b1 [0:7], b2 [0:3], b3 [0:1];
    generate
        for (gi = 0; gi < 8; gi = gi + 1) begin : gen_l1
            assign g1[gi] = max2(g_cand[2*gi], g_cand[2*gi+1]);
            assign b1[gi] = max2(best_cand[2*gi], best_cand[2*gi+1]);
        end
        for (gi = 0; gi < 4; gi = gi + 1) begin : gen_l2
            assign g2[gi] = max2(g1[2*gi], g1[2*gi+1]);
            assign b2[gi] = max2(b1[2*gi], b1[2*gi+1]);
        end
        for (gi = 0; gi < 2; gi = gi + 1) begin : gen_l3
            assign g3[gi] = max2(g2[2*gi], g2[2*gi+1]);
            assign b3[gi] = max2(b2[2*gi], b2[2*gi+1]);
        end
    endgenerate
    wire [24:0] g_sel    = max2(g3[0], g3[1]);
    wire [24:0] best_sel = max2(b3[0], b3[1]);

    wire            sel_valid = best_sel[24] | g_sel[24];
    wire [LBLW-1:0] sel_lab   = best_sel[24] ? best_sel[23:20] : g_sel[23:20];

    // (B) 时序块：纯非阻塞寄存器更新
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col <= 0; row <= 0;
            in_run <= 0; run_start <= 0;
            next_label <= 1; label_full <= 0;
            num_prev <= 0; num_curr <= 0;
            vsync_d <= 0; frame_done <= 0;
            bbox_x0 <= 0; bbox_x1 <= 0; bbox_y0 <= 0; bbox_y1 <= 0;
            area_out <= 0; fill_out <= 0; found <= 0;
            for (i = 0; i < MAX_LABEL; i = i + 1) begin
                comp_x0[i] <= 11'h7FF; comp_x1[i] <= 0;
                comp_y0[i] <= 11'h7FF; comp_y1[i] <= 0;
                comp_fill[i] <= 0;
                comp_row_x0[i] <= 11'h7FF; comp_row_x1[i] <= 0;
                comp_row_touched[i] <= 0;
                comp_lx_row[i] <= 0; comp_rx_row[i] <= 0;
                comp_ty_col[i] <= 0; comp_by_col[i] <= 0;
            end
            for (i = 0; i < MAX_RUNS; i = i + 1) begin
                prun_start[i] <= 0; prun_end[i] <= 0; prun_label[i] <= 0;
                crun_start[i] <= 0; crun_end[i] <= 0; crun_label[i] <= 0;
            end
        end else begin
            if (px_vsync && !vsync_d) begin
                // ---- 帧末：锁存组合块选出的连通域，再清零 ----
                if (sel_valid) begin
                    found    <= 1'b1;
                    area_out <= comp_fill[sel_lab];
                    fill_out <= comp_fill[sel_lab];
                    bbox_x0  <= comp_x0[sel_lab];
                    bbox_x1  <= comp_x1[sel_lab];
                    bbox_y0  <= comp_y0[sel_lab];
                    bbox_y1  <= comp_y1[sel_lab];
                    lx_row   <= comp_lx_row[sel_lab];
                    rx_row   <= comp_rx_row[sel_lab];
                    ty_col   <= comp_ty_col[sel_lab];
                    by_col   <= comp_by_col[sel_lab];
                end else begin
                    found    <= 1'b0;
                    area_out <= 0; fill_out <= 0;
                    bbox_x0  <= 0; bbox_x1 <= 0; bbox_y0 <= 0; bbox_y1 <= 0;
                    lx_row <= 0; rx_row <= 0; ty_col <= 0; by_col <= 0;
                end
                frame_done <= 1'b1;
                col <= 0; row <= 0;
                in_run <= 0; run_start <= 0;
                next_label <= 1; label_full <= 0;
                num_prev <= 0; num_curr <= 0;
                for (i = 0; i < MAX_LABEL; i = i + 1) begin
                    comp_x0[i] <= 11'h7FF; comp_x1[i] <= 0;
                    comp_y0[i] <= 11'h7FF; comp_y1[i] <= 0;
                    comp_fill[i] <= 0;
                    comp_row_x0[i] <= 11'h7FF; comp_row_x1[i] <= 0;
                    comp_row_touched[i] <= 0;
                    comp_lx_row[i] <= 0; comp_rx_row[i] <= 0;
                    comp_ty_col[i] <= 0; comp_by_col[i] <= 0;
                end
                for (i = 0; i < MAX_RUNS; i = i + 1) begin
                    prun_start[i] <= 0; prun_end[i] <= 0; prun_label[i] <= 0;
                    crun_start[i] <= 0; crun_end[i] <= 0; crun_label[i] <= 0;
                end
            end else if (px_valid) begin
                frame_done <= 1'b0;
                in_run    <= in_run_next;
                run_start <= run_start_next;

                if (do_fin) begin
                    if (run_lab_w != 0) begin
                        if (fin_s < comp_x0[run_lab_w]) begin comp_x0[run_lab_w] <= fin_s; comp_lx_row[run_lab_w] <= row; end
                        if (fin_e > comp_x1[run_lab_w]) begin comp_x1[run_lab_w] <= fin_e; comp_rx_row[run_lab_w] <= row; end
                        if (row < comp_y0[run_lab_w]) begin comp_y0[run_lab_w] <= row; comp_ty_col[run_lab_w] <= fin_s; end
                        if (row > comp_y1[run_lab_w]) begin comp_y1[run_lab_w] <= row; comp_by_col[run_lab_w] <= fin_s; end
                        if (fin_s < comp_row_x0[run_lab_w]) comp_row_x0[run_lab_w] <= fin_s;
                        if (fin_e > comp_row_x1[run_lab_w]) comp_row_x1[run_lab_w] <= fin_e;
                        comp_row_touched[run_lab_w] <= 1'b1;
                    end
                    if (num_curr < MAX_RUNS) begin
                        crun_start[num_curr] <= fin_s;
                        crun_end[num_curr]   <= fin_e;
                        crun_label[num_curr] <= run_lab_w;
                        num_curr <= num_curr + 1'b1;
                    end
                    if (new_label_w) begin
                        next_label <= next_label + 1'b1;
                        if (next_label + 1'b1 >= MAX_LABEL) label_full <= 1'b1;
                    end
                end

                if (col == IMG_W - 1) begin
                    for (i = 0; i < MAX_RUNS; i = i + 1) begin
                        prun_start[i] <= crun_start[i];
                        prun_end[i]   <= crun_end[i];
                        prun_label[i] <= crun_label[i];
                    end
                    num_prev <= num_curr;
                    num_curr <= 0;
                    for (i = 1; i < MAX_LABEL; i = i + 1) begin
                        if (comp_row_touched[i])
                            comp_fill[i] <= comp_fill[i] + (comp_row_x1[i] - comp_row_x0[i] + 1'b1);
                        comp_row_touched[i] <= 0;
                        comp_row_x0[i] <= 11'h7FF;
                        comp_row_x1[i] <= 0;
                    end
                    col <= 0; row <= row + 1;
                end else begin
                    col <= col + 1;
                end
            end else begin
                frame_done <= 1'b0;
            end

            vsync_d <= px_vsync;
        end
    end

endmodule
