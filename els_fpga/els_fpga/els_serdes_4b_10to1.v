`timescale 1ns / 1ps


//10倍速率串行发送模块，把编码后数据依次发送：
module els_serdes_4b_10to1(
    input clkx5,
    input reset_n,
    
    input [9:0] data_in_0,  //各Channel待发送数据
    input [9:0] data_in_1,
    input [9:0] data_in_2,
    input [9:0] data_in_3,
    
    output data_out_0_p,   //各差分信号
    output data_out_0_n,
    output data_out_1_p,
    output data_out_1_n,
    output data_out_2_p,
    output data_out_2_n,
    output data_out_3_p,
    output data_out_3_n
    
    );
    
    
  //////////////////////
  /////////////////////
  //移位操作模块：负责把待发送各数据依次移位准备发送
  
  
        //send_cnt计数器，对clkx5的周期进行计数：
        reg [2:0] send_cnt;
        
        always @ (posedge clkx5)
        if(!reset_n) send_cnt<=0;
        else begin
            if(send_cnt>=4) send_cnt<=0;
            else send_cnt<=send_cnt+1;
            end

    //数据移位模块，
    
    reg [4:0] tmds_shift_0_h,tmds_shift_1_h,tmds_shift_2_h,tmds_shift_3_h,
              tmds_shift_0_l,tmds_shift_1_l,tmds_shift_2_l,tmds_shift_3_l;
    
    wire [4:0] tmds_0_h={data_in_0[8],data_in_0[6],data_in_0[4],data_in_0[2],data_in_0[0]};  //待在Channel 0，时钟上升沿发送的数据
    
    wire [4:0] tmds_0_l={data_in_0[9],data_in_0[7],data_in_0[5],data_in_0[3],data_in_0[1]};  //待在Channel 0，时钟下降沿发送的数据
     
    wire [4:0] tmds_1_h={data_in_1[8],data_in_1[6],data_in_1[4],data_in_1[2],data_in_1[0]};  //待在Channel 1，时钟上升沿发送的数据
    
    wire [4:0] tmds_1_l={data_in_1[9],data_in_1[7],data_in_1[5],data_in_1[3],data_in_1[1]};  //待在Channel 1，时钟下降沿发送的数据
    
    wire [4:0] tmds_2_h={data_in_2[8],data_in_2[6],data_in_2[4],data_in_2[2],data_in_2[0]};  //待在Channel 2，时钟上升沿发送的数据
    
    wire [4:0] tmds_2_l={data_in_2[9],data_in_2[7],data_in_2[5],data_in_2[3],data_in_2[1]};  //待在Channel 2，时钟下降沿发送的数据
    
    wire [4:0] tmds_3_h={data_in_3[8],data_in_3[6],data_in_3[4],data_in_3[2],data_in_3[0]};  //待在Channel 3，时钟上升沿发送的数据
    
    wire [4:0] tmds_3_l={data_in_3[9],data_in_3[7],data_in_3[5],data_in_3[3],data_in_3[1]};  //待在Channel 3，时钟下降沿发送的数据
    
        
    always @ (posedge clkx5)
    if(!reset_n) begin
        tmds_shift_0_h<=0;
        tmds_shift_1_h<=0;
        tmds_shift_2_h<=0;
        tmds_shift_3_h<=0;
        
        tmds_shift_0_l<=0;
        tmds_shift_1_l<=0;
        tmds_shift_2_l<=0;
        tmds_shift_3_l<=0;
        end
        
    else if(send_cnt==4) begin              //当clkx5走过5个周期，即clk走过1个周期时（此时图像数据更新一次），将待发送数据更新
        tmds_shift_0_h<=tmds_0_h;
        tmds_shift_1_h<=tmds_1_h;
        tmds_shift_2_h<=tmds_2_h;
        tmds_shift_3_h<=tmds_3_h;
        
        tmds_shift_0_l<=tmds_0_l;
        tmds_shift_1_l<=tmds_1_l;
        tmds_shift_2_l<=tmds_2_l;
        tmds_shift_3_l<=tmds_3_l;
        end
        
    else begin                                 //其余时刻，让各移位寄存器右移，发送其最低位，以此实现依次全部发送
        tmds_shift_0_h<=tmds_shift_0_h>>1;
        tmds_shift_1_h<=tmds_shift_1_h>>1;
        tmds_shift_2_h<=tmds_shift_2_h>>1;
        tmds_shift_3_h<=tmds_shift_3_h>>1;
        
        tmds_shift_0_l<=tmds_shift_0_l>>1;
        tmds_shift_1_l<=tmds_shift_1_l>>1;
        tmds_shift_2_l<=tmds_shift_2_l>>1;
        tmds_shift_3_l<=tmds_shift_3_l>>1;
        end
                
    
  ////////////////////
  ///////////////////
  //双沿发送数据：
  
    wire data_out_0,data_out_1,data_out_2,data_out_3;
      
    ODDR #(
      .DDR_CLK_EDGE("SAME_EDGE"), // "OPPOSITE_EDGE" or "SAME_EDGE" 
      .INIT(1'b0),    // Initial value of Q: 1'b0 or 1'b1
      .SRTYPE("SYNC") // Set/Reset type: "SYNC" or "ASYNC" 
   ) 
   ODDR_inst0 
   (
      .Q(data_out_0),   // 1-bit DDR output
      
      .C(clkx5),   // 1-bit clock input
      .CE(reset_n), // 1-bit clock enable input
      
      .D1(tmds_shift_0_h[0]), // 1-bit data input (positive edge)
      .D2(tmds_shift_0_l[0]), // 1-bit data input (negative edge)
      
      .R(1'b0),   // 1-bit reset
      .S(1'b0)    // 1-bit set
   );
   
   ODDR #(
      .DDR_CLK_EDGE("SAME_EDGE"), 
      .INIT(1'b0), 
      .SRTYPE("SYNC") 
   ) 
   ODDR_inst1 
   (
      .Q(data_out_1), 
      
      .C(clkx5), 
      .CE(reset_n), 
      
      .D1(tmds_shift_1_h[0]),
      .D2(tmds_shift_1_l[0]),
      
      .R(1'b0), 
      .S(1'b0) 
   );
   
   ODDR #(
      .DDR_CLK_EDGE("SAME_EDGE"), 
      .INIT(1'b0), 
      .SRTYPE("SYNC") 
   ) 
   ODDR_inst2 
   (
      .Q(data_out_2), 
      
      .C(clkx5),   
      .CE(reset_n),
      
      .D1(tmds_shift_2_h[0]),
      .D2(tmds_shift_2_l[0]), 
      
      .R(1'b0), 
      .S(1'b0)  
   );
   
   ODDR #(
      .DDR_CLK_EDGE("SAME_EDGE"), 
      .INIT(1'b0),  
      .SRTYPE("SYNC")
   ) 
   ODDR_inst3 
   (
      .Q(data_out_3), 
      
      .C(clkx5),  
      .CE(reset_n),
      
      .D1(tmds_shift_3_h[0]),
      .D2(tmds_shift_3_l[0]),
      
      .R(1'b0),  
      .S(1'b0)   
   );
   
   
 /////////////////////////
 ////////////////////////
 //将待输送数据处理为两个差分信号后正式输出：
 
   OBUFDS #(
      .IOSTANDARD("DEFAULT"), // Specify the output I/O standard
      .SLEW("SLOW")           // Specify the output slew rate
   ) 
   OBUFDS_inst0 
   (
      .O(data_out_0_p),     // Diff_p output (connect directly to top-level port)
      .OB(data_out_0_n),   // Diff_n output (connect directly to top-level port)
      
      .I(data_out_0)      // Buffer input
   );
   
   OBUFDS #(
      .IOSTANDARD("DEFAULT"),
      .SLEW("SLOW")       
   ) 
   OBUFDS_inst1 
   (
      .O(data_out_1_p),   
      .OB(data_out_1_n),  
      
      .I(data_out_1)   
   );
   
   OBUFDS #(
      .IOSTANDARD("DEFAULT"), 
      .SLEW("SLOW")       
   ) 
   OBUFDS_inst2 
   (
      .O(data_out_2_p),   
      .OB(data_out_2_n), 
      
      .I(data_out_2)   
   );
   
   OBUFDS #(
      .IOSTANDARD("DEFAULT"), 
      .SLEW("SLOW")      
   ) 
   OBUFDS_inst3 
   (
      .O(data_out_3_p),   
      .OB(data_out_3_n),  
      
      .I(data_out_3)  
   );
  
   
endmodule
