`timescale 1ns / 1ps


//IIC协议的读写模块分为命令层：i2c_ctrl与执行层：bit_shift

//这是IIC总线的命令层，负责接收读写任务，打包数据，输出指令给到执行层，让执行层控制或读取总线
module els_i2c_ctrl #(           
    parameter DATA_WIDTH=8
)
(
    input clk,
    input reset_n,
    
    input [7:0] device_id,      //IIC读写从机设备的ID
    input wr_req,
    input rd_req,
    input [DATA_WIDTH-1:0] wr_data,        //待写数据
    
    input [15:0] addr,
    input addr_mode,            //addr_mode显示存储单元地址的位数，为1表示共16位，为0表示共8位
    
    input [31:0] i2c_delay_cnt_max,//IIC读写完成后进行延时
    
    output reg ack,                 //输出最终的从机应答标志，为1表示过程中从机有过未应答情况
    
    output reg [DATA_WIDTH-1:0] rd_data, //最后读出的数据
    
    output reg rw_done_post,    //经过延迟后输出的rw_done
    
    output i2c_sclk,
    inout i2c_sdata
    );
    

  /////////////////
  ////////////////
  //使用三段式状态机，发出IIC的读写操作各阶段的指令：
  
    reg trans_go;       //命令位级执行层开始完成指令
    wire trans_done;    //位级执行层已经完成指令的标志信号
    
    reg [4:0] wr_cnt,rd_cnt; //读写操作的计数，因为IIC读写需要进行多段操作，所以通过计数显示此时应进行哪个操作
  
  localparam   S_IDLE=7'b1,         //空闲态，不发出任何指令
  
               S_WR_REG=7'b10,      //写准备阶段，发出相关指令给位级执行层，一个周期后直接进入写阶段
               S_WAIT_WR=7'b100,    //写阶段，等待执行层完成
               S_WR_DONE=7'b1000,   //写完成阶段，表示执行层完成了一个写指令
               
               S_RD_REG=7'b10000,   //读准备阶段，发出相关指令给位级执行层，一个周期后直接进入读阶段
               S_WAIT_RD=7'b100000, //读阶段，等待执行层完成
               S_RD_DONE=7'b1000000;//读完成阶段，表示执行层完成了一个读指令
                            
    reg [6:0] state,next_state;
    
    always @ (posedge clk)
    if(!reset_n) state<=S_IDLE;
    else state<=next_state;
    
    
    //状态转换：
    always @ (*)
    case(state)
    S_IDLE:if(wr_req) next_state=S_WR_REG;      //一旦接收到写请求就进入写准备阶段
           else if(rd_req) next_state=S_RD_REG; //一旦接收到读请求就进入读准备阶段
           else next_state=S_IDLE;
           
    S_WR_REG:next_state=S_WAIT_WR;              //经过一个周期的准备，发出相关指令后直接进入写阶段
    
    S_WAIT_WR:if(trans_done) next_state=S_WR_DONE; //等待位级执行层完成任务后，进入写完成态
              else next_state=S_WAIT_WR;
              
    S_WR_DONE:if(wr_cnt==4) next_state=S_IDLE;     //等待写指令计数为4后，即完成整个IIC的写操作，回到空闲态
              else next_state=S_WR_REG;            //否则回到写准备状态，继续后续IIC写过程
    
    S_RD_REG:next_state=S_WAIT_RD;                 //读操作与写同理，发出读相关指令
    
    S_WAIT_RD:if(trans_done) next_state=S_RD_DONE;  //执行完成后进入读完成态
              else next_state=S_WAIT_RD;
              
    S_RD_DONE:if(rd_cnt==5) next_state=S_IDLE;     //直至读指令计数为5，即已经完成一整个读操作后才回到空闲态
              else next_state=S_RD_REG;            //否则继续读操作
    
    default:next_state=S_IDLE;
    endcase
    
    
  ///////////////////
  //////////////////
  //状态机的输出：
    
    localparam  C_START=6'b1,       //起始位指令，让执行层控制总线产生IIC起始信号
                C_WRITE=6'b10,      //写指令，让执行层控制总线完成一个字节的写        //注：因为每一次写操作后都必会检测从机应答，故写指令也包含检测应答
                C_READ=6'b100,      //读指令，让执行层根据总线读取并打包一个字节的数据
                C_ACK=6'b1000,      //检测从机应答指令，让执行层根据总线检查从机是否应答
                C_NACK=6'b10000,    //产生主机应答指令，让执行层控制总线产生主机应答
                C_STOP=6'b100000;   //终止位指令，让执行层控制总线产生IIC终止信号
   
    reg [5:0] cmd;                  //命令层发给执行层的指令
    
    reg [7:0] wr_data_reg;          //写数据寄存8位
    wire [7:0] rd_data_reg;         //读数据寄存8位
    
        task write_byte;                    //写任务，产生指令与待写数据
            input [5:0] task_wr_cmd;
            input [7:0] task_wr_data_reg;
        begin
            cmd<=task_wr_cmd;
            wr_data_reg<=task_wr_data_reg;
            end
        endtask
    
        task read_byte;                     //读任务，产生指令与读操作时需要进行的写地址数据
            input [5:0] task_rd_cmd;
            input [7:0] task_rwr_data_reg;
        begin
            cmd<=task_rd_cmd;
            wr_data_reg<=task_rwr_data_reg;
            end
        endtask
    
    reg [5:0] data_cnt;     //当数据多于8位时，data_cnt显示此时已经发了几位的data
    reg rw_done;            //延时前的读写完成标志信号
    
    wire ack_o;             //执行层输出过来的从机应答标志，为1表示从机没有应答
    
    
        //读写请求到来时，锁定住addr：
        
        reg [15:0] addr_reg;
        
        always @ (posedge clk)
        if(!reset_n) addr_reg<=0;
        else if(wr_req||rd_req) addr_reg<=addr;
    
    
    always @ (posedge clk)
    if(!reset_n) begin
        cmd<=0;
        rw_done<=0;
        wr_data_reg<=0;
        wr_cnt<=0;
        rd_cnt<=0;
        data_cnt<=0;
        ack<=0;
        rd_data<=0;
        end
        
    else case(state)
        S_IDLE:
            begin
               cmd<=cmd;
               rw_done<=0;
               wr_data_reg<=0;
               wr_cnt<=0;
               rd_cnt<=0;
               trans_go<=0;
               data_cnt<=0;
               ack<=0;
               rd_data<=rd_data;
               end
               
        S_WR_REG:
            begin
                 rw_done<=0;
                 rd_cnt<=0;
                 trans_go<=1;         //写准备状态，让执行层开始执行相关指令
                 wr_cnt<=wr_cnt;
                 data_cnt<=data_cnt;
                 ack<=ack|ack_o;      //若从机某一时刻不应答，就一直让ack保持高
                 
                 case(wr_cnt)           
                 0:write_byte(C_START|C_WRITE,device_id);                       //发起指令：起始位指令与写指令；产生起始位，写从机的设备ID
                 1:write_byte(C_WRITE,addr_reg[15:8]);                          //发起指令：写指令；写地址的前8位（若地址共16位）
                 2:write_byte(C_WRITE,addr_reg[7:0]);                           //发起指令：写指令；写地址的后8位
                 3:write_byte(C_WRITE,wr_data[DATA_WIDTH-1-data_cnt-:8]);       //发起指令：写指令；写数据的未写部分的最高8位
                 4:write_byte(C_WRITE|C_STOP,wr_data[DATA_WIDTH-1-data_cnt-:8]);//发起指令：写指令和终止位指令；写数据的最低8位，产生终止位
                 default:write_byte(0,0);
                 endcase
                 
                 end
                 
        S_WAIT_WR:
            begin
                  ack<=ack|ack_o;
                  rw_done<=0;
                  rd_cnt<=0;
                  trans_go<=0;      //拉低trans_go
                  wr_cnt<=wr_cnt;
                  cmd<=cmd;
                  wr_data_reg<=wr_data_reg;
                  
                  if(trans_done&&(wr_cnt==3||wr_cnt==4)) data_cnt<=data_cnt+8; //执行层完成一次写字节后，让data_cnt加8
                  
                  end
                  
        S_WR_DONE:
            begin
                  if(wr_cnt==4) rw_done<=1;    //当wr_cnt为4，表示已经完全完成IIC写操作，输出rw_done
                  else rw_done<=0;
                  
                  data_cnt<=data_cnt;
                  
                  case(wr_cnt)                          //根据此时的写指令计数来判断后续
                  
                  //产生起始位以及设备ID写完后：
                  0:wr_cnt<=1;                          //执行层完成写设备ID后，计数从0到1
                  
                  //地址的前8位写完后：
                  1:if(addr_mode) wr_cnt<=2;             //若地址共16位，计数变为2继续写地址的后8位
                    else if(DATA_WIDTH==8) wr_cnt<=4;    //若地址共8位且数据只有8位，计数变为4，写完这8位数据后产生终止位
                    else wr_cnt<=3;                      //若地址共8位且数据多于8位，计数变为3，写当前未写数据的最高8位
                  
                  //地址的后8位写完后： 
                  2:if(DATA_WIDTH==8) wr_cnt<=4;         //若数据只有8位，计数变为4，写完这8位数据后产生终止位
                    else wr_cnt<=3;                      //若多于8位就计数变为3开始写未写数据的最高8位
                  
                  //数据的未写部分的前8位写完后：  
                  3:if(data_cnt==DATA_WIDTH-8) wr_cnt<=4;//当data_cnt已经计到只差一个字节时，计数变为4进行最后8位数据的写与产生终止位
                    else wr_cnt<=3;                       //否则继续写下8位
                  
                  //最后8位数据写完以及产生终止位后：
                  4:wr_cnt<=0;                            //已经全部完成，写指令计数清零
                  
                  default:wr_cnt<=0;
                  endcase
                  
                  rd_cnt<=0;
                  cmd<=cmd;
                  trans_go<=0;
                  wr_data_reg<=wr_data_reg;
                  
                  ack<=ack|ack_o;
                  
                  end
                  
        S_RD_REG:
            begin
                 rw_done<=0;
                 wr_cnt<=0;
                 rd_cnt<=rd_cnt;
                 trans_go<=1;
                 data_cnt<=data_cnt;
                 
                 rd_data<=rd_data<<8;         //每到读准备阶段就让读数据左移8位
                 
                 ack<=ack|ack_o;
                 
                 case(rd_cnt)
                 0:read_byte(C_START|C_WRITE,device_id);        //发起指令：起始位指令与写指令；产生起始位，写从机的设备ID
                 1:read_byte(C_WRITE,addr_reg[15:8]);           //发起指令：写指令；写地址的前8位（若地址共16位）
                 2:read_byte(C_WRITE|C_STOP,addr_reg[7:0]);     //发起指令：写指令与终止位指令；写地址的后8位并产生终止位
                 
                 3:read_byte(C_START|C_WRITE,device_id|8'b1);   //发起指令：起始位指令与写指令；产生起始位并写从机的设备ID（最后一位改为1）
                 4:read_byte(C_READ|C_ACK,0);                   //发起指令：读指令与检测从机应答；
                 5:read_byte(C_READ|C_NACK|C_STOP,0);           //发起指令：读指令与产生主机应答与产生终止位；
                 default:read_byte(0,0);
                 endcase
                 
                 end
                 
        S_WAIT_RD:
            begin
                  rw_done<=0;
                  wr_cnt<=0;
                  rd_cnt<=rd_cnt;
                  trans_go<=0;
                  cmd<=cmd;
                  wr_data_reg<=wr_data_reg;
                  ack<=ack|ack_o;
                  
                  if(trans_done&&(rd_cnt==4||rd_cnt==5)) data_cnt<=data_cnt+8; //同理，读完8位数据后让data_cnt加8
                  
                  end
                  
        S_RD_DONE:
            begin
                  trans_go<=0;
                  wr_cnt<=0;
                  cmd<=cmd;
                  wr_data_reg<=wr_data_reg;
                  ack<=ack|ack_o;
                  
                  if(rd_cnt==5) rw_done<=1;     //当读指令计数为5表示已经完成读操作，产生rw_done
                  else rw_done<=0;
                  
                  data_cnt<=data_cnt;
                  
                  if(rd_cnt==4|rd_cnt==5) rd_data[7:0]<=rd_data_reg;    //把读出的8位数据寄存到最后读数据的后8位
                  else rd_data<=rd_data;
                  
                  case(rd_cnt)
                  
                  //产生起始位与写设备ID完成后：
                  0:if(addr_mode) rd_cnt<=1;          //若地址共16位，开始写地址的前8位
                    else rd_cnt<=2;                   //若地址共8位，开始写这8位的地址
                  
                  //写地址的前8位完成后：  
                  1:rd_cnt<=2;                          //写完后写后8位地址
                  
                  //写地址的最后8位完成后：
                  2:rd_cnt<=3;                           //再次产生起始位与写设备ID
                  
                  //再次产生起始位与写设备ID（最后一位变为1）完成后：
                  3:if(DATA_WIDTH==8) rd_cnt<=5;                //若数据共8位，直接读完8位后产生主机应答并产生终止位
                    else rd_cnt<=4;                             //若数据多于8位，读8位后检测应答
                  
                  //读完一个字节并检测应答完成后：  
                  4:if(data_cnt==DATA_WIDTH-8) rd_cnt<=5;   //若未读数据刚好只差8位，读完这最后8位后产生应答并产生终止位
                    else rd_cnt<=4;                         //否则继续读下8位
                  
                  //读完最后8位数据，产生应答，产生终止位后：  
                  5:rd_cnt<=0;                              //读操作已经全部完成，读指令计数清零
                  
                  default:rd_cnt<=0;
                  endcase
                  
                  end
                  
        default:
            begin
               cmd<=0;
               rw_done<=0;
               wr_data_reg<=0;
               wr_cnt<=0;
               rd_cnt<=0;
               end
        endcase
  
  
  ////////////////////
  ////////////////////
  //位级执行层，执行命令层给出的指令，负责控制或读取总线：
  
  els_i2c_bit_shift #(
        .CLK_FREQ(50_000_000),
        .SCLK_FREQ(50_000)
    ) els_i2c_bit_shift_inst0 (
    .clk(clk),
    .reset_n(reset_n),
    
    .cmd(cmd),
    
    .tx_data(wr_data_reg),
    
    .go(trans_go),      
    .done(trans_done),
    
    .rx_data(rd_data_reg),
    
    .ack_o(ack_o),
    
    .i2c_sclk(i2c_sclk),
    .i2c_sdata(i2c_sdata)
    
    );
  
  
  /////////////////
  ////////////////
  //对最后输出的rw_done进行延时输出操作：
  
    reg delay_cnt_en;
    reg [31:0] i2c_delay_cnt;
    reg [31:0] i2c_delay_cnt_max_reg;
  
    //读写请求到来时，锁定住delay_cnt_max，防止其在数据传输过程中变化导致的影响：
    always @ (posedge clk)
    if(!reset_n) i2c_delay_cnt_max_reg<=0;
    else if(wr_req||rd_req) i2c_delay_cnt_max_reg<=i2c_delay_cnt_max;
    
    //减计数使能：
    always @ (posedge clk)
    if(!reset_n) delay_cnt_en<=0;
    else if(rw_done) delay_cnt_en<=1;                           //检测到rw_done后开始减计数
    else if(delay_cnt_en==1&&i2c_delay_cnt==0) delay_cnt_en<=0;
    
    
    //减计数计数器：
    always @ (posedge clk)
    if(!reset_n) i2c_delay_cnt<=0;
    else if(rw_done) i2c_delay_cnt<=i2c_delay_cnt_max_reg;  //rw_done到来时赋上减计数起始值
    else if(delay_cnt_en)begin
        if(i2c_delay_cnt==0) i2c_delay_cnt<=0;              //减计数成功减到零
        else i2c_delay_cnt<=i2c_delay_cnt-1;
        end
    else i2c_delay_cnt<=0;
    
    always @ (posedge clk)
    if(!reset_n) rw_done_post<=0;
    else if(delay_cnt_en==1&&i2c_delay_cnt==0) rw_done_post<=1;     //待减计数减为0输出最后延时后的rw_done_post
    else rw_done_post<=0;
    
    
endmodule
