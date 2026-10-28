`timescale 1ns / 1ps

module els_camera_init #(
    parameter DATA_WIDTH=8,
    parameter ADDR_WIDTH=16,
    parameter OV_IMAGE_WIDTH=800,
    parameter OV_IMAGE_HEIGHT=480
)
(
    input clk,
    input reset_n,
    
    output reg init_done,   //初始化完成标志信号
    
    output i2c_sclk,
    
    inout i2c_sdata
    
    );
    
    localparam LUT_SIZE=281;    //所使用的查找表的大小
    

  //////////////
  //////////////
  //延时0.5s后给出开始初始化信号，进行摄像头初始化：
    
    reg [29:0] start_delay_cnt;
    reg start_flag;
    
    always @ (posedge clk)
    if(!reset_n) start_delay_cnt<=0;
    else if(start_delay_cnt>=25_000_000) start_delay_cnt<=25_000_000;    //计数器延时
    else start_delay_cnt<=start_delay_cnt+1;
    
    always @ (posedge clk)
    if(!reset_n) start_flag<=0;
    else if(start_delay_cnt==25_000_000-1) start_flag<=1;
    else start_flag<=0;
    
   
  ////////////////
  //////////////// 
  //使用三段式状态机进行IIC协议的写数据操作：
    
    reg i2c_wr_req;
    reg [30:0] i2c_delay_cnt_max;       //i2c传输完成后延时给出i2c_rw_done信号
    reg [15:0] init_cnt;
    
    wire i2c_ack;
    wire i2c_rw_done;
    
    localparam S_IDLE=4'b1,         //空闲状态
               S_WR_PRE=4'b10,      //写准备状态
               S_WR=4'b100,         //写状态
               S_INIT_DONE=4'b1000; //完成初始化状态
               
    reg [3:0] state,next_state;
    
    always @ (posedge clk)
    if(!reset_n) state<=S_IDLE;
    else state<=next_state;
    
    always @ (*)
    case(state)
    
    S_IDLE:if(start_flag) next_state=S_WR_PRE;   //等待start_flag到达后进入写准备状态准备开始写
           else next_state=S_IDLE;
    
    S_WR_PRE:if(i2c_wr_req) next_state=S_WR;     //写准备状态持续两个周期，第二个周期时也就是i2c_wr_req信号为1时正式进入写状态
             else next_state=S_WR_PRE;
    
    S_WR:if(i2c_rw_done&&init_cnt==LUT_SIZE-1) next_state=S_INIT_DONE;  //当数据全部写完时进入完成状态
         else if(i2c_rw_done) next_state=S_WR_PRE;                      //i2c传输成功后回到准备状态，准备进行下一次写
         else next_state=S_WR;
         
    S_INIT_DONE:next_state=S_INIT_DONE;
    
    default:next_state=S_IDLE;
    endcase
    
    always @ (posedge clk)
    if(!reset_n) begin
        init_done<=0;
        i2c_wr_req<=0;
        i2c_delay_cnt_max<=0;
        init_cnt<=0;
        end
        
    else begin
    
        //init_done:
        if(state==S_INIT_DONE) init_done<=1;
        else init_done<=0;
        
        //i2c_wr_req:
        if((state==S_WR_PRE)&&(!i2c_wr_req)) i2c_wr_req<=1;  //写准备状态的第一个周期产生i2c_wr_req信号，第二个周期时i2c_wr_req为1
        else i2c_wr_req<=0;
        
        //i2c_delay_cnt_max:
        if(init_cnt==1) i2c_delay_cnt_max<=2_500_000;       //由于要求，写完第一个数据后需要进行延时使摄像头充分复位
        else i2c_delay_cnt_max<=0;
        
        //init_cnt:
        if(state==S_IDLE) init_cnt<=0;
        else if(i2c_rw_done&&!i2c_ack) init_cnt<=init_cnt+1;    //每写完一次就让init_cnt自增进行下个数据的写
        
        end
    
  ///////////////
  //////////////
  //调用查找表，根据init_cnt输出对应的lut_data：
    
    wire [24:0] lut_data;
        
    ov5640_initial_table #(
      .DATA_WIDTH(DATA_WIDTH),
      .ADDR_WIDTH(ADDR_WIDTH),
      .IMAGE_WIDTH(OV_IMAGE_WIDTH),
      .IMAGE_HEIGHT(OV_IMAGE_HEIGHT)
    )
    u0 
    (
    .clk(clk),
    .addr(init_cnt),
    
    .q(lut_data)
    );
    
   
   ////////////////
   ///////////////
   //调用IIC协议发送模块，将初始化数据分别写入摄像头的寄存器中： 
    
    els_i2c_ctrl i2c_ctrl_inst (
    .clk(clk),
    .reset_n(reset_n),
    
    .device_id(8'h78),
    .wr_req(i2c_wr_req),

    .wr_data(lut_data[7:0]),        //查找表的后8位是i2c的写数据
    .addr(lut_data[23:8]),          //查找表的前16位是i2c的写地址
    .addr_mode(1'b1),
    
    .i2c_sclk(i2c_sclk),
    .ack(i2c_ack),

    .rw_done_post(i2c_rw_done),
    .i2c_delay_cnt_max(i2c_delay_cnt_max),
    
    .i2c_sdata(i2c_sdata)
    );
        
    
endmodule
