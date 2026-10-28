`timescale 1ns / 1ps

module els_ddr_ctrl_2ports #(

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
(   
    input ddr3_clk_200m,
    input ddr3_rst_n,
    
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
    
    input [30:0] axi_wr_addr_begin,
    input [30:0] axi_wr_addr_end,
    input [30:0] axi_rd_addr_begin,
    input [30:0] axi_rd_addr_end,
    
    input [AXI_ID_WIDTH-1:0] axi_id,
    
    output [14:0] ddr3_addr,
    output [2:0] ddr3_ba,
    output ddr3_cas_n,
    output [0:0] ddr3_ck_n,
    output [0:0] ddr3_ck_p,
    output [0:0] ddr3_cke,
    output ddr3_ras_n,
    output ddr3_reset_n,
    output ddr3_we_n,
    inout [15:0] ddr3_dq,
    inout [1:0] ddr3_dqs_n,
    inout [1:0]	ddr3_dqs_p,
    output [0:0] ddr3_cs_n,
    output [1:0] ddr3_dm,
    output [0:0] ddr3_odt,
    
    output ddr3_init_done,
    output ui_clk,
    
    output one_frame_wr_done,
    output one_frame_rd_done
    
    );
    
    wire [AXI_ID_WIDTH-1:0]	axi_awid;
    wire [AXI_ADDR_WIDTH-1:0]	axi_awaddr;
    wire [7:0]	axi_awlen;
    wire [2:0]	axi_awsize;
    wire [1:0]	axi_awburst;
    wire [0:0]	axi_awlock;
    wire [3:0]	axi_awcache;
    wire [2:0]	axi_awprot;
    wire[3:0]	axi_awqos;
    wire axi_awvalid;
    wire axi_awready;
    
    wire [AXI_DATA_WIDTH-1:0] axi_wdata;
    wire [AXI_DATA_WIDTH/8-1:0]	axi_wstrb;
    wire axi_wlast;
    wire	axi_wvalid;
    wire	axi_wready;
    
    wire [AXI_ID_WIDTH-1:0]	axi_bid;
    wire [1:0]	axi_bresp;
    wire	axi_bvalid;
    wire	axi_bready;
    
    wire [AXI_ID_WIDTH-1:0]	axi_arid;
    wire [AXI_ADDR_WIDTH-1:0]	axi_araddr;
    wire [7:0]	axi_arlen;
    wire [2:0] axi_arsize;
    wire [1:0]	axi_arburst;
    wire [0:0]	axi_arlock;
    wire [3:0]	axi_arcache;
    wire [2:0]	axi_arprot;
    wire [3:0]	axi_arqos;
    wire	axi_arvalid;
    wire	axi_arready;
    
    wire [AXI_ID_WIDTH-1:0]	axi_rid;
    wire [AXI_DATA_WIDTH-1:0]	axi_rdata;
    wire [1:0]	axi_rresp;
    wire	axi_rlast;
    wire	axi_rvalid;
    wire	axi_rready;
    
    wire [3:0] axi_awregion,axi_arregion;
    
    wire ui_clk_sync_rst;
    wire mmcm_locked;
    wire init_calib_complete;
    
    wire wrfifo_empty;
    wire rdfifo_full;
    
    assign ddr3_init_done=init_calib_complete&&mmcm_locked;
    
    mig_7series_16bit mig_7series_0_inst0 (


    // Memory interface ports

    .ddr3_addr                      (ddr3_addr),  // output [14:0]		ddr3_addr

    .ddr3_ba                        (ddr3_ba),  // output [2:0]		ddr3_ba

    .ddr3_cas_n                     (ddr3_cas_n),  // output			ddr3_cas_n

    .ddr3_ck_n                      (ddr3_ck_n),  // output [0:0]		ddr3_ck_n

    .ddr3_ck_p                      (ddr3_ck_p),  // output [0:0]		ddr3_ck_p

    .ddr3_cke                       (ddr3_cke),  // output [0:0]		ddr3_cke

    .ddr3_ras_n                     (ddr3_ras_n),  // output			ddr3_ras_n

    .ddr3_reset_n                   (ddr3_reset_n),  // output			ddr3_reset_n

    .ddr3_we_n                      (ddr3_we_n),  // output			ddr3_we_n

    .ddr3_dq                        (ddr3_dq),  // inout [15:0]		ddr3_dq

    .ddr3_dqs_n                     (ddr3_dqs_n),  // inout [1:0]		ddr3_dqs_n

    .ddr3_dqs_p                     (ddr3_dqs_p),  // inout [1:0]		ddr3_dqs_p

    .init_calib_complete            (init_calib_complete),  // output			init_calib_complete

      

	.ddr3_cs_n                      (ddr3_cs_n),  // output [0:0]		ddr3_cs_n

    .ddr3_dm                        (ddr3_dm),  // output [1:0]		ddr3_dm

    .ddr3_odt                       (ddr3_odt),  // output [0:0]		ddr3_odt

    // Application interface ports

    .ui_clk                         (ui_clk),  // output			ui_clk

    .ui_clk_sync_rst                (ui_clk_sync_rst),  // output			ui_clk_sync_rst

    .mmcm_locked                    (mmcm_locked),  // output			mmcm_locked

    .aresetn                        (ddr3_rst_n),  // input			aresetn

    .app_sr_req                     (1'b0),  // input			app_sr_req

    .app_ref_req                    (1'b0),  // input			app_ref_req

    .app_zq_req                     (1'b0),  // input			app_zq_req

    .app_sr_active                  (),  // output			app_sr_active

    .app_ref_ack                    (),  // output			app_ref_ack

    .app_zq_ack                     (),  // output			app_zq_ack

    // Slave Interface Write Address Ports

    .s_axi_awid                     (axi_awid),  // input [3:0]			s_axi_awid

    .s_axi_awaddr                   (axi_awaddr),  // input [29:0]			s_axi_awaddr

    .s_axi_awlen                    (axi_awlen),  // input [7:0]			s_axi_awlen

    .s_axi_awsize                   (axi_awsize),  // input [2:0]			s_axi_awsize

    .s_axi_awburst                  (axi_awburst),  // input [1:0]			s_axi_awburst

    .s_axi_awlock                   (axi_awlock),  // input [0:0]			s_axi_awlock

    .s_axi_awcache                  (axi_awcache),  // input [3:0]			s_axi_awcache

    .s_axi_awprot                   (axi_awprot),  // input [2:0]			s_axi_awprot

    .s_axi_awqos                    (axi_awqos),  // input [3:0]			s_axi_awqos

    .s_axi_awvalid                  (axi_awvalid),  // input			s_axi_awvalid

    .s_axi_awready                  (axi_awready),  // output			s_axi_awready

    // Slave Interface Write Data Ports

    .s_axi_wdata                    (axi_wdata),  // input [127:0]			s_axi_wdata

    .s_axi_wstrb                    (axi_wstrb),  // input [15:0]			s_axi_wstrb

    .s_axi_wlast                    (axi_wlast),  // input			s_axi_wlast

    .s_axi_wvalid                   (axi_wvalid),  // input			s_axi_wvalid

    .s_axi_wready                   (axi_wready),  // output			s_axi_wready

    // Slave Interface Write Response Ports

    .s_axi_bid                      (axi_bid),  // output [3:0]			s_axi_bid

    .s_axi_bresp                    (axi_bresp),  // output [1:0]			s_axi_bresp

    .s_axi_bvalid                   (axi_bvalid),  // output			s_axi_bvalid

    .s_axi_bready                   (axi_bready),  // input			s_axi_bready

    // Slave Interface Read Address Ports

    .s_axi_arid                     (axi_arid),  // input [3:0]			s_axi_arid

    .s_axi_araddr                   (axi_araddr),  // input [29:0]			s_axi_araddr

    .s_axi_arlen                    (axi_arlen),  // input [7:0]			s_axi_arlen

    .s_axi_arsize                   (axi_arsize),  // input [2:0]			s_axi_arsize

    .s_axi_arburst                  (axi_arburst),  // input [1:0]			s_axi_arburst

    .s_axi_arlock                   (axi_arlock),  // input [0:0]			s_axi_arlock

    .s_axi_arcache                  (axi_arcache),  // input [3:0]			s_axi_arcache

    .s_axi_arprot                   (axi_arprot),  // input [2:0]			s_axi_arprot

    .s_axi_arqos                    (axi_arqos),  // input [3:0]			s_axi_arqos

    .s_axi_arvalid                  (axi_arvalid),  // input			s_axi_arvalid

    .s_axi_arready                  (axi_arready),  // output			s_axi_arready

    // Slave Interface Read Data Ports

    .s_axi_rid                      (axi_rid),  // output [3:0]			s_axi_rid

    .s_axi_rdata                    (axi_rdata),  // output [127:0]			s_axi_rdata

    .s_axi_rresp                    (axi_rresp),  // output [1:0]			s_axi_rresp

    .s_axi_rlast                    (axi_rlast),  // output			s_axi_rlast

    .s_axi_rvalid                   (axi_rvalid),  // output			s_axi_rvalid

    .s_axi_rready                   (axi_rready),  // input			s_axi_rready

    // System Clock Ports

    .sys_clk_i                       (ddr3_clk_200m),

    .sys_rst                        (ddr3_rst_n) // input sys_rst

    );
    
    els_fifo_with_axi #(
    
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
    
        .FIFO_DW(FIFO_DW),
//        .AXI_WR_ADDR_BEGIN(AXI_WR_ADDR_BEGIN),
//        .AXI_WR_ADDR_END(AXI_WR_ADDR_END),
//        .AXI_RD_ADDR_BEGIN(AXI_RD_ADDR_BEGIN),
//        .AXI_RD_ADDR_END(AXI_RD_ADDR_END),
        
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_ID_WIDTH(AXI_ID_WIDTH),
//        .AXI_ID(AXI_ID),
        .AXI_BURST_LEN(AXI_BURST_LEN),
        .FIFO_TO_AXI_DATA_DEPTH(FIFO_TO_AXI_DATA_DEPTH)
      ) 
      els_fifo_with_axi_inst0 (
    .clk(ui_clk),
    .reset(~init_calib_complete),
    
    .axi_wr_en(axi_wr_en),
    .axi_rd_en(axi_rd_en),
    
    .wrfifo_clr(wrfifo_clr),
    .wrfifo_clk(wrfifo_clk),
    .wrfifo_wr_en(wrfifo_wr_en),
    .wrfifo_din(wrfifo_din),
    .rdfifo_clr(rdfifo_clr),
    .rdfifo_clk(rdfifo_clk),
    .rdfifo_rd_en(rdfifo_rd_en),
    .wrfifo_full(wrfifo_full),
    .wrfifo_wr_cnt(wrfifo_wr_cnt),
    .rdfifo_dout(rdfifo_dout),
    .rdfifo_empty(rdfifo_empty),
    .rdfifo_rd_cnt(rdfifo_rd_cnt),
    .wrfifo_empty(wrfifo_empty),
    .rdfifo_full(rdfifo_full),
    
    .axi_wr_addr_begin(axi_wr_addr_begin),
    .axi_wr_addr_end(axi_wr_addr_end),
    .axi_rd_addr_begin(axi_rd_addr_begin),
    .axi_rd_addr_end(axi_rd_addr_end),
    
    .axi_id(axi_id),
    
    .m_axi_awid(axi_awid),
    .m_axi_awaddr(axi_awaddr),
    .m_axi_awlen(axi_awlen),
    .m_axi_awsize(axi_awsize),
    .m_axi_awburst(axi_awburst),
    .m_axi_awlock(axi_awlock),
    .m_axi_awcache(axi_awcache),
    .m_axi_awprot(axi_awprot),
    .m_axi_awqos(axi_awqos),
    .m_axi_awregion(axi_awregion),
    .m_axi_awvalid(axi_awvalid),
    .m_axi_awready(axi_awready),
    
    .m_axi_wvalid(axi_wvalid),
    .m_axi_wready(axi_wready),
    .m_axi_wlast(axi_wlast),
    .m_axi_wdata(axi_wdata),
    .m_axi_wstrb(axi_wstrb),
    
    .m_axi_bvalid(axi_bvalid),
    .m_axi_bready(axi_bready),
    .m_axi_bid(axi_bid),
    .m_axi_bresp(axi_bresp),
    
    .m_axi_arid(axi_arid),
    .m_axi_araddr(axi_araddr),
    .m_axi_arvalid(axi_arvalid),
    .m_axi_arready(axi_arready),
    .m_axi_arlen(axi_arlen),
    .m_axi_arsize(axi_arsize),
    .m_axi_arburst(axi_arburst),
    .m_axi_arlock(axi_arlock),
    .m_axi_arcache(axi_arcache),
    .m_axi_arprot(axi_arprot),
    .m_axi_arqos(axi_arqos),
    .m_axi_arregion(axi_arregion),
    
    .m_axi_rvalid(axi_rvalid),
    .m_axi_rready(axi_rready),
    .m_axi_rlast(axi_rlast),
    .m_axi_rid(axi_rid),
    .m_axi_rdata(axi_rdata),
    .m_axi_rresp(axi_rresp),
    
    .one_frame_wr_done(one_frame_wr_done),
    .one_frame_rd_done(one_frame_rd_done)
    
    );
    
endmodule
