`timescale 1ns / 1ps

module els_axi_ctrl #(

    parameter IMAGE_WIDTH=800,
    parameter IMAGE_HEIGHT=480,
    
    parameter FIFO_DW=16,//FIFO_DW=FIFO_TO_OUT_DATA_WIDTH:即fifo向外的数据位宽
    
    parameter AXI_DATA_WIDTH=128,//实际上相当于fifo向内的数据位宽
    parameter AXI_ADDR_WIDTH=32,
    parameter AXI_ID_WIDTH=4,

    parameter AXI_BURST_LEN=31,
    parameter FIFO_TO_AXI_DATA_DEPTH=64,//fifo向内的数据（地址）深度
    
    localparam FIFO_TO_AXI_DATA_DEPTH_WIDTH=$clog2(FIFO_TO_AXI_DATA_DEPTH),//fifo向内的地址位宽
    localparam FIFO_TO_OUT_DATA_DEPTH=FIFO_TO_AXI_DATA_DEPTH*AXI_DATA_WIDTH/FIFO_DW,//fifo向外的数据深度，满足此乘积关系
    localparam FIFO_TO_OUT_DATA_DEPTH_WIDTH=$clog2(FIFO_TO_OUT_DATA_DEPTH)//fifo向外的地址位宽
    )
    (
    input clk,
    input reset_n,
      
    input axi_wr_en,
    input axi_rd_en,
    
    
    //wr_fifo:
    input wrfifo_wr_clk,
    input wrfifo_clr,
    input wrfifo_wr_en,
    
    input [FIFO_DW-1:0] wrfifo_wr_data,
    
    
    //rd_fifo:
    input rdfifo_rd_clk,
    input rdfifo_clr,
    input rdfifo_rd_en,
    
    output [FIFO_DW-1:0] rdfifo_rd_data,
    
    
    //AXI_addr:
    input [AXI_ADDR_WIDTH-1:0] axi_wr_addr_begin,
    input [AXI_ADDR_WIDTH-1:0] axi_wr_addr_end,
    input [AXI_ADDR_WIDTH-1:0] axi_rd_addr_begin,
    input [AXI_ADDR_WIDTH-1:0] axi_rd_addr_end,
    
    input [AXI_ID_WIDTH-1:0] axi_id,
    
    
    //读写一帧完成的标志：
    output one_frame_wr_done,
    output one_frame_rd_done,
    
    
    //AXI:
        
        //A:
        input axi_aready,
        
        output [AXI_ID_WIDTH-1:0] axi_aid,
        output [AXI_ADDR_WIDTH-1:0] axi_aaddr,
        output [7:0] axi_alen,
        output [2:0] axi_asize,
        output [1:0] axi_aburst,
        output [1:0] axi_alock,
        output axi_avalid,
        output axi_atype,
        
        
        //W:
        input axi_wready,
        
        output [AXI_ID_WIDTH-1:0] axi_wid,
        output [AXI_DATA_WIDTH-1:0] axi_wdata,
        output [AXI_DATA_WIDTH/8-1:0] axi_wstrb,
        output axi_wlast,
        output axi_wvalid,
        
               
        //B:
        input [AXI_ID_WIDTH-1:0] axi_bid,
        input axi_bvalid,
        
        output axi_bready,
        
        
        //R:
        input [AXI_ID_WIDTH-1:0] axi_rid,
        input [AXI_DATA_WIDTH-1:0] axi_rdata,
        input axi_rlast,
        input axi_rvalid,
        input [1:0] axi_rresp,
        
        output axi_rready
         
    
    );
    
    
  ////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////
  //读写FIFO以及各通道的信号：
    
    
    wire axi_awready;
    wire [AXI_ADDR_WIDTH-1:0] axi_awaddr;
    wire [AXI_ID_WIDTH-1:0] axi_awid;
    wire axi_awvalid;
    wire [7:0] axi_awlen;
    wire [2:0] axi_awsize;
    wire [1:0] axi_awburst;
    wire [1:0] axi_awlock;
    
    wire axi_arready;
    wire [AXI_ADDR_WIDTH-1:0] axi_araddr;
    wire [AXI_ID_WIDTH-1:0] axi_arid;
    wire axi_arvalid;
    wire [7:0] axi_arlen;
    wire [2:0] axi_arsize;
    wire [1:0] axi_arburst;
    wire [1:0] axi_arlock;
  
  
    els_fifo_with_axi #(

        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
    
        .FIFO_DW(FIFO_DW),//FIFO_DW=FIFO_TO_OUT_DATA_WIDTH:即fifo向外的数据位宽
        
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),//实际上相当于fifo向内的数据位宽
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_ID_WIDTH(AXI_ID_WIDTH),
        .AXI_BURST_LEN(AXI_BURST_LEN),
        
        .FIFO_TO_AXI_DATA_DEPTH(FIFO_TO_AXI_DATA_DEPTH)//fifo向内的数据（地址）深度
        )
    (   
        .clk(clk),
        .reset(~reset_n),
        
        
        .axi_wr_en(axi_wr_en),
        .axi_rd_en(axi_rd_en),
        
        
        //WRITE_FIFO:
        .wrfifo_clr(wrfifo_clr),
        .wrfifo_clk(wrfifo_wr_clk),
        .wrfifo_wr_en(wrfifo_wr_en),
        .wrfifo_din(wrfifo_wr_data),
         
        .wrfifo_full(),
        .wrfifo_empty(),
        .wrfifo_wr_cnt(),
        
        
        //READ_FIFO:
        .rdfifo_clr(rdfifo_clr),
        .rdfifo_clk(rdfifo_rd_clk),
        .rdfifo_rd_en(rdfifo_rd_en),
        
        .rdfifo_dout(rdfifo_rd_data),
        .rdfifo_rd_cnt(),
        .rdfifo_empty(),
        .rdfifo_full(),
        
        
        //AXI读写基地址与末地址，以及地址ID：
        .axi_wr_addr_begin(axi_wr_addr_begin),
        .axi_wr_addr_end(axi_wr_addr_end),
        .axi_rd_addr_begin(axi_rd_addr_begin),
        .axi_rd_addr_end(axi_rd_addr_end),
        
        .axi_id(axi_id),
        
        
        //AW:
        .m_axi_awready(axi_awready),
        
        .m_axi_awaddr(axi_awaddr),
        .m_axi_awid(axi_awid),
        .m_axi_awvalid(axi_awvalid),
        .m_axi_awlen(axi_awlen),
        .m_axi_awsize(axi_awsize),
        .m_axi_awburst(axi_awburst),
        .m_axi_awlock(axi_awlock),
        
        
        //W:
        .m_axi_wready(axi_wready),
        
        .m_axi_wvalid(axi_wvalid),
        .m_axi_wlast(axi_wlast),
        .m_axi_wdata(axi_wdata),
        .m_axi_wstrb(axi_wstrb),
        .m_axi_wid(axi_wid),
        
        
        //B:
        .m_axi_bvalid(axi_bvalid),
        .m_axi_bid(axi_bid),
        
        .m_axi_bready(axi_bready),
            
        
        //AR:
        .m_axi_arready(axi_arready),
         
        . m_axi_araddr(axi_araddr),
        .m_axi_arvalid(axi_arvalid), 
        .m_axi_arid(axi_arid),
        .m_axi_arlen(axi_arlen),
        .m_axi_arsize(axi_arsize),
        .m_axi_arburst(axi_arburst),
        .m_axi_arlock(axi_arlock),
        
        
        //R:
        .m_axi_rvalid(axi_rvalid),
        .m_axi_rlast(axi_rlast),
        .m_axi_rid(axi_rid),
        .m_axi_rdata(axi_rdata),
        .m_axi_rresp(axi_rresp),
        
        .m_axi_rready(axi_rready),
        
        
        //读写一帧完成的标志信号：
        .one_frame_wr_done(one_frame_wr_done),
        .one_frame_rd_done(one_frame_rd_done)
    
    );
    
    
    //读写操作仲裁状态机：
        //负责产生atype信号以及合并AW, AR通道的数据到A通道：
        
    els_axi_aw_ar_mux #(
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_ID_WIDTH(AXI_ID_WIDTH)
    )
    axi_mux
    (
        .clk(clk),
        .reset_n(reset_n),
        
        
        //aw:
        .axi_awaddr_i(axi_awaddr),
        .axi_awvalid_i(axi_awvalid),
        .axi_awlen_i(axi_awlen),
        .axi_awid_i(axi_awid),
        
        .axi_awready_o(axi_awready),
        
        
        //ar:
        .axi_araddr_i(axi_araddr),
        .axi_arvalid_i(axi_arvalid),
        .axi_arlen_i(axi_arlen),
        .axi_arid_i(axi_arid),
        
        .axi_arready_o(axi_arready),
        
        
        //a:
        .axi_aready_i(axi_aready),
        
        .axi_aid_o(axi_aid),
        .axi_aaddr_o(axi_aaddr),
        .axi_alen_o(axi_alen),
        .axi_atype_o(axi_atype),
        .axi_avalid_o(axi_avalid)
        
      );
	  
	  
	//////////////////////
	/////////////////////
	//其余信号：
   
    assign axi_asize=4;
    assign axi_aburst=1;
    assign axi_alock=0;
    
    
    
endmodule
