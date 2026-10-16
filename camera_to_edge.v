module cam_to_edge #(
    parameter IMG_W = 16,
    parameter IMG_H = 16,
    parameter FIFO_DEPTH = 512
)(
    // ---- 摄像头侧 (pclk) ----
    input  wire        pclk,
    input  wire        rst_n_pclk,
    input  wire [7:0]  cam_R,
    input  wire [7:0]  cam_G,
    input  wire [7:0]  cam_B,
    input  wire        cam_de,//摄像头的data enable

    // ---- 系统侧 (clk) ----
    input  wire        clk,
    input  wire        rst_n,
    output wire        edge_flag
);

    // ========== 写侧 (pclk) ==========
    wire        fifo_wr_en = cam_de;
    wire [23:0] fifo_wr_data = {cam_R, cam_G, cam_B};

    // 写像素计数（用于产生 frame_done_pclk）
    reg [15:0] wr_pix_cnt;
    always @(posedge pclk or negedge rst_n_pclk)
        if (!rst_n_pclk)     wr_pix_cnt <= 0;
        else if (cam_de)
            if (wr_pix_cnt == IMG_W*IMG_H-1) wr_pix_cnt <= 0;
            else    wr_pix_cnt <= wr_pix_cnt + 1'b1;

    reg frame_done_pclk;
    always @(posedge pclk or negedge rst_n_pclk)
        if (!rst_n_pclk) frame_done_pclk <= 0;
        else frame_done_pclk <= cam_de && (wr_pix_cnt == IMG_W*IMG_H-1);
        //当数到 IMG_W*IMG_H-1（即一帧最后一个像素） 时归零并准备下一帧，同时将 frame_done_pclk 拉高一个 pclk 时钟周期

    // ========== 例化异步 FIFO ==========
    wire        fifo_full, fifo_empty;
    wire [23:0] fifo_dout;

    async_fifo #(.DW(24), .DEPTH(FIFO_DEPTH)) u_fifo (
        .wr_clk  (pclk),
        .wr_rst_n(rst_n_pclk),
        .wr_en   (fifo_wr_en & ~fifo_full),
        .wr_data (fifo_wr_data),
        .full    (fifo_full),

        .rd_clk  (clk),
        .rd_rst_n(rst_n),
        .rd_en   (fifo_rd_en),
        .rd_data (fifo_dout),
        .empty   (fifo_empty)
    );

    // ========== 跨时钟同步 frame_done ==========
    //将pclk时钟域的frame_done_pclk跨时钟同步到clk时钟域
    reg [2:0] fd_sync;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) fd_sync <= 3'b0;
        else        fd_sync <= {fd_sync[1:0], frame_done_pclk};
        //将frame_done_pclk同步2次减少亚稳态，再延迟一拍用于检测上升沿

        wire frame_ready_sync = fd_sync[2] & ~fd_sync[1];
        //上升沿检测，将frame_active同步到frame_active

        
    // ========== 读侧 (clk) ==========
    reg        frame_active;
    reg [15:0] rd_pix_cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_active <= 0;
            rd_pix_cnt   <= 0;
        end 
        else if (!frame_active && frame_ready_sync) begin
            frame_active <= 1'b1;
            rd_pix_cnt   <= 0;
        end 
        //读满一帧后将frame_active拉低后，等待新的frame_ready_sync脉冲到来时再拉高frame_active拉高读新的一帧
        else if (frame_active) begin
            if (rd_pix_cnt == IMG_W*IMG_H-1) begin
                frame_active <= 1'b0;
                rd_pix_cnt   <= 0;
            end 
            else begin
                rd_pix_cnt   <= rd_pix_cnt + 1'b1;
            end
            //当数到 IMG_W*IMG_H-1（即一帧最后一个像素） 时归零并准备下一帧
        end
    end

    wire fifo_rd_en = frame_active;   // 连续读

    // 拆 RGB
    wire [7:0] R    = fifo_dout[23:16];
    wire [7:0] G_in = fifo_dout[15:8];
    wire [7:0] B    = fifo_dout[7:0];

    // ========== 下游 ==========
    edge_pipeline #(.IMG_W(IMG_W), .THRESHOLD(100)) u_edge (
        .clk(clk), .rst_n(rst_n),
        .R(R), .G_in(G_in), .B(B),
        .edge_flag(edge_flag)
    );

endmodule