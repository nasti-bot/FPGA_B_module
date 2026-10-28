`timescale 1ns / 1ps

module els_axi_to_fifo #(

    parameter IMAGE_WIDTH=800,
    parameter IMAGE_HEIGHT=480,

//    parameter AXI_ID=0,
    parameter AXI_ID_WIDTH=4,
    parameter AXI_DATA_WIDTH=128,
    parameter FIFO_TO_AXI_DATA_DEPTH=64,
//    parameter AXI_RD_ADDR_BEGIN=0,
//    parameter AXI_RD_ADDR_END=1023,
    parameter AXI_BURST_LEN=31,
    parameter AXI_ADDR_WIDTH=30,
    
    localparam AXI_DATA_SIZE=$clog2(AXI_DATA_WIDTH/8),
    localparam FIFO_TO_AXI_DATA_DEPTH_WIDTH=$clog2(FIFO_TO_AXI_DATA_DEPTH)
    ) 
(   input clk,
    input reset,
    
    input axi_rd_en,
    
    input [FIFO_TO_AXI_DATA_DEPTH_WIDTH-1:0] rdfifo_wr_cnt,
    input rdfifo_alfull,
    input m_axi_arready,
    input m_axi_rvalid,
    input m_axi_rlast,
    input [AXI_ID_WIDTH-1:0] m_axi_rid,
    input [AXI_DATA_WIDTH-1:0] m_axi_rdata,
    input [1:0] m_axi_rresp,
    input addr_clr,
    input rdfifo_rst_busy,
    
    input [30:0] axi_rd_addr_begin,
    input [30:0] axi_rd_addr_end,
    
    input [AXI_ID_WIDTH-1:0] axi_id,
    
    output [AXI_ID_WIDTH-1:0] m_axi_arid,
    output reg [AXI_ADDR_WIDTH-1:0] m_axi_araddr,
    output [7:0] m_axi_arlen,
    output [2:0] m_axi_arsize,
    output [1:0] m_axi_arburst,
    output reg m_axi_arvalid,
    output m_axi_rready,
    output reg rdfifo_wr_en,
    output reg [AXI_DATA_WIDTH-1:0] rdfifo_data_in,
    output [0:0] m_axi_arlock,
    output [3:0] m_axi_arcache,
    output [2:0] m_axi_arprot,
    output [3:0] m_axi_arqos,
    output [3:0] m_axi_arregion,
    
    output reg one_frame_rd_done
    
    );
    
    localparam S_IDLE=3'b1,
               S_RD_ADDR=3'b10,
               S_RD_DATA=3'b100;
               
    reg [2:0] state,next_state;
    
    reg axi_araddr_clr;
    reg one_frame_rd_done_sync1,one_frame_rd_done_sync2;
    
    
    wire [11:0] rd_req_cnt_thresh;
    wire rd_ddr3_req;
    wire m_axi_aren,m_axi_ren;
    
    always @ (posedge clk or posedge reset)
    if(reset) state<=S_IDLE;
    else if(!axi_rd_en) state<=S_IDLE;
    else state<=next_state;
    
    always @ (*)
    case(state)
    
    S_IDLE:if(rd_ddr3_req) next_state=S_RD_ADDR;
           else next_state=S_IDLE;
    
    S_RD_ADDR:if(m_axi_aren) next_state=S_RD_DATA;
              else next_state=S_RD_ADDR;
    
    S_RD_DATA:if(m_axi_ren&&m_axi_rresp==2'b00&&m_axi_rlast&&m_axi_rid==axi_id) next_state=S_IDLE;
              else next_state=S_RD_DATA;
    
    default:next_state=S_IDLE;
    endcase
    
    assign m_axi_arid=axi_id;
    assign m_axi_arlen=AXI_BURST_LEN[7:0];
    assign m_axi_arsize=4;
    assign m_axi_arburst=2'b01;
    assign m_axi_arlock  = 1'b0;
    assign m_axi_arcache = 4'b0000;
    assign m_axi_arprot  = 3'b000;
    assign m_axi_arqos   = 4'b0000;
    assign m_axi_arregion= 4'b0000;
    
    always @ (posedge clk or posedge reset)
    if(reset) begin
        m_axi_araddr<=0;
        m_axi_arvalid<=0;
        rdfifo_wr_en<=0;
        rdfifo_data_in<=0;   
        end
        
    else if(!axi_rd_en) begin
        m_axi_araddr<=0;
        m_axi_arvalid<=0;
        rdfifo_wr_en<=0;
        rdfifo_data_in<=0;   
        end
    
    else begin
        //m_axi_araddr:
        if(addr_clr||axi_araddr_clr) m_axi_araddr<=axi_rd_addr_begin;
        else if(one_frame_rd_done_sync2) m_axi_araddr<=axi_rd_addr_begin;
//        else if(m_axi_araddr>=axi_rd_addr_end) m_axi_araddr<=axi_rd_addr_begin;
        else if(m_axi_ren&&m_axi_rresp==2'b00&&m_axi_rid==axi_id&&m_axi_rlast&&state==S_RD_DATA) m_axi_araddr<=m_axi_araddr+((AXI_DATA_WIDTH/8)*(AXI_BURST_LEN+1));
        
        //m_axi_arvalid:
        if(state==S_RD_ADDR&&!m_axi_aren) m_axi_arvalid<=1;
        else if(state==S_RD_ADDR&&m_axi_aren) m_axi_arvalid<=0;
        
        //rdfifo_wr_en:
        if(state==S_RD_DATA&m_axi_ren) rdfifo_wr_en<=1;
        else if(addr_clr || axi_araddr_clr) rdfifo_wr_en<=0;
        else rdfifo_wr_en<=0;
        
        //rdfifo_data_in:
        if(state==S_RD_DATA&&m_axi_ren) rdfifo_data_in<=m_axi_rdata;
        else if(addr_clr || axi_araddr_clr) rdfifo_data_in<=0;
        else if(state==S_IDLE) rdfifo_data_in<=0;
        
       
        end
        
    always @ (posedge clk or posedge reset)
    if(reset) axi_araddr_clr<=0;
    else if(m_axi_rlast&&m_axi_ren&&m_axi_rresp==2'b00) axi_araddr_clr<=0;
    else if(addr_clr&&(m_axi_arvalid||m_axi_rvalid)) axi_araddr_clr<=1;//和上个模块同理
    
    assign rd_req_cnt_thresh=FIFO_TO_AXI_DATA_DEPTH-AXI_BURST_LEN;
    
    assign rd_ddr3_req=((rdfifo_wr_cnt<rd_req_cnt_thresh-3)&&(rdfifo_rst_busy==0))?1'b1:1'b0;
     
    assign m_axi_rready=!rdfifo_alfull;//不能直接为1，否则会溢出，必须等到FIFO有空位再读进FIFO
        
    assign m_axi_ren=m_axi_rvalid&&m_axi_rready;
    
    assign m_axi_aren=m_axi_arvalid&&m_axi_arready;
    
    
    always @ (posedge clk or posedge reset)
    if(reset) one_frame_rd_done<=0;
    else if(m_axi_ren&&m_axi_rresp==2'b00&&m_axi_rid==axi_id&&m_axi_rlast&&state==S_RD_DATA&&m_axi_araddr>=axi_rd_addr_end-(AXI_DATA_WIDTH/8)*(AXI_BURST_LEN+1)) 
            one_frame_rd_done<=1;
    else one_frame_rd_done<=0;
    
    always @ (posedge clk)
    begin
        one_frame_rd_done_sync1<=one_frame_rd_done;
        one_frame_rd_done_sync2<=one_frame_rd_done_sync1;
    end
    
endmodule
