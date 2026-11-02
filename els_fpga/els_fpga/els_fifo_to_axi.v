`timescale 1ns / 1ps

module els_fifo_to_axi #(

    parameter IMAGE_WIDTH=800,
    parameter IMAGE_HEIGHT=480,
    
    parameter AXI_BURST_LEN=31,
    parameter AXI_DATA_WIDTH=128,
    parameter AXI_ADDR_WIDTH=30,
    parameter AXI_ID_WIDTH=4,
//    parameter AXI_WR_ADDR_BEGIN=0,
//    parameter AXI_WR_ADDR_END=1023,
//    parameter AXI_ID=0,
    parameter FIFO_TO_AXI_DATA_DEPTH=64,
    
    localparam FIFO_TO_AXI_DATA_DEPTH_WIDTH=$clog2(FIFO_TO_AXI_DATA_DEPTH),
    localparam AXI_DATA_SIZE=$clog2(AXI_DATA_WIDTH/8)
    )
(
    input clk,
    input reset,
    
    input axi_wr_en,
    
    input [FIFO_TO_AXI_DATA_DEPTH_WIDTH-1:0] wrfifo_rd_cnt,
    input wrfifo_empty,
    input wrfifo_rst_busy,
    input [AXI_DATA_WIDTH-1:0] wrfifo_data_out,
    input m_axi_awready,
    input m_axi_wready,
    input m_axi_bvalid,
    input [1:0] m_axi_bresp,
    input [AXI_ID_WIDTH-1:0] m_axi_bid,
    input addr_clr,
    
    input [30:0] axi_wr_addr_begin,
    input [30:0] axi_wr_addr_end,
    
    input [AXI_ID_WIDTH-1:0] axi_id,
    
    output [7:0] m_axi_awlen,
    output [2:0] m_axi_awsize,
    output [1:0] m_axi_awburst,
    output [0:0] m_axi_awlock,
    output [3:0] m_axi_awcache,
    output [2:0] m_axi_awprot,
    output [3:0] m_axi_awqos,
    output [3:0] m_axi_awregion,
    output [AXI_DATA_WIDTH/8-1:0] m_axi_wstrb,
    output m_axi_bready,
    output [AXI_ID_WIDTH-1:0] m_axi_awid,
    output reg [AXI_ADDR_WIDTH-1:0] m_axi_awaddr,
    output reg wrfifo_rd_en,
    output reg m_axi_awvalid,
    output reg m_axi_wvalid,
    output reg m_axi_wlast,
    output reg [AXI_DATA_WIDTH-1:0] m_axi_wdata,
    
    output reg one_frame_wr_done
    
    );
    
    localparam S_IDLE=5'b1,
               S_WR_ADDR=5'b10,
               S_WR_DATA_PRE=5'b100,
               S_WR_DATA=5'b1000,
               S_WR_RESP=5'b10000;
    
    reg [4:0] state,next_state;
    
    wire m_axi_awen,m_axi_wen,m_axi_ben;
    wire wr_ddr3_req;
    wire [11:0] wr_req_cnt_thresh;
    
    reg wrfifo_rd_en_sync1;
    reg [15:0] axi_wr_beat_cnt;
    reg axi_awaddr_clr;
    reg one_frame_wr_done_sync1,one_frame_wr_done_sync2;
    
    always @ (posedge clk or posedge reset)
    if(reset) state<=S_IDLE;
    else state<=next_state;
    
    always @ (*)
    case(state)
    S_IDLE:if(wr_ddr3_req) next_state=S_WR_ADDR;
           else next_state=S_IDLE;
           
    S_WR_ADDR:if(m_axi_awen) next_state=S_WR_DATA_PRE;
              else next_state=S_WR_ADDR;
              
    S_WR_DATA_PRE:next_state=S_WR_DATA;
    
    S_WR_DATA:if(m_axi_wen&&m_axi_wlast) next_state=S_WR_RESP;
              else if(m_axi_wen&&!m_axi_wlast) next_state=S_WR_DATA_PRE;
              else next_state=S_WR_DATA;
    
    S_WR_RESP:if((m_axi_ben)&&(m_axi_bid==axi_id)&&(m_axi_bresp==2'b00)) next_state=S_IDLE;
              else next_state=S_WR_RESP;
    
    default:next_state=S_IDLE;
    endcase
    
    assign m_axi_awid=axi_id;
    assign m_axi_awlen=AXI_BURST_LEN[7:0];
    assign m_axi_awsize=4;
    assign m_axi_awburst=2'b01;
    assign m_axi_awlock=1'b0;
    assign m_axi_awcache=4'b0000;
    assign m_axi_awprot=3'b000;
    assign m_axi_awqos=4'b0000;
    assign m_axi_awregion=4'b0000;
    assign m_axi_wstrb=16'hffff;
    assign m_axi_bready=1'b1;
    
    always @ (posedge clk or posedge reset)
    if(reset) begin
        m_axi_awaddr<=0;
        wrfifo_rd_en<=0;
        wrfifo_rd_en_sync1<=0;
        m_axi_awvalid<=0;
        m_axi_wvalid<=0;
        axi_wr_beat_cnt<=0;
        m_axi_wlast<=0;
        m_axi_wdata<=0;
        end
    else begin
        //m_axi_awaddr:
        if(addr_clr||axi_awaddr_clr) m_axi_awaddr<=axi_wr_addr_begin;//保证地址完全复位，防止漏掉复位，注意：一旦axi_awaddr_clr为高会立刻让地址复位
        else if(one_frame_wr_done_sync2) m_axi_awaddr<=axi_wr_addr_begin;
//        else if(m_axi_awaddr>=axi_wr_addr_end) m_axi_awaddr<=axi_wr_addr_begin;
        else if((state==S_WR_RESP)&&(m_axi_ben)&&(m_axi_bid==axi_id)&&(m_axi_bresp==2'b00)) m_axi_awaddr<=m_axi_awaddr+(m_axi_awlen+1)*(AXI_DATA_WIDTH/8);
        
        //m_axi_awvalid:
        if(state==S_WR_ADDR&&!m_axi_awen) m_axi_awvalid<=1;
        else if(state==S_WR_ADDR&&m_axi_awen) m_axi_awvalid<=0;
        
        //wrfifo_rd_en:
        if(state==S_WR_ADDR&&m_axi_awen) wrfifo_rd_en<=1;
        else if(state==S_WR_DATA&&m_axi_wen&&!m_axi_wlast) wrfifo_rd_en<=1;
        else wrfifo_rd_en<=0;
        
        //wrfifo_rd_en_sync1:
        wrfifo_rd_en_sync1<=wrfifo_rd_en;
        
        //m_axi_wvalid:
        if(state==S_WR_DATA&&wrfifo_rd_en_sync1) m_axi_wvalid<=1;
        else if(state==S_WR_DATA&&m_axi_wen) m_axi_wvalid<=0;
        
        //axi_wr_beat_cnt:
        if(state==S_WR_DATA&&m_axi_wen) axi_wr_beat_cnt<=axi_wr_beat_cnt+1;
        else if(state==S_IDLE) axi_wr_beat_cnt<=0;
        
        //m_axi_wlast:
        if(AXI_BURST_LEN==0) begin
            if(state==S_WR_DATA_PRE) m_axi_wlast<=1;
            else if(state==S_WR_DATA&&m_axi_wen) m_axi_wlast<=0;
            end
        else begin
            if(state==S_WR_DATA_PRE&&axi_wr_beat_cnt==AXI_BURST_LEN) m_axi_wlast<=1;
            else if(state==S_WR_DATA&&m_axi_wen) m_axi_wlast<=0;
            end
            
        //m_axi_wdata:
        if(state==S_WR_DATA&&wrfifo_rd_en_sync1) m_axi_wdata<=wrfifo_data_out;
        else if(state==S_IDLE) m_axi_wdata<=0;
        
        end
        
    always @ (posedge clk or posedge reset)
    if(reset) axi_awaddr_clr<=0;
    else if(m_axi_ben) axi_awaddr_clr<=0;//如果burst传输成功了，就撤掉地址复位请求。因为每一次burst的初始地址在最开始已经确定，不能让这一次burst的clr影响下一次burst
    else if(addr_clr&&(m_axi_awvalid||m_axi_wvalid)) axi_awaddr_clr<=1;//只有在总线忙，也就是awvalid或者wvalid高电平时，才锁存复位信号，防止窄脉冲addr_clr高时漏掉复位，总线不忙会正常复位不用管
        
    assign wr_req_cnt_thresh=AXI_BURST_LEN+1;
    
    assign wr_ddr3_req=(wrfifo_rd_cnt>=wr_req_cnt_thresh&&!wrfifo_rst_busy&&!wrfifo_empty)?1'b1:1'b0;
    
    assign m_axi_awen=m_axi_awvalid&&m_axi_awready;
    
    assign m_axi_wen=m_axi_wvalid&&m_axi_wready;
    
    assign m_axi_ben=m_axi_bvalid&&m_axi_bready;
    
    always @ (posedge clk or posedge reset)
    if(reset) one_frame_wr_done<=0;
    else if((m_axi_ben)&&(m_axi_bid==axi_id)&&(m_axi_bresp==2'b00)&&(state==S_WR_RESP)&&(m_axi_awaddr>=axi_wr_addr_end-(m_axi_awlen+1)*(AXI_DATA_WIDTH/8))) 
                one_frame_wr_done<=1;
    else one_frame_wr_done<=0;
    
    always @ (posedge clk)
    begin
        one_frame_wr_done_sync1<=one_frame_wr_done;
        one_frame_wr_done_sync2<=one_frame_wr_done_sync1;
    end

endmodule
