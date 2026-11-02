`timescale 1ns / 1ps


//此模块将fifo_to_axi, wr_fifo以及axi_to_fifo, rd_fifo封装起来：
module els_fifo_with_axi #(

    parameter IMAGE_WIDTH=800,
    parameter IMAGE_HEIGHT=480,

    parameter FIFO_DW=16,//FIFO_DW=FIFO_TO_OUT_DATA_WIDTH:即fifo向外的数据位宽
    
    parameter AXI_DATA_WIDTH=128,//实际上相当于fifo向内的数据位宽
    parameter AXI_ADDR_WIDTH=30,
    parameter AXI_ID_WIDTH=4,
    parameter AXI_BURST_LEN=31,
    
    parameter FIFO_TO_AXI_DATA_DEPTH=64,//fifo向内的数据（地址）深度
    
    localparam FIFO_TO_AXI_DATA_DEPTH_WIDTH=$clog2(FIFO_TO_AXI_DATA_DEPTH),//fifo向内的地址位宽
    localparam FIFO_TO_OUT_DATA_DEPTH=FIFO_TO_AXI_DATA_DEPTH*AXI_DATA_WIDTH/FIFO_DW,//fifo向外的数据深度，满足此乘积关系
    localparam FIFO_TO_OUT_DATA_DEPTH_WIDTH=$clog2(FIFO_TO_OUT_DATA_DEPTH)//fifo向外的地址位宽
    )
(   
    input clk,
    input reset,
    
    
    input axi_wr_en,
    input axi_rd_en,
    
    
    //WRITE_FIFO:
    input wrfifo_clr,
    input wrfifo_clk,
    input wrfifo_wr_en,
    input [FIFO_DW-1:0] wrfifo_din,
     
    output wrfifo_full,
    output wrfifo_empty,
    output [FIFO_TO_OUT_DATA_DEPTH_WIDTH-1:0] wrfifo_wr_cnt,
    
    
    //READ_FIFO:
    input rdfifo_clr,
    input rdfifo_clk,
    input rdfifo_rd_en,
    
    output [FIFO_DW-1:0] rdfifo_dout,
    output [FIFO_TO_OUT_DATA_DEPTH_WIDTH-1:0] rdfifo_rd_cnt,
    output rdfifo_empty,
    output rdfifo_full,
    
    
    //AXI读写基地址与末地址，以及地址ID：
    input [AXI_ADDR_WIDTH-1:0] axi_wr_addr_begin,
    input [AXI_ADDR_WIDTH-1:0] axi_wr_addr_end,
    input [AXI_ADDR_WIDTH-1:0] axi_rd_addr_begin,
    input [AXI_ADDR_WIDTH-1:0] axi_rd_addr_end,
    
    input [AXI_ID_WIDTH-1:0] axi_id,
    
    
    //AW:
    input m_axi_awready,
    
    output [AXI_ADDR_WIDTH-1:0] m_axi_awaddr,
    output [AXI_ID_WIDTH-1:0] m_axi_awid,
    output m_axi_awvalid,
    output [7:0] m_axi_awlen,
    output [2:0] m_axi_awsize,
    output [1:0] m_axi_awburst,
    output [0:0] m_axi_awlock,
    output [3:0] m_axi_awcache,
    output [2:0] m_axi_awprot,
    output [3:0] m_axi_awqos,
    output [3:0] m_axi_awregion,
    
    
    //W:
    input m_axi_wready,
    
    output m_axi_wvalid,
    output m_axi_wlast,
    output [AXI_DATA_WIDTH-1:0] m_axi_wdata,
    output [AXI_DATA_WIDTH/8-1:0] m_axi_wstrb,
    output [AXI_ID_WIDTH-1:0] m_axi_wid,
    
    
    //B:
    input m_axi_bvalid,
    input [AXI_ID_WIDTH-1:0] m_axi_bid,
    input [1:0] m_axi_bresp,
    
    output m_axi_bready,
        
    
    //AR:
    input m_axi_arready,
     
    output [AXI_ADDR_WIDTH-1:0] m_axi_araddr,
    output m_axi_arvalid, 
    output [AXI_ID_WIDTH-1:0] m_axi_arid,
    output [7:0] m_axi_arlen,
    output [2:0] m_axi_arsize,
    output [1:0] m_axi_arburst,
    output [0:0] m_axi_arlock,
    output [3:0] m_axi_arcache,
    output [2:0] m_axi_arprot,
    output [3:0] m_axi_arqos,
    output [3:0] m_axi_arregion,
    
    
    //R:
    input m_axi_rvalid,
    input m_axi_rlast,
    input [AXI_ID_WIDTH-1:0] m_axi_rid,
    input [AXI_DATA_WIDTH-1:0] m_axi_rdata,
    input [1:0] m_axi_rresp,
    
    output m_axi_rready,
    
    
    //读写一帧完成的标志信号：
    output one_frame_wr_done,
    output one_frame_rd_done

    );
    

  //////////////////////////
  /////////////////////////
  //对读写FIFO的清零信号打两拍使之更稳定：
    
   reg  wrfifo_clr_sync0,wrfifo_clr_sync1,  //结尾带_sync0表示是打一拍后的；带_sync1表示是打两拍后的。
        rdfifo_clr_sync0,rdfifo_clr_sync1;
   
    always @ (posedge clk)
    begin
        wrfifo_clr_sync1<=wrfifo_clr_sync0;
        wrfifo_clr_sync0<=wrfifo_clr;
        
        rdfifo_clr_sync1<=rdfifo_clr_sync0;
        rdfifo_clr_sync0<=rdfifo_clr;
        end
    
        //若读FIFO有清零请求或AXI没有读使能，就让读FIFO复位： 
        wire rdfifo_rst;
           
        assign rdfifo_rst=rdfifo_clr||!axi_rd_en;
    
    
  ////////////////////////////
  ///////////////////////////
  //写通路：
  
  wire  wrfifo_rst_busy;    //写FIFO正在复位的标志信号

  wire wrfifo_rd_en;
  
  wire [AXI_DATA_WIDTH-1:0] wrfifo_dout;
  
  wire [FIFO_TO_AXI_DATA_DEPTH_WIDTH-1:0] wrfifo_rd_cnt;              //写FIFO的读端的数据数
  
  
  /////wr_fifo:
    wr_ddr3_fifo wr_ddr3_fifo_inst0 (
    
     .a_rst_i(wrfifo_clr),         
    
     //写端：
     .wr_clk_i(wrfifo_clk),        //wrfifo写端时钟
     
     .wdata(wrfifo_din), 
     .wr_en_i(wrfifo_wr_en),
     
     //读端：
     .rd_clk_i(clk),              //wrfifo读端时钟
     
     .rd_en_i(wrfifo_rd_en),
     .rdata(wrfifo_dout),
      
      //
     .full_o(wrfifo_full),
     .empty_o(wrfifo_empty),
     
     .rd_datacount_o(wrfifo_rd_cnt),
     .wr_datacount_o(wrfifo_wr_cnt),
     
     .rst_busy(wrfifo_rst_busy)
    );
    
	
    //wr_axi:
    els_fifo_to_axi #(
    
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
    
        .AXI_BURST_LEN(AXI_BURST_LEN),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_ID_WIDTH(AXI_ID_WIDTH),

        .FIFO_TO_AXI_DATA_DEPTH(FIFO_TO_AXI_DATA_DEPTH)
        
        ) els_fifo_to_axi4_inst0
    (
    .clk(clk),
    .reset(reset),
    
    .axi_wr_en(axi_wr_en),
    
    .addr_clr(wrfifo_clr_sync1),
    
    
    //wr_fifo:
        //IN:
        .wrfifo_rd_cnt(wrfifo_rd_cnt),
        .wrfifo_empty(wrfifo_empty),
        .wrfifo_rst_busy(wrfifo_rst_busy),
        .wrfifo_data_out(wrfifo_dout),
        
        //OUT:
        .wrfifo_rd_en(wrfifo_rd_en),
    
    
    //AW:
        //IN:
        .m_axi_awready(m_axi_awready),
        
        //OUT:
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awid(m_axi_awid),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awlock(m_axi_awlock),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awqos(m_axi_awqos),
        .m_axi_awregion(m_axi_awregion),
    
    
    //W:
        //IN:
        .m_axi_wready(m_axi_wready),
        
        //OUT:
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wid(m_axi_wid),
    
    
    //B:
        //IN:
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bresp(0),
        .m_axi_bid(m_axi_bid),
        
        //OUT:
        .m_axi_bready(m_axi_bready),
    
    
    //写地址与对应ID：
    .axi_wr_addr_begin(axi_wr_addr_begin),
    .axi_wr_addr_end(axi_wr_addr_end),
    
    .axi_id(axi_id),
    
    
    //写完一帧的标志：
    .one_frame_wr_done(one_frame_wr_done)
    
    );
    
    
    
  /////////////////////////////
  ///////////////////////////
  //读通路：
  
  wire  rdfifo_rst_busy;          //rdfifo正在复位的标志信号
    
  wire [AXI_DATA_WIDTH-1:0] rdfifo_din;
  
  wire rdfifo_wr_en;
  
  wire [FIFO_TO_AXI_DATA_DEPTH_WIDTH-1:0] rdfifo_wr_cnt;
  
  
  ///////rd_fifo:
    rd_ddr3_fifo rd_ddr3_fifo_inst0 (
    .a_rst_i(rdfifo_rst),
    
     //写端：
    .wr_clk_i(clk),               //rdfifo写端时钟
    
    .wdata(rdfifo_din),   
    .wr_en_i(rdfifo_wr_en),  
    
    //读端：
    .rd_clk_i(rdfifo_clk),        //rdfifo读端时钟
    
    .rd_en_i(rdfifo_rd_en),       
    .rdata(rdfifo_dout),    
    
    //
    .full_o(rdfifo_full),       
    .empty_o(rdfifo_empty),     
      
    .rd_datacount_o(rdfifo_rd_cnt),
    .wr_datacount_o(rdfifo_wr_cnt), 
    
    .rst_busy(rdfifo_rst_busy) 
    
    );
    
    
    //rd_axi:
    els_axi_to_fifo #(
    
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
    
        .AXI_ID_WIDTH(AXI_ID_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_BURST_LEN(AXI_BURST_LEN),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        
        .FIFO_TO_AXI_DATA_DEPTH(FIFO_TO_AXI_DATA_DEPTH)

    ) 
    els_axi4_to_fifo_inst0 
    (
    .clk(clk),
    .reset(reset),
    
    .axi_rd_en(axi_rd_en),
    
    .addr_clr(rdfifo_clr_sync1),
    
    
    //rd_fifo:
        //IN:
        .rdfifo_wr_cnt(rdfifo_wr_cnt),
        .rdfifo_alfull(rdfifo_full),
        .rdfifo_rst_busy(rdfifo_rst_busy),
        
        //OUT:
        .rdfifo_wr_en(rdfifo_wr_en),
        .rdfifo_data_in(rdfifo_din),
    
    
    //AR:
        //IN:
        .m_axi_arready(m_axi_arready),
        
        //OUT:
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arid(m_axi_arid),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arqos(m_axi_arqos),
        .m_axi_arregion(m_axi_arregion),
    
    
    //R:
        //IN:
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rid(m_axi_rid),
        .m_axi_rresp(m_axi_rresp),
        
        //OUT:
        .m_axi_rready(m_axi_rready),
       
       
    //读地址以及地址ID：
    .axi_rd_addr_begin(axi_rd_addr_begin),
    .axi_rd_addr_end(axi_rd_addr_end),
    
    .axi_id(axi_id),
    
    
    //读完一帧的标志： 
    .one_frame_rd_done(one_frame_rd_done)
    
    );
    
    
	
endmodule
