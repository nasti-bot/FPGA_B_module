`timescale 1ns / 1ps


//此模块联系读FIFO与AXI读相关通道，产生或读取AR, R 通道相关信号：
module els_axi_to_fifo #(

    parameter IMAGE_WIDTH=800,
    parameter IMAGE_HEIGHT=480,

    parameter AXI_ID_WIDTH=4,
    parameter AXI_DATA_WIDTH=128,
    parameter AXI_BURST_LEN=31,
    parameter AXI_ADDR_WIDTH=30,
    
    parameter FIFO_TO_AXI_DATA_DEPTH=64,
    
    localparam AXI_DATA_SIZE=$clog2(AXI_DATA_WIDTH/8),
    localparam FIFO_TO_AXI_DATA_DEPTH_WIDTH=$clog2(FIFO_TO_AXI_DATA_DEPTH)
    
    ) 
(   
    input clk,
    input reset,
    
    input axi_rd_en,         //AXI读操作的使能信号
    
    
    //rd_fifo:
    input [FIFO_TO_AXI_DATA_DEPTH_WIDTH-1:0] rdfifo_wr_cnt,
    
    input rdfifo_alfull,
    
    input rdfifo_rst_busy,
    
    output reg rdfifo_wr_en,
    output reg [AXI_DATA_WIDTH-1:0] rdfifo_data_in,
    
    
    //
    input addr_clr,                  //读地址复位的请求，将读地址恢复到此时的基地址
     
    
    //该帧的地址：	
    input [AXI_ADDR_WIDTH-1:0] axi_rd_addr_begin,
    input [AXI_ADDR_WIDTH-1:0] axi_rd_addr_end,
    
    input [AXI_ID_WIDTH-1:0] axi_id,
    
    
    //AR:
    input m_axi_arready,
    
    output [AXI_ID_WIDTH-1:0] m_axi_arid,
    output reg [AXI_ADDR_WIDTH-1:0] m_axi_araddr,
    output [7:0] m_axi_arlen,
    output [2:0] m_axi_arsize,
    output [1:0] m_axi_arburst,
    output reg m_axi_arvalid,
    
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
    
    
    
    output reg one_frame_rd_done
    
    );
      
      
  ////////////////////////////////////
  ///////////////////////////////////
  //读请求的发起：  
    
    wire [11:0] rd_req_cnt_thresh;        //读请求发起阈值
    wire rd_ddr3_req;                     //读请求
    
    assign rd_req_cnt_thresh=FIFO_TO_AXI_DATA_DEPTH-AXI_BURST_LEN;     //阈值是读FIFO刚好还差一个burst的数据就满时
    
    assign rd_ddr3_req=((rdfifo_wr_cnt<rd_req_cnt_thresh-3)&&(rdfifo_rst_busy==0))?1'b1:1'b0;  //保险起见，当读FIFO更空时再写入数据
     
    assign m_axi_rready=!rdfifo_alfull;              //不能直接为1，必须等到读FIFO有空位再读进FIFO 
    
  /////////////////////
  /////////////////////
  //使用三段式状态机，输出读相关信号：
    
    localparam S_IDLE=3'b1,             //空闲态，等待读请求的发起
               S_RD_ADDR=3'b10,         //写读地址态，输出要读的数据的地址
               S_RD_DATA=3'b100;        //读数据态，读取AXI输送的数据
               
    reg [2:0] state,next_state;
    
    always @ (posedge clk)
    if(reset) state<=S_IDLE;
    else if(!axi_rd_en) state<=S_IDLE;          //若axi读使能为低，留在空闲态不进行读操作
    else state<=next_state;
    
    
    
        //表示握手成功的标志，结尾用_en表示：
        wire m_axi_aren,m_axi_ren;
        
        assign m_axi_ren=m_axi_rvalid&&m_axi_rready;
        assign m_axi_aren=m_axi_arvalid&&m_axi_arready;
    
    
    //状态转换：
    always @ (*)
    case(state)
    
    S_IDLE:if(rd_ddr3_req) next_state=S_RD_ADDR;             //当收到读请求时，立刻进入写读地址态
    
           else next_state=S_IDLE;
    
    
    S_RD_ADDR:if(m_axi_aren) next_state=S_RD_DATA;          //当写读地址握手成功后，进入读数据态
    
              else next_state=S_RD_ADDR;
              
    
    S_RD_DATA:if(m_axi_ren&&m_axi_rresp==2'b00&&m_axi_rlast&&m_axi_rid==axi_id) next_state=S_IDLE;   //当读状态时读的是最后一个beat，回到空闲态，完成此次burst的读
    
              else next_state=S_RD_DATA;
              
    
    default:next_state=S_IDLE;
    endcase
    
    
    //状态机的输出：
    
    
        //读地址复位的请求：
        reg axi_araddr_clr;
        
        always @ (posedge clk)
        if(reset) axi_araddr_clr<=0;
        else if(m_axi_rlast&&m_axi_ren&&m_axi_rresp==2'b00) axi_araddr_clr<=0;
        else if(addr_clr&&(m_axi_arvalid||m_axi_rvalid)) axi_araddr_clr<=1;//和上个模块同理
    
    
        //读完一帧的标志信号的产生与打拍：
        reg one_frame_rd_done_sync0,
            one_frame_rd_done_sync1;
        
            //当此时读地址刚好要到达末地址且读完成时，意味着刚好读完了一帧，输出标志信号：
            always @ (posedge clk)
            if(reset) one_frame_rd_done<=0;
            else if(m_axi_ren&&m_axi_rresp==2'b00&&m_axi_rid==axi_id&&m_axi_rlast&&state==S_RD_DATA&&
                    m_axi_araddr>=axi_rd_addr_end-(AXI_DATA_WIDTH/8)*(AXI_BURST_LEN+1))                one_frame_rd_done<=1;
                    
            else one_frame_rd_done<=0;
            
            //同写操作，由于帧缓存状态机从拿到读一帧完成标志到输出新的读地址需要经过两个周期，故把标志信号打两拍：
            always @ (posedge clk)
            
            begin
                one_frame_rd_done_sync0<=one_frame_rd_done;
                one_frame_rd_done_sync1<=one_frame_rd_done_sync0;
            end
    
    
    //AR通道信号的产生，以及数据的读取：
    
    always @ (posedge clk)
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
      
      //AR:
      
        //m_axi_araddr:
        if(addr_clr||axi_araddr_clr) m_axi_araddr<=axi_rd_addr_begin;
        
        else if(one_frame_rd_done_sync1) m_axi_araddr<=axi_rd_addr_begin;           //此时帧缓存状态机已经给出新的读地址
        
        else if(m_axi_ren && m_axi_rresp==2'b00 && m_axi_rid==axi_id & &m_axi_rlast && state==S_RD_DATA) m_axi_araddr<=m_axi_araddr+((AXI_DATA_WIDTH/8)*(AXI_BURST_LEN+1));   //每当读完一个beat且读响应正确后，让读地址自增
        
        
        //m_axi_arvalid:
        if(state==S_RD_ADDR && !m_axi_aren) m_axi_arvalid<=1;        //在写读地址状态，若为握手成功，给出arvalid来握手
        
        else if(state==S_RD_ADDR && m_axi_aren) m_axi_arvalid<=0;    //握手成功后撤回
        
        
     // 读取数据：
        
        //rdfifo_wr_en:
        if(state==S_RD_DATA && m_axi_ren) rdfifo_wr_en<=1;               //当处于读状态且读握手成功后，此时数据有效，给出读FIFO的写使能信号
        
        else if(addr_clr || axi_araddr_clr) rdfifo_wr_en<=0;
        
        else rdfifo_wr_en<=0;
        
        
        //rdfifo_data_in:
        if(state==S_RD_DATA && m_axi_ren) rdfifo_data_in<=m_axi_rdata;  //当处于读状态且读握手成功后，锁存数据，准备写入读FIFO
        
        else if(addr_clr || axi_araddr_clr) rdfifo_data_in<=0;
        
        else if(state==S_IDLE) rdfifo_data_in<=0;
        
       
        end
        
        
        //其余相关输出：    
        assign m_axi_arid=axi_id;
        assign m_axi_arlen=AXI_BURST_LEN[7:0];
        assign m_axi_arsize=4;
        assign m_axi_arburst=2'b01;
        assign m_axi_arlock  = 1'b0;
        assign m_axi_arcache = 4'b0000;
        assign m_axi_arprot  = 3'b000;
        assign m_axi_arqos   = 4'b0000;
        assign m_axi_arregion= 4'b0000;
        
        

endmodule
