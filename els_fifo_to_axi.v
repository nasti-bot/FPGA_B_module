`timescale 1ns / 1ps


//此模块联系写FIFO与AXI写相关通道，产生AW, W, B 通道相关信号：
module els_fifo_to_axi #(

    parameter IMAGE_WIDTH=800,
    parameter IMAGE_HEIGHT=480,
    
    parameter AXI_BURST_LEN=31,
    parameter AXI_DATA_WIDTH=128,
    parameter AXI_ADDR_WIDTH=30,
    parameter AXI_ID_WIDTH=4,

    parameter FIFO_TO_AXI_DATA_DEPTH=64,
    
    localparam FIFO_TO_AXI_DATA_DEPTH_WIDTH=$clog2(FIFO_TO_AXI_DATA_DEPTH),
    localparam AXI_DATA_SIZE=$clog2(AXI_DATA_WIDTH/8)
    )
(
    input clk,
    input reset,
    
    
    input [FIFO_TO_AXI_DATA_DEPTH_WIDTH-1:0] wrfifo_rd_cnt,
    
    input wrfifo_empty,
    input wrfifo_rst_busy,
    
    output reg wrfifo_rd_en,
    input [AXI_DATA_WIDTH-1:0] wrfifo_data_out,
    
    
    input addr_clr,                //请求将写地址复位回到此时的基地址
    
    
    input axi_wr_en,
    
	
    //该帧的地址：
    input [AXI_ADDR_WIDTH-1:0] axi_wr_addr_begin,
    input [AXI_ADDR_WIDTH-1:0] axi_wr_addr_end,
    
    input [AXI_ID_WIDTH-1:0] axi_id,
    
	
    //AW:
    input m_axi_awready,
    
    output [AXI_ID_WIDTH-1:0] m_axi_awid,
    output reg [AXI_ADDR_WIDTH-1:0] m_axi_awaddr,
    output reg m_axi_awvalid,
    
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
    
    output [AXI_DATA_WIDTH/8-1:0] m_axi_wstrb,
    output reg m_axi_wvalid,
    output reg m_axi_wlast,
    output reg [AXI_DATA_WIDTH-1:0] m_axi_wdata,
    output [AXI_ID_WIDTH-1:0] m_axi_wid,
    
    
    //B:
    input m_axi_bvalid,
    input [1:0] m_axi_bresp,            //从机给的写响应
    input [AXI_ID_WIDTH-1:0] m_axi_bid,
    
    output reg m_axi_bready,
    
       
    output reg one_frame_wr_done     //输出写完一帧的标志信号
    
    );
    
    
  /////////////////
  /////////////////
  //通过读取写FIFO中读端的计数，满一次burst的数据量后就发起AXI的写请求：
    
    wire [11:0] wr_req_cnt_thresh;                //写请求发起阈值
    wire wr_ddr3_req;                             //写请求
    
    assign wr_req_cnt_thresh=AXI_BURST_LEN+1;      //阈值是刚好满一次burst的数据量
    
    assign wr_ddr3_req=(wrfifo_rd_cnt>=wr_req_cnt_thresh && !wrfifo_rst_busy && !wrfifo_empty)?1'b1:1'b0; //刚好满一次burst的数据量就发起写请求
    
    
  ////////////////////
  ////////////////////
  //使用三段式状态机，输出AXI写相关信号：
  
    localparam S_IDLE=5'b1,             //空闲态，等待写请求的发起
               S_WR_ADDR=5'b10,         //写地址状态，产生awvalid来握手
               S_WR_DATA_PRE=5'b100,    //写准备状态，在写状态前持续一个周期，发起读取写FIFO中的数据的请求
               S_WR_DATA=5'b1000,       //写状态，产生wvalid来握手,与wdata, wlast
               S_WR_RESP=5'b10000;      //写响应态，等待从机的响应
    
    reg [4:0] state,next_state;
  
    always @ (posedge clk)
    if(reset) state<=S_IDLE;
    else state<=next_state;
    
    
        //表示握手成功的标志，结尾用_en表示：
        wire m_axi_awen,m_axi_wen,m_axi_ben;
        
        assign m_axi_awen=m_axi_awvalid&&m_axi_awready; 
        assign m_axi_wen=m_axi_wvalid&&m_axi_wready;
        assign m_axi_ben=m_axi_bvalid&&m_axi_bready;
    
    
    //状态转换：
    always @ (*)
    case(state)
    S_IDLE:if(wr_ddr3_req) next_state=S_WR_ADDR;        //当收到写请求时，立刻进入写地址态
    
           else next_state=S_IDLE;
           
           
    S_WR_ADDR:if(m_axi_awen) next_state=S_WR_DATA_PRE;      //写地址握手成功后，立刻进入写准备状态
    
              else next_state=S_WR_ADDR;
              
              
    S_WR_DATA_PRE:next_state=S_WR_DATA;        //下个周期就进入写状态
    
    
    S_WR_DATA:if(m_axi_wen&&m_axi_wlast) next_state=S_WR_RESP;              //当最后一次握手，即传的是这次burst的最后一个beat时，结束写，进入写响应态
    
              else if(m_axi_wen&&!m_axi_wlast) next_state=S_WR_DATA_PRE;    //若不是最后一个beat，回到写准备状态准备传下一个beat
              
              else next_state=S_WR_DATA;
    
    
    S_WR_RESP:if((m_axi_ben)&&(m_axi_bid==axi_id)&&(m_axi_bresp==2'b00)) next_state=S_IDLE;    //当写响应握手成功且检查正确，回到空闲态，完成此次burst的传输
    
              else next_state=S_WR_RESP;
    
    
    default:next_state=S_IDLE;
    endcase
    
    
    //状态机的输出：
        
         
         //写地址复位的请求：
         reg axi_awaddr_clr; 
        
         always @ (posedge clk)
         if(reset) axi_awaddr_clr<=0;
         else if(m_axi_ben) axi_awaddr_clr<=0;//如果burst传输成功了，就撤掉地址复位请求。因为每一次burst的初始地址在最开始已经确定，不能让这一次burst的clr影响下一次burst
         else if(addr_clr&&(m_axi_awvalid||m_axi_wvalid)) axi_awaddr_clr<=1;//只有在总线忙，也就是awvalid或者wvalid高电平时，才锁存复位信号，防止窄脉冲addr_clr高时漏掉复位，总线不忙会正常复位不用管
        
        
        //一帧写完成标志的产生与打拍：
        reg one_frame_wr_done_sync0,          //结尾带_sync0表示是打一拍后的
            one_frame_wr_done_sync1;          //结尾带_sync1表示是打两拍后的
                
                //当处于写响应状态且握手成功且此时写地址刚好快达到末地址时，意味着一帧刚好写完，输出标志信号   
                always @ (posedge clk)
                if(reset) one_frame_wr_done<=0; 
                else if((m_axi_ben)&&(m_axi_bid==axi_id)&&(m_axi_bresp==2'b00)&&(state==S_WR_RESP)&&
                        (m_axi_awaddr>=axi_wr_addr_end-(m_axi_awlen+1)*(AXI_DATA_WIDTH/8)))            one_frame_wr_done<=1;
                                                                                                                         
                else one_frame_wr_done<=0;
                
                //对一帧写完成的标志进行打两拍，因为帧缓存状态机从拿到完成标志到输出新地址需要经过两个周期：
                always @ (posedge clk)
                
                begin
                    one_frame_wr_done_sync0<=one_frame_wr_done;
                    one_frame_wr_done_sync1<=one_frame_wr_done_sync0;
                end
    
    
    //AW, W, B通道信号的产生:
    
    reg wrfifo_rd_data_valid;                   //从写FIFO中读出的数据的有效信号
    
    reg [15:0] axi_wr_beat_cnt;                 //beat_cnt:显示此时正在传的是这次burst的第几个beat
    
    always @ (posedge clk)
    if(reset) begin
    
        wrfifo_rd_en<=0;
        wrfifo_rd_data_valid<=0;
        
        m_axi_awaddr<=0;
        m_axi_awvalid<=0;

        axi_wr_beat_cnt<=0;
        
        m_axi_wvalid<=0;
        m_axi_wlast<=0;
        m_axi_wdata<=0;
        
        end
    else begin
    
      //AW:
      
        //m_axi_awaddr:
        if(addr_clr||axi_awaddr_clr) m_axi_awaddr<=axi_wr_addr_begin;                  //保证地址完全复位，防止漏掉复位，一旦axi_awaddr_clr为高会立刻让地址复位
        
        else if(one_frame_wr_done_sync1) m_axi_awaddr<=axi_wr_addr_begin;              //此时帧缓存状态机已经给出新的基地址，刚好赋上
        
        else if((state==S_WR_RESP)&&(m_axi_ben)&&(m_axi_bid==axi_id)&&(m_axi_bresp==2'b00)) m_axi_awaddr<=m_axi_awaddr+(m_axi_awlen+1)*(AXI_DATA_WIDTH/8);  //每当到达写响应态且握手成功后，让写地址自增
               
        
        //m_axi_awvalid:
        if(state==S_WR_ADDR && !m_axi_awen) m_axi_awvalid<=1;      //若处于写地址态且未握手成功，就给出awvalid来握手
        
        else if(state==S_WR_ADDR && m_axi_awen) m_axi_awvalid<=0;  //握手成功后撤回awvalid
        
        
      //  
        
        //wrfifo_rd_en:
        if(state==S_WR_ADDR && m_axi_awen) wrfifo_rd_en<=1;                       //当写地址态握手成功后，开始读出写FIFO的数据以进行写
        
        else if(state==S_WR_DATA && m_axi_wen && !m_axi_wlast) wrfifo_rd_en<=1;     //若写状态握手成功且此时传的不是最后一个beat，也继续读写FIFO的数据
        
        else wrfifo_rd_en<=0;
        
 
        //wrfifo_rd_data_valid:
        wrfifo_rd_data_valid<=wrfifo_rd_en;   
       
        
     //W:   
        
        //m_axi_wvalid:
        if(state==S_WR_DATA && wrfifo_rd_data_valid) m_axi_wvalid<=1;        //当读出写FIFO中的数据后，准备握手信号wvalid
        
        else if(state==S_WR_DATA && m_axi_wen) m_axi_wvalid<=0;             //等握手成功后撤回
               
        
        //m_axi_wdata:
        if(state==S_WR_DATA && wrfifo_rd_data_valid) m_axi_wdata<=wrfifo_data_out;  //当写FIFO的数据被读出后，将其作为待写数据等待发送
        
        else if(state==S_IDLE) m_axi_wdata<=0;
              
        
        //axi_wr_beat_cnt:
        if(state==S_WR_DATA && m_axi_wen) axi_wr_beat_cnt<=axi_wr_beat_cnt+1;     //每当写状态握手成功一次后，意味着一个beat传了出去，让beat_cnt自增
        
        else if(state==S_IDLE) axi_wr_beat_cnt<=0;                              //完成一个burst的传输后自动清零
              
        
        //m_axi_wlast:
        
        if(AXI_BURST_LEN==0) begin                                                    //若burst只含一个beat，写状态时wlast始终为1
            if(state==S_WR_DATA_PRE) m_axi_wlast<=1;
            else if(state==S_WR_DATA && m_axi_wen) m_axi_wlast<=0;
            end
            
        else begin
            if(state==S_WR_DATA_PRE && axi_wr_beat_cnt==AXI_BURST_LEN) m_axi_wlast<=1;  //否则当写的是最后一个beat时wlast才为1
            else if(state==S_WR_DATA && m_axi_wen) m_axi_wlast<=0;
            end
            
     
     //B:
        
         //m_axi_bready:
         m_axi_bready<=1;       //让bready固定为1，随时可以和bvalid握手
            
            
      end
         
        
        //其余固定的相关信号：
        assign m_axi_awid=axi_id;
        assign m_axi_wid=axi_id;
        assign m_axi_awlen=AXI_BURST_LEN[7:0];
        assign m_axi_awsize=4;
        assign m_axi_awburst=2'b01;
        assign m_axi_awlock=1'b0;
        assign m_axi_awcache=4'b0000;
        assign m_axi_awprot=3'b000;
        assign m_axi_awqos=4'b0000;
        assign m_axi_awregion=4'b0000;
        assign m_axi_wstrb=16'hffff;        //写通道完全选通
     
     
  ///////////////////////////////
  //////////////////////////////



endmodule
