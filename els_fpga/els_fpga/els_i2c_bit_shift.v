`timescale 1ns / 1ps

//这是IIC协议的位级执行层，负责接收命令层的指令，控制或读取总线：
module els_i2c_bit_shift #(
    parameter CLK_FREQ=50_000_000,  //所使用的时钟频率
    parameter SCLK_FREQ=50_000      //i2c_sclk的频率
)
(
    input clk,
    input reset_n,
    
    input [5:0] cmd,            //命令层给出的指令
    
    input [7:0] tx_data,        //待发送数据
    
    input go,                   //开始执行指令的标志信号
    output reg done,           //完成一次指令的标志信号
    
    output reg [7:0] rx_data,   //读出的数据
    
    output reg ack_o,           //显示从机应答是否出现异常，为1表示从机应答异常
    
    output reg i2c_sclk,        //IIC总线
    inout i2c_sdata
    
    );
    
    
    ////////////////
    /////////////////
    //分频计数器，计数来控制i2c_sclk的翻转：
            
    localparam DIV_MCNT=CLK_FREQ/SCLK_FREQ/4-1;     //分频计数器最大值，由时钟频率与i2c_sclk频率决定，显示sclk多久变化一次
    
    reg div_cnt_en;
    
    reg [29:0] div_cnt;
    
    always @ (posedge clk)
    if(!reset_n) div_cnt<=0;
    else if(div_cnt_en) begin
        if(div_cnt==DIV_MCNT) div_cnt<=0;
        else div_cnt<=div_cnt+1;
        end
    else div_cnt<=0;
    
    
  //////////////////
  /////////////////
  //使用三段式状态机来执行相应指令：
    
    localparam  S_IDLE=7'b1,            //空闲态，不执行任何指令
                S_START=7'b10,          //起始态，控制总线产生起始位
                S_WRITE=7'b100,         //写状态，控制总线依次产生相应的8位数据
                S_CHECK_ACK=7'b1000,    //检测应答态，检查总线是否被从机拉低
                S_READ=7'b10000,        //读状态，依次读取总线上的8位数据
                S_GEN_ACK=7'b100000,    //产生应答态，拉高总线产生主机应答
                S_STOP=7'b1000000;      //终止态，控制总线产生终止位
    
    reg [6:0] state,next_state;
    
    
    localparam  C_START=6'b1,           //起始指令，产生起始位
                C_WRITE=6'b10,          //写指令
                C_READ=6'b100,          //读指令
                C_ACK=6'b1000,          //检测应答ACK指令，或是读数据后产生低电平应答ACK指令
                C_NACK=6'b10000,        //产生高电平应答NACK指令
                C_STOP=6'b100000;       //终止指令，产生终止位
                
    reg [4:0] sclk_cnt;         //显示sclk翻转的过程，sclk_cnt每计数4次，sclk翻转一个周期
    
    reg i2c_sdata_oe;           //i2c_sdata输出使能信号，为1表示此时是主机控制总线，为0表示是从机控制总线
    reg i2c_sdata_o;            //当主机控制总线时输出的i2c_sdata
    
    assign i2c_sdata=(!i2c_sdata_o&&i2c_sdata_oe)?1'b0:1'bz;  //IIC总线会自动拉高
    
                
    always @ (posedge clk)
    if(!reset_n) state<=S_IDLE;
    else state<=next_state;
    
    //状态转换：
    always @ (*)
    case(state)
    S_IDLE: if(go) begin                                        //接收到开始信号go后进行状态转换
                             
                if((cmd&C_START)) next_state=S_START;           //若指令中包含起始指令，就进入起始态
                else if((cmd&C_WRITE)) next_state=S_WRITE;      //否则若指令中包含写指令，进入写状态
                else if((cmd&C_READ)) next_state=S_READ;        //否则若指令中包含读指令，进入读状态
                else next_state=S_IDLE;                         //否则留在空闲态
                
                end
                
            else next_state=S_IDLE;
            
    S_START:if(div_cnt==DIV_MCNT&&sclk_cnt==3) begin            //当sclk翻转一个周期后进行状态转换
             
                if((cmd&C_WRITE)) next_state=S_WRITE;           //指令中含写指令时，进入写状态
                else next_state=S_START;                        //否则留在起始态
                        
                end
                
            else next_state=S_START;
            
    S_WRITE:if(div_cnt==DIV_MCNT&&sclk_cnt==31) next_state=S_CHECK_ACK;   //写完成后，进入检测应答态
    
            else next_state=S_WRITE;
            
    S_CHECK_ACK:if(div_cnt==DIV_MCNT&&sclk_cnt==3) begin        //当sclk翻转一个周期后进行状态转换
    
                    if((cmd&C_STOP)) next_state=S_STOP;         //指令中含终止指令时，进入终止态
                    else next_state=S_IDLE;                     //否则进入空闲态等下一个指令
                    
                    end
                    
                else next_state=S_CHECK_ACK;
              
    S_READ:if(div_cnt==DIV_MCNT&&sclk_cnt==31) next_state=S_GEN_ACK;    //读完成后，进入产生应答态
    
           else next_state=S_READ;
           
    S_GEN_ACK:if(div_cnt==DIV_MCNT&&sclk_cnt==3) begin      //当sclk翻转一个周期后进行状态转换
    
                    if((cmd&C_STOP)) next_state=S_STOP;     //指令中含终止指令时，进入终止态
                    else next_state=S_IDLE;                 //否则进入空闲态等下一个指令
                    
                    end
                    
              else next_state=S_GEN_ACK;
              
    S_STOP:if(div_cnt==DIV_MCNT&&sclk_cnt==3) next_state=S_IDLE;    //sclk经过一个周期后回到空闲态等下一个指令
    
           else next_state=S_STOP;
           
    default:next_state=S_IDLE;
    endcase
    
    
    always @ (posedge clk)
    if(!reset_n) begin
    
        rx_data<=0;
        sclk_cnt<=0;
        ack_o<=0;
        i2c_sclk<=1;
        i2c_sdata_oe<=0;
        i2c_sdata_o<=1;
        div_cnt_en<=0;
        
        end      
        
    else case(state)
    
    S_IDLE: begin
    
            if(go) div_cnt_en<=1;   //接收到开始信号立刻让分频计数器开始计数
            else div_cnt_en<=0;
            
            rx_data<=rx_data;
            
            ack_o<=0;
                 
            end
            
    S_START:begin
    
            if(div_cnt==DIV_MCNT) begin       //sclk计数器，分频计数器计满一次就增一次
                if(sclk_cnt==3) sclk_cnt<=0;
                else sclk_cnt<=sclk_cnt+1;
                end
                
            rx_data<=rx_data;
            
            ack_o<=ack_o;
            
            i2c_sdata_oe<=1;        //主机掌握总线控制权
            
            div_cnt_en<=1;
            
            case(sclk_cnt)          //sclk_cnt为相应值时，依次控制i2c_sclk与i2c_sdata_o的值，从而实现i2c_sclk周期性翻转同时i2c_sdata_o的值与之对齐
            
            0:begin
                i2c_sclk<=0;
                i2c_sdata_o<=1;
                end
                
            1:begin
                i2c_sclk<=1;
                i2c_sdata_o<=1;
                end
                
            2:begin
                i2c_sclk<=1;
                i2c_sdata_o<=0;
                end
                
            3:begin
                i2c_sclk<=0;
                i2c_sdata_o<=0;
                end
                
            default:begin
                i2c_sclk<=1;
                i2c_sdata_o<=1;
                end
            endcase
            
            end
            
    S_WRITE:begin
    
            if(div_cnt==DIV_MCNT) begin
                if(sclk_cnt==31) sclk_cnt<=0;   //由于要传8位数据，相当于sclk要翻转8个周期，一个周期对应sclk_cnt计四次，故共计32次
                else sclk_cnt<=sclk_cnt+1;
                end
                
            div_cnt_en<=1;
            
            ack_o<=0;
            
            rx_data<=rx_data;
            
            i2c_sdata_oe<=1;
            
            case(sclk_cnt)
            
            0,4,8,12,16,20,24,28:begin                                  //写状态时，根据sclk/4的值让i2c_sdata_o依次为待传数据的相应位（高位优先）
                                 i2c_sclk<=0;
                                 i2c_sdata_o<=tx_data[7-sclk_cnt[4:2]]; //如：sclk_cnt为0-3时，对应sclk的周期内sdata_o为tx_data[7]；为4-7时，对应sdata_o为tx_data[6];
                                 end
                                 
            1,5,9,13,17,21,25,29:begin
                                 i2c_sclk<=1;
                                 i2c_sdata_o<=i2c_sdata_o;
                                 end
                                 
            2,6,10,14,18,22,26,30:begin
                                  i2c_sclk<=1;
                                  i2c_sdata_o<=i2c_sdata_o;
                                  end
                                  
            3,7,11,15,19,23,27,31:begin
                                  i2c_sclk<=0;
                                  i2c_sdata_o<=i2c_sdata_o;
                                  end
                                  
            default:begin
                    i2c_sclk<=1;
                    i2c_sdata_o<=1;
                    end
             endcase
             
             end
             
    S_CHECK_ACK:begin
    
                if(div_cnt==DIV_MCNT) begin
                    if(sclk_cnt==3) sclk_cnt<=0;
                    else sclk_cnt<=sclk_cnt+1;
                    end
                    
                i2c_sdata_oe<=0;          //主机放下总线控制权，等待从机应答
                i2c_sdata_o<=0;
                
                div_cnt_en<=1;
                
                rx_data<=rx_data;
                
                case(sclk_cnt)
                
                0:begin
                    i2c_sclk<=0;
                    ack_o<=i2c_sdata;     //读取此时的sdata，收集从机应答
                    end
                    
                1:begin
                    i2c_sclk<=1;
                    ack_o<=ack_o;
                    end
                    
                2:begin
                    i2c_sclk<=1;
                    ack_o<=ack_o;
                    end
                    
                3:begin
                    i2c_sclk<=0;
                    ack_o<=ack_o;
                    end
                    
                default:begin
                        i2c_sclk<=1;
                        ack_o<=0;
                        end
                endcase
                
                end
                
    S_READ:begin
    
            if(div_cnt==DIV_MCNT) begin
                if(sclk_cnt==31) sclk_cnt<=0;
                else sclk_cnt<=sclk_cnt+1;
                end
                
            i2c_sdata_oe<=0;        //读状态时主机不控制总线
            i2c_sdata_o<=0;
            
            div_cnt_en<=1;
            
            ack_o<=ack_o;
            
            case(sclk_cnt)
            
            0,4,8,12,16,20,24,28:begin
                                 i2c_sclk<=0;
                                 rx_data<=rx_data;
                                 end
                                 
            1,5,9,13,17,21,25,29:begin
                                 i2c_sclk<=1;
                                 rx_data<=rx_data;
                                 end
                                 
            2,6,10,14,18,22,26,30:begin
                                  i2c_sclk<=1;
                                  if(div_cnt==DIV_MCNT/2) rx_data[7-sclk_cnt[4:2]]<=i2c_sdata; //读取此时的sdata，给到读数据的相应位（高位优先）；如此时sclk_cnt为2，则读出的bit给rx_data[7]
                                  end
                                  
            3,7,11,15,19,23,27,31:begin
                                  i2c_sclk<=0;
                                  rx_data<=rx_data;
                                  end
                                  
            default:begin 
                    i2c_sclk<=1;
                    rx_data<=0;
                    end
            endcase
            
            end
            
    S_GEN_ACK:begin
    
             if(div_cnt==DIV_MCNT) begin
                if(sclk_cnt==3) sclk_cnt<=0;
                else sclk_cnt<=sclk_cnt+1;
                end
                
             i2c_sdata_oe<=1;         //主机控制总线产生应答
             
             div_cnt_en<=1;
             
             ack_o<=ack_o;
             
             rx_data<=rx_data;
             
             case(sclk_cnt)
             
             0:begin
               i2c_sclk<=0;
               
               if(cmd&C_ACK) i2c_sdata_o<=0;         //此时表示主机产生低电平应答ACK
               else if(cmd&C_NACK) i2c_sdata_o<=1;   //此时主机产生高电平应答NACK
               
               end
               
             1:begin
              i2c_sclk<=1;
              i2c_sdata_o<=i2c_sdata_o;
              end
              
             2:begin
              i2c_sclk<=1;
              i2c_sdata_o<=i2c_sdata_o;
              end
              
             3:begin
              i2c_sclk<=0;
              i2c_sdata_o<=i2c_sdata_o;
              end
              
             default:begin
                    i2c_sclk<=1;
                    i2c_sdata_o<=1;
                    end
             endcase
             
             end
             
    S_STOP:begin
    
            if(div_cnt==DIV_MCNT) begin
                if(sclk_cnt==3) sclk_cnt<=0;
                else sclk_cnt<=sclk_cnt+1;
                end
                
            div_cnt_en<=1;
            
            rx_data<=rx_data;
            
            ack_o<=ack_o;
            
            i2c_sdata_oe<=1;
            
            case(sclk_cnt)      //此时主机根据sclk_cnt依次控制i2c_sdata产生终止标志信号
            
            0:begin
             i2c_sclk<=0;
             i2c_sdata_o<=0;
             end
             
            1:begin
             i2c_sclk<=1;
             i2c_sdata_o<=0;
             end
             
            2:begin
             i2c_sclk<=1;
             i2c_sdata_o<=1;
             end
             
            3:begin
             i2c_sclk<=1;
             i2c_sdata_o<=1;
             end
             
            default:begin
                    i2c_sclk<=1;
                    i2c_sdata_o<=1;
                    end
            endcase
            
            end
            
    default:begin
        rx_data<=0;
        sclk_cnt<=0;
        ack_o<=0;
        i2c_sclk<=1;
        i2c_sdata_oe<=0;
        i2c_sdata_o<=1;
        div_cnt_en<=0;
        end
        
    endcase


    //完成一次指令标志的产生：
    always @ (posedge clk)
    if(!reset_n) done<=0;
    else if(state!=S_IDLE&&next_state==S_IDLE) done<=1;     //当主机从非空闲态回到空闲态，说明完成了一次指令
    else done<=0;
       
    
endmodule
