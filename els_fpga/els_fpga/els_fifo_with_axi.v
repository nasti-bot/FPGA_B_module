`timescale 1ns / 1ps

module els_fifo_with_axi #(

    parameter IMAGE_WIDTH=800,
    parameter IMAGE_HEIGHT=480,

    parameter FIFO_DW=16,//FIFO_DW=FIFO_TO_OUT_DATA_WIDTH:即fifo向外的数据位宽
//    parameter AXI_WR_ADDR_BEGIN=0,
//    parameter AXI_WR_ADDR_END=1023,
//    parameter AXI_RD_ADDR_BEGIN=0,
//    parameter AXI_RD_ADDR_END=1023,
    
    parameter AXI_DATA_WIDTH=128,//实际上相当于fifo向内的数据位宽
    parameter AXI_ADDR_WIDTH=30,
    parameter AXI_ID_WIDTH=4,
//    parameter AXI_ID=0,
    parameter AXI_BURST_LEN=31,
    parameter FIFO_TO_AXI_DATA_DEPTH=64,//fifo向内的数据（地址）深度
    
    localparam FIFO_TO_AXI_DATA_DEPTH_WIDTH=$clog2(FIFO_TO_AXI_DATA_DEPTH),//fifo向内的地址位宽
    localparam FIFO_TO_OUT_DATA_DEPTH=FIFO_TO_AXI_DATA_DEPTH*AXI_DATA_WIDTH/FIFO_DW,//fifo向外的数据深度，满足此乘积关系
    localparam FIFO_TO_OUT_DATA_DEPTH_WIDTH=$clog2(FIFO_TO_OUT_DATA_DEPTH)//fifo向外的地址位宽
    )
(   input clk,
    input reset,
    
    input axi_wr_en,
    input axi_rd_en,
    
    input wrfifo_clr,
    input wrfifo_clk,
    input wrfifo_wr_en,
    input [FIFO_DW-1:0] wrfifo_din,
    input rdfifo_clr,
    input rdfifo_clk,
    input rdfifo_rd_en,
    output wrfifo_full,
    output [FIFO_TO_OUT_DATA_DEPTH_WIDTH-1:0] wrfifo_wr_cnt,
    output [FIFO_DW-1:0] rdfifo_dout,
    output rdfifo_empty,
    output [FIFO_TO_OUT_DATA_DEPTH_WIDTH-1:0] rdfifo_rd_cnt,
    output wrfifo_empty,
    output rdfifo_full,
    
    input [30:0] axi_wr_addr_begin,
    input [30:0] axi_wr_addr_end,
    input [30:0] axi_rd_addr_begin,
    input [30:0] axi_rd_addr_end,
    
    input [AXI_ID_WIDTH-1:0] axi_id,
    
    output [AXI_ID_WIDTH-1:0] m_axi_awid,
    output [AXI_ADDR_WIDTH-1:0] m_axi_awaddr,
    output [7:0] m_axi_awlen,
    output [2:0] m_axi_awsize,
    output [1:0] m_axi_awburst,
    output [0:0] m_axi_awlock,
    output [3:0] m_axi_awcache,
    output [2:0] m_axi_awprot,
    output [3:0] m_axi_awqos,
    output [3:0] m_axi_awregion,
    output m_axi_awvalid,
    input m_axi_awready,
    
    output m_axi_wvalid,
    input m_axi_wready,
    output m_axi_wlast,
    output [AXI_DATA_WIDTH-1:0] m_axi_wdata,
    output [AXI_DATA_WIDTH/8-1:0] m_axi_wstrb,
    
    input m_axi_bvalid,
    output m_axi_bready,
    input [AXI_ID_WIDTH-1:0] m_axi_bid,
    input [1:0] m_axi_bresp,
    
    output [AXI_ID_WIDTH-1:0] m_axi_arid,
    output [AXI_ADDR_WIDTH-1:0] m_axi_araddr,
    output m_axi_arvalid,
    input m_axi_arready,
    output [7:0] m_axi_arlen,
    output [2:0] m_axi_arsize,
    output [1:0] m_axi_arburst,
    output [0:0] m_axi_arlock,
    output [3:0] m_axi_arcache,
    output [2:0] m_axi_arprot,
    output [3:0] m_axi_arqos,
    output [3:0] m_axi_arregion,
    
    input m_axi_rvalid,
    output m_axi_rready,
    input m_axi_rlast,
    input [AXI_ID_WIDTH-1:0] m_axi_rid,
    input [AXI_DATA_WIDTH-1:0] m_axi_rdata,
    input [1:0] m_axi_rresp,
    
    output one_frame_wr_done,
    output one_frame_rd_done

    );
    
    reg wrfifo_clr_sync1,wrfifo_clr_sync2,rdfifo_clr_sync1,rdfifo_clr_sync2;
    
    wire wrfifo_rd_en;
    wire [AXI_DATA_WIDTH-1:0] wrfifo_dout;
    wire [11:0] wrfifo_rd_cnt;
    wire wrfifo_wr_rst_busy,wrfifo_rd_rst_busy;
    wire rdfifo_wr_rst_busy,rdfifo_rd_rst_busy;
    
    wire [AXI_DATA_WIDTH-1:0] rdfifo_din;
    wire rdfifo_wr_en;
    wire [11:0] rdfifo_wr_cnt;
    wire rdfifo_rst;
    
   
    always @ (posedge clk)
    begin
        wrfifo_clr_sync2<=wrfifo_clr_sync1;
        wrfifo_clr_sync1<=wrfifo_clr;
        
        rdfifo_clr_sync2<=rdfifo_clr_sync1;
        rdfifo_clr_sync1<=rdfifo_clr;
        end
        
    assign rdfifo_rst=rdfifo_clr||!axi_rd_en;
    
    wr_ddr3_fifo wr_ddr3_fifo_inst0 (
     .rst(wrfifo_clr),         
     .wr_clk(wrfifo_clk),  
     .rd_clk(clk), 
     .din(wrfifo_din), 
     .wr_en(wrfifo_wr_en), 
     .rd_en(wrfifo_rd_en),
     
     .dout(wrfifo_dout), 
     .full(wrfifo_full),
     .empty(wrfifo_empty),
     .rd_data_count(wrfifo_rd_cnt),
     .wr_data_count(wrfifo_wr_cnt),
     .wr_rst_busy(wrfifo_wr_rst_busy), 
     .rd_rst_busy(wrfifo_rd_rst_busy)
    );
    
    els_fifo_to_axi #(
    
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
    
        .AXI_BURST_LEN(AXI_BURST_LEN),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_ID_WIDTH(AXI_ID_WIDTH),
//        .AXI_WR_ADDR_BEGIN(AXI_WR_ADDR_BEGIN),
//        .AXI_WR_ADDR_END(AXI_WR_ADDR_END),
//        .AXI_ID(AXI_ID),
        .FIFO_TO_AXI_DATA_DEPTH(FIFO_TO_AXI_DATA_DEPTH)
        ) els_fifo_to_axi4_inst0
    (
    .clk(clk),
    .reset(reset),
    
    .axi_wr_en(axi_wr_en),
    
    .wrfifo_rd_cnt(wrfifo_rd_cnt),
    .wrfifo_empty(wrfifo_empty),
    .wrfifo_rst_busy(wrfifo_rd_rst_busy),
    .wrfifo_data_out(wrfifo_dout),
    .m_axi_awready(m_axi_awready),
    .m_axi_wready(m_axi_wready),
    .m_axi_bvalid(m_axi_bvalid),
    .m_axi_bresp(m_axi_bresp),
    .m_axi_bid(m_axi_bid),
    .addr_clr(wrfifo_clr_sync2),
    
    .axi_wr_addr_begin(axi_wr_addr_begin),
    .axi_wr_addr_end(axi_wr_addr_end),
    
    .axi_id(axi_id),
    
    . m_axi_awlen(m_axi_awlen),
    .m_axi_awsize(m_axi_awsize),
    .m_axi_awburst(m_axi_awburst),
    . m_axi_awlock(m_axi_awlock),
    .m_axi_awcache(m_axi_awcache),
    .m_axi_awprot(m_axi_awprot),
    .m_axi_awqos(m_axi_awqos),
    .m_axi_awregion(m_axi_awregion),
    .m_axi_wstrb(m_axi_wstrb),
    .m_axi_bready(m_axi_bready),
    .m_axi_awid(m_axi_awid),
    .m_axi_awaddr(m_axi_awaddr),
    .wrfifo_rd_en(wrfifo_rd_en),
    .m_axi_awvalid(m_axi_awvalid),
    .m_axi_wvalid(m_axi_wvalid),
    .m_axi_wlast(m_axi_wlast),
    .m_axi_wdata(m_axi_wdata),
    
    .one_frame_wr_done(one_frame_wr_done)
    );
    
    rd_ddr3_fifo rd_ddr3_fifo_inst0 (
    .rst(rdfifo_rst),
    .wr_clk(clk), 
    .rd_clk(rdfifo_clk), 
    .din(rdfifo_din),   
    .wr_en(rdfifo_wr_en),  
    .rd_en(rdfifo_rd_en),  
        
    .dout(rdfifo_dout),    
    .full(rdfifo_full),       
    .empty(rdfifo_empty),       
    .rd_data_count(rdfifo_rd_cnt),
    .wr_data_count(rdfifo_wr_cnt), 
    .wr_rst_busy(rdfifo_wr_rst_busy),   
    .rd_rst_busy(rdfifo_rd_rst_busy)
    );
    
    els_axi_to_fifo #(
    
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
    
//        .AXI_ID(AXI_ID),
        .AXI_ID_WIDTH(AXI_ID_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .FIFO_TO_AXI_DATA_DEPTH(FIFO_TO_AXI_DATA_DEPTH),
//        .AXI_RD_ADDR_BEGIN(AXI_RD_ADDR_BEGIN),
//        .AXI_RD_ADDR_END(AXI_RD_ADDR_END),
        .AXI_BURST_LEN(AXI_BURST_LEN),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH)
    ) 
    els_axi4_to_fifo_inst0 (
    .clk(clk),
    .reset(reset),
    
    .axi_rd_en(axi_rd_en),
    
    .rdfifo_wr_cnt(rdfifo_wr_cnt),
    .rdfifo_alfull(rdfifo_full),
    .m_axi_arready(m_axi_arready),
    .m_axi_rvalid(m_axi_rvalid),
    .m_axi_rlast(m_axi_rlast),
    .m_axi_rid(m_axi_rid),
    .m_axi_rdata(m_axi_rdata),
    .m_axi_rresp(m_axi_rresp),
    .addr_clr(rdfifo_clr_sync2),
    .rdfifo_rst_busy(rdfifo_wr_rst_busy),
    
    .axi_rd_addr_begin(axi_rd_addr_begin),
    .axi_rd_addr_end(axi_rd_addr_end),
    
    .axi_id(axi_id),
    
    .m_axi_arid(m_axi_arid),
    .m_axi_araddr(m_axi_araddr),
    .m_axi_arlen(m_axi_arlen),
    .m_axi_arsize(m_axi_arsize),
    .m_axi_arburst(m_axi_arburst),
    .m_axi_arvalid(m_axi_arvalid),
    .m_axi_rready(m_axi_rready),
    .rdfifo_wr_en(rdfifo_wr_en),
    .rdfifo_data_in(rdfifo_din),
    .m_axi_arlock(m_axi_arlock),
    .m_axi_arcache(m_axi_arcache),
    .m_axi_arprot(m_axi_arprot),
    .m_axi_arqos(m_axi_arqos),
    .m_axi_arregion(m_axi_arregion),
    
    .one_frame_rd_done(one_frame_rd_done)
    
    );
    
endmodule
