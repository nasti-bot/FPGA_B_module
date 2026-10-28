`timescale 1ns / 1ps


//HDMI显示驱动的顶层模块，负责联系TMDS编码器与10倍速率串行发送器：
module els_hdmi_ctrl (
    input pixel_clk,    //驱动hdmi模块的时钟
    input pixel_clkx5,  //以10倍速率发送hdmi数据的5倍时钟（双边触发）
    input reset_n,
    
    input [7:0] din_blue,   //待发送的各图像数据
    input [7:0] din_green,
    input [7:0] din_red,
    
    input hsync,            //图像数据的行，场同步信号，以及数据使能信号
    input vsync,
    input de,
    
    output hdmi_clk_p,      //hdmi控制模块最终提供给hdmi接口的各差分信号
    output hdmi_clk_n,
    output [2:0] hdmi_data_p,
    output [2:0] hdmi_data_n
    );
    
    
    wire [9:0] data_blue,data_green,data_red;  //经过TMDS编码后的待发送的数据
  
  
  //////////////////
  //////////////////
  //TMDS编码器：
        //数据通道共3条，分别对R, G, B 数据进行编码：
  
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
  //10倍速率串行发送器，负责把经TMDS编码后的数据通过（5倍时钟+双边触发）的方式以10倍速率发送： 
    
    els_serdes_4b_10to1 serdes_4b_10to1 (
    
    .clkx5(pixel_clkx5),
    .reset_n(reset_n),
    
    .data_in_0(data_blue),          //Channel 0 : R
    .data_in_1(data_green),         //Channel 1 : G
    .data_in_2(data_red),           //Channel 2 : B
    .data_in_3(10'b11111_00000),    //Channel C : CLK（提供给HDMI屏幕）
    
    .data_out_0_p(hdmi_data_p[0]),
    .data_out_0_n(hdmi_data_n[0]),
    .data_out_1_p(hdmi_data_p[1]),
    .data_out_1_n(hdmi_data_n[1]),
    .data_out_2_p(hdmi_data_p[2]),
    .data_out_2_n(hdmi_data_n[2]),
    
    .data_out_3_p(hdmi_clk_p),
    .data_out_3_n(hdmi_clk_n)
    );
    
endmodule
