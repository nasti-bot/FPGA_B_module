`timescale 1ns / 1ps


//HDMI显示驱动的顶层模块，负责联系TMDS编码器与串行发送器：
module els_hdmi_tx (

    input pixel_clk,    //驱动hdmi模块的时钟
    input pixel_clkx2,  //以10倍速率发送hdmi数据的2倍时钟
    input pixel_clkx5,  //以10倍速率发送hdmi数据的5倍时钟
    input reset_n,
    
    input [7:0] din_blue,   //待发送的各图像数据
    input [7:0] din_green,
    input [7:0] din_red,
    
    input hsync,            //图像数据的行，场同步信号，以及数据使能信号
    input vsync,
    input de,
    
    output [4:0] hdmi_tx_c_o,
    output [4:0] hdmi_tx_0_o,
    output [4:0] hdmi_tx_1_o,
    output [4:0] hdmi_tx_2_o
    
    );
    
    
  //////////////////
  //////////////////
  //TMDS编码器：
        //数据通道共3条，分别对R, G, B 数据进行编码，时钟通道Channel C的不需要编码：
        
    wire [9:0] data_blue,data_green,data_red;  //经过TMDS编码后的待发送的数据
  
    //Channel 0:  B
    els_tmds_encoder TMDS_encoder_channel0 (
    
    .clk(pixel_clk),
    .reset_n(reset_n),
    
    .data_in(din_blue),
    
    .c0(hsync),
    .c1(vsync),
    .de(de),
    
    .q_out(data_blue)
    );
    
    //Channel 1:  G
    els_tmds_encoder TMDS_encoder_channel1 (
    
    .clk(pixel_clk),
    .reset_n(reset_n),
    
    .data_in(din_green),
    
    .c0(1'b0),
    .c1(1'b0),
    .de(de),
    
    .q_out(data_green)
    );
    
    //Channel 2:  R
    els_tmds_encoder TMDS_encoder_channel2 (
    
    .clk(pixel_clk),
    .reset_n(reset_n),
    
    .data_in(din_red),
    
    .c0(1'b0),
    .c1(1'b0),
    .de(de),
    
    .q_out(data_red)
    );
    
    
  /////////////////
  /////////////////
  //TMDS编码后的数据的发送模块，对接TMDS编码器与T35F324开发板上的HDMI串行发送器：
     
    wire [9:0] hdmi_tx_c_data= 10'b11111_00000,     //Channel C待传数据（CLK）
               hdmi_tx_0_data= data_blue,           //Channel 0待传数据（B）
               hdmi_tx_1_data= data_green,          //Channel 1待传数据（G）
               hdmi_tx_2_data= data_red;            //Channel 2待传数据（R）
    
    reg hdmi_tx_cnt;                               //HDMI传输计数，显示此时是在传输的哪个步骤
    
	reg [9:0] hdmi_tx_c_reg,                       //寄存各Channel待传数据
	          hdmi_tx_0_reg,
	          hdmi_tx_1_reg,
	          hdmi_tx_2_reg;
	      
	
	//传输计数器：          
	always @ (posedge pixel_clkx2)
	if(!reset_n) hdmi_tx_cnt<=0;
	else hdmi_tx_cnt<=~hdmi_tx_cnt;
	         
	
	//寄存器的赋值与移位模块：         
	always @(posedge pixel_clkx2)
    if(!reset_n) begin
        	hdmi_tx_c_reg<=0;
        	hdmi_tx_0_reg<=0;
        	hdmi_tx_1_reg<=0;
        	hdmi_tx_2_reg<=0;
        	end
        	
	else begin
	
	   //当传输计数为0时，寄存各Channel的待传数据：
	   if(!hdmi_tx_cnt) begin
	        hdmi_tx_c_reg<=hdmi_tx_c_data;
        	hdmi_tx_0_reg<=hdmi_tx_0_data;
        	hdmi_tx_1_reg<=hdmi_tx_1_data;
        	hdmi_tx_2_reg<=hdmi_tx_2_data;
        	end
       
       
       //当传输计数为1时，让寄存的10位数据右移5位：
       else begin
            hdmi_tx_c_reg<=hdmi_tx_c_reg>>5;
            hdmi_tx_0_reg<=hdmi_tx_0_reg>>5;
            hdmi_tx_1_reg<=hdmi_tx_1_reg>>5;
            hdmi_tx_2_reg<=hdmi_tx_2_reg>>5;
            end  
	end
	
        //hdmi并行输出的永远是寄存的10位数据的后5位，从而实现按序分两次并行传输10位数据：
        assign hdmi_tx_c_o=hdmi_tx_c_reg[4:0];
        assign hdmi_tx_0_o=hdmi_tx_0_reg[4:0];
        assign hdmi_tx_1_o=hdmi_tx_1_reg[4:0];
        assign hdmi_tx_2_o=hdmi_tx_2_reg[4:0];
    
    
    
endmodule
